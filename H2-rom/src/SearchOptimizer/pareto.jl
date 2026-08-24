"""目的の向き。`MinimizeObjective` は小さいほど良い。"""
@enum ObjectiveSense MinimizeObjective MaximizeObjective

"""
    dominates(a, b, senses) -> Bool

`a` が `b` に支配されるかではなく、`a` が `b` を支配するかを返す。
全ての目的で劣らず、少なくとも1つで真に優ることを支配と呼ぶ。
"""
function dominates(a::AbstractVector{<:Real}, b::AbstractVector{<:Real},
                   senses::AbstractVector{ObjectiveSense})
    strictly_better = false
    @inbounds for k in eachindex(a)
        av, bv = a[k], b[k]
        if senses[k] === MaximizeObjective
            av, bv = -av, -bv
        end
        av > bv && return false
        av < bv && (strictly_better = true)
    end
    return strictly_better
end

"""
    non_dominated(objectives; senses) -> Vector{Int}

他のいずれの点にも支配されない点の添字を返す。`objectives` は行が設計、
列が目的の行列。`senses` は目的ごとの向きで、既定は全て最小化。

重み付けは一切用いない。目的の間の交換比率を仮定せずに求まるのが非劣解集合である。
値が完全に同じ点は互いを支配しないため、どちらも残る。
"""
function non_dominated(objectives::AbstractMatrix{<:Real};
                       senses::Union{Nothing,AbstractVector{ObjectiveSense}} = nothing)
    n, d = size(objectives)
    n == 0 && return Int[]
    d >= 1 || throw(SearchError("目的が0個では非劣解集合を定義できない"))
    sv = senses === nothing ? fill(MinimizeObjective, d) : senses
    length(sv) == d ||
        throw(SearchError("目的の向きの数 $(length(sv)) が目的の数 $d と一致しない"))
    keep = Int[]
    @inbounds for i in 1:n
        ai = @view objectives[i, :]
        dominated = false
        for j in 1:n
            i == j && continue
            if dominates(@view(objectives[j, :]), ai, sv)
                dominated = true
                break
            end
        end
        dominated || push!(keep, i)
    end
    return keep
end

"""
    non_dominated_by_group(objectives, groups; senses) -> Dict{Any,Vector{Int}}

群ごとに非劣解集合を求める。TSV本数を固定したときの交換関係を見るために用いる。
返る添字は元の行番号。
"""
function non_dominated_by_group(objectives::AbstractMatrix{<:Real}, groups::AbstractVector;
                                senses::Union{Nothing,AbstractVector{ObjectiveSense}} = nothing)
    size(objectives, 1) == length(groups) ||
        throw(SearchError("目的の行数 $(size(objectives,1)) と群の数 $(length(groups)) が一致しない"))
    out = Dict{eltype(groups),Vector{Int}}()
    for g in unique(groups)
        idx = findall(==(g), groups)
        local_keep = non_dominated(objectives[idx, :]; senses = senses)
        out[g] = idx[local_keep]
    end
    return out
end
