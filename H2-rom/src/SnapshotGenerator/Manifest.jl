module Manifest

using JSON3
using StructTypes
using Dates
using ..Types: SnapshotManifest, SnapshotCase

export save_manifest, load_manifest, add_case!, update_case_status!

"""
    save_manifest(manifest::SnapshotManifest, path::String)
"""
function save_manifest(manifest::SnapshotManifest, path::String)
    open(path, "w") do io
        JSON3.pretty(io, manifest)
    end
end

"""
    load_manifest(path::String) -> SnapshotManifest
"""
function load_manifest(path::String)
    if !isfile(path)
        return SnapshotManifest(string(now()), Dict{String, Float64}(), Dict{String, Any}(), SnapshotCase[])
    end
    return JSON3.read(read(path, String), SnapshotManifest)
end

"""
    add_case!(manifest::SnapshotManifest, mu::Vector{Float64}) -> SnapshotCase
"""
function add_case!(manifest::SnapshotManifest, mu::Vector{Float64})
    new_id = isempty(manifest.cases) ? 1 : maximum(c -> c.id, manifest.cases) + 1
    new_case = SnapshotCase(new_id, "pending", mu, "", 0.0)
    push!(manifest.cases, new_case)
    return new_case
end

"""
    update_case_status!(manifest::SnapshotManifest, id::Int, status::String; filepath="", runtime=0.0)
"""
function update_case_status!(manifest::SnapshotManifest, id::Int, status::String; filepath="", runtime=0.0)
    for c in manifest.cases
        if c.id == id
            c.status = status
            c.filepath = filepath
            c.runtime = runtime
            break
        end
    end
end

end # module
