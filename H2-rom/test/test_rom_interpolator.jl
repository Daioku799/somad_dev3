using Test

if !isdefined(Main, :ROMInterpolator)
    include("../src/ROMInterpolator/ROMInterpolator.jl")
end
using .ROMInterpolator: AbstractInterpolator, ScalingParams, RBFInterpolator, fit_scaler, scale_data, is_reliable, reconstruct_field, reshape_to_3d, get_tmax

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
    @test rbf.metadata isa Dict{String, Any}
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
    @test rbf.metadata["kernel_type"] == "gaussian"

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

@testset "ROMInterpolator is_reliable Test" begin
    epsilon = 0.5
    rbf = RBFInterpolator(epsilon)

    # 1. Dummy training data
    # 2 input dimensions, 3 samples, 3 output modes
    X = [1.0 2.0 3.0;
         4.0 5.0 6.0]
    Y = [10.0 20.0 30.0;
         40.0 50.0 60.0;
         70.0 80.0 90.0]
    fit!(rbf, X, Y)

    # parameter_bounds is [1.0 4.0; 3.0 6.0]

    # 2. In-bounds parameters (true)
    @test is_reliable(rbf, [2.0, 5.0]) == true
    @test is_reliable(rbf, [1.0, 4.0]) == true
    @test is_reliable(rbf, [3.0, 6.0]) == true

    # 3. Near-boundary parameters (tol = 1e-9)
    @test is_reliable(rbf, [1.0 - 0.99e-9, 4.0]) == true
    @test is_reliable(rbf, [3.0 + 0.99e-9, 6.0]) == true
    @test is_reliable(rbf, [1.0 - 1.01e-9, 4.0]) == false
    @test is_reliable(rbf, [3.0 + 1.01e-9, 6.0]) == false

    # 4. Out-of-bounds parameters (false)
    @test is_reliable(rbf, [0.0, 5.0]) == false
    @test is_reliable(rbf, [2.0, 7.0]) == false
    @test is_reliable(rbf, [0.0, 7.0]) == false

    # 5. Dimension mismatch (DimensionMismatch)
    @test_throws DimensionMismatch is_reliable(rbf, [2.0])
    @test_throws DimensionMismatch is_reliable(rbf, [2.0, 5.0, 1.0])
end

@testset "ROMInterpolator Reconstructor Test" begin
    # 1. Correct linear combination test
    coeffs = [1.0, 2.0]
    basis = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    mean_field = [0.1, 0.2, 0.3]
    
    expected = [5.1, 11.2, 17.3]
    @test reconstruct_field(coeffs, basis, mean_field) ≈ expected

    # 2. DimensionMismatch validation test (basis columns != length(coeffs))
    coeffs_bad = [1.0, 2.0, 3.0]
    @test_throws DimensionMismatch reconstruct_field(coeffs_bad, basis, mean_field)

    # 3. DimensionMismatch validation test (basis rows != length(mean_field))
    mean_field_bad = [0.1, 0.2]
    @test_throws DimensionMismatch reconstruct_field(coeffs, basis, mean_field_bad)
end

@testset "ROMInterpolator Reshape to 3D and Get Tmax Test" begin
    # 1. Test reshape_to_3d with valid input
    theta = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    grid_size = (2, 2, 2)
    reshaped = reshape_to_3d(theta, grid_size)
    @test size(reshaped) == (2, 2, 2)
    @test reshaped[1, 1, 1] == 1.0
    @test reshaped[2, 2, 2] == 8.0

    # 2. Test reshape_to_3d with size mismatch (DimensionMismatch)
    bad_grid_size = (2, 2, 3)
    @test_throws DimensionMismatch reshape_to_3d(theta, bad_grid_size)

    # 3. Test get_tmax with valid input
    @test get_tmax(theta) == 8.0
    @test get_tmax([5.5, -1.0, 12.3, 0.0]) == 12.3

    # 4. Test get_tmax with empty input (ArgumentError)
    empty_theta = Float64[]
    @test_throws ArgumentError get_tmax(empty_theta)
end

@testset "ROMInterpolator Persistence Test" begin
    using .ROMInterpolator: save_rom_model, load_rom_model

    # Create dummy model
    min_vals = [0.0, 0.1]
    max_vals = [1.0, 0.9]
    scaling = ScalingParams(min_vals, max_vals)
    weights = [1.0 2.0; 3.0 4.0]
    centers = [0.1 0.2; 0.3 0.4]
    epsilon = 0.5
    parameter_bounds = [0.0 0.1; 1.0 0.9]
    
    model = RBFInterpolator(weights, centers, epsilon, scaling, parameter_bounds)
    model.metadata = Dict{String, Any}("kernel_type" => "gaussian", "custom_key" => "custom_val")

    # Use a temporary directory for output within the workspace
    temp_dir = joinpath(@__DIR__, "temp_persistence_test")
    rm(temp_dir; force=true, recursive=true)
    
    filepath = joinpath(temp_dir, "nested", "rom_model.jld2")
    
    # Save the model
    save_rom_model(filepath, model)
    
    @test isfile(filepath)
    
    # Load the model
    loaded_model = load_rom_model(filepath)
    
    # Verify loaded model type and field values
    @test loaded_model isa RBFInterpolator
    @test loaded_model.weights == model.weights
    @test loaded_model.centers == model.centers
    @test loaded_model.epsilon == model.epsilon
    @test loaded_model.scaling_params.min_vals == model.scaling_params.min_vals
    @test loaded_model.scaling_params.max_vals == model.scaling_params.max_vals
    @test loaded_model.parameter_bounds == model.parameter_bounds
    @test loaded_model.metadata == model.metadata
    
    # Clean up
    rm(temp_dir; force=true, recursive=true)
