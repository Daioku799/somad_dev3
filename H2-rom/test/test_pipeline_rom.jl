using Test
using JLD2
using LinearAlgebra
using Statistics
using Random

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "H2-rom", "src", "PipelineROM", "PipelineROM.jl"))
using .PipelineROM

"""
設計変数 mu になめらかに依存する合成温度場を作る。

内部領域のみを列に並べた行列を返す（PipelineData.field と同じ規約）。
線形項・二次項・交差項でそれぞれ独立な空間応答を使うため、温度場は
3*ncell 次元の部分空間を張る。基底数の候補を十分に取れるようにするための構成。
mu に対して滑らかなので POD + RBF はほぼ厳密に再現でき、かつ二次項と交差項が
あるため線形和モデルでは再現しきれない。
"""
function make_synthetic(; ncell = 6, inner = (5, 5, 4), n_train = 30,
                          n_val = 8, n_test = 8, seed = 7)
    rng = MersenneTwister(seed)
    ngrid = prod(inner)
    lin   = [randn(rng, ngrid) for _ in 1:ncell]
    quad  = [randn(rng, ngrid) for _ in 1:ncell]
    cross = [randn(rng, ngrid) for _ in 1:ncell]
    total = n_train + n_val + n_test
    mu = Matrix{Float64}(undef, ncell, total)
    field = Matrix{Float64}(undef, ngrid, total)
    for j in 1:total
        m = rand(rng, ncell)
        mu[:, j] = m
        col = fill(300.0, ngrid)
        for i in 1:ncell
            nxt = i == ncell ? 1 : i + 1
            col .+= m[i] .* lin[i]
            col .+= 0.40 * m[i]^2 .* quad[i]
            col .+= 0.30 * (m[i] * m[nxt]) .* cross[i]
        end
        field[:, j] = col
    end
    names = ["c$(lpad(j, 2, '0'))" for j in 1:total]
    return (field = field, mu = mu, inner = inner, names = names,
            train = collect(1:n_train),
            validation = collect(n_train+1:n_train+n_val),
            test = collect(n_train+n_val+1:total))
end

const S = make_synthetic()

