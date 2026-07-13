using Test

@testset "H2-rom All Tests" begin
    tests = [
        "test_ga_types.jl",
        "test_types.jl",
        "test_constraint_manager.jl",
        "test_engine.jl",
        "test_engine_selection.jl",
        "test_manifest.jl",
        "test_sampler.jl",
        "test_runner.jl",
        "test_snapshot_generator.jl",
        "test_pod_engine.jl",
        "test_rom_interpolator.jl",
        "test_rom_validator.jl"
    ]
    
    for t in tests
        println("Running $t in a separate process...")
        cmd = `julia --project=. test/$t`
        @test success(cmd)
    end
end
