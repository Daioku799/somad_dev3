using Test
using LinearAlgebra

# 依存モジュールのロード
if !isdefined(Main, :ROMInterpolator)
    include(joinpath(@__DIR__, "../H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
end
using .ROMInterpolator

# PaperEvaluation のロード (まだ実装前なので、ファイルが存在しないか、関数が存在しない)
if !isdefined(Main, :PaperEvaluation)
    include(joinpath(@__DIR__, "../H2-rom/src/PaperEvaluation/PaperEvaluation.jl"))
end
using .PaperEvaluation

@testset "PaperEvaluation.jl Unit Tests" begin
    @testset "monitor_rom_size" begin
        # U: 100 x 5 (500 elements) -> 4000 bytes = 3.906 KB
        basis = rand(100, 5)
        
        # W: 5 x 10 (50 elements) -> 400 bytes = 0.391 KB
        weights = rand(5, 10)
        centers = rand(10, 2)
        epsilon = 1.5
        scaling_params = ScalingParams(zeros(2), ones(2))
        parameter_bounds = [zeros(2) ones(2)]
        
        rom_model = RBFInterpolator(weights, centers, epsilon, scaling_params, parameter_bounds)
        
        report = monitor_rom_size(basis, rom_model)
        
        println("Generated Report:\n", report)
        
        @test report isa String
        @test occursin("elements", lowercase(report)) || occursin("要素数", report)
        @test occursin("KB", report) || occursin("MB", report)
        
        # 正しい数値が含まれるか検証
        @test occursin("500", report)
        @test occursin("550", report)
    end

    @testset "time measurement helper" begin
        # test measure_time
        result, elapsed = PaperEvaluation.measure_time() do
            sleep(0.1)
            "done"
        end
        @test result == "done"
        @test elapsed >= 0.08
        @test elapsed <= 0.5

        # test format_elapsed_time
        formatted = PaperEvaluation.format_elapsed_time(12.3456)
        @test occursin("12.3456", formatted)
        @test occursin("seconds", formatted) || occursin("秒", formatted)
    end
end