@testset "PipelineROM" begin

    @testset "build_rom は学習分割のみを使う" begin
        st = RomSettings(modes = 6, epsilon = 1.0, lambda = 1e-8)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        # 補間の中心は学習ケース数と一致する
        @test size(m.interpolator.centers, 2) == length(S.train)
        @test m.train_names == S.names[S.train]
        @test size(m.basis, 2) == 6
        @test length(m.mean_field) == prod(S.inner)
        @test m.inner_shape == S.inner
        # 平均場は学習分割の平均であり、全体の平均ではない
        @test m.mean_field ≈ vec(mean(S.field[:, S.train], dims = 2))
        @test !(m.mean_field ≈ vec(mean(S.field, dims = 2)))
    end

    @testset "基底数が学習ケース数を超える指定は中止する" begin
        st = RomSettings(modes = 999, epsilon = 1.0, lambda = 1e-8)
        @test_throws RomBuildError build_rom(S.field, S.mu, S.train, S.inner, st;
                                             names = S.names)
    end

    @testset "学習点では POD 射影を再現する" begin
        # 正則化をほぼ切れば、RBF は学習点で厳密に補間する。したがって予測は
        # 打ち切り基底への射影と一致し、残差は補間誤差ではなく打ち切り誤差になる。
        st = RomSettings(modes = 12, epsilon = 1.0, lambda = 1e-12)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        i = S.train[3]
        p = predict_field(m, S.mu[:, i])
        t = S.field[:, i]
        proj = m.mean_field .+ m.basis * (m.basis' * (t .- m.mean_field))
        @test norm(p .- proj) / norm(proj) < 1e-8
        @test predict_tmax(m, S.mu[:, i]) ≈ maximum(proj) atol = 1e-8
        # 12基底でも打ち切り誤差自体は小さい
        @test norm(proj .- t) / norm(t) < 0.01
    end

    @testset "evaluate_accuracy が4指標を返す" begin
        st = RomSettings(modes = 8, epsilon = 1.0, lambda = 1e-8)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        r = evaluate_accuracy(m, S.field, S.mu, S.test; names = S.names)
        @test r.n == length(S.test)
        for v in (r.tmax_mae, r.tmax_rmse, r.tmax_maxe, r.field_l2_rel)
            @test isfinite(v) && v >= 0.0
        end
        # 定義どおりの関係
        @test r.tmax_mae <= r.tmax_rmse + 1e-12
        @test r.tmax_rmse <= r.tmax_maxe + 1e-12
        @test r.names == S.names[S.test]
        @test length(r.tmax_pred) == length(S.test)
        @test r.tmax_true ≈ [maximum(S.field[:, i]) for i in S.test]
    end

    @testset "誤差指標の値が定義と一致する" begin
        st = RomSettings(modes = 8, epsilon = 1.0, lambda = 1e-8)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        r = evaluate_accuracy(m, S.field, S.mu, S.validation; names = S.names)
        d = r.tmax_pred .- r.tmax_true
        @test r.tmax_mae ≈ mean(abs.(d))
        @test r.tmax_rmse ≈ sqrt(mean(abs2, d))
        @test r.tmax_maxe ≈ maximum(abs.(d))
    end

    @testset "保存して再読み込みしても同じ予測になる" begin
        st = RomSettings(modes = 10, epsilon = 0.5, lambda = 1e-6)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        mktempdir() do dir
            path = joinpath(dir, "rom_model.jld2")
            save_rom(path, m)
            @test isfile(path)
            m2 = load_rom(path)
            @test m2.settings == m.settings
            @test m2.inner_shape == m.inner_shape
            @test m2.train_names == m.train_names
            for i in vcat(S.validation, S.test)
                @test predict_field(m2, S.mu[:, i]) ≈ predict_field(m, S.mu[:, i])
                @test predict_tmax(m2, S.mu[:, i]) == predict_tmax(m, S.mu[:, i])
            end
            r1 = evaluate_accuracy(m,  S.field, S.mu, S.test; names = S.names)
            r2 = evaluate_accuracy(m2, S.field, S.mu, S.test; names = S.names)
            @test r1.tmax_mae == r2.tmax_mae
            @test r1.field_l2_rel == r2.field_l2_rel
        end
    end

    @testset "select_settings は候補の中から選ぶ" begin
        grid = (modes = [4, 8, 12], epsilon = [0.5, 1.0], lambda = [1e-8, 1e-6])
        best, rows, model = select_settings(S.field, S.mu, S.train, S.validation, S.inner;
                                            modes = grid.modes, epsilons = grid.epsilon,
                                            lambdas = grid.lambda, names = S.names)
        @test best.modes in grid.modes
        @test best.epsilon in grid.epsilon
        @test best.lambda in grid.lambda
        @test length(rows) == length(grid.modes) * length(grid.epsilon) * length(grid.lambda)
        # 選ばれた設定は候補中で最小の Tmax 平均絶対誤差を持つ
        @test minimum(r.tmax_mae for r in rows) ≈
              first(r.tmax_mae for r in rows if r.modes == best.modes &&
                    r.epsilon == best.epsilon && r.lambda == best.lambda)
        # 返るモデルは best 設定で構築したものと同一の予測を返す
        @test model.settings == best
        ref = build_rom(S.field, S.mu, S.train, S.inner, best; names = S.names)
        for i in S.test
            @test predict_field(model, S.mu[:, i]) ≈ predict_field(ref, S.mu[:, i])
        end
    end

    @testset "基底数が学習ケース数を超える候補は飛ばす" begin
        # 学習24件に対し modes=40 は成立しない。候補から除かれるだけで中止しない
        best, rows, _ = select_settings(S.field, S.mu, S.train, S.validation, S.inner;
                                        modes = [4, 40], epsilons = [1.0],
                                        lambdas = [1e-8], names = S.names)
        @test best.modes == 4
        @test length(rows) == 1
    end

    @testset "非線形項があるため線形和モデルより誤差が小さい" begin
        st = RomSettings(modes = 12, epsilon = 1.0, lambda = 1e-8)
        m = build_rom(S.field, S.mu, S.train, S.inner, st; names = S.names)
        r = evaluate_accuracy(m, S.field, S.mu, S.test; names = S.names)
        # セル別本数の線形和で Tmax を回帰する
        A = hcat(ones(length(S.names)), permutedims(S.mu))
        y = [maximum(S.field[:, j]) for j in 1:length(S.names)]
        b = A[S.train, :] \ y[S.train]
        lin_mae = mean(abs.(A[S.test, :] * b .- y[S.test]))
        @test r.tmax_mae < lin_mae
    end
end
