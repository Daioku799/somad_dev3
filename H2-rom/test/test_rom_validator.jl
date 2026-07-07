using Test

# まだ ROMValidator.jl は存在しないため、includeは失敗するはずです
if !isdefined(Main, :ROMValidator)
    include("../src/ROMValidator/ROMValidator.jl")
end
using .ROMValidator: ValidationResult, ValidationSummary, get_validation_samples, load_test_case, calculate_l2_error, calculate_tmax_error, calculate_hotspot_error, judge_accuracy, evaluate_validation_results, measure_dataset_size, measure_fvm_runtime
using JLD2
using JSON3

@testset "ROMValidator Types Test" begin
    # ValidationResult のインスタンス化テスト
    result = ValidationResult(
        "test_sample_01",
        0.015,
        1.2,
        0.005,
        true
    )

    @test result.sample_id == "test_sample_01"
    @test result.relative_l2_error == 0.015
    @test result.tmax_error == 1.2
    @test result.hotspot_dist == 0.005
    @test result.is_passed == true

    # ValidationSummary のインスタンス化テスト
    summary = ValidationSummary(
        [result],
        Dict("relative_l2_error" => 0.015, "tmax_error" => 1.2, "hotspot_dist" => 0.005),
        Dict("relative_l2_error" => 0.015, "tmax_error" => 1.2, "hotspot_dist" => 0.005),
        :validated
    )

    @test length(summary.results) == 1
    @test summary.mean_metrics["relative_l2_error"] == 0.015
    @test summary.max_metrics["tmax_error"] == 1.2
    @test summary.overall_status == :validated
end

@testset "ROMValidator Task 1.2 Test" begin
    test_dir = mktempdir()
    try
        # Create dummy JLD2 files
        snap1_path = joinpath(test_dir, "snap1.jld2")
        snap2_path = joinpath(test_dir, "snap2.jld2")
        snap3_path = joinpath(test_dir, "snap3.jld2")
        # non-jld2 file to test filtering
        other_path = joinpath(test_dir, "other.txt")
        write(other_path, "not a jld2")

        jldsave(snap1_path; temperature=[20.0, 30.0], metadata=Dict("snapshot_id" => "snap_1", "mu" => [1.0, 2.0]))
        jldsave(snap2_path; temperature=[25.0, 35.0], metadata=Dict("snapshot_id" => "snap_2", "mu" => [3.0, 4.0]))
        
        # 3D temperature array
        temp3d = reshape(collect(1.0:8.0), 2, 2, 2)
        jldsave(snap3_path; temperature=temp3d, metadata=Dict("snapshot_id" => "snap_3", "mu" => [5.0, 6.0]))

        # Test get_validation_samples
        trained_ids = ["snap_1"]
        samples = get_validation_samples(test_dir, trained_ids)
        
        @test length(samples) == 2
        @test snap2_path in samples
        @test snap3_path in samples
        @test !(snap1_path in samples)

        # Test load_test_case for snap2
        temp_vec, mu_vec, snap_id = load_test_case(snap2_path)
        @test temp_vec == [25.0, 35.0]
        @test mu_vec == [3.0, 4.0]
        @test snap_id == "snap_2"

        # Test load_test_case for snap3 (3D array should be flattened)
        temp_vec3, mu_vec3, snap_id3 = load_test_case(snap3_path)
        @test temp_vec3 == collect(1.0:8.0)
        @test mu_vec3 == [5.0, 6.0]
        @test snap_id3 == "snap_3"
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ROMValidator Task 2.1 Test" begin
    # Test calculate_l2_error
    fvm1 = [1.0, 2.0, 3.0]
    rom1 = [1.1, 1.9, 3.1]
    
    # ||fvm1 - rom1||_2 = sqrt(0.1^2 + (-0.1)^2 + 0.1^2) = sqrt(0.03) ≈ 0.173205
    # ||fvm1||_2 = sqrt(1^2 + 2^2 + 3^2) = sqrt(14) ≈ 3.741657
    # relative error ≈ sqrt(0.03/14) ≈ 0.046291
    @test calculate_l2_error(fvm1, rom1) ≈ sqrt(0.03/14)
    
    # Mismatched length
    @test_throws DimensionMismatch calculate_l2_error(fvm1, [1.0, 2.0])
    
    # Near zero FVM norm (< 1e-12)
    @test calculate_l2_error([1e-13, 0.0], [1.0, 1.0]) == 0.0
    
    # Test calculate_tmax_error
    fvm2 = [10.0, 20.0, 15.0]
    rom2 = [11.0, 19.5, 14.0]
    # max(fvm2) = 20.0, max(rom2) = 19.5, abs diff = 0.5
    @test calculate_tmax_error(fvm2, rom2) ≈ 0.5
    
    # Mismatched length
    @test_throws DimensionMismatch calculate_tmax_error(fvm2, [10.0, 20.0])
    
    # Empty vector
    @test_throws ArgumentError calculate_tmax_error(Float64[], Float64[])
