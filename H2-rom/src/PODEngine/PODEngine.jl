module PODEngine

using LinearAlgebra
using JLD2
using Statistics

include("types.jl")
include("loader.jl")

export PODModel
export load_snapshot_matrix

end # module
