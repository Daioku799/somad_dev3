using Pkg
Pkg.activate("H2-main-ext")

push!(LOAD_PATH, joinpath(pwd(), "H2-main-ext/src/ValidationPlot"))
using ValidationPlot

# Input and Output paths
raw_data_dir = "data/raw"
output_dir = "plots/validation"

# Snapshots to process
snapshots = ["snapshot_13.jld2", "snapshot_14.jld2", "snapshot_15.jld2"]

println("Starting Integration Test for ValidationPlot...")

for snap in snapshots
    filepath = joinpath(raw_data_dir, snap)
    if isfile(filepath)
        println("Processing $snap...")
        try
            output_path = plot_snapshot_validation(
                filepath; 
                output_dir=output_dir, 
                temp_lims=(300.0, 450.0)
            )
            println("  Generated: $output_path")
        catch e
            println("  Error processing $snap: $e")
        end
    else
        println("  Skip: $snap (not found)")
    end
end

println("Integration Test completed.")
