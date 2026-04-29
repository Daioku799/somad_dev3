module ValidationPlot

using JLD2
using Plots
using Printf

# Include necessary helper functions from plotter pattern
function chk_idx(i, nx)
    if i < 1 i = 1 end
    if i > nx i = nx end
    return i
end

function find_i(x::Float64, x0, dx, nx)
    i = floor(Int32, (x - x0) / dx + 1.5)
    return chk_idx(i, nx)
end

function find_j(y::Float64, y0, dy, ny)
    j = floor(Int32, (y - y0) / dy + 1.5)
    return chk_idx(j, ny)
end

function find_k(Z::Vector{Float64}, zc, nz)
    if zc < Z[1] || zc > Z[nz+1]
        return zc < Z[1] ? 1 : nz
    end
    for k in 1:nz
        if Z[k] ≤ zc < Z[k+1]
            return k
        end
    end
    return nz
end

"""
    plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots")

Plot XY cross-section of temperature and ID (TSV layout) from a snapshot JLD2.
"""
function plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots")
    if !isfile(snapshot_file)
        println("Error: File not found: $snapshot_file")
        return
    end

    data = load(snapshot_file)
    θ = data["theta"]
    ID = data["id_map"]
    Z = data["z_faces"]
    NX, NY, NZ = data["nx"], data["ny"], data["nz"]
    
    # Assuming lx, ly = 1.2e-3 from standard config
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    Δh = (dx, dy, 1.0)
    
    mkpath(out_dir)
    base_name = splitext(basename(snapshot_file))[1]
    
    k = find_k(Z, zc, NZ)
    
    # 1. Temperature Plot
    s_temp = θ[2:NX+1, 2:NY+1, k+1] # Adjusting for ghost cells if present
    # In q3d, θ size is (MX, MY, MZ) where MX = NX + 2
    
    x_coords = [(ox[1] + dx * (i - 0.5)) * 1000 for i in 1:NX]
    y_coords = [(ox[2] + dy * (j - 0.5)) * 1000 for j in 1:NY]
    
    p1 = contour(x_coords, y_coords, s_temp', 
        fill=true, c=:thermal, aspect_ratio=:equal,
        title="Temperature at Z=$(zc*1000)mm ($base_name)",
        xlabel="X [mm]", ylabel="Y [mm]")
    
    # 2. Geometry / TSV Plot
    s_id = ID[2:NX+1, 2:NY+1, k+1]
    p2 = heatmap(x_coords, y_coords, s_id', 
        c=:grays, aspect_ratio=:equal,
        title="Geometry ID at Z=$(zc*1000)mm ($base_name)",
        xlabel="X [mm]", ylabel="Y [mm]")
    
    # Save plots
    savefig(p1, joinpath(out_dir, "$(base_name)_temp_xy.png"))
    savefig(p2, joinpath(out_dir, "$(base_name)_geo_xy.png"))
    
    println("Plots saved to $out_dir for $base_name")
end

"""
    plot_by_id(id::Int; zc=0.33e-3, data_dir="data")
"""
function plot_by_id(id::Int; zc=0.33e-3, data_dir="data")
    file_path = joinpath(data_dir, "raw", "snapshot_$(id).jld2")
    plot_snapshot_xy(file_path, zc=zc, out_dir=joinpath(data_dir, "plots"))
end

export plot_snapshot_xy, plot_by_id

end # module
