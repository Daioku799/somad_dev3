using Test
using Statistics

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "H2-rom", "src", "ObjectiveMetrics", "ObjectiveMetrics.jl"))
using .ObjectiveMetrics

const DX = 5.0e-6
const DY = 5.0e-6

"""層ごとに厚みが違う z 座標。本モデルと同様に等間隔ではない。"""
nonuniform_z(nz) = cumsum([i % 3 == 0 ? 2.5e-6 : 22.5e-6 for i in 1:nz])

"""`f(x, y, z)` から内部領域のみの列ベクトルを作る。"""
function make_column(f, inner, zc)
    nx, ny, nz = inner
    T = Array{Float64}(undef, nx, ny, nz)
    for k in 1:nz, j in 1:ny, i in 1:nx
        T[i, j, k] = f((i - 0.5) * DX, (j - 0.5) * DY, zc[k])
    end
    return vec(T)
end

@testset "ObjectiveMetrics 温度場由来の候補" begin
    inner = (8, 8, 6)
    zc = nonuniform_z(inner[3])
    geom = GridGeometry(dx = DX, dy = DY, z_centers = zc)

    @testset "一様な温度場では全指標が0" begin
        col = make_column((x, y, z) -> 310.0, inner, zc)
        m = field_metrics(col, inner, geom)
        @test m.hot_plane_dt == 0.0
        @test m.hot_plane_grad_max == 0.0
        @test m.max_plane_dt == 0.0
        @test m.grad3d_max == 0.0
        @test m.grad3d_mean == 0.0
    end

    @testset "x方向の線形場で勾配が厳密に一致する" begin
        a = 2.0e5                      # K/m
        col = make_column((x, y, z) -> 300.0 + a * x, inner, zc)
        m = field_metrics(col, inner, geom)
        @test m.hot_plane_grad_max ≈ a
        @test m.grad3d_max ≈ a
        @test m.grad3d_mean ≈ a
        # 面内温度差は端から端までの差
        @test m.hot_plane_dt ≈ a * (inner[1] - 1) * DX
        @test m.max_plane_dt ≈ m.hot_plane_dt
    end

    @testset "z方向のみの場では面内指標が0になる" begin
        b = 1.5e5
        col = make_column((x, y, z) -> 300.0 + b * z, inner, zc)
        m = field_metrics(col, inner, geom)
        @test m.hot_plane_dt == 0.0
        @test m.hot_plane_grad_max == 0.0
        @test m.max_plane_dt == 0.0
        @test m.grad3d_max ≈ b
        @test m.grad3d_mean ≈ b
        # 最大温度は最も z が大きい面に乗る
        @test m.hot_plane_k == inner[3]
    end

    @testset "z の非等間隔が勾配に効く" begin
        b = 1.5e5
        col = make_column((x, y, z) -> 300.0 + b * z, inner, zc)
        wrong = GridGeometry(dx = DX, dy = DY,
                             z_centers = collect(range(zc[1], zc[end], length = inner[3])))
        @test field_metrics(col, inner, geom).grad3d_max ≈ b
        # 等間隔と誤認すると値がずれる（非等間隔を正しく扱っている証拠）
        @test !isapprox(field_metrics(col, inner, wrong).grad3d_max, b; rtol = 1e-3)
    end

    @testset "最大温度が乗る面を正しく選ぶ" begin
        kpeak = 4
        col = make_column((x, y, z) -> 300.0, inner, zc)
        T = reshape(col, inner)
        T[3, 3, kpeak] = 340.0            # この面だけ突出させる
        T[5, 5, 2] = 320.0                # 2番目に高い面
        m = field_metrics(vec(T), inner, geom)
        @test m.hot_plane_k == kpeak
        @test m.hot_plane_dt ≈ 40.0
        # 全面での最大は最も差の大きい面（= kpeak）
        @test m.max_plane_dt ≈ 40.0
    end

    @testset "全面の最大は最高温面の値以上" begin
        col = make_column((x, y, z) -> 300.0 + 3.0e4 * x + 8.0e4 * z + 1.0e9 * x * z,
                          inner, zc)
        m = field_metrics(col, inner, geom)
        @test m.max_plane_dt >= m.hot_plane_dt
    end

    @testset "中心差分は内部でのみ評価する" begin
        col = make_column((x, y, z) -> 300.0, inner, zc)
        base = field_metrics(col, inner, geom)
        @test base.grad3d_max == 0.0

        # 角のセルは、どの評価点の中心差分にも現れない。
        # (1,1,1) を見るのは (2,1,1) (1,2,1) (1,1,2) だが、いずれも
        # 添字に 1 を含むため評価点にならない。
        Tc = reshape(copy(col), inner)
        Tc[1, 1, 1] = 1000.0
        mc = field_metrics(vec(Tc), inner, geom)
        @test mc.grad3d_max == 0.0        # 勾配からは見えない
        @test mc.max_plane_dt ≈ 700.0     # 面内温度差からは見える
        @test mc.hot_plane_k == 1

        # 内部のセルなら評価点の中心差分に現れる
        Ti = reshape(copy(col), inner)
        Ti[3, 3, 3] = 1000.0
        mi = field_metrics(vec(Ti), inner, geom)
        @test mi.grad3d_max > 0.0
    end

    @testset "格子が小さすぎる場合は勾配を0とする" begin
        tiny = (2, 2, 2)
        zt = nonuniform_z(2)
        gt = GridGeometry(dx = DX, dy = DY, z_centers = zt)
        col = make_column((x, y, z) -> 300.0 + 1.0e5 * x, tiny, zt)
        m = field_metrics(col, tiny, gt)
        @test m.hot_plane_grad_max == 0.0
        @test m.grad3d_max == 0.0
        @test m.grad3d_mean == 0.0
        @test m.hot_plane_dt > 0.0       # 温度差は測れる
    end

    @testset "形の不一致は中止する" begin
        col = make_column((x, y, z) -> 300.0, inner, zc)
        @test_throws MetricError field_metrics(col, (9, 8, 6), geom)
        bad = GridGeometry(dx = DX, dy = DY, z_centers = zc[1:end-1])
        @test_throws MetricError field_metrics(col, inner, bad)
    end

    @testset "全ケースについて算出する" begin
        ncase = 5
        cols = hcat([make_column((x, y, z) -> 300.0 + (c * 1.0e4) * x + 5.0e4 * z,
                                 inner, zc) for c in 1:ncase]...)
        vals = field_metrics_all(cols, inner, geom)
        for k in FIELD_METRIC_NAMES
            v = getproperty(vals, Symbol(k))
            @test length(v) == ncase
            @test all(isfinite, v)
        end
        # 勾配は c に対して単調に増える
        @test issorted(vals.hot_plane_grad_max)
        @test length(FIELD_METRIC_NAMES) == 5
    end
end
