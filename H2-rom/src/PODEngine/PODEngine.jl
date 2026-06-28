module PODEngine

using LinearAlgebra
using JLD2
using Statistics

include("types.jl")
include("loader.jl")
include("solver.jl")

export PODModel
export load_snapshot_matrix
export compute_pod

end # module