end

@testset "ROMValidator Task 2.2 Test" begin
    # Grid setup: nx=2, ny=3, nz=4, total = 24
    grid_info = Dict{String, Any}(
        "nx" => 2,
        "ny" => 3,
        "nz" => 4,
        "lx" => 10.0,
        "ly" => 15.0,
        "z_centers" => [1.0, 2.0, 3.0, 4.0]
    )

    # Correct dimensions (length 24)
    fvm = zeros(24)
    rom = zeros(24)
    
    # Check physical coordinates:
    # dx = 10/2 = 5.0, dy = 15/3 = 5.0
    
    # Hotspot 1: Index 1 (FVM)
    # k = (1-1)÷6 + 1 = 1 -> z = 1.0
    # rem = 0
    # j = 0÷2 + 1 = 1 -> y = 0.5 * 5.0 = 2.5
    # i = 0%2 + 1 = 1 -> x = 0.5 * 5.0 = 2.5
    # (x, y, z) = (2.5, 2.5, 1.0)
    fvm[1] = 100.0 # Max at index 1

    # Hotspot 2: Index 2 (ROM)
    # k = (2-1)÷6 + 1 = 1 -> z = 1.0
    # rem = 1
    # j = 1÷2 + 1 = 1 -> y = 0.5 * 5.0 = 2.5
    # i = 1%2 + 1 = 2 -> x = 1.5 * 5.0 = 7.5
    # (x, y, z) = (7.5, 2.5, 1.0)
    rom[2] = 100.0 # Max at index 2
    # Expected distance: 5.0
    @test calculate_hotspot_error(fvm, rom, grid_info) ≈ 5.0

    # Hotspot 3: Index 11
    # k = (11-1)÷6 + 1 = 2 -> z = 2.0
    # rem = 4
    # j = 4÷2 + 1 = 3 -> y = 2.5 * 5.0 = 12.5
    # i = 4%2 + 1 = 1 -> x = 0.5 * 5.0 = 2.5
    # (x, y, z) = (2.5, 12.5, 2.0)
    rom_alt = zeros(24)
    rom_alt[11] = 100.0
    # Expected distance: sqrt((2.5-2.5)^2 + (12.5-2.5)^2 + (2.0-1.0)^2) = sqrt(100 + 1) = sqrt(101) ≈ 10.0498756
    @test calculate_hotspot_error(fvm, rom_alt, grid_info) ≈ sqrt(101.0)

    # Input validations
    # 1. Length mismatch between fvm and rom
    @test_throws DimensionMismatch calculate_hotspot_error(fvm, zeros(23), grid_info)
    # 2. Length mismatch with grid total size
    @test_throws DimensionMismatch calculate_hotspot_error(zeros(23), zeros(23), grid_info)
    # 3. Missing keys in grid_info
    for key in ["nx", "ny", "nz", "lx", "ly", "z_centers"]
        bad_grid = copy(grid_info)
        delete!(bad_grid, key)
        @test_throws KeyError calculate_hotspot_error(fvm, rom, bad_grid)
    end
end

