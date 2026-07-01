using Test

# まだ ROMValidator.jl は存在しないため、includeは失敗するはずです
if !isdefined(Main, :ROMValidator)
    include("../src/ROMValidator/ROMValidator.jl")
end
using .ROMValidator: ValidationResult, ValidationSummary, get_validation_samples, load_test_case, calculate_l2_error, calculate_tmax_error, calculate_hotspot_error, judge_accuracy, evaluate_validation_results
using JLD2

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


