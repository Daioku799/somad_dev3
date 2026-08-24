const REQUIRED_PLAN_KEYS = ("cap", "cases")
const REQUIRED_CASE_KEYS = ("case", "name", "budget", "counts", "split", "sum_sq", "max_cell")

function _require(dict, key, context)
    haskey(dict, key) || throw(DatasetLoadError("$(context): 必須キー '$(key)' がない"))
    return dict[key]
end

function _read_plan(spec::DatasetSpec)
    path = joinpath(spec.run_dir, spec.plan_name)
    isfile(path) || throw(DatasetLoadError("計画情報が見つからない: $(path)"))
    plan = JSON.parsefile(path)
    for k in REQUIRED_PLAN_KEYS
        _require(plan, k, "計画情報 $(path)")
    end
    cap = Int(plan["cap"])
    raw = plan["cases"]
    isempty(raw) && throw(DatasetLoadError("計画情報 $(path): ケースが1件もない"))
    records = CaseRecord[]
    for c in raw
        for k in REQUIRED_CASE_KEYS
            _require(c, k, "計画情報 $(path) のケース $(get(c, "name", "?"))")
        end
        push!(records, CaseRecord(Int(c["case"]), String(c["name"]), Int(c["budget"]),
                                  Int.(c["counts"]), String(c["split"]),
                                  Int(c["sum_sq"]), Int(c["max_cell"])))
    end
    ncell = haskey(plan, "ncell") ? Int(plan["ncell"]) : length(records[1].counts)
    for r in records
        length(r.counts) == ncell ||
            throw(DatasetLoadError("ケース $(r.name): セル数が $(length(r.counts)) で、期待値 $(ncell) と異なる"))
    end
    return cap, ncell, records
end

"""
    interior_view(column, shape) -> Array{Float64,3}

内部領域のみを並べた列ベクトルを、ゴーストを除いた3次元配列として見る。
`shape` はゴーストを含む元の形を渡す。
"""
function interior_view(column::AbstractVector{Float64}, shape::NTuple{3,Int})
    inner = (shape[1] - 2, shape[2] - 2, shape[3] - 2)
    length(column) == prod(inner) ||
        throw(DatasetLoadError("列の長さ $(length(column)) が内部形状 $(inner) と一致しない"))
    return reshape(column, inner)
end

"""
    load_dataset(spec::DatasetSpec) -> LoadedDataset

計画情報とスナップショット群を読み取る。欠落や形の不一致はケース名を示して中止する。
"""
function load_dataset(spec::DatasetSpec)
    cap, ncell, records = _read_plan(spec)

    shape = (0, 0, 0)
    cols = Vector{Vector{Float64}}(undef, length(records))
    tmax = Vector{Float64}(undef, length(records))
    tmean = Vector{Float64}(undef, length(records))

    for (i, r) in enumerate(records)
        path = joinpath(spec.run_dir, "cases", r.name, spec.snapshot_name)
        isfile(path) ||
            throw(DatasetLoadError("ケース $(r.name): スナップショットが見つからない ($(path))"))
        data = JLD2.load(path)
        haskey(data, spec.field_key) ||
            throw(DatasetLoadError("ケース $(r.name): キー '$(spec.field_key)' がスナップショットにない"))
        T = data[spec.field_key]
        ndims(T) == 3 ||
            throw(DatasetLoadError("ケース $(r.name): 温度場が3次元でない (次元数 $(ndims(T)))"))
        s = size(T)
        if shape == (0, 0, 0)
            all(s .> 2) ||
                throw(DatasetLoadError("ケース $(r.name): 内部領域を持たない形 $(s)"))
            shape = s
        elseif s != shape
            throw(DatasetLoadError("ケース $(r.name): 温度場の形が $(s) で、他のケース $(shape) と一致しない"))
        end
        inner = @view T[2:s[1]-1, 2:s[2]-1, 2:s[3]-1]
        cols[i] = vec(Float64.(inner))
        tmax[i] = maximum(inner)
        tmean[i] = sum(inner) / length(inner)
    end

    field = reduce(hcat, cols)
    mu = reduce(hcat, [Float64.(r.counts) ./ cap for r in records])
    return LoadedDataset(spec, cap, ncell, records, field, mu, shape, tmax, tmean)
end

"""
    split_indices(ds, split) -> Vector{Int}

指定した分割ラベルを持つケースの添字を、計画情報の順で返す。
`"interp"` は明示的に指定したときのみ返る。
"""
split_indices(ds::LoadedDataset, split::AbstractString) =
    findall(r -> r.split == split, ds.records)

"""
    budget_indices(ds, budget) -> Vector{Int}

指定した TSV 本数を持つケースの添字を返す。
"""
budget_indices(ds::LoadedDataset, budget::Integer) =
    findall(r -> r.budget == budget, ds.records)

"""
    budgets(ds) -> Vector{Int}

データセットに含まれる TSV 本数の一覧を返す。
"""
budgets(ds::LoadedDataset) = sort(unique(r.budget for r in ds.records))

"""
    split_counts(ds) -> Dict{String,Int}

分割ラベルごとのケース数を返す。来歴記録に用いる。
"""
function split_counts(ds::LoadedDataset)
    counts = Dict{String,Int}()
    for r in ds.records
        counts[r.split] = get(counts, r.split, 0) + 1
    end
    return counts
end
