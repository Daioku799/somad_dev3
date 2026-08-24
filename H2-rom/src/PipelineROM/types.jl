"""
    RomSettings

縮約モデルの構築条件。基底数は RIC しきい値では決まらないため明示的に持つ
（旧データセットでは RIC 0.999 が 114 基底を残し、補間が過適合した）。
"""
struct RomSettings
    modes::Int
    epsilon::Float64
    lambda::Float64
    ric_threshold::Float64
end

function RomSettings(; modes::Integer, epsilon::Real, lambda::Real,
                       ric_threshold::Real = 0.9999)
    modes >= 1 || throw(ArgumentError("基底数は1以上でなければならない: $modes"))
    epsilon > 0 || throw(ArgumentError("カーネル幅は正でなければならない: $epsilon"))
    lambda >= 0 || throw(ArgumentError("正則化係数は非負でなければならない: $lambda"))
    return RomSettings(Int(modes), Float64(epsilon), Float64(lambda),
                       Float64(ric_threshold))
end

"""
    RomModel

構築済みの縮約モデル。`basis` は打ち切り後の基底、`singular_values` は
打ち切り前の全特異値（特異値減衰の図に用いる）。
温度場の列はゴーストセルを除いた内部領域のみであり、`inner_shape` はその形。
"""
struct RomModel
    basis::Matrix{Float64}
    mean_field::Vector{Float64}
    singular_values::Vector{Float64}
    interpolator::RBFInterpolator
    settings::RomSettings
    inner_shape::NTuple{3,Int}
    train_names::Vector{String}
end

"""
    AccuracyReport

学習に用いていない分割に対する予測誤差。

- `tmax_mae` / `tmax_rmse` / `tmax_maxe`: 最大温度の平均絶対誤差・二乗平均平方根誤差・最大絶対誤差 [K]
- `field_l2_rel`: 温度場の相対 L2 誤差 [%]（絶対温度を基準）
- `field_l2_rise`: 同じ誤差を温度上昇分（300 K からの差）を基準にした値 [%]
"""
struct AccuracyReport
    n::Int
    tmax_mae::Float64
    tmax_rmse::Float64
    tmax_maxe::Float64
    field_l2_rel::Float64
    field_l2_rise::Float64
    tmax_pred::Vector{Float64}
    tmax_true::Vector{Float64}
    names::Vector{String}
end

"""縮約モデルを構築できないことを示す。"""
struct RomBuildError <: Exception
    msg::String
end

Base.showerror(io::IO, e::RomBuildError) = print(io, "RomBuildError: ", e.msg)
