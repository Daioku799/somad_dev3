using Test

# Load SnapshotGenerator
include("../src/SnapshotGenerator/SnapshotGenerator.jl")
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

