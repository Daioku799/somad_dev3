"""
    GridGeometry

温度場の格子間隔。x・y は等間隔だが、z は層構成に従って**等間隔ではない**
（層の厚みと分割数が層ごとに違う）。そのため z 方向の差分には実際の座標が要る。

`z_centers` はゴーストセルを除いた内部領域のセル中心の z 座標で、長さは内部の nz と一致する。
"""
struct GridGeometry
    dx::Float64
    dy::Float64
    z_centers::Vector{Float64}
end

function GridGeometry(; dx::Real, dy::Real, z_centers::AbstractVector{<:Real})
    dx > 0 || throw(ArgumentError("dx は正でなければならない: $dx"))
    dy > 0 || throw(ArgumentError("dy は正でなければならない: $dy"))
    length(z_centers) >= 1 || throw(ArgumentError("z_centers が空"))
    return GridGeometry(Float64(dx), Float64(dy), Float64.(z_centers))
end

"""候補指標を算出できないことを示す。"""
struct MetricError <: Exception
    msg::String
end

Base.showerror(io::IO, e::MetricError) = print(io, "MetricError: ", e.msg)

"""候補指標の由来。設計変数由来の候補は温度場を使わないため予測誤差を持たない。"""
@enum MetricSource FieldDerived DesignDerived

"""
    MetricSpec

候補指標の共通の形。温度場由来か設計変数由来かの区別を持つ。
"""
struct MetricSpec
    name::String
    label::String
    source::MetricSource
end

"""その候補が予測誤差を持つか。設計変数由来の候補は温度場を経ないため持たない。"""
has_prediction_error(spec::MetricSpec) = spec.source === FieldDerived