@testset "ROMValidator Task 2.3 Test" begin
    # 1. Test judge_accuracy
    @test judge_accuracy(1.5; tmax_threshold=2.0) == :validated
    @test judge_accuracy(2.0; tmax_threshold=2.0) == :validated
    @test judge_accuracy(2.1; tmax_threshold=2.0) == :unfit
    @test judge_accuracy(1.9) == :validated  # default tmax_threshold = 2.0
    @test judge_accuracy(2.5) == :unfit

    # 2. Test evaluate_validation_results with valid inputs (expect :validated)
    results_pass = [
        ValidationResult("sample_1", 0.01, 1.2, 0.02, true),
        ValidationResult("sample_2", 0.03, 1.8, 0.04, true)
    ]
    summary_pass = evaluate_validation_results(results_pass; tmax_threshold=2.0)
    
    @test summary_pass.overall_status == :validated
    # mean relative_l2_error = (0.01 + 0.03)/2 = 0.02
    # mean tmax_error = (1.2 + 1.8)/2 = 1.5
    # mean hotspot_dist = (0.02 + 0.04)/2 = 0.03
    @test summary_pass.mean_metrics["relative_l2_error"] ≈ 0.02
    @test summary_pass.mean_metrics["tmax_error"] ≈ 1.5
    @test summary_pass.mean_metrics["hotspot_dist"] ≈ 0.03

    # max relative_l2_error = 0.03
    # max tmax_error = 1.8
    # max hotspot_dist = 0.04
    @test summary_pass.max_metrics["relative_l2_error"] ≈ 0.03
    @test summary_pass.max_metrics["tmax_error"] ≈ 1.8
    @test summary_pass.max_metrics["hotspot_dist"] ≈ 0.04

    # 3. Test evaluate_validation_results with unfit output (mean tmax_error > threshold)
    results_fail = [
        ValidationResult("sample_1", 0.01, 1.8, 0.02, true),
        ValidationResult("sample_2", 0.03, 2.4, 0.04, true)
    ]
    summary_fail = evaluate_validation_results(results_fail; tmax_threshold=2.0)
    @test summary_fail.overall_status == :unfit
    @test summary_fail.mean_metrics["tmax_error"] ≈ 2.1 # (1.8 + 2.4) / 2

    # 4. Test evaluate_validation_results with empty input (expect ArgumentError)
    @test_throws ArgumentError evaluate_validation_results(ValidationResult[]; tmax_threshold=2.0)
end

