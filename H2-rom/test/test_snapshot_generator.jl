using Test
using JSON3
using JLD2
using Dates

# Include SnapshotGenerator
include("../src/SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator

@testset "Snapshot Generator Integration Test" begin
    # Create a temporary directory for the workspace
    test_work_base = mktempdir()
    
    # 1. Setup mock solver directory
    mock_solver_dir = joinpath(test_work_base, "mock_solver")
    mkpath(mock_solver_dir)
    
    # Copy Project.toml/Manifest.toml to the mock solver dir so Julia can activate it
    cp(joinpath(@__DIR__, "../Project.toml"), joinpath(mock_solver_dir, "Project.toml"))
    if isfile(joinpath(@__DIR__, "../Manifest.toml"))
        cp(joinpath(@__DIR__, "../Manifest.toml"), joinpath(mock_solver_dir, "Manifest.toml"))
    end
    
    # Write mock run.jl which creates a dummy JLD2 file
    mock_run_jl = joinpath(mock_solver_dir, "run.jl")
    write(mock_run_jl, """
    using JLD2
    snap_idx = findfirst(x -> x == "--snapshot", ARGS)
    if snap_idx !== nothing && snap_idx < length(ARGS)
        snap_path = ARGS[snap_idx + 1]
        mkpath(dirname(snap_path))
        JLD2.jldopen(snap_path, "w") do file
            file["theta"] = [1.0 2.0; 3.0 4.0]
            file["other_val"] = "mocked"
        end
    end
    """)
    
    # Generate baseline config JSONs inside mock_solver_dir
    # We will use SnapshotGenerator's runner utilities or raw dicts to build basic config files
    using .SnapshotGenerator.Sampler.H2MainExt.ConfigLoader: generate_test_config
    using .SnapshotGenerator.Runner: generate_case_configs, SnapshotCase
    
    base_config = generate_test_config()
    # Create mock Case and ModelConfig to write baseline configs using generate_case_configs
    dummy_case = SnapshotCase(0, "pending", fill(0.5, 16), "", 0.0)
    
    # Ensure config setup is compatible with 4x4 density map
    using .SnapshotGenerator.Sampler.H2MainExt.ConfigLoader: ModelConfig, TSVConfig, DensityMapConfig, ManufacturingConfig
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
    
    # Save baseline configuration to mock solver directory
    generate_case_configs(dummy_case, config, mock_solver_dir)
    
    # Setup data directory
    test_data_dir = joinpath(test_work_base, "data")
    
    # 2. Execute run_generator
    n_cases = 3
    manifest = run_generator(n_cases; solver_dir=mock_solver_dir, data_dir=test_data_dir)
    
    # 3. Assertions
    @test manifest isa SnapshotManifest
    @test length(manifest.cases) == n_cases
    
    # Check that manifest.json is created
    manifest_path = joinpath(test_data_dir, "manifest.json")
    @test isfile(manifest_path)
    
    # Read manifest and check cases
    loaded_manifest = JSON3.read(read(manifest_path, String), SnapshotManifest)
    @test length(loaded_manifest.cases) == n_cases
    
    for c in loaded_manifest.cases
        @test c.status == "success"
        @test isfile(c.filepath)
        @test endswith(c.filepath, "snapshot_$(c.id).jld2")
        
        # Verify the file contents
        JLD2.jldopen(c.filepath, "r") do file
            @test haskey(file, "temperature")
            @test file["temperature"] == [1.0 2.0; 3.0 4.0]
            @test haskey(file, "metadata")
            
            meta = file["metadata"]
            @test haskey(meta, "snapshot_id")
            @test haskey(meta, "mu")
            @test length(meta["mu"]) == 16
        end
    end
    
    # Cleanup
    rm(test_work_base, recursive=true, force=true)
end
