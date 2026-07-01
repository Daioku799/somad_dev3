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