@testset "ROMValidator Task 3.1 Test" begin
    using .ROMValidator: generate_report

    results = [
        ValidationResult("sample_1", 0.01, 1.2, 0.02, true),
        ValidationResult("sample_2", 0.03, 1.8, 0.04, true)
    ]
    summary = evaluate_validation_results(results; tmax_threshold=2.0)

    test_dir = mktempdir()
    try
        generate_report(summary, test_dir)

        md_path = joinpath(test_dir, "validation.md")
        json_path = joinpath(test_dir, "validation.json")

        @test isfile(md_path)
        @test isfile(json_path)

        # JSON 内容の検証
        json_content = JSON3.read(read(json_path, String))
        @test string(json_content.overall_status) == "validated"
        @test json_content.mean_metrics.relative_l2_error ≈ 0.02
        @test json_content.mean_metrics.tmax_error ≈ 1.5
        @test json_content.mean_metrics.hotspot_dist ≈ 0.03
        @test json_content.max_metrics.tmax_error ≈ 1.8

        # MD 内容の検証
        md_content = read(md_path, String)
        @test occursin("validated", md_content)
        @test occursin("0.02", md_content)
        @test occursin("1.5", md_content)
        @test occursin("1.8", md_content)
        @test occursin("[sample_1_rom_fvm_comparison_xy.png](sample_1_rom_fvm_comparison_xy.png)", md_content)
        @test occursin("![sample_1 Comparison Plot](sample_1_rom_fvm_comparison_xy.png)", md_content)
        @test occursin("[sample_2_rom_fvm_comparison_xy.png](sample_2_rom_fvm_comparison_xy.png)", md_content)
        @test occursin("![sample_2 Comparison Plot](sample_2_rom_fvm_comparison_xy.png)", md_content)
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ROMValidator Task 3.2 Test" begin
    using .ROMValidator: generate_comparison_plots
    
    grid_info = Dict{String, Any}(
        "nx" => 2,
        "ny" => 3,
        "nz" => 4,
        "lx" => 1.2e-3,
        "ly" => 1.2e-3,
        "z_centers" => [0.15e-3, 0.25e-3, 0.35e-3, 0.55e-3]
    )
    
    theta_fvm = collect(1.0:24.0)
    theta_rom = theta_fvm .+ 0.1
    mu = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
    
    # 1. Test defaults (save_individuals = false)
    test_dir = mktempdir()
    try
        generate_comparison_plots(theta_fvm, theta_rom, grid_info, test_dir, "test_sample", mu; save_individuals=false)
        
        @test isfile(joinpath(test_dir, "test_sample_rom_fvm_comparison_xy.png"))
        @test !isfile(joinpath(test_dir, "test_sample_rom_fvm_density_xy.png"))
        @test !isfile(joinpath(test_dir, "test_sample_rom_fvm_fvm_xy.png"))
        @test !isfile(joinpath(test_dir, "test_sample_rom_fvm_rom_xy.png"))
        @test !isfile(joinpath(test_dir, "test_sample_rom_fvm_diff_xy.png"))
    finally
        rm(test_dir, recursive=true, force=true)
    end

    # 2. Test save_individuals = true
    test_dir2 = mktempdir()
    try
        generate_comparison_plots(theta_fvm, theta_rom, grid_info, test_dir2, "test_sample", mu; save_individuals=true)
        
        @test isfile(joinpath(test_dir2, "test_sample_rom_fvm_comparison_xy.png"))
        @test isfile(joinpath(test_dir2, "test_sample_rom_fvm_density_xy.png"))
        @test isfile(joinpath(test_dir2, "test_sample_rom_fvm_fvm_xy.png"))
        @test isfile(joinpath(test_dir2, "test_sample_rom_fvm_rom_xy.png"))
        @test isfile(joinpath(test_dir2, "test_sample_rom_fvm_diff_xy.png"))
    finally
        rm(test_dir2, recursive=true, force=true)
    end
end

