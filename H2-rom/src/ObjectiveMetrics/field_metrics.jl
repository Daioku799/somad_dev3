"""温度場から算出する候補指標の名前。順序は出力表の列順に対応する。"""
const FIELD_METRIC_NAMES = ("hot_plane_dt", "hot_plane_grad_max", "max_plane_dt",
                            "grad3d_max", "grad3d_mean")

"""面 `k` の面内温度差（最大 − 最小）。"""
function _plane_dt(T::AbstractArray{Float64,3}, k::Int)
    p = @view T[:, :, k]
    return maximum(p) - minimum(p)
end

"""
面 `k` の面内勾配の大きさの最大値 [K/m]。

中心差分で求めるため、評価点は各方向の端を除いた内部に限る。
端を評価点にできる格子が無い場合は 0 を返す。
"""
function _plane_grad_max(T::AbstractArray{Float64,3}, k::Int, dx::Float64, dy::Float64)
    nx, ny, _ = size(T)
    (nx >= 3 && ny >= 3) || return 0.0
    best = 0.0
    @inbounds for j in 2:ny-1, i in 2:nx-1
        gx = (T[i+1, j, k] - T[i-1, j, k]) / (2dx)
        gy = (T[i, j+1, k] - T[i, j-1, k]) / (2dy)
        g = sqrt(gx * gx + gy * gy)
        g > best && (best = g)
    end
    return best
end

"""
三次元勾配の大きさの最大値と平均 [K/m]。

z は等間隔ではないため、`(T[k+1] - T[k-1]) / (z[k+1] - z[k-1])` で差分を取る。
評価点は3方向とも端を除いた内部に限る。
"""
function _grad3d_stats(T::AbstractArray{Float64,3}, geom::GridGeometry)
    nx, ny, nz = size(T)
    (nx >= 3 && ny >= 3 && nz >= 3) || return (0.0, 0.0)
    z = geom.z_centers
    dx, dy = geom.dx, geom.dy
    best = 0.0
    acc = 0.0
    cnt = 0
    @inbounds for k in 2:nz-1
        dz = z[k+1] - z[k-1]
        dz != 0.0 || throw(MetricError("z 座標が重複している（k=$k）ため差分を取れない"))
        for j in 2:ny-1, i in 2:nx-1
            gx = (T[i+1, j, k] - T[i-1, j, k]) / (2dx)
            gy = (T[i, j+1, k] - T[i, j-1, k]) / (2dy)
            gz = (T[i, j, k+1] - T[i, j, k-1]) / dz
            g = sqrt(gx * gx + gy * gy + gz * gz)
            g > best && (best = g)
            acc += g
            cnt += 1
        end
    end
    return (best, cnt == 0 ? 0.0 : acc / cnt)
end

"""
    field_metrics(column, inner_shape, geom) -> NamedTuple

1ケース分の温度場から、候補指標5種を算出する。`column` はゴーストセルを
除いた内部領域のみを並べた列ベクトル。

- `hot_plane_dt`: 最大温度が乗る z 面での面内温度差 [K]
- `hot_plane_grad_max`: 同じ面での面内勾配の大きさの最大 [K/m]
- `max_plane_dt`: 全ての z 面で面内温度差を求めた最大値 [K]
- `grad3d_max` / `grad3d_mean`: 三次元勾配の大きさの最大と平均 [K/m]

診断用に、最大温度が乗る面の添字 `hot_plane_k` も返す。
"""
function field_metrics(column::AbstractVector{Float64}, inner_shape::NTuple{3,Int},
                       geom::GridGeometry)
    nx, ny, nz = inner_shape
    length(column) == nx * ny * nz ||
        throw(MetricError("列の長さ $(length(column)) が内部形状 $(inner_shape) と一致しない"))
    length(geom.z_centers) == nz ||
        throw(MetricError("z 座標の数 $(length(geom.z_centers)) が内部形状の nz=$(nz) と一致しない"))

    T = reshape(column, inner_shape)

    kbest = 1
    vbest = -Inf
    max_dt = 0.0
    @inbounds for k in 1:nz
        p = @view T[:, :, k]
        hi = maximum(p)
        dt = hi - minimum(p)
        dt > max_dt && (max_dt = dt)
        if hi > vbest
            vbest = hi
            kbest = k
        end
    end

    gmax, gmean = _grad3d_stats(T, geom)
    return (hot_plane_k = kbest,
            hot_plane_dt = _plane_dt(T, kbest),
            hot_plane_grad_max = _plane_grad_max(T, kbest, geom.dx, geom.dy),
            max_plane_dt = max_dt,
            grad3d_max = gmax,
            grad3d_mean = gmean)
end

"""
    field_metrics_all(field, inner_shape, geom) -> NamedTuple

全ケースについて候補指標を算出し、指標ごとのベクトルにして返す。
列順は `field` の列順と一致する。
"""
function field_metrics_all(field::AbstractMatrix{Float64}, inner_shape::NTuple{3,Int},
                           geom::GridGeometry)
    n = size(field, 2)
    hot_k = Vector{Int}(undef, n)
    out = Dict(name => Vector{Float64}(undef, n) for name in FIELD_METRIC_NAMES)
    for j in 1:n
        m = field_metrics(@view(field[:, j]), inner_shape, geom)
        hot_k[j] = m.hot_plane_k
        for name in FIELD_METRIC_NAMES
            out[name][j] = getproperty(m, Symbol(name))
        end
    end
    return (hot_plane_k = hot_k,
            hot_plane_dt = out["hot_plane_dt"],
            hot_plane_grad_max = out["hot_plane_grad_max"],
            max_plane_dt = out["max_plane_dt"],
            grad3d_max = out["grad3d_max"],
            grad3d_mean = out["grad3d_mean"])
end
