module ValidationPlot

using JLD2
using Plots
using Printf
using LinearAlgebra
using Statistics

# Helper functions for coordinates
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

function find_k(Z::Vector{Float64}, zc)
    nz = length(Z) - 1
    if zc < Z[1] || zc > Z[end]
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
    plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots", clims=nothing)

Plot XY cross-section of temperature and ID (TSV layout) from a snapshot JLD2.
Supports fixing color scale with `clims=(tmin, tmax)`.
"""
function plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots", clims=nothing)
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
    
    mkpath(out_dir)
    base_name = splitext(basename(snapshot_file))[1]
    
    k = find_k(Z, zc)
    
    # 1. Temperature Plot (removing ghost cells if present)
    # The size of θ is typically (NX+2, NY+2, NZ+something)
    sz = size(θ)
    MX, MY = sz[1], sz[2]
    
    s_temp = (MX > NX) ? θ[2:NX+1, 2:NY+1, k+1] : θ[:, :, k]
    s_id = (size(ID, 1) > NX) ? ID[2:NX+1, 2:NY+1, k+1] : ID[:, :, k]
    
    x_coords = [(ox[1] + dx * (i - 0.5)) * 1000 for i in 1:NX]
    y_coords = [(ox[2] + dy * (j - 0.5)) * 1000 for j in 1:NY]
    
    # Apply clims if provided
    clims_val = clims === nothing ? (minimum(s_temp), maximum(s_temp)) : clims
    
    # Heatmap/contour for temperature
    p_temp = heatmap(x_coords, y_coords, s_temp', 
        fill=true, c=:thermal, aspect_ratio=:equal, clim=clims_val,
        title="Temperature at Z=$(zc*1000)mm\nRange: $(round(minimum(s_temp), digits=1))K - $(round(maximum(s_temp), digits=1))K",
        xlabel="X [mm]", ylabel="Y [mm]")
    
    # Material / Geometry ID heatmap
    p_geo = heatmap(x_coords, y_coords, s_id', 
        c=:blues, aspect_ratio=:equal,
        title="Geometry ID (TSV/Materials)\nZ=$(zc*1000)mm",
        xlabel="X [mm]", ylabel="Y [mm]")
    
    # Save individual plots
    savefig(p_temp, joinpath(out_dir, "$(base_name)_temp_xy.png"))
    savefig(p_geo, joinpath(out_dir, "$(base_name)_geo_xy.png"))
    
    # Side-by-side plot
    p_side = plot(p_geo, p_temp, layout=(1, 2), size=(1000, 450))
    savefig(p_side, joinpath(out_dir, "$(base_name)_sidebyside_xy.png"))
    
    println("Plots saved to $out_dir for $base_name (Side-by-side: $(base_name)_sidebyside_xy.png)")
end

"""
    plot_singular_values(singular_values::Vector{Float64}; out_dir="plots")

Plot the singular values decay on a log scale and the cumulative energy ratio (RIC).
"""
function plot_singular_values(singular_values::Vector{Float64}; out_dir="plots")
    mkpath(out_dir)
    n_modes = length(singular_values)
    
    # Compute relative cumulative energy
    sq_sum = sum(singular_values .^ 2)
    ric = cumsum(singular_values .^ 2) ./ sq_sum
    
    # Log scale plot of singular values
    p1 = plot(1:n_modes, singular_values, yscale=:log10, marker=:circle,
        title="Singular Values Decay (SVD)",
        xlabel="POD Mode Index", ylabel="Singular Value (log10)",
        label="Singular Value", legend=:topright, grid=true)
    
    # Cumulative Energy plot
    p2 = plot(1:n_modes, ric, marker=:square, ylims=(0.0, 1.05),
        title="Cumulative Energy Fraction (RIC)",
        xlabel="POD Mode Index", ylabel="Fraction",
        label="Cumulative RIC", legend=:bottomright, grid=true)
    
    p_svd = plot(p1, p2, layout=(1, 2), size=(900, 400))
    savefig(p_svd, joinpath(out_dir, "svd_decay_ric.png"))
    println("SVD decay plot saved to: $(out_dir)/svd_decay_ric.png")
end

"""
    plot_rom_comparison(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, 
                         grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}; 
                         zc=0.33e-3, out_dir="plots", clims=nothing)

Plot a side-by-side comparison of FVM (reference) vs ROM (predicted) temperature fields,
and their absolute error distribution at a specific cross-section.
"""
function plot_rom_comparison(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, 
                             grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}; 
                             zc=0.33e-3, out_dir="plots", clims=nothing)
    mkpath(out_dir)
    MX, MY, MZ = grid_size
    
    # Reshape back to 3D grid
    T_fvm = reshape(theta_fvm, MX, MY, MZ)
    T_rom = reshape(theta_rom, MX, MY, MZ)
    T_diff = abs.(T_fvm .- T_rom)
    
    # Grid info
    NX, NY = MX - 2, MY - 2
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    
    k = find_k(Z, zc)
    
    # Extract slices
    s_fvm = T_fvm[2:NX+1, 2:NY+1, k]
    s_rom = T_rom[2:NX+1, 2:NY+1, k]
    s_diff = T_diff[2:NX+1, 2:NY+1, k]
    
    x_coords = [(ox[1] + dx * (i - 0.5)) * 1000 for i in 1:NX]
    y_coords = [(ox[2] + dy * (j - 0.5)) * 1000 for j in 1:NY]
    
    # Temperature scale limits
    clims_val = clims === nothing ? (min(minimum(s_fvm), minimum(s_rom)), max(maximum(s_fvm), maximum(s_rom))) : clims
    
    p_fvm = heatmap(x_coords, y_coords, s_fvm',
        fill=true, c=:thermal, aspect_ratio=:equal, clim=clims_val,
        title="FVM Reference\nT_max = $(round(maximum(s_fvm), digits=1))K",
        xlabel="X [mm]", ylabel="Y [mm]")
        
    p_rom = heatmap(x_coords, y_coords, s_rom',
        fill=true, c=:thermal, aspect_ratio=:equal, clim=clims_val,
        title="ROM Predicted\nT_max = $(round(maximum(s_rom), digits=1))K",
        xlabel="X [mm]", ylabel="Y [mm]")
        
    p_diff = heatmap(x_coords, y_coords, s_diff',
        fill=true, c=:reds, aspect_ratio=:equal,
        title="Absolute Error (K)\nMean Err = $(round(mean(s_diff), digits=4))K",
        xlabel="X [mm]", ylabel="Y [mm]")
        
    p_comp = plot(p_fvm, p_rom, p_diff, layout=(1, 3), size=(1350, 400))
    savefig(p_comp, joinpath(out_dir, "rom_fvm_comparison_xy.png"))
    println("ROM vs FVM comparison plot saved to: $(out_dir)/rom_fvm_comparison_xy.png")
end

export plot_snapshot_xy, plot_singular_values, plot_rom_comparison

end # module
