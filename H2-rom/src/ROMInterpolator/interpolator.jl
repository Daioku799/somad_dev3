# interpolator.jl - RBF補間器の実装

"""
    compute_kernel_matrix(X::Matrix{Float64}, centers::Matrix{Float64}, epsilon::Float64) -> Matrix{Float64}

入力データ `X` (N_dim x N_s) と中心点 `centers` (N_dim x N_c) の間のガウスRBFカーネル行列を計算する。
返される行列 `Phi` のサイズは N_s x N_c であり、各要素は Phi[i, j] = exp(-(epsilon * r_{i, j})^2) となる。
ここで、r_{i, j} は X[:, i] と centers[:, j] のユークリッド距離である。
"""
function compute_kernel_matrix(X::Matrix{Float64}, centers::Matrix{Float64}, epsilon::Float64)::Matrix{Float64}
    N_dim_X, N_s = size(X)
    N_dim_C, N_c = size(centers)
    
    if N_dim_X != N_dim_C
        throw(DimensionMismatch("次元不一致: Xの次元数は $(N_dim_X) ですが、centersの次元数は $(N_dim_C) です。"))
    end
    
    Phi = Matrix{Float64}(undef, N_s, N_c)
    eps_sq = epsilon * epsilon
    
    @inbounds for j in 1:N_c
        for i in 1:N_s
            dist_sq = 0.0
            for d in 1:N_dim_X
                diff = X[d, i] - centers[d, j]
                dist_sq += diff * diff
            end
            Phi[i, j] = exp(-eps_sq * dist_sq)
        end
    end
    
    return Phi
end

"""
    fit!(interpolator::AbstractInterpolator, X::Matrix{Float64}, Y::Matrix{Float64}; lambda::Float64=1e-6)

RBF補間モデルの重みとスケーリングパラメータなどを学習データ (X, Y) から算出します。
- `X`: 入力パラメータ行列 (N_dim x N_samples)
- `Y`: 出力（PODモード係数）行列 (N_modes x N_samples)
- `lambda`: 正則化パラメータ (デフォルト 1e-6)
"""
function fit!(interpolator::RBFInterpolator, X::Matrix{Float64}, Y::Matrix{Float64}; lambda::Float64=1e-6)
    N_dim, N_s = size(X)
    N_modes, N_s_Y = size(Y)

    if N_s != N_s_Y
        throw(ArgumentError("入力データ X (サンプル数: $(N_s)) と出力データ Y (サンプル数: $(N_s_Y)) のサンプル数が一致しません。"))
    end
    if N_s == 0
        throw(ArgumentError("学習サンプルの数が 0 です。少なくとも 1 つ以上のサンプルが必要です。"))
    end

    # 1. スケーラーのフィッティングとスケーリング
    scaling_params = fit_scaler(X)
    X_scaled = scale_data(X, scaling_params)

    # 2. パラメータ境界の計算 (2 x N_dim)
    # 1行目は各次元の最小値、2行目は最大値
    parameter_bounds = Matrix{Float64}(undef, 2, N_dim)
    parameter_bounds[1, :] .= scaling_params.min_vals
    parameter_bounds[2, :] .= scaling_params.max_vals

    # 3. カーネル行列の計算 (N_s x N_s)
    Phi = compute_kernel_matrix(X_scaled, X_scaled, interpolator.epsilon)

    # 4. 重みの算出: W = Y / (Phi + lambda * I) (N_modes x N_s)
    W = Y / (Phi + lambda * I)

    # フィールドの更新
    interpolator.weights = W
    interpolator.centers = X_scaled
    interpolator.scaling_params = scaling_params
    interpolator.parameter_bounds = parameter_bounds
    interpolator.metadata["kernel_type"] = "gaussian"

    return interpolator
end

"""
    predict(interpolator::AbstractInterpolator, x::Vector{Float64}) -> Vector{Float64}

学習済みの補間モデルを用いて、未知のパラメータ `x` (長さ N_dim) に対する出力（PODモード係数）を予測します。
"""
function predict(interpolator::RBFInterpolator, x::Vector{Float64})::Vector{Float64}
    # 1. 入力スケーリング
    x_scaled = scale_data(x, interpolator.scaling_params)

    # 2. カーネルベクトルの計算 (1 x N_s)
    phi_x = compute_kernel_matrix(reshape(x_scaled, :, 1), interpolator.centers, interpolator.epsilon)

    # 3. 係数の予測 (N_modes x 1)
    phi_x_vec = vec(phi_x)
    a = interpolator.weights * phi_x_vec

    return a
end

"""
    is_reliable(interpolator::AbstractInterpolator, mu::Vector{Float64})::Bool

入力パラメータ `mu` がモデルの信頼領域（外挿でない領域）内にあるかどうかを判定します。
"""
function is_reliable end

"""
    is_reliable(interpolator::RBFInterpolator, mu::Vector{Float64})::Bool

`RBFInterpolator` の信頼領域判定。入力 `mu` の各次元が、学習データのパラメータ範囲（許容誤差 tol = 1e-9）に収まっているか判定します。
"""
function is_reliable(interpolator::RBFInterpolator, mu::Vector{Float64})::Bool
    N_dim = size(interpolator.parameter_bounds, 2)
    if length(mu) != N_dim
        throw(DimensionMismatch("次元不一致: 入力パラメータの次元数は $(length(mu)) ですが、補間器の次元数は $(N_dim) です。"))
    end

    tol = 1e-9
    @inbounds for i in 1:N_dim
        min_val = interpolator.parameter_bounds[1, i]
        max_val = interpolator.parameter_bounds[2, i]
        if !(min_val - tol <= mu[i] <= max_val + tol)
            return false
        end
    end
    return true
end


