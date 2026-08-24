"""
    ObjectiveMetrics

目的関数の候補指標を温度場と設計変数から算出することのみを所有する。
採否の判定に用いるしきい値は持たず、呼び出し側から与えられる。
"""
module ObjectiveMetrics

using Statistics

include("types.jl")
include("field_metrics.jl")
include("design_metrics.jl")
include("statistics.jl")
include("specs.jl")

export GridGeometry, MetricError, MetricSource, FieldDerived, DesignDerived, MetricSpec
export FIELD_METRIC_NAMES, DESIGN_METRIC_NAMES, ALL_METRIC_SPECS
export field_metrics, field_metrics_all
export design_bias, design_metrics_all
export spearman, metric_stats, metric_spec, has_prediction_error

end # module
