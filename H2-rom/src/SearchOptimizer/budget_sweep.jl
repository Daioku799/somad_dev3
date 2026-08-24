"""
    uniform_design(budget, cap, ncell) -> Vector{Int}

総本数をできるだけ均等に配った設計。基準となる比較対象として用いる。
セル間の差は高々1本になる。
"""
function uniform_design(budget::Integer, cap::Integer, ncell::Integer)
    budget >= 0 || throw(SearchError("総本数は0以上でなければならない: $budget"))
    budget <= cap * ncell ||
        throw(SearchError("総本数 $budget を収容できない（上限 $cap x $ncell セル = $(cap * ncell)）"))
    base, r = divrem(Int(budget), Int(ncell))
    counts = fill(base, Int(ncell))
    for i in 1:r
        counts[i] += 1
    end
    return counts
end

"""
    in_range_budgets(budgets, train_budgets) -> Vector{Int}

学習した水準の最小と最大で挟まれた本数だけを残す。
範囲外は縮約モデルが外挿になるため、探索対象から除く。
"""
function in_range_budgets(budgets, train_budgets)
    isempty(train_budgets) &&
        throw(SearchError("学習水準が空のため探索範囲を決められない"))
    lo, hi = extrema(train_budgets)
    return [Int(b) for b in budgets if lo <= b <= hi]
end

"""
    BudgetSweepRow

1つの総本数についての走査結果。最良・最悪・一様配置と、最良と最悪の差を持つ。
"""
struct BudgetSweepRow
    budget::Int
    best::SearchSolution
    worst::SearchSolution
    uniform_counts::Vector{Int}
    uniform_value::Float64
    spread::Float64
    n_distinct_best::Int
    n_distinct_worst::Int
    n_eval::Int
end

"""
    budget_sweep(f, budgets, cfg; train_budgets = nothing) -> Vector{BudgetSweepRow}

指定された各総本数について独立に探索を行い、最良設計・最悪設計・一様配置の
目的値と、最良と最悪の差を返す。

`train_budgets` を渡すと、その範囲外の本数を探索対象から除く。
`cfg` の `maximize` は無視し、最小化と最大化の双方を実行する。
"""
function budget_sweep(f, budgets, cfg::SearchConfig; train_budgets = nothing)
    targets = train_budgets === nothing ? [Int(b) for b in budgets] :
              in_range_budgets(budgets, train_budgets)
    rows = BudgetSweepRow[]
    for b in targets
        lo = multi_start_search(f, b, SearchConfig(cap = cfg.cap, ncell = cfg.ncell,
                    n_restart = cfg.n_restart, seed = cfg.seed, maximize = false))
        hi = multi_start_search(f, b, SearchConfig(cap = cfg.cap, ncell = cfg.ncell,
                    n_restart = cfg.n_restart, seed = cfg.seed, maximize = true))
        uc = uniform_design(b, cfg.cap, cfg.ncell)
        uv = Float64(f(uc))
        push!(rows, BudgetSweepRow(b, lo.best, hi.best, uc, uv,
                                   hi.best.value - lo.best.value,
                                   lo.n_distinct, hi.n_distinct,
                                   lo.n_eval + hi.n_eval + 1))
    end
    return rows
end
