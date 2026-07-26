using Test

@testset "Verify Legacy FVM Main Script Test" begin
    # verify_legacy_fvm.jl がプロジェクトルートに存在することを確認
    script_path = joinpath(@__DIR__, "..", "verify_legacy_fvm.jl")
    
    @testset "Check script execution" begin
        # 実行前の確認（REDフェーズでは存在しないはずなので、ここで落ちるか、もしくは実行で失敗する）
        @test isfile(script_path)
        
        if isfile(script_path)
            # プロジェクトルートから実行
            project_path = abspath(joinpath(@__DIR__, "..", "H2-main-ext"))
            root_dir = abspath(joinpath(@__DIR__, ".."))
            cmd = setenv(`$(Base.julia_cmd()) --project=$project_path $script_path`, dir=root_dir)
            
            println("Running verify_legacy_fvm.jl via subprocess...")
            success_run = false
            try
                success_run = success(cmd)
            catch e
                println("Execution failed with error: ", e)
            end
            
            @test success_run
        else
            println("verify_legacy_fvm.jl does not exist yet (expected in RED phase)")
        end
    end
end
