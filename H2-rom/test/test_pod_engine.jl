using Test

if !isdefined(Main, :PODEngine)
    include("../src/PODEngine/PODEngine.jl")
end
using .PODEngine

@testset "PODEngine Types Test" begin
    # Dummy fields for PODModel
    basis = [1.0 2.0; 3.0 4.0]
    singular_values = [5.0, 6.0]
    coefficients = [7.0 8.0; 9.0 10.0]
    mean_field = [11.0, 12.0]
    snapshot_ids = ["snap1", "snap2"]
    mu_vectors = [0.1 0.2; 0.3 0.4]
    metadata = Dict{String, Any}(
        "ric_threshold" => 0.999,
        "n_modes" => 2,
        "trained_snapshot_ids" => ["snap1", "snap2"],
        "grid" => Dict{String, Any}(
            "dims" => (2, 2, 1),
            "spacing" => (0.1, 0.1, 0.1),
            "physical_size" => (0.2, 0.2, 0.1)
        )
    )

    model = PODModel(
        basis,
        singular_values,
        coefficients,
        mean_field,
        snapshot_ids,
        mu_vectors,
        metadata
    )

    @test model.basis == basis
    @test model.singular_values == singular_values
    @test model.coefficients == coefficients
    @test model.mean_field == mean_field
    @test model.snapshot_ids == snapshot_ids
    @test model.mu_vectors == mu_vectors
    @test model.metadata == metadata
end

