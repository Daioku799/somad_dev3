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
end
