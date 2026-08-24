"""
    random_design(rng, budget, cap, ncell) -> Vector{Int}

制約を満たす初期設計を無作為に作る。合計が `budget`、各セルは 0 以上 `cap` 以下。
"""
function random_design(rng::AbstractRNG, budget::Integer, cap::Integer, ncell::Integer)
    budget >= 0 || throw(SearchError("総本数は0以上でなければならない: $budget"))
    budget <= cap * ncell ||
        throw(SearchError("総本数 $budget を収容できない（上限 $cap x $ncell セル = $(cap * ncell)）"))
    counts = zeros(Int, ncell)
    room = collect(1:ncell)
    for _ in 1:budget
        k = rand(rng, eachindex(room))
        i = room[k]
        counts[i] += 1
        counts[i] == cap && deleteat!(room, k)
    end
    return counts
end

"""
    neighbor_moves(counts, cap)

近傍の操作を列挙する。1本をセル `i` からセル `j` へ移す `(i, j)` の組で、
移した結果が制約を満たすものだけを返す。合計本数は操作によって変わらない。
"""
function neighbor_moves(counts::AbstractVector{<:Integer}, cap::Integer)
    n = length(counts)
    return ((i, j) for i in 1:n if counts[i] >= 1
                   for j in 1:n if j != i && counts[j] < cap)
end

_better(a::Float64, b::Float64, maximize::Bool) = maximize ? a > b : a < b

"""
    descend(f, start, cap; maximize = false) -> SearchSolution

`start` から出発し、1本を別のセルへ移す近傍のうち最も改善する手を選んで進む。
改善が止まったら終える。目的関数の評価回数は解の `n_eval` に入る。

`f` は設計ベクトル（整数のセル別本数）のみを受け取る。縮約モデルも温度場も知らない。
"""
function descend(f, start::AbstractVector{<:Integer}, cap::Integer; maximize::Bool = false)
    counts = collect(Int, start)
    all(0 .<= counts .<= cap) ||
        throw(SearchError("初期設計がセル上限 $cap を満たさない: $counts"))
    value = Float64(f(counts))
    n_eval = 1
    steps = 0
    trial = similar(counts)
    while true
        best_move = nothing
        best_value = value
        for (i, j) in neighbor_moves(counts, cap)
            copyto!(trial, counts)
            trial[i] -= 1
            trial[j] += 1
            v = Float64(f(trial))
            n_eval += 1
            if _better(v, best_value, maximize)
                best_value = v
                best_move = (i, j)
            end
        end
        best_move === nothing && break
        counts[best_move[1]] -= 1
        counts[best_move[2]] += 1
        value = best_value
        steps += 1
    end
    return SearchSolution(counts, value, steps, n_eval)
end

"""
    multi_start_search(f, budget, cfg) -> SearchResult

複数の異なる初期設計から降下を繰り返し、相異なる解を集める。
返る全ての設計は合計本数の保存とセル上限を満たす。
"""
function multi_start_search(f, budget::Integer, cfg::SearchConfig)
    budget >= 0 || throw(SearchError("総本数は0以上でなければならない: $budget"))
    budget <= cfg.cap * cfg.ncell ||
        throw(SearchError("総本数 $budget を収容できない" *
                          "（上限 $(cfg.cap) x $(cfg.ncell) セル = $(cfg.cap * cfg.ncell)）"))
    rng = MersenneTwister(cfg.seed)
    found = Dict{Vector{Int},SearchSolution}()
    n_eval = 0
    for _ in 1:cfg.n_restart
        start = random_design(rng, budget, cfg.cap, cfg.ncell)
        sol = descend(f, start, cfg.cap; maximize = cfg.maximize)
        n_eval += sol.n_eval
        haskey(found, sol.counts) || (found[sol.counts] = sol)
    end
    sols = collect(values(found))
    sort!(sols, by = s -> (cfg.maximize ? -s.value : s.value, s.counts))
    return SearchResult(Int(budget), first(sols), sols, cfg.n_restart,
                        length(sols), n_eval, cfg.maximize)
end
