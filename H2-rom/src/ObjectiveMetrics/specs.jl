"""候補指標の一覧。温度場由来と設計変数由来をまとめて扱うための正本。"""
const ALL_METRIC_SPECS = MetricSpec[
    MetricSpec("hot_plane_dt",       "最高温面の面内温度差 [K]",       FieldDerived),
    MetricSpec("hot_plane_grad_max", "最高温面の面内最大勾配 [K/m]",   FieldDerived),
    MetricSpec("max_plane_dt",       "全面での面内温度差の最大 [K]",   FieldDerived),
    MetricSpec("grad3d_max",         "三次元勾配の最大 [K/m]",         FieldDerived),
    MetricSpec("grad3d_mean",        "三次元勾配の平均 [K/m]",         FieldDerived),
    MetricSpec("sum_sq",             "セル別本数の二乗和",             DesignDerived),
]

"""
    metric_spec(name) -> MetricSpec

名前から候補指標の定義を引く。
"""
function metric_spec(name::AbstractString)
    i = findfirst(s -> s.name == name, ALL_METRIC_SPECS)
    i === nothing && throw(MetricError("候補指標 '$name' は定義されていない。" *
                                       "利用できるのは $(join([s.name for s in ALL_METRIC_SPECS], ", "))"))
    return ALL_METRIC_SPECS[i]
end
