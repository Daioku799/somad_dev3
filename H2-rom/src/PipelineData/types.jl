"""
    CaseRecord

計画情報に記載された1ケース分のメタデータ。
"""
struct CaseRecord
    case::Int
    name::String
    budget::Int
    counts::Vector{Int}
    split::String          # "train" | "validation" | "test" | "interp"
    sum_sq::Int
    max_cell::Int
end

"""
    DatasetSpec

データセットの所在と読み取り規約。run 固有のパスはここから注入され、
モジュール内部にはハードコードしない。
"""
struct DatasetSpec
    run_dir::String
    plan_name::String
    snapshot_name::String
    field_key::String
end

function DatasetSpec(; run_dir::AbstractString,
                       plan_name::AbstractString = "case_plan.json",
                       snapshot_name::AbstractString = "snapshot.jld2",
                       field_key::AbstractString = "theta")
    return DatasetSpec(String(run_dir), String(plan_name),
                       String(snapshot_name), String(field_key))
end

"""
    LoadedDataset

読み込んだデータセット。`field` と `mu` の列順は `records` と一致する。
`field` はゴーストセルを除いた内部領域のみを列に並べたもの。
`shape` はゴーストを含む元の形。
"""
struct LoadedDataset
    spec::DatasetSpec
    cap::Int
    ncell::Int
    records::Vector{CaseRecord}
    field::Matrix{Float64}
    mu::Matrix{Float64}
    shape::NTuple{3,Int}
    tmax::Vector{Float64}
    tmean::Vector{Float64}
end

"""計画情報またはスナップショットが読み取れないことを示す。"""
struct DatasetLoadError <: Exception
    msg::String
end

Base.showerror(io::IO, e::DatasetLoadError) = print(io, "DatasetLoadError: ", e.msg)
