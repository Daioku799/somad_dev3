"""
    output_root(prov) -> String

出力先の根。全ての書き出しはこの配下に限定される。
"""
output_root(prov::RunProvenance) = joinpath(prov.run_dir, OUTPUT_SUBDIR)

"""
    resolve_output(prov, filename) -> String

`filename` を出力先の根からの相対パスとして解決する。
根の外に出る指定は拒否する。
"""
function resolve_output(prov::RunProvenance, filename::AbstractString)
    isabspath(filename) &&
        throw(OutputBoundaryError("絶対パスは指定できない: $(filename)"))
    root = abspath(output_root(prov))
    target = abspath(joinpath(root, filename))
    (target == root || startswith(target, root * "/")) ||
        throw(OutputBoundaryError("出力先が $(root) の外に出る: $(filename)"))
    mkpath(dirname(target))
    return target
end

_cell(x) = x isa AbstractFloat ? string(x) : string(x)

"""
    write_table(prov, filename, header, rows; scope="pooled") -> String

結果表を TSV で書き出す。1行目に集計の範囲を記録し、全水準をまとめた集計と
水準ごとの集計を出力上で区別できるようにする。
"""
function write_table(prov::RunProvenance, filename::AbstractString,
                     header::AbstractVector, rows::AbstractVector;
                     scope::AbstractString = "pooled")
    scope in VALID_SCOPES ||
        throw(ReportFormatError("集計の範囲は $(VALID_SCOPES) のいずれか: $(scope)"))
    for (i, r) in enumerate(rows)
        length(r) == length(header) ||
            throw(ReportFormatError("行 $(i) の要素数 $(length(r)) が見出し $(length(header)) と一致しない"))
    end
    path = resolve_output(prov, filename)
    open(path, "w") do io
        println(io, "# scope=", scope)
        println(io, join(string.(header), "\t"))
        for r in rows
            println(io, join(_cell.(r), "\t"))
        end
    end
    return path
end

"""
    write_text(prov, filename, body) -> String

人間可読の要約を書き出す。
"""
function write_text(prov::RunProvenance, filename::AbstractString, body::AbstractString)
    path = resolve_output(prov, filename)
    open(path, "w") do io
        write(io, body)
    end
    return path
end

"""
    set_model_settings!(prov; pod_modes, rbf_settings)

縮約モデルの基底数と補間の設定を来歴に記録する。
"""
function set_model_settings!(prov::RunProvenance; pod_modes::Integer = prov.pod_modes,
                             rbf_settings::AbstractDict = prov.rbf_settings)
    prov.pod_modes = Int(pod_modes)
    prov.rbf_settings = Dict{String,Any}(String(k) => v for (k, v) in rbf_settings)
    return prov
end

"""
    record_seed!(prov, name, seed)

乱数を用いる処理の再現に必要な指定を記録する。
"""
function record_seed!(prov::RunProvenance, name::AbstractString, seed::Integer)
    prov.seeds[String(name)] = Int(seed)
    return prov
end

"""
    record_warning!(prov, message)

警告を集約する。判定が意味を持たない場合や汎化が不足する場合に用いる。
"""
function record_warning!(prov::RunProvenance, message::AbstractString)
    push!(prov.warnings, String(message))
    return prov
end

warnings(prov::RunProvenance) = prov.warnings

"""
    write_warnings(prov; filename="warnings.txt") -> String

集約した警告を一箇所に書き出す。
"""
function write_warnings(prov::RunProvenance; filename::AbstractString = "warnings.txt")
    body = isempty(prov.warnings) ? "警告なし\n" : join(prov.warnings, "\n") * "\n"
    return write_text(prov, filename, body)
end

"""
    write_provenance(prov; filename="provenance.json") -> String

データセットの識別子、ケース数、分割の内訳、基底数、補間の設定、乱数の指定を記録する。
"""
function write_provenance(prov::RunProvenance; filename::AbstractString = "provenance.json")
    payload = Dict{String,Any}(
        "run_dir" => prov.run_dir,
        "dataset_id" => prov.dataset_id,
        "n_cases" => prov.n_cases,
        "split_counts" => prov.split_counts,
        "pod_modes" => prov.pod_modes,
        "rbf_settings" => prov.rbf_settings,
        "seeds" => prov.seeds,
        "warnings" => prov.warnings,
        "generated_at" => prov.generated_at,
    )
    path = resolve_output(prov, filename)
    open(path, "w") do io
        JSON.print(io, payload, 1)
    end
    return path
end
