using Test

# まだ ROMValidator.jl は存在しないため、includeは失敗するはずです
if !isdefined(Main, :ROMValidator)
    include("../src/ROMValidator/ROMValidator.jl")
end
using .ROMValidator: ValidationResult, ValidationSummary, get_validation_samples, load_test_case, calculate_l2_error, calculate_tmax_error
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

