# scaler.jl - Data Scaling functions for ROMInterpolator

"""
    fit_scaler(data::Matrix{Float64}) -> ScalingParams

密度マップの正規化のための最小値・最大値を各次元（各行）に沿って計算します。
データは N_dim x N_samples の行列です。
"""
function fit_scaler(data::Matrix{Float64})
    n_dim = size(data, 1)
    min_vals = Vector{Float64}(undef, n_dim)
    max_vals = Vector{Float64}(undef, n_dim)
    for i in 1:n_dim
        row = view(data, i, :)
        min_vals[i] = minimum(row)
        max_vals[i] = maximum(row)
    end
    return ScalingParams(min_vals, max_vals)
end

"""
    scale_data(data::AbstractVecOrMat, params::ScalingParams)

Min-Max正規化を実行します。
各次元で max - min < 1e-12 の場合は 0.0 を出力してゼロ除算を回避します。
"""
function scale_data(data::AbstractVector, params::ScalingParams)
    n_dim = length(data)
    @assert n_dim == length(params.min_vals) "Data dimension mismatch with scaling parameters"
    scaled = Vector{Float64}(undef, n_dim)
    for i in 1:n_dim
        diff = params.max_vals[i] - params.min_vals[i]
        if diff < 1e-12
            scaled[i] = 0.0
        else
            scaled[i] = (data[i] - params.min_vals[i]) / diff
        end
    end
    return scaled
end

function scale_data(data::AbstractMatrix, params::ScalingParams)
    n_dim, n_samples = size(data)
    @assert n_dim == length(params.min_vals) "Data dimension mismatch with scaling parameters"
    scaled = Matrix{Float64}(undef, n_dim, n_samples)
    for i in 1:n_dim
        diff = params.max_vals[i] - params.min_vals[i]
        if diff < 1e-12
            for j in 1:n_samples
                scaled[i, j] = 0.0
            end
        else
            min_val = params.min_vals[i]
            for j in 1:n_samples
                scaled[i, j] = (data[i, j] - min_val) / diff
            end
        end
    end
    return scaled
end
