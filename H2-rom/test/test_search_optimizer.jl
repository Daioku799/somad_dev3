using Test
using Random

const ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "H2-rom", "src", "SearchOptimizer", "SearchOptimizer.jl"))
using .SearchOptimizer

feasible(c, budget, cap) = sum(c) == budget && all(0 .<= c .<= cap)

@testset "SearchOptimizer" begin
    CAP, NCELL = 9, 4

    # セル番号の重み付き和。制約下の最適解が手で分かる。
    linear(c) = sum(i * c[i] for i in eachindex(c))

    @testset "実行可能な初期設計を作る" begin
        rng = MersenneTwister(1)
        for budget in (0, 1, 12, 20, CAP * NCELL)
            for _ in 1:20
                c = random_design(rng, budget, CAP, NCELL)
                @test feasible(c, budget, CAP)
            end
        end
    end

    @testset "収容できない本数は中止する" begin
        rng = MersenneTwister(1)
        @test_throws SearchError random_design(rng, CAP * NCELL + 1, CAP, NCELL)
        @test_throws SearchError random_design(rng, -1, CAP, NCELL)
    end

    @testset "近傍は1本を別のセルへ移す操作" begin
        c = [9, 3, 0, 0]
        mv = collect(neighbor_moves(c, CAP))
        # 上限に達しているセルへは移せない。空のセルからは移せない
        @test all(c[i] >= 1 && c[j] < CAP for (i, j) in mv)
        @test !any(j == 1 for (_, j) in mv)      # セル1は上限9
        @test !any(i == 3 || i == 4 for (i, _) in mv)  # セル3,4は空
        # 移動後も必ず実行可能
        for (i, j) in mv
            d = copy(c); d[i] -= 1; d[j] += 1
            @test feasible(d, sum(c), CAP)
        end
    end

    @testset "既知の目的関数で最小解に到達する" begin
        cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 30, seed = 42)
        r = multi_start_search(linear, 12, cfg)
        @test r.budget == 12
        @test r.best.counts == [9, 3, 0, 0]
        @test r.best.value ≈ 15.0
        @test all(feasible(s.counts, 12, CAP) for s in r.solutions)
        @test r.n_restart == 30
        @test r.n_distinct == length(r.solutions)
    end

    @testset "同じ実装で最大解も得られる" begin
        cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 30, seed = 42,
                           maximize = true)
        r = multi_start_search(linear, 12, cfg)
        @test r.best.counts == [0, 0, 3, 9]
        @test r.best.value ≈ 45.0
        @test all(feasible(s.counts, 12, CAP) for s in r.solutions)
    end

    @testset "返る設計は全て制約を満たす" begin
        # 谷が多数ある目的関数
        rng = MersenneTwister(7)
        w = randn(rng, NCELL)
        rugged(c) = sum(w[i] * c[i]^2 for i in eachindex(c)) - 0.3 * prod(c .+ 1)
        for budget in (7, 12, 25, 33)
            for mx in (false, true)
                cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 20,
                                   seed = 3, maximize = mx)
                r = multi_start_search(rugged, budget, cfg)
                @test all(feasible(s.counts, budget, CAP) for s in r.solutions)
                @test feasible(r.best.counts, budget, CAP)
                @test 1 <= r.n_distinct <= 20
            end
        end
    end

    @testset "相異なる解を数える" begin
        cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 25, seed = 5)
        r = multi_start_search(linear, 12, cfg)
        # 線形なら谷は1つしかない
        @test r.n_distinct == 1
        @test length(unique(s.counts for s in r.solutions)) == r.n_distinct
    end

    @testset "同じ乱数指定なら同じ結果になる" begin
        mk() = multi_start_search(linear, 15,
                    SearchConfig(cap = CAP, ncell = NCELL, n_restart = 12, seed = 99))
        a, b = mk(), mk()
        @test a.best.counts == b.best.counts
        @test a.best.value == b.best.value
        @test [s.counts for s in a.solutions] == [s.counts for s in b.solutions]
        @test a.n_eval == b.n_eval
        c = multi_start_search(linear, 15,
                SearchConfig(cap = CAP, ncell = NCELL, n_restart = 12, seed = 100))
        @test c.best.counts == a.best.counts     # 最適解は同じ
    end

    @testset "指定の初期設計から降下する" begin
        start = [0, 0, 3, 9]
        s = descend(linear, start, CAP; maximize = false)
        @test s.counts == [9, 3, 0, 0]
        @test s.steps > 0
        # 既に最適なら一歩も動かない
        @test descend(linear, [9, 3, 0, 0], CAP; maximize = false).steps == 0
    end

    @testset "目的関数は設計ベクトルのみを受け取る" begin
        seen = Vector{Vector{Int}}()
        probe(c) = (push!(seen, copy(c)); linear(c))
        multi_start_search(probe, 10,
            SearchConfig(cap = CAP, ncell = NCELL, n_restart = 3, seed = 1))
        @test !isempty(seen)
        @test all(length(c) == NCELL for c in seen)
        @test all(eltype(c) === Int for c in seen)
        @test all(feasible(c, 10, CAP) for c in seen)
    end
end

