"""設計変数のみから算出する候補指標の名前。"""
const DESIGN_METRIC_NAMES = ("sum_sq",)

"""
    design_bias(counts) -> Int

セル別本数の二乗和。総本数が同じでも、特定のセルに集中しているほど大きくなる。
温度場を使わないため予測誤差を持たない。
"""
design_bias(counts::AbstractVector{<:Integer}) = sum(abs2, counts)

"""
    design_metrics_all(counts_list) -> NamedTuple

全ケースについて設計変数由来の候補を算出する。順序は `counts_list` に従う。
"""
design_metrics_all(counts_list::AbstractVector) =
    (sum_sq = [design_bias(c) for c in counts_list],)
