using Test

if !isdefined(Main, :SnapshotGenerator)
    include("../src/SnapshotGenerator/SnapshotGenerator.jl")
end
using .SnapshotGenerator: SnapshotCase
using .SnapshotGenerator.Runner: prepare_work_dir

@testset "Runner Workspace Preparation Test" begin
    # Create temporary directory for testing
    test_work_base = mktempdir()
    
    # SnapshotCase for test
    case = SnapshotCase(999, "pending", [0.5], "", 0.0)
    
    # Expected directory path
    expected_dir = joinpath(test_work_base, "case_999")
    
    # 1. First invocation: directory should be created
    actual_dir = prepare_work_dir(case, test_work_base)
    
    @test actual_dir == expected_dir
    @test isdir(expected_dir)
    
    # 2. Add dummy file inside
    dummy_file = joinpath(expected_dir, "dummy.txt")
    write(dummy_file, "temp content")
    @test isfile(dummy_file)
    
    # 3. Second invocation: directory should be cleaned and empty
    prepare_work_dir(case, test_work_base)
    
    @test !isfile(dummy_file)
    @test isdir(expected_dir)
    @test isempty(readdir(expected_dir))
    
    # Clean up test_work_base
    rm(test_work_base, recursive=true, force=true)
end

@testset "Runner Dynamic Config Generation Test" begin
    using .SnapshotGenerator.Runner: generate_case_configs
    using .SnapshotGenerator.Sampler.H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig, generate_test_config, load_config
    using JSON

    test_work_base = mktempdir()
    case_dir = joinpath(test_work_base, "case_101")
    mkpath(case_dir)

    # Prepare case
    case = SnapshotCase(101, "pending", fill(0.75, 16), "", 0.0)

    # Prepare config
    base_config = generate_test_config()
    density_map = DensityMapConfig(4, 4, fill(0.5, 16), 0, 16, 1.0, Tuple{Int, Int}[])
    manufacturing = ManufacturingConfig(2*base_config.tsv.radius, 50e-6, 0.0, 0.0)
    tsv_config = TSVConfig(:density, Tuple{Float64, Float64}[], base_config.tsv.radius, base_config.tsv.height, density_map, manufacturing, nothing)

    config = ModelConfig(
        base_config.materials,
        base_config.layers,
        tsv_config,
        base_config.lx,
        base_config.ly,
        base_config.pg_dpth,
        base_config.s_dpth,
        base_config.d_ufill,
        base_config.r_bump,
        base_config.snapshot_enabled,
        base_config.snapshot_dir,
        base_config.fixed_silicon_lambda,
        base_config.epsilon,
        base_config.max_iter
    )

    # Call generate_case_configs
    generate_case_configs(case, config, case_dir)

    # Verify files exist
    config_file = joinpath(case_dir, "config.json")
    tsv_config_file = joinpath(case_dir, "tsv_config.json")
    @test isfile(config_file)
    @test isfile(tsv_config_file)

    # Verify content of tsv_config.json
    tsv_json = JSON.parsefile(tsv_config_file)
    @test tsv_json["tsv_mode"] == "density"
    @test tsv_json["density_map"]["mu"] == case.mu

    # Verify it can be loaded back using load_config
    loaded_config = load_config(config_file, tsv_config_file)
    @test loaded_config.tsv.mode == :density
    @test loaded_config.tsv.density.mu == case.mu

    # Clean up
    rm(test_work_base, recursive=true, force=true)
end

@testset "Runner Timeout and Error Handling Test" begin
    using .SnapshotGenerator.Runner: run_simulation_case, default_model_config
    using .SnapshotGenerator.Sampler.H2MainExt.ConfigLoader: ModelConfig

    test_work_base = mktempdir()
    case = SnapshotCase(102, "pending", fill(0.5, 16), "", 0.0)
    config = default_model_config()

    # 1. Immediate failure test (invalid solver directory causing run.jl not found or execution failure)
    nonexistent_solver_dir = joinpath(test_work_base, "nonexistent_solver")
    status_fail, snap_fail, err_fail = run_simulation_case(
        case, nonexistent_solver_dir, test_work_base, config
    )
    @test status_fail == "failed"
    @test isempty(snap_fail)
    @test !isempty(err_fail)

    # 2. Timeout test
    # Create a mock solver directory with a run.jl that sleeps
    mock_solver_dir = joinpath(test_work_base, "mock_solver")
    mkpath(mock_solver_dir)
    mock_run_jl = joinpath(mock_solver_dir, "run.jl")
    write(mock_run_jl, """
    println("Mock solver started...")
    sleep(10)
    println("Mock solver finished.")
    """)
    
    # We call with a short timeout_sec=2
    status_time, snap_time, err_time = run_simulation_case(
        case, mock_solver_dir, test_work_base, config; timeout_sec=2
    )
    @test status_time == "timeout"
    @test isempty(snap_time)
    
    # Clean up
    rm(test_work_base, recursive=true, force=true)
