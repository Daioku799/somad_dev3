"""
    ObjectiveMetrics

目的関数の候補指標を温度場と設計変数から算出することのみを所有する。
採否の判定に用いるしきい値は持たず、呼び出し側から与えられる。
"""
module ObjectiveMetrics

using Statistics

include("types.jl")
include("field_metrics.jl")

export GridGeometry, MetricError, FIELD_METRIC_NAMES
export field_metrics, field_metrics_all

end # module
