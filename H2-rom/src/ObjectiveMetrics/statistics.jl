"""同順位を平均順位に置き換えた順位を返す。"""
function _average_ranks(v::AbstractVector{<:Real})
    n = length(v)
    order = sortperm(v)
    r = Vector{Float64}(undef, n)
    i = 1
    @inbounds while i <= n
        j = i
        while j < n && v[order[j+1]] == v[order[i]]
            j += 1
        end
        avg = (i + j) / 2
        for k in i:j
            r[order[k]] = avg
        end
        i = j + 1
    end
    return r
end

"""
    spearman(a, b) -> Float64

順位相関。同順位は平均順位で扱う。
どちらかが全て同値で順位に差が無い場合は、相関を定義できないため 0 を返す。
"""
function spearman(a::AbstractVector{<:Real}, b::AbstractVector{<:Real})
    length(a) == length(b) ||
        throw(MetricError("長さが違う: $(length(a)) と $(length(b))"))
    length(a) >= 2 || throw(MetricError("順位相関には2件以上が必要: $(length(a))"))
    ra, rb = _average_ranks(a), _average_ranks(b)
    ma, mb = mean(ra), mean(rb)
    da, db = ra .- ma, rb .- mb
    den = sqrt(sum(abs2, da) * sum(abs2, db))
    return den == 0.0 ? 0.0 : sum(da .* db) / den
end

"""
    metric_stats(values, tmax) -> NamedTuple

1つの候補について、最大温度との順位相関と、設計によって取りうる幅を返す。
`range_ratio` は幅を平均で割った値で、水準間で幅を比べるために用いる。
"""
function metric_stats(values::AbstractVector{<:Real}, tmax::AbstractVector{<:Real})
    length(values) == length(tmax) ||
        throw(MetricError("候補の件数 $(length(values)) と最大温度の件数 $(length(tmax)) が違う"))
    lo, hi = extrema(values)
    mu = mean(values)
    return (n = length(values), spearman = spearman(tmax, values),
            min = float(lo), max = float(hi), range = float(hi - lo),
            mean = float(mu), std = length(values) >= 2 ? std(values) : 0.0,
            range_ratio = mu == 0 ? 0.0 : float(hi - lo) / abs(mu))
end

"""
    metric_prediction_error(truth, pred; spread = nothing) -> NamedTuple

実測の温度場から算出した候補の値 `truth` と、縮約モデルが再構成した温度場から
算出した値 `pred` の誤差を返す。

`spread` にその候補が設計によって取りうる幅を渡すと、幅に対する誤差の比
`error_ratio` を返す。渡さない場合は `truth` の幅を用いる。予測可能性の条件は
この比を用いて判定する（判定のしきい値は呼び出し側が持つ）。
"""
function metric_prediction_error(truth::AbstractVector{<:Real},
                                 pred::AbstractVector{<:Real};
                                 spread::Union{Nothing,Real} = nothing)
    length(truth) == length(pred) ||
        throw(MetricError("実測 $(length(truth)) 件と予測 $(length(pred)) 件で数が違う"))
    isempty(truth) && throw(MetricError("比較対象が0件"))
    d = pred .- truth
    lo, hi = extrema(truth)
    w = spread === nothing ? float(hi - lo) : float(spread)
    mae = mean(abs.(d))
    return (n = length(truth), mae = mae, rmse = sqrt(mean(abs2, d)),
            maxe = maximum(abs.(d)), bias = mean(d),
            spearman = length(truth) >= 2 ? spearman(truth, pred) : 0.0,
            spread = w, error_ratio = w == 0 ? Inf : mae / w)
end
