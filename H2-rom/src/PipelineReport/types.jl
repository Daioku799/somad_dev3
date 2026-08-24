const VALID_SCOPES = ("pooled", "per_budget")
const OUTPUT_SUBDIR = "rom"

"""
    RunProvenance

結果がどの条件から得られたかを追跡するための来歴。可変であり、
解析の進行に伴って基底数・補間設定・乱数指定・警告が追記される。
"""
mutable struct RunProvenance
    run_dir::String
    dataset_id::String
    n_cases::Int
    split_counts::Dict{String,Int}
    pod_modes::Int
    rbf_settings::Dict{String,Any}
    seeds::Dict{String,Int}
    warnings::Vector{String}
    generated_at::String
end

function RunProvenance(; run_dir::AbstractString,
                         dataset_id::AbstractString,
                         n_cases::Integer,
                         split_counts::AbstractDict = Dict{String,Int}())
    return RunProvenance(String(run_dir), String(dataset_id), Int(n_cases),
                         Dict{String,Int}(String(k) => Int(v) for (k, v) in split_counts),
                         0, Dict{String,Any}(), Dict{String,Int}(), String[],
                         Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"))
end

"""出力先が run ディレクトリの外に出ようとしたことを示す。"""
struct OutputBoundaryError <: Exception
    msg::String
end

Base.showerror(io::IO, e::OutputBoundaryError) = print(io, "OutputBoundaryError: ", e.msg)

"""結果表の形が不正であることを示す。"""
struct ReportFormatError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ReportFormatError) = print(io, "ReportFormatError: ", e.msg)
