using Test

@testset "H2-rom All Tests" begin
    println("Running test_types.jl...")
    include("test_types.jl")
    
    println("Running test_manifest.jl...")
    include("test_manifest.jl")
    
    println("Running test_sampler.jl...")
    include("test_sampler.jl")
    
    println("Running test_runner.jl...")
    include("test_runner.jl")
    
    println("Running test_snapshot_generator.jl...")
    include("test_snapshot_generator.jl")
    
    println("Running test_pod_engine.jl...")
    include("test_pod_engine.jl")
    
    println("Running test_rom_interpolator.jl...")
    include("test_rom_interpolator.jl")
    
    println("Running test_rom_validator.jl...")
    include("test_rom_validator.jl")
end