end

@testset "Runner Successful Simulation and Post-Processing Test" begin
    using .SnapshotGenerator.Runner: run_simulation_case, default_model_config
    using .SnapshotGenerator.Types: SnapshotManifest, SnapshotCase
    using .SnapshotGenerator.Manifest: save_manifest
    using JLD2
    using JSON3
    using Dates

    # Create temp base dir
    test_work_base = mktempdir()
    
    # Paths for test data and manifest
    test_data_dir = joinpath(test_work_base, "data")
    mkpath(test_data_dir)
    test_manifest_path = joinpath(test_data_dir, "manifest.json")
    
    # Create SnapshotCase and SnapshotManifest
    case = SnapshotCase(105, "pending", fill(0.1, 16), "", 0.0)
    manifest = SnapshotManifest(string(now()), Dict{String, Float64}(), Dict{String, Any}(), [case])
    save_manifest(manifest, test_manifest_path)

    # Create mock solver directory
    mock_solver_dir = joinpath(test_work_base, "mock_solver")
    mkpath(mock_solver_dir)
    cp(joinpath(@__DIR__, "../Project.toml"), joinpath(mock_solver_dir, "Project.toml"))
    if isfile(joinpath(@__DIR__, "../Manifest.toml"))
        cp(joinpath(@__DIR__, "../Manifest.toml"), joinpath(mock_solver_dir, "Manifest.toml"))
    end
    mock_run_jl = joinpath(mock_solver_dir, "run.jl")
    
    write(mock_run_jl, """
    using JLD2
    
    snap_idx = findfirst(x -> x == "--snapshot", ARGS)
    if snap_idx !== nothing && snap_idx < length(ARGS)
        snap_path = ARGS[snap_idx + 1]
        mkpath(dirname(snap_path))
        JLD2.jldopen(snap_path, "w") do file
            file["theta"] = [1.0 2.0; 3.0 4.0]
            file["other_val"] = "keep_me"
        end
    end
    """)

    config = default_model_config()
    
    # Run the simulation case with manifest and data_dir parameters
    status, snap_file, err = run_simulation_case(
        case, mock_solver_dir, test_work_base, config;
        manifest=manifest, manifest_path=test_manifest_path, data_dir=test_data_dir
    )

    @test status == "success"
    
    # Verify final JLD2 path and presence
    expected_jld2_path = joinpath(test_data_dir, "raw", "snapshot_105.jld2")
    @test isfile(expected_jld2_path)
    
    # Verify temporary file is cleaned up
    case_dir = joinpath(test_work_base, "case_105")
    temp_snap_path = joinpath(case_dir, "snapshot.jld2")
    @test !isfile(temp_snap_path)
    
    # Verify content of final JLD2 file
    JLD2.jldopen(expected_jld2_path, "r") do file
        @test haskey(file, "temperature")
        @test file["temperature"] == [1.0 2.0; 3.0 4.0]
        @test haskey(file, "other_val")
        @test file["other_val"] == "keep_me"
        @test haskey(file, "metadata")
        
        metadata = file["metadata"]
        @test haskey(metadata, "snapshot_id")
        @test haskey(metadata, "mu")
        @test metadata["mu"] == fill(0.1, 16)
        @test haskey(metadata, "timestamp")
    end
    
    # Verify updated manifest
    loaded_manifest = JSON3.read(read(test_manifest_path, String), SnapshotManifest)
    updated_case = loaded_manifest.cases[1]
    @test updated_case.status == "success"
    @test updated_case.filepath == expected_jld2_path
    @test updated_case.runtime > 0.0
    
    # Clean up
    rm(test_work_base, recursive=true, force=true)
end



