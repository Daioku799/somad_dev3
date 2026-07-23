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

    @testset "plot_svd_decay" begin
        # Generate some synthetic singular values (exponential decay)
        singular_values = [10.0^-(i-1) for i in 1:10]
        output_path = joinpath(@__DIR__, "test_svd_decay.png")
        
        # Ensure file does not exist before test
        if isfile(output_path)
            rm(output_path)
        end
        
        # Call the plot function
        plot_svd_decay(singular_values, output_path)
        
        # Verify the file is generated
        @test isfile(output_path)
        
        # Verify it is a valid PNG by checking magic number
        if isfile(output_path)
            bytes = read(output_path, 8)
            @test bytes == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
            # Clean up
            rm(output_path)
        end
    end

    @testset "sweep_rbf_parameters" begin
        # Generate dummy data
        N_dim = 2
        r = 3
        N_grid = 50
        N_train = 8
        N_val = 4
        
        Mu_train = rand(N_dim, N_train)
        coeffs_train = rand(r, N_train)
        Mu_val = rand(N_dim, N_val)
        
        # Generate true temperature fields for validation
        basis = rand(N_grid, r)
        mean_field = fill(300.0, N_grid)
        val_temp_fields = Matrix{Float64}(undef, N_grid, N_val)
        for i in 1:N_val
            val_temp_fields[:, i] = mean_field + basis * rand(r)
        end
        
        # Dummy grid_info
        grid_info = Dict{String, Any}("dummy" => true)
        
        epsilon_range = [0.1, 0.5, 1.0, 2.0]
        lambda_range = [1e-8, 1e-6, 1e-4, 1e-2]
        
        output_dir = joinpath(@__DIR__, "test_sweep_output")
        if isdir(output_dir)
            rm(output_dir; recursive=true, force=true)
        end
        
        # Run sweep
        sweep_rbf_parameters(
            Mu_train, coeffs_train,
            Mu_val, val_temp_fields,
            grid_info, basis, mean_field,
            epsilon_range, lambda_range,
            output_dir
        )
        
        # Verification
        @test isdir(output_dir)
        l2_plot = joinpath(output_dir, "rbf_sweep_l2.png")
        tmax_plot = joinpath(output_dir, "rbf_sweep_tmax.png")
        @test isfile(l2_plot)
        @test isfile(tmax_plot)
        
        # Validate magic number of PNG
        for f in [l2_plot, tmax_plot]
            if isfile(f)
                bytes = read(f, 8)
                @test bytes == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
            end
        end
        
        # Clean up
        rm(output_dir; recursive=true, force=true)
    end
end

