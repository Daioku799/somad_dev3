module Types

using StructTypes

export SnapshotCase, SnapshotManifest

mutable struct SnapshotCase
    id::Int
    status::String # "pending", "success", "failed", "timeout"
    mu::Vector{Float64}
    filepath::String
    runtime::Float64

    SnapshotCase() = new(0, "pending", Float64[], "", 0.0)
    SnapshotCase(id, status, mu, filepath, runtime) = new(id, status, mu, filepath, runtime)
end

StructTypes.StructType(::Type{SnapshotCase}) = StructTypes.Mutable()

mutable struct SnapshotManifest
    created_at::String
    param_range::Dict{String, Float64}
    constraints::Dict{String, Any}
    cases::Vector{SnapshotCase}

    SnapshotManifest() = new("", Dict{String, Float64}(), Dict{String, Any}(), SnapshotCase[])
    SnapshotManifest(created_at, param_range, constraints, cases) = new(created_at, param_range, constraints, cases)
end

StructTypes.StructType(::Type{SnapshotManifest}) = StructTypes.Mutable()

end # module
