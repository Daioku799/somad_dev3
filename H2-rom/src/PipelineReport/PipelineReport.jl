"""
    PipelineReport

結果表・来歴・警告の書き出しのみを所有する。全ての出力は run ディレクトリ配下の
解析結果置き場に限定され、その外へは書き出せない。
"""
module PipelineReport

using JSON
using Dates

include("types.jl")
include("writer.jl")

export RunProvenance, OutputBoundaryError, ReportFormatError
export output_root, resolve_output, write_table, write_text
export set_model_settings!, record_seed!, record_warning!, warnings
export write_warnings, write_provenance

end # module
