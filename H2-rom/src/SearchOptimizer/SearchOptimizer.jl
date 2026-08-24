"""
    SearchOptimizer

制約付き設計空間の探索のみを所有する。目的関数は「設計ベクトル → スカラー値」の
関数として外から受け取り、縮約モデルも温度場も知らない。

設計は整数のセル別本数で表し、合計本数の保存とセル上限を常に満たす。
"""
module SearchOptimizer

using Random
using Statistics

include("types.jl")
include("local_search.jl")
include("budget_sweep.jl")
include("pareto.jl")

export SearchConfig, SearchSolution, SearchResult, SearchError
export random_design, neighbor_moves, descend, multi_start_search
export BudgetSweepRow, uniform_design, in_range_budgets, budget_sweep
export ObjectiveSense, MinimizeObjective, MaximizeObjective
export dominates, non_dominated, non_dominated_by_group

end # module
