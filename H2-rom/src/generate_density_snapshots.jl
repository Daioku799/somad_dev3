include("SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator

# Use absolute paths
root_dir = abspath(joinpath(@__DIR__, "../.."))
solver_dir = joinpath(root_dir, "H2-main-ext")
data_dir = joinpath(root_dir, "data")

# Generate 2 density-based snapshots for testing
run_density_generator(2, gx=4, gy=4, radius=5e-6, solver_dir=solver_dir, data_dir=data_dir)
