#!/usr/bin/env julia

# ... (docstring remains same) ...

# srcディレクトリをロードパスに追加
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

# heat3ds.jlをインクルード
include("src/heat3ds.jl")

using Base.Threads

# Default parameters
NX, NY, NZ = 240, 240, 30
solver = "pbicgstab"
smoother = "gs"
epsilon = 1.0e-4
par = "sequential"
is_steady = true
snapshot_path = ""

# Simple Argument Parser
i = 1
while i <= length(ARGS)
    arg = ARGS[i]
    if arg == "--snapshot" && i + 1 <= length(ARGS)
        global snapshot_path = ARGS[i+1]
        global i += 2
    elseif !startswith(arg, "--")
        # Positional arguments (legacy support)
        # 1:NX 2:NY 3:NZ 4:solver 5:smoother 6:epsilon 7:par 8:is_steady
        # This is a bit brittle, but keeping it for compatibility
        try
            pos = i - (snapshot_path == "" ? 0 : 2) # Adjust if snapshot was before
            # Actually simpler to just check index
            if i == 1 global NX = parse(Int, arg)
            elseif i == 2 global NY = parse(Int, arg)
            elseif i == 3 global NZ = parse(Int, arg)
            elseif i == 4 global solver = arg
            elseif i == 5 global smoother = arg
            elseif i == 6 global epsilon = parse(Float64, arg)
            elseif i == 7 global par = arg
            elseif i == 8 global is_steady = parse(Bool, arg)
            end
        catch
            @warn "Failed to parse positional argument: $arg"
        end
        global i += 1
    else
        @warn "Unknown option: $arg"
        global i += 1
    end
end

println("Julia Threads: ", nthreads())
println("Running with parameters:")
println("  Grid: $(NX)x$(NY)x$(NZ)")
println("  Solver: $(solver), Smoother: $(smoother)")
println("  Epsilon: $(epsilon), Parallel: $(par)")
println("  Steady-state: $(is_steady)")
if snapshot_path != ""
    println("  Snapshot: $(snapshot_path)")
end
println()

q3d(NX, NY, NZ, solver, smoother, epsilon=epsilon, par=par, is_steady=is_steady, snapshot_path=snapshot_path)