@testset "ROMValidator Task 4.1 Test" begin
    using .ROMValidator: run_validation
    
    if !isdefined(Main, :ROMInterpolator)
        try
            include("../ROMInterpolator/ROMInterpolator.jl")
        catch
            include("../src/ROMInterpolator/ROMInterpolator.jl")
        end
    end
    
    using .ROMInterpolator: RBFInterpolator, save_rom_model, ScalingParams
    
    test_dir = mktempdir()
    try
        # 1. Create dummy snapshots in raw_dir
        raw_dir = joinpath(test_dir, "raw")
        mkpath(raw_dir)
        
        # Grid parameters: 2 * 3 * 4 = 24 elements
        grid_info = Dict{String, Any}(
            "nx" => 2,
            "ny" => 3,
            "nz" => 4,
            "lx" => 1.2e-3,
            "ly" => 1.2e-3,
            "z_centers" => [0.15e-3, 0.25e-3, 0.35e-3, 0.55e-3]
        )
        
        # Snapshot 1 (trained)
        snap1_path = joinpath(raw_dir, "snap1.jld2")
        jldsave(snap1_path; temperature=collect(1.0:24.0), id_map=zeros(UInt8, 2, 3, 4), nx=2, ny=3, nz=4, z_faces=collect(0.0:4.0), metadata=Dict("snapshot_id" => "snap_1", "mu" => fill(1.5, 16)))
        
        # Snapshot 2 (validation)
        snap2_path = joinpath(raw_dir, "snap2.jld2")
        jldsave(snap2_path; temperature=collect(1.0:24.0) .+ 1.0, id_map=zeros(UInt8, 2, 3, 4), nx=2, ny=3, nz=4, z_faces=collect(0.0:4.0), metadata=Dict("snapshot_id" => "snap_2", "mu" => collect(range(0.0, 1.0, length=16))))
        
        # 2. Create dummy trained RBFInterpolator model and save it
        model_path = joinpath(test_dir, "rom_model.jld2")
        model = RBFInterpolator(
            fill(1.0, (2, 2)), # weights (shape: N_basis x N_centers)
            zeros(16, 2), # centers (N_dim x N_centers, where N_centers = 2, N_dim = 16)
            1.0, # epsilon
            ScalingParams(zeros(16), ones(16)), # scaling_params
            vcat(zeros(1, 16), ones(1, 16)), # parameter_bounds (2 x N_dim)
            Dict{String, Any}("kernel_type" => "gaussian")
        )
        save_rom_model(model_path, model)
        
        # Dummy basis (24 x 2) and mean field (24)
        basis = reshape(collect(1.0:48.0), 24, 2) ./ 10.0
        mean_field = zeros(24)
        
        # Run validation
        output_dir = joinpath(test_dir, "output")
        
        summary = run_validation(
            model_path,
            raw_dir,
            output_dir,
            ["snap_1"], # trained_snapshot_ids
            grid_info,
            basis,
            mean_field;
            tmax_threshold=30.0,
            save_individuals=false
        )
        
        @test summary.overall_status == :validated
        @test length(summary.results) == 1
        @test summary.results[1].sample_id == "snap_2"
        
        # Check files
        @test isfile(joinpath(output_dir, "validation.json"))
        @test isfile(joinpath(output_dir, "validation.md"))
        @test isfile(joinpath(output_dir, "snap_2_rom_fvm_comparison_xy.png"))
        @test !isfile(joinpath(output_dir, "snap_2_rom_fvm_density_xy.png"))
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ROMValidator Task 5.1 Test" begin
    # Task 5.1: E2E Verification
    using .ROMValidator: run_validation
    using .ROMInterpolator: RBFInterpolator, save_rom_model, ScalingParams
    
    test_dir = mktempdir()
    try
        raw_dir = joinpath(test_dir, "raw")
        mkpath(raw_dir)
        
        # 2 * 3 * 4 = 24 elements grid
        grid_info = Dict{String, Any}(
            "nx" => 2,
            "ny" => 3,
            "nz" => 4,
            "lx" => 1.2e-3,
            "ly" => 1.2e-3,
            "z_centers" => [0.15e-3, 0.25e-3, 0.35e-3, 0.55e-3]
        )
        
        # Write multiple snapshots
        jldsave(joinpath(raw_dir, "snap_t1.jld2"); temperature=collect(1.0:24.0), id_map=zeros(UInt8, 2, 3, 4), nx=2, ny=3, nz=4, z_faces=collect(0.0:4.0), metadata=Dict("snapshot_id" => "trained1", "mu" => fill(1.5, 16)))
        jldsave(joinpath(raw_dir, "snap_v1.jld2"); temperature=collect(1.0:24.0) .+ 0.5, id_map=zeros(UInt8, 2, 3, 4), nx=2, ny=3, nz=4, z_faces=collect(0.0:4.0), metadata=Dict("snapshot_id" => "val1", "mu" => collect(range(0.0, 1.0, length=16))))
        jldsave(joinpath(raw_dir, "snap_v2.jld2"); temperature=collect(1.0:24.0) .+ 1.5, id_map=zeros(UInt8, 2, 3, 4), nx=2, ny=3, nz=4, z_faces=collect(0.0:4.0), metadata=Dict("snapshot_id" => "val2", "mu" => collect(range(0.0, 1.0, length=16))))
        
        model_path = joinpath(test_dir, "rom_model.jld2")
        model = RBFInterpolator(
            fill(1.0, (2, 2)), # weights
            zeros(16, 2), # centers
            1.0, # epsilon
            ScalingParams(zeros(16), ones(16)), # scaling
            vcat(zeros(1, 16), ones(1, 16)), # parameter_bounds
            Dict{String, Any}("kernel_type" => "gaussian")
        )
        save_rom_model(model_path, model)
        
        basis = reshape(collect(1.0:48.0), 24, 2) ./ 10.0
        mean_field = zeros(24)
        output_dir = joinpath(test_dir, "output")
        
        # Execute run_validation
        summary = run_validation(
            model_path,
            raw_dir,
            output_dir,
            ["trained1"], # trained list
            grid_info,
            basis,
            mean_field;
            tmax_threshold=30.0,
            save_individuals=false
        )
        
        # Verify result summary structure and values
        @test summary.overall_status == :validated
        @test length(summary.results) == 2
        
        # Verify only the expected 4-column comparison plot exists (no other plot images)
        files = readdir(output_dir)
        png_files = filter(f -> endswith(f, ".png"), files)
        @test length(png_files) == 2
        @test "val1_rom_fvm_comparison_xy.png" in png_files
        @test "val2_rom_fvm_comparison_xy.png" in png_files
        
        # Report files validation
        @test isfile(joinpath(output_dir, "validation.json"))
        @test isfile(joinpath(output_dir, "validation.md"))
        
        # Test report content
        report_md = read(joinpath(output_dir, "validation.md"), String)
        @test occursin("# ROM Validation Report", report_md)
        @test occursin("Overall Status", report_md)
        @test occursin("val1", report_md)
        @test occursin("val2", report_md)
        @test occursin("[val1_rom_fvm_comparison_xy.png](val1_rom_fvm_comparison_xy.png)", report_md)
        @test occursin("![val1 Comparison Plot](val1_rom_fvm_comparison_xy.png)", report_md)
        @test occursin("[val2_rom_fvm_comparison_xy.png](val2_rom_fvm_comparison_xy.png)", report_md)
        @test occursin("![val2 Comparison Plot](val2_rom_fvm_comparison_xy.png)", report_md)
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ValidationPlot Snapshot Plots Test" begin
    # Test plot_snapshot_xy directly
    using Main.ValidationPlot: plot_snapshot_xy
    
    test_dir = mktempdir()
    try
        snap_path = joinpath(test_dir, "snapshot_test_case.jld2")
        jldsave(snap_path;
            temperature=reshape(collect(20.0:43.0), 2, 3, 4),
            id_map=zeros(UInt8, 2, 3, 4),
            nx=2,
            ny=3,
            nz=4,
            z_faces=[0.0, 0.1, 0.2, 0.3, 0.4],
            metadata=Dict("snapshot_id" => "test_case", "mu" => collect(range(0.0, 1.0, length=16)))
        )
        
        # 1. save_individuals = false
        plot_snapshot_xy(snap_path; zc=0.15, out_dir=test_dir, save_individuals=false)
        @test isfile(joinpath(test_dir, "snapshot_test_case_snapshot_xy.png"))
        @test !isfile(joinpath(test_dir, "snapshot_test_case_temp_xy.png"))
        @test !isfile(joinpath(test_dir, "snapshot_test_case_geo_xy.png"))
        @test !isfile(joinpath(test_dir, "snapshot_test_case_density_xy.png"))
        
        # Remove generated files for clean next test
        rm(joinpath(test_dir, "snapshot_test_case_snapshot_xy.png"))
        
        # 2. save_individuals = true
        plot_snapshot_xy(snap_path; zc=0.15, out_dir=test_dir, save_individuals=true)
        @test isfile(joinpath(test_dir, "snapshot_test_case_snapshot_xy.png"))
        @test isfile(joinpath(test_dir, "snapshot_test_case_temp_xy.png"))
        @test isfile(joinpath(test_dir, "snapshot_test_case_geo_xy.png"))
        @test isfile(joinpath(test_dir, "snapshot_test_case_density_xy.png"))
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ValidationPlot ROM Comparison Normalize Test" begin
    using Main.ValidationPlot: plot_rom_comparison
    
    test_dir = mktempdir()
    try
        grid_info = Dict{String, Any}(
            "nx" => 2,
            "ny" => 3,
            "nz" => 4,
            "lx" => 1.2e-3,
            "ly" => 1.2e-3,
            "z_centers" => [0.15e-3, 0.25e-3, 0.35e-3, 0.55e-3]
        )
        theta_fvm = collect(100.0:123.0) # max=123.0, min=100.0
        theta_rom = collect(101.0:124.0)
        mu = fill(0.5, 16)
        z_centers = [0.15e-3, 0.25e-3, 0.35e-3, 0.55e-3]
        grid_size = (2, 3, 4)
        
        # Test with normalize=true
        plot_rom_comparison(
            theta_fvm, theta_rom, grid_size, z_centers, mu;
            zc=0.35e-3, out_dir=test_dir, save_individuals=true, normalize=true, sample_id="norm_test"
        )
        
        @test isfile(joinpath(test_dir, "norm_test_rom_fvm_comparison_xy.png"))
        @test isfile(joinpath(test_dir, "norm_test_rom_fvm_fvm_xy.png"))
        @test isfile(joinpath(test_dir, "norm_test_rom_fvm_rom_xy.png"))
        
        # Verify that normalization actually works by ensuring FVM is scaled to [0, 1]
        T_fvm = reshape(theta_fvm, grid_size)
        tmin_fvm = minimum(T_fvm)
        tmax_fvm = maximum(T_fvm)
        denom = tmax_fvm - tmin_fvm
        
        T_fvm_norm = (T_fvm .- tmin_fvm) ./ denom
        @test minimum(T_fvm_norm) ≈ 0.0
        @test maximum(T_fvm_norm) ≈ 1.0
        
        T_rom = reshape(theta_rom, grid_size)
        T_rom_norm = (T_rom .- tmin_fvm) ./ denom
        @test minimum(T_rom_norm) ≈ 1.0 / 23.0
        @test maximum(T_rom_norm) ≈ 24.0 / 23.0
    finally
        rm(test_dir, recursive=true, force=true)
    end
