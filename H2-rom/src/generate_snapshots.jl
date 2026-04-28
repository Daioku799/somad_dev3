include("SnapshotGenerator/SnapshotGenerator.jl")
using .SnapshotGenerator

# Generate 3 snapshots for testing
run_generator(3, solver_dir="../H2-main-ext", data_dir="../data")
