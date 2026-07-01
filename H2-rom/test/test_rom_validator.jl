using Test

# まだ ROMValidator.jl は存在しないため、includeは失敗するはずです
if !isdefined(Main, :ROMValidator)
    include("../src/ROMValidator/ROMValidator.jl")
end
using .ROMValidator: ValidationResult, ValidationSummary

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
