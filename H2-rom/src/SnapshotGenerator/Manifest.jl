module Manifest

using JSON3
using StructTypes
using Dates

export SimulationCase, SnapshotManifest, save_manifest, load_manifest, add_case!, update_case_status!

mutable struct SimulationCase
    id::Int
    status::String # "pending", "success", "failed", "timeout"
    params::Dict{String, Any}
    snapshot_file::String
    error_msg::String

    SimulationCase() = new(0, "pending", Dict{String, Any}(), "", "")
    SimulationCase(id, status, params, snapshot, error) = new(id, status, params, snapshot, error)
end

StructTypes.StructType(::Type{SimulationCase}) = StructTypes.Mutable()

mutable struct SnapshotManifest
    project::String
    created_at::String
    cases::Vector{SimulationCase}

    SnapshotManifest() = new("H2-rom", "", SimulationCase[])
    SnapshotManifest(project, created_at, cases) = new(project, created_at, cases)
end

StructTypes.StructType(::Type{SnapshotManifest}) = StructTypes.Mutable()

"""
    save_manifest(manifest::SnapshotManifest, path::String)
"""
function save_manifest(manifest::SnapshotManifest, path::String)
    open(path, "w") do io
        JSON3.pretty(io, manifest)
    end
end

"""
    load_manifest(path::String)
"""
function load_manifest(path::String)
    if !isfile(path)
        return SnapshotManifest("H2-rom", string(now()), SimulationCase[])
    end
    return JSON3.read(read(path, String), SnapshotManifest)
end

function add_case!(manifest::SnapshotManifest, params::Dict{String, Any})
    new_id = isempty(manifest.cases) ? 1 : maximum(c -> c.id, manifest.cases) + 1
    new_case = SimulationCase(new_id, "pending", params, "", "")
    push!(manifest.cases, new_case)
    return new_case
end

function update_case_status!(manifest::SnapshotManifest, id::Int, status::String; snapshot="", error="")
    for c in manifest.cases
        if c.id == id
            c.status = status
            c.snapshot_file = snapshot
            c.error_msg = error
            break
        end
    end
end

end # module