end

@testset "ROMInterpolator High-Level API Test" begin
    # train_rom と evaluate_rom をインポート
    using .ROMInterpolator: train_rom, evaluate_rom

    # テストデータ
    X = [1.0 2.0 3.0;
         4.0 5.0 6.0]
    Y = [10.0 20.0 30.0;
         40.0 50.0 60.0;
         70.0 80.0 90.0]
         
    temp_dir = joinpath(@__DIR__, "temp_high_level_test")
    rm(temp_dir; force=true, recursive=true)
    model_path = joinpath(temp_dir, "rom_model.jld2")
    
    # 1. train_rom の検証
    model = train_rom(X, Y, model_path; epsilon=0.5, lambda=1e-9)
    
    @test model isa RBFInterpolator
    @test isfile(model_path)
    @test model.epsilon == 0.5
    @test size(model.weights) == (3, 3)
    
    # 2. evaluate_rom の検証 (範囲内)
    basis = [1.0 0.0 0.0;
             0.0 1.0 0.0;
             0.0 0.0 1.0;
             0.1 0.2 0.3]
    mean_field = [0.1, 0.2, 0.3, 0.4]
    
    mu_in = [2.0, 5.0]
    theta_in = evaluate_rom(model, basis, mean_field, mu_in)
    
    # 計算された theta_in が期待値に近いことを確認
    expected_in = [20.1, 50.2, 80.3, 36.4]
    @test theta_in ≈ expected_in atol=1e-3
    
    # 3. evaluate_rom の検証 (範囲外: 外挿警告が発生すること)
    mu_out = [0.0, 5.0]
    
    @test_logs (:warn, "[Warning] Input parameter mu is outside the training bounds (extrapolation).") begin
        theta_out = evaluate_rom(model, basis, mean_field, mu_out)
        @test length(theta_out) == 4
    end
    
    # クリーンアップ
    rm(temp_dir; force=true, recursive=true)
end

@testset "ROMInterpolator Integration with PODEngine Test" begin
    # 1. Load PODEngine safely
    if !isdefined(Main, :PODEngine)
        include("../src/PODEngine/PODEngine.jl")
    end
    using .PODEngine
    using .ROMInterpolator: train_rom, evaluate_rom, get_tmax

    # 2. Simulate snapshot data generation
    # Let N_grid = 120 (spatial points), N_snapshots = 15, N_dim = 8 (parameter dimension)
    N_grid = 120
    N_snapshots = 15
    N_dim = 8

    # Generate parameter matrix mu_vectors (N_dim x N_snapshots) in [0.1, 0.9]
    import Random
    rng = Random.MersenneTwister(42)
    mu_vectors = 0.1 .+ 0.8 .* rand(rng, N_dim, N_snapshots)

    # Generate snapshot matrix (N_grid x N_snapshots)
    # The temperature field should be physically plausible (e.g. [20.0, 900.0])
    base_temp = 300.0 .+ 200.0 .* sin.(range(0, pi, length=N_grid)) # ranges from 300 to 500
    X_snapshots = zeros(N_grid, N_snapshots)
    for i in 1:N_snapshots
        # Parametric variation
        var_factor = sum(mu_vectors[:, i]) / N_dim # ranges around 0.5
        X_snapshots[:, i] = base_temp .* (0.8 + 0.4 * var_factor) # temperature ranges [240, 720]
    end

    # 3. Compute POD modes, singular values, coefficients, and mean field
    basis, singular_values, coefficients, mean_field = PODEngine.compute_pod(X_snapshots; ric_threshold=0.999)

    # N_modes is the number of selected modes
    N_modes = size(basis, 2)
    @test N_modes > 0
    @test size(coefficients) == (N_modes, N_snapshots)

    # 4. Train RBF Interpolator model
    temp_dir = joinpath(@__DIR__, "temp_integration_test")
    rm(temp_dir; force=true, recursive=true)
    model_path = joinpath(temp_dir, "integrated_rom_model.jld2")

    model = train_rom(mu_vectors, coefficients, model_path; epsilon=1.0, lambda=1e-8)
    @test model isa RBFInterpolator
    @test isfile(model_path)

    # 5. Evaluate the trained ROM interpolator model on a new parameter mu_new
    min_bounds = minimum(mu_vectors, dims=2)
    max_bounds = maximum(mu_vectors, dims=2)
    mu_new = vec(min_bounds + 0.5 * (max_bounds - min_bounds))

    # Evaluate the model
    theta_new = evaluate_rom(model, basis, mean_field, mu_new)

    # 6. Verify temperature field physical plausibility
    # Check length
    @test length(theta_new) == N_grid

    # Check that temperature values are in a reasonable physical range [20.0, 1000.0]
    @test all(20.0 .<= theta_new .<= 1000.0)

    # Check get_tmax calculates the maximum temperature correctly
    tmax = get_tmax(theta_new)
    @test tmax ≈ maximum(theta_new)

    # Clean up
    rm(temp_dir; force=true, recursive=true)
end




