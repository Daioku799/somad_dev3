using Test

if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end
using .ROMInterpolator: AbstractInterpolator, ScalingParams, RBFInterpolator

@testset "ROMInterpolator Types Test" begin
    # Dummy fields for ScalingParams
    min_vals = [0.0, 0.1]
    max_vals = [1.0, 0.9]
    scaling = ScalingParams(min_vals, max_vals)
    
    @test scaling.min_vals == min_vals
    @test scaling.max_vals == max_vals

    # Dummy fields for RBFInterpolator
    weights = [1.0 2.0; 3.0 4.0]
    centers = [0.1 0.2; 0.3 0.4]
    epsilon = 0.5
    parameter_bounds = [0.0 0.1; 1.0 0.9]
    
    rbf = RBFInterpolator(weights, centers, epsilon, scaling, parameter_bounds)
    
    @test rbf isa AbstractInterpolator
    @test rbf.weights == weights
    @test rbf.centers == centers
    @test rbf.epsilon == epsilon
    @test rbf.scaling_params === scaling
    @test rbf.parameter_bounds == parameter_bounds
end
