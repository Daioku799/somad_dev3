using Test

if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end
using .ROMInterpolator: AbstractInterpolator, ScalingParams, RBFInterpolator, fit_scaler, scale_data

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

@testset "ROMInterpolator Scaling Test" begin
    # Test fit_scaler
    data = [1.0 2.0 3.0; 
            0.0 5.0 10.0]
    params = fit_scaler(data)
    @test params.min_vals == [1.0, 0.0]
    @test params.max_vals == [3.0, 10.0]

    # Test scale_data for Vector
    vec = [2.0, 5.0]
    scaled_vec = scale_data(vec, params)
    @test scaled_vec ≈ [0.5, 0.5]

    # Test scale_data for Matrix
    scaled_matrix = scale_data(data, params)
    @test scaled_matrix ≈ [0.0 0.5 1.0; 
                           0.0 0.5 1.0]

    # Test zero-division safety (max - min < 1e-12)
    # The first row is constant: [2.0, 2.0, 2.0] -> max - min = 0.0 < 1e-12
    const_data = [2.0 2.0 2.0; 
                  0.0 5.0 10.0]
    params_const = fit_scaler(const_data)
    @test params_const.min_vals == [2.0, 0.0]
    @test params_const.max_vals == [2.0, 10.0]

    scaled_const = scale_data(const_data, params_const)
    @test scaled_const ≈ [0.0 0.0 0.0;
                          0.0 0.5 1.0]

    # Test with division safety boundary close to 1e-12
    # difference exactly 0.5e-12 < 1e-12 -> should scale to 0.0
    epsilon_data = [1.0 1.0 + 0.5e-12;
                    0.0 10.0]
    params_eps = fit_scaler(epsilon_data)
    scaled_eps = scale_data(epsilon_data, params_eps)
    @test scaled_eps[1, :] ≈ [0.0, 0.0]
end

@testset "ROMInterpolator RBF Kernel Test" begin
    X = [1.0 2.0 3.0;
         4.0 5.0 6.0]
    
    centers = [1.0 2.0;
               4.0 6.0]
    
    epsilon = 0.5
    
    expected = [
        1.0                      exp(-1.25);
        exp(-0.5)                exp(-0.25);
        exp(-2.0)                exp(-0.25)
    ]
    
    # We call ROMInterpolator.compute_kernel_matrix which is not yet implemented or exported.
    # This will fail with UndefVarError because compute_kernel_matrix doesn't exist.
    kernel_matrix = ROMInterpolator.compute_kernel_matrix(X, centers, epsilon)
    @test kernel_matrix ≈ expected
end

@testset "ROMInterpolator fit! and predict Test" begin
    using .ROMInterpolator: fit!, predict

    # 1. Initialization
    epsilon = 0.5
    rbf = RBFInterpolator(epsilon)
    @test rbf.epsilon == epsilon
    @test isempty(rbf.weights)

    # 2. Dummy training data
    # 2 input dimensions, 3 samples, 3 output modes
    X = [1.0 2.0 3.0;
         4.0 5.0 6.0]
    Y = [10.0 20.0 30.0;
         40.0 50.0 60.0;
         70.0 80.0 90.0]

    # 3. Execution of fit!
    fit!(rbf, X, Y; lambda=1e-6)

    # 4. Assert fields after fit!
    @test size(rbf.weights) == (3, 3) # N_modes x N_samples
    @test size(rbf.centers) == (2, 3) # N_dim x N_samples
    @test rbf.scaling_params.min_vals == [1.0, 4.0]
    @test rbf.scaling_params.max_vals == [3.0, 6.0]
    @test rbf.parameter_bounds == [1.0 4.0; 3.0 6.0] # 2 x N_dim

    # 5. Predict and verify reconstruction accuracy
    for i in 1:3
        x = X[:, i]
        y_pred = predict(rbf, x)
        @test y_pred ≈ Y[:, i] atol=1e-3
    end

    # 6. Input validation tests
    # Mismatched sample sizes
    X_bad = [1.0 2.0; 4.0 5.0]
    @test_throws ArgumentError fit!(rbf, X_bad, Y)

    # Empty dataset
    X_empty = Matrix{Float64}(undef, 2, 0)
    Y_empty = Matrix{Float64}(undef, 3, 0)
    @test_throws ArgumentError fit!(rbf, X_empty, Y_empty)
end



