include("SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator

# Generate 30 snapshots for testing
run_generator(30, solver_dir="../H2-main-ext", data_dir="../data")