@testset "PODEngine Snapshot Loader Test" begin
    using JLD2
    mktempdir() do tmpdir
        JLD2.jldopen(joinpath(tmpdir, "snap1.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_1", "mu" => [0.1, 0.2])
            file["z_centers"] = [0.05, 0.15]
        end
        
        JLD2.jldopen(joinpath(tmpdir, "snap2.jld2"), "w") do file
            file["temperature"] = reshape(collect(19.0:36.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_2", "mu" => [0.3, 0.4])
            file["z_centers"] = [0.05, 0.15]
        end
        
        X, snapshot_ids, mu_vectors, grid_info = load_snapshot_matrix(tmpdir)
        
        @test size(X) == (18, 2)
        @test X[:, 1] == collect(1.0:18.0)
        @test X[:, 2] == collect(19.0:36.0)
        @test snapshot_ids == ["snap_1", "snap_2"]
        @test size(mu_vectors) == (2, 2)
        @test mu_vectors[:, 1] == [0.1, 0.2]
        @test mu_vectors[:, 2] == [0.3, 0.4]
        @test grid_info["nx"] == 3
        @test grid_info["ny"] == 3
        @test grid_info["nz"] == 2
        @test grid_info["z_centers"] == [0.05, 0.15]
    end

    mktempdir() do tmpdir
        JLD2.jldopen(joinpath(tmpdir, "snap1.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_1", "mu" => [0.1, 0.2])
        end
        
        JLD2.jldopen(joinpath(tmpdir, "snap2.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 4 # Mismatched nx
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_2", "mu" => [0.3, 0.4])
        end
        
        @test_throws ErrorException load_snapshot_matrix(tmpdir)
    end
end

@testset "PODEngine SVD Solver Test" begin
    using LinearAlgebra
    # 既知の行列 X (3行2列)
    X = [1.0 2.0; 3.0 5.0; 5.0 8.0]
    
    # 期待される平均値 (各行の平均)
    # 1行目: (1+2)/2 = 1.5
    # 2行目: (3+5)/2 = 4.0
    # 3行目: (5+8)/2 = 6.5
    expected_mean = [1.5, 4.0, 6.5]
    
    # まだ compute_pod が定義/エクスポートされていないため、
    # この呼び出しは例外またはエラーを起こすはずです。
    Ur, Sr, Vr_coeffs, mean_field = compute_pod(X; ric_threshold=0.999)
    
    # 平均値の検証
    @test mean_field ≈ expected_mean
    
    # 中心化行列の検証
    X_centered = X .- mean_field
    
    # 係数と基底を用いた復元テンソルの検証
    # X_centered ≈ Ur * Vr_coeffs
    @test Ur * Vr_coeffs ≈ X_centered atol=1e-12
    
    # 特異値と基底の関係
    # Ur は正規直交基底であるはず: Ur' * Ur ≈ I
    @test Ur' * Ur ≈ Matrix(I, size(Ur, 2), size(Ur, 2)) atol=1e-12
end

@testset "PODEngine RIC-based Truncation Test" begin
    # 4列のスナップショット行列を作成し、平均場がゼロになるように設計
    # これにより中心化行列のランクが3になり、3つの非ゼロ特異値を得られる
    X = [10.0  0.0  0.0 -10.0;
          0.0  1.0  0.0  -1.0;
          0.0  0.0  0.1  -0.1;
          0.0  0.0  0.0   0.0]
    
    # 特異値の二乗: 200.0, 2.0, 0.02
    # 総分散: 202.02
    # 累積比率 (RIC):
    # 1モード目: 200.0 / 202.02 ≈ 0.989999
    # 2モード目: 202.0 / 202.02 ≈ 0.999901
    # 3モード目: 202.02 / 202.02 = 1.0
    
    # 1. 異なる ric_threshold で異なるモード数が選択されるか検証
    Ur, Sr, Vr_coeffs, mf = compute_pod(X; ric_threshold=0.95)
    @test length(Sr) == 1
    
    Ur, Sr, Vr_coeffs, mf = compute_pod(X; ric_threshold=0.995)
    @test length(Sr) == 2
    
    Ur, Sr, Vr_coeffs, mf = compute_pod(X; ric_threshold=0.99999)
    @test length(Sr) == 3
    
    # 2. デフォルトのしきい値 (0.999) の検証
    Ur_def, Sr_def, Vr_coeffs_def, mf_def = compute_pod(X)
    @test length(Sr_def) == 2
    
    # 3. エッジケース: しきい値が 1.0 のとき
    Ur_1, Sr_1, Vr_coeffs_1, mf_1 = compute_pod(X; ric_threshold=1.0)
    @test length(Sr_1) == 3
    
    # 4. エッジケース: ゼロ分散 (平坦な行列)
    X_flat = [2.0 2.0 2.0; 2.0 2.0 2.0; 2.0 2.0 2.0]
    Ur_flat, Sr_flat, Vr_coeffs_flat, mf_flat = compute_pod(X_flat; ric_threshold=0.999)
    @test length(Sr_flat) == 1
    @test all(Sr_flat .≈ 0.0)
end

@testset "PODEngine Model Persistence Test" begin
    # Create a dummy model
    basis = [1.0 2.0; 3.0 4.0; 5.0 6.0]
    singular_values = [10.0, 5.0]
    coefficients = [1.0 2.0; 3.0 4.0]
    mean_field = [1.5, 2.5, 3.5]
    snapshot_ids = ["s1", "s2"]
    mu_vectors = [0.1 0.2; 0.3 0.4]
    metadata = Dict{String, Any}(
        "ric_threshold" => 0.99,
        "n_modes" => 2,
        "trained_snapshot_ids" => ["s1", "s2"],
        "grid" => Dict{String, Any}(
            "dims" => (3, 1, 1),
            "spacing" => (0.5, 0.5, 0.5),
            "physical_size" => (1.5, 0.5, 0.5)
        )
    )
    
    model = PODModel(basis, singular_values, coefficients, mean_field, snapshot_ids, mu_vectors, metadata)
    
    mktempdir() do tmpdir
        filepath = joinpath(tmpdir, "model.jld2")
        
        # This should fail initially because save_pod_model is not defined/exported
        save_pod_model(filepath, model)
        
        # Load the model
        loaded_model = load_pod_model(filepath)
        
        # Verify fields
        @test loaded_model.basis == model.basis
        @test loaded_model.singular_values == model.singular_values
        @test loaded_model.coefficients == model.coefficients
        @test loaded_model.mean_field == model.mean_field
        @test loaded_model.snapshot_ids == model.snapshot_ids
        @test loaded_model.mu_vectors == model.mu_vectors
        @test loaded_model.metadata == model.metadata
    end
end

@testset "PODEngine Pipeline Integration Test" begin
    using JLD2
    mktempdir() do raw_dir
        # Create dummy snapshots
        JLD2.jldopen(joinpath(raw_dir, "snap1.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:6.0), 3, 2, 1)
            file["nx"] = 3
            file["ny"] = 2
            file["nz"] = 1
            file["metadata"] = Dict("snapshot_id" => "snap_1", "mu" => [0.1, 0.2])
        end
        
        JLD2.jldopen(joinpath(raw_dir, "snap2.jld2"), "w") do file
            file["temperature"] = reshape(collect(7.0:12.0), 3, 2, 1)
            file["nx"] = 3
            file["ny"] = 2
            file["nz"] = 1
            file["metadata"] = Dict("snapshot_id" => "snap_2", "mu" => [0.3, 0.4])
        end
        
        mktempdir() do model_dir
            model_path = joinpath(model_dir, "pod_model.jld2")
            
            # Run the generator orchestrator
            run_pod_generation(raw_dir, model_path; ric_threshold=0.999)
            
            # Load and verify the generated model
            model = load_pod_model(model_path)
            
            @test size(model.basis, 1) == 6
            @test length(model.singular_values) >= 1
            @test size(model.coefficients, 2) == 2
            @test length(model.mean_field) == 6
            @test model.snapshot_ids == ["snap_1", "snap_2"]
            @test size(model.mu_vectors) == (2, 2)
            @test model.metadata["ric_threshold"] == 0.999
            @test model.metadata["n_modes"] == length(model.singular_values)
            @test model.metadata["trained_snapshot_ids"] == ["snap_1", "snap_2"]
            @test model.metadata["grid"]["dims"] == (3, 2, 1)
        end
    end
end