end

@testset "ROMValidator Measurement Logic Test" begin
    # 1. measure_dataset_size test
    test_dir = mktempdir()
    try
        # Directory does not exist or empty
        @test measure_dataset_size(joinpath(test_dir, "nonexistent")) == 0
        @test measure_dataset_size(test_dir) == 0

        # Create dummy JLD2 files and check sizes
        file1 = joinpath(test_dir, "snap1.jld2")
        file2 = joinpath(test_dir, "snap2.jld2")
        other_file = joinpath(test_dir, "other.txt")

        write(file1, "12345") # 5 bytes
        write(file2, "1234567890") # 10 bytes
        write(other_file, "123456789012345") # 15 bytes (should be ignored)

        # Expected dataset size: 5 + 10 = 15 bytes
        @test measure_dataset_size(test_dir) == 15
    finally
        rm(test_dir, recursive=true, force=true)
    end

    # 2. measure_fvm_runtime test
    test_dir2 = mktempdir()
    try
        manifest_path = joinpath(test_dir2, "manifest.json")
        
        # Manifest does not exist
        @test measure_fvm_runtime(manifest_path) == (0.0, 0.0)

        # Valid manifest with mixed statuses
        manifest_data = Dict(
            "cases" => [
                Dict("id" => 1, "status" => "success", "runtime" => 10.0),
                Dict("id" => 2, "status" => "failed", "runtime" => 5.0),
                Dict("id" => 3, "status" => "success", "runtime" => 20.0),
                Dict("id" => 4, "status" => "pending", "runtime" => 0.0)
            ]
        )
        
        open(manifest_path, "w") do io
            JSON3.write(io, manifest_data)
        end

        # Total runtime = 10.0 + 20.0 = 30.0
        # Success count = 2
        # Average runtime = 30.0 / 2 = 15.0
        tot, avg = measure_fvm_runtime(manifest_path)
        @test tot ≈ 30.0
        @test avg ≈ 15.0

        # Manifest with no success cases
        manifest_data_no_success = Dict(
            "cases" => [
                Dict("id" => 1, "status" => "failed", "runtime" => 10.0)
            ]
        )
        open(manifest_path, "w") do io
            JSON3.write(io, manifest_data_no_success)
        end

        tot_ns, avg_ns = measure_fvm_runtime(manifest_path)
        @test tot_ns == 0.0
        @test avg_ns == 0.0
    finally
        rm(test_dir2, recursive=true, force=true)
    end
end