@testset "SearchOptimizer 本数の走査" begin
    CAP, NCELL = 9, 4
    linear(c) = sum(i * c[i] for i in eachindex(c))

    @testset "一様配置はできるだけ均等に配る" begin
        @test uniform_design(12, CAP, NCELL) == [3, 3, 3, 3]
        @test uniform_design(14, CAP, NCELL) == [4, 4, 3, 3]
        @test uniform_design(0, CAP, NCELL) == [0, 0, 0, 0]
        @test uniform_design(CAP * NCELL, CAP, NCELL) == fill(CAP, NCELL)
        @test_throws SearchError uniform_design(CAP * NCELL + 1, CAP, NCELL)
        for b in 0:(CAP*NCELL)
            c = uniform_design(b, CAP, NCELL)
            @test sum(c) == b && all(0 .<= c .<= CAP)
            @test maximum(c) - minimum(c) <= 1      # 均等の定義
        end
    end

    @testset "学習水準の範囲外を除外する" begin
        @test in_range_budgets(30:70, [36, 48, 60]) == collect(36:60)
        @test in_range_budgets([20, 36, 48, 60, 72], [36, 48, 60]) == [36, 48, 60]
        @test isempty(in_range_budgets([10, 90], [36, 48, 60]))
        @test_throws SearchError in_range_budgets(30:70, Int[])
    end

    @testset "各本数で最良・最悪・一様が揃う" begin
        cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 15, seed = 11)
        rows = budget_sweep(linear, [10, 12, 14], cfg)
        @test [r.budget for r in rows] == [10, 12, 14]
        for r in rows
            @test sum(r.best.counts) == r.budget
            @test sum(r.worst.counts) == r.budget
            @test sum(r.uniform_counts) == r.budget
            @test all(0 .<= r.best.counts .<= CAP)
            @test all(0 .<= r.worst.counts .<= CAP)
            @test r.best.value <= r.uniform_value <= r.worst.value
            @test r.spread ≈ r.worst.value - r.best.value
            @test r.spread >= 0
        end
        r12 = rows[2]
        @test r12.best.counts == [9, 3, 0, 0]
        @test r12.worst.counts == [0, 0, 3, 9]
        @test r12.uniform_counts == [3, 3, 3, 3]
        @test r12.uniform_value ≈ 30.0
    end

    @testset "範囲外の本数は結果に含まれない" begin
        cfg = SearchConfig(cap = CAP, ncell = NCELL, n_restart = 5, seed = 1)
        rows = budget_sweep(linear, [5, 10, 12, 40], cfg; train_budgets = [10, 12])
        @test [r.budget for r in rows] == [10, 12]
        @test !any(r.budget in (5, 40) for r in rows)
    end

    @testset "同じ乱数指定なら同じ走査結果になる" begin
        mk() = budget_sweep(linear, [10, 12],
                    SearchConfig(cap = CAP, ncell = NCELL, n_restart = 8, seed = 77))
        a, b = mk(), mk()
        @test [r.best.counts for r in a] == [r.best.counts for r in b]
        @test [r.worst.counts for r in a] == [r.worst.counts for r in b]
        @test [r.spread for r in a] == [r.spread for r in b]
    end
end

@testset "SearchOptimizer 非劣解集合" begin

    @testset "既知の2目的の点集合" begin
        #  (1,4) (2,2) (3,1) が前線。(3,3) と (4,5) は支配される
        M = [1.0 4.0;
             2.0 2.0;
             3.0 1.0;
             3.0 3.0;
             4.0 5.0]
        @test non_dominated(M) == [1, 2, 3]
    end

    @testset "支配の定義" begin
        mn = [MinimizeObjective, MinimizeObjective]
        @test dominates([1.0, 1.0], [2.0, 2.0], mn)
        @test dominates([1.0, 2.0], [1.0, 3.0], mn)     # 片方が同値でも真に優ればよい
        @test !dominates([1.0, 3.0], [2.0, 2.0], mn)    # 交換関係にある
        @test !dominates([1.0, 1.0], [1.0, 1.0], mn)    # 同値は支配しない
    end

    @testset "同値の点は両方残る" begin
        M = [1.0 1.0; 1.0 1.0; 2.0 2.0]
        @test non_dominated(M) == [1, 2]
    end

    @testset "目的の向きを指定できる" begin
        M = [1.0 4.0; 2.0 2.0; 3.0 1.0; 3.0 3.0]
        # 第2目的を最大化すると前線が変わる
        s = [MinimizeObjective, MaximizeObjective]
        @test non_dominated(M; senses = s) == [1]
        @test_throws SearchError non_dominated(M; senses = [MinimizeObjective])
    end

    @testset "3目的" begin
        M = [1.0 5.0 5.0;
             5.0 1.0 5.0;
             5.0 5.0 1.0;
             2.0 2.0 2.0;
             6.0 6.0 6.0]      # 全てに劣る
        keep = non_dominated(M)
        @test 5 ∉ keep
        @test Set(keep) == Set([1, 2, 3, 4])
    end

    @testset "端の場合" begin
        @test non_dominated(zeros(0, 2)) == Int[]
        @test non_dominated([3.0 4.0]) == [1]
    end

    @testset "群ごとの非劣解集合" begin
        M = [1.0 4.0;   # N=36
             2.0 2.0;
             3.0 3.0;   # 支配される
             1.0 4.0;   # N=48
             0.5 5.0;
             2.0 6.0]   # 支配される
        g = [36, 36, 36, 48, 48, 48]
        out = non_dominated_by_group(M, g)
        @test Set(keys(out)) == Set([36, 48])
        @test out[36] == [1, 2]
        @test out[48] == [4, 5]
        @test_throws SearchError non_dominated_by_group(M, [1, 2])
    end

    @testset "重みを一切指定せずに求まる" begin
        # 目的の尺度を任意に変えても前線の構成は変わらない（単調変換に対する不変性）
        M = [1.0 4.0; 2.0 2.0; 3.0 1.0; 3.0 3.0; 4.0 5.0]
        scaled = hcat(M[:, 1] .* 1000.0, M[:, 2] .* 0.001)
        @test non_dominated(M) == non_dominated(scaled)
    end
end
