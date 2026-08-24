"""
    SelectionVerdict

1候補についての採否判定。独立性・予測可能性の2条件と、その結果を持つ。
"""
struct SelectionVerdict
    name::String
    source::MetricSource
    max_abs_spearman::Float64
    independent::Bool
    error_ratio::Float64
    predictable::Bool
    adopted::Bool
    reason::String
end

"""
    select_third_objective(candidates; max_abs_spearman, max_error_ratio, fallback, override)
        -> (String, Vector{SelectionVerdict})

2条件の論理積で第3目的を選ぶ。

- **独立性**: 最大温度との順位相関の絶対値が `max_abs_spearman` を下回る
- **予測可能性**: 予測誤差が設計による幅に対する比で `max_error_ratio` を下回る

両条件を満たす候補のうち、最大温度との相関が最も低いものを採用する。
温度場由来の候補が1つも条件を満たさない場合は `fallback`（設計変数由来の偏り指標）
に退避する。退避先は温度場を経ないため常に採用できる。

`override` に候補名を渡すと、判定表は全候補について出したうえで、採用だけを
その候補に固定する。判定と決定を分離して記録するための経路であり、
条件を満たさない候補を指定した場合もその旨を理由に残して採用する。

`candidates` は `(name, source, max_abs_spearman, error_ratio)` を持つ列。
"""
function select_third_objective(candidates;
                                max_abs_spearman::Real,
                                max_error_ratio::Real,
                                fallback::AbstractString = "sum_sq",
                                override::Union{Nothing,AbstractString} = nothing)
    isempty(candidates) && throw(MetricError("候補が0件"))
    names = [String(c.name) for c in candidates]
    length(unique(names)) == length(names) ||
        throw(MetricError("候補名が重複している"))
    override === nothing || String(override) in names ||
        throw(MetricError("指定された候補 '$(override)' が候補一覧に無い。" *
                          "利用できるのは $(join(names, ", "))"))
    fallback in names ||
        throw(MetricError("退避先 '$fallback' が候補一覧に無い"))

    judged = map(candidates) do c
        indep = abs(c.max_abs_spearman) < max_abs_spearman
        pred = c.error_ratio < max_error_ratio
        (name = String(c.name), source = c.source,
         rho = float(c.max_abs_spearman), independent = indep,
         ratio = float(c.error_ratio), predictable = pred)
    end

    # 機械的な選定: 両条件を満たす温度場由来の候補のうち相関が最も低いもの
    passing = [j for j in judged if j.independent && j.predictable &&
                                    j.source === FieldDerived]
    mechanical = isempty(passing) ? fallback :
                 passing[argmin([abs(j.rho) for j in passing])].name
    adopted = override === nothing ? mechanical : String(override)

    verdicts = SelectionVerdict[]
    for j in judged
        reason = if j.name == adopted && override !== nothing
            base = "決定により固定"
            j.independent && j.predictable ? "$base（2条件とも満たす）" :
                "$base（" * (j.independent ? "" : "独立性を満たさない ") *
                (j.predictable ? "" : "予測可能性を満たさない") * "）"
        elseif j.name == adopted && isempty(passing)
            "退避先として採用（温度場由来の候補が全て不採用）"
        elseif j.name == adopted
            "2条件を満たす候補のうち最大温度との相関が最も低い"
        elseif !j.independent
            "不採用: 最大温度と冗長（|相関| $(round(abs(j.rho), digits=3)) ≧ $(max_abs_spearman)）"
        elseif !j.predictable
            "不採用: 予測できない（誤差/幅 $(round(j.ratio, digits=3)) ≧ $(max_error_ratio)）"
        elseif j.source === DesignDerived
            "条件は満たすが退避先。温度場由来の候補が優先される"
        else
            "条件は満たすが、より相関の低い候補が採用された"
        end
        push!(verdicts, SelectionVerdict(j.name, j.source, j.rho, j.independent,
                                         j.ratio, j.predictable, j.name == adopted, reason))
    end
    return adopted, verdicts
end
