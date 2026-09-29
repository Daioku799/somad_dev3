"""Versioned, fail-closed persistence contract for thermal snapshots."""
module SnapshotContract

using JLD2
using ..ResearchContracts
using ..ThermalOperators

include("Types.jl")
include("Validation.jl")
include("Persistence.jl")

export SnapshotIdentity, ThermalSnapshot
export build_snapshot, validate_snapshot, validate_snapshot_for_dataset
export save_snapshot, load_snapshot

end
