using Pkg
Pkg.activate("H2-main-ext")

using Test
include("../src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

include("../src/ComponentGenerator/ComponentGenerator.jl")
using .ComponentGenerator

@testset "ComponentGenerator Main API" begin
    config = generate_test_config()
    
    # Test that generate_all_components exists and returns a Vector{GeometryObject}
    # It should dynamically dispatch Layout.expand_coordinates and Validator.validate_physical_constraints
    @testset "Basic API Signature and Return Type" begin
        # For now, it should return a Vector of GeometryObjects without crashing.
        objs = generate_all_components(config)
        @test objs isa Vector{GeometryObject}
    end
end
