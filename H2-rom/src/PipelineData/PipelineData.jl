"""
    PipelineData

データセット契約の解釈のみを所有する。計画情報とスナップショット群を読み取り、
分割を確定する。目的関数も探索も知らない。run 固有のパスは `DatasetSpec` から注入する。
"""
module PipelineData

using JLD2
using JSON

include("types.jl")
include("loader.jl")

export CaseRecord, DatasetSpec, LoadedDataset, DatasetLoadError
export load_dataset, split_indices, budget_indices, budgets, split_counts, interior_view

end # module
