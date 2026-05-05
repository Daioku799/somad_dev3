push!(LOAD_PATH, "H2-rom/src/SnapshotGenerator")
include("H2-rom/src/SnapshotGenerator/Sampler.jl")
using .Sampler
samples = Sampler.generate_samples(3)
for (i, p) in enumerate(samples)
    println("Sample $i: radius=$(p.radius)")
    println("  Coord 1: $(p.coords[1])")
end
