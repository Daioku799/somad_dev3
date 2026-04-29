include("ValidationPlot/ValidationPlot.jl")
using .ValidationPlot

"""
    plot_snapshots.jl [id1 id2 ...]
    
Usage:
    julia --project=. src/plot_snapshots.jl 13 14 15
"""

if isempty(ARGS)
    println("Usage: julia --project=. src/plot_snapshots.jl [id1 id2 ...]")
    exit()
end

for arg in ARGS
    try
        id = parse(Int, arg)
        println("Plotting snapshot $id...")
        plot_by_id(id, data_dir="../data")
    catch e
        println("Error processing ID $arg: $e")
    end
end
