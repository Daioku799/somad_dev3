module ValidationPlot

using JLD2
using Plots
using Printf
using LinearAlgebra
using Statistics

# --- Helper functions for coordinates (Self-contained, identical to plotter.jl) ---

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

function find_k(Z::Vector{Float64}, zc, nz, mode=3)
    if mode==1 || mode==4
        if zc<Z[1] || zc>Z[nz+1]
            return zc < Z[1] ? 1 : nz
        end
        for k in 1:nz
            if Z[k] ≤ zc < Z[k+1]
                return k
            end
        end
    else
        if zc<Z[1] || zc>Z[nz]
            return zc < Z[1] ? 1 : nz - 1
        end
        for k in 1:nz-1
            if Z[k] ≤ zc < Z[k+1]
                return k
            end
        end
    end
    return nz
end

"""
    plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots", clims=nothing, save_individuals::Bool=false)

Plot XY cross-section including density map, ID map, and temperature field side-by-side (1x3 plot).
Supports fixing temperature scale limits via `clims=(tmin, tmax)`.
If `save_individuals` is true, also saves individual plot components.
"""
function plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots", clims=nothing, save_individuals::Bool=false)
    if !isfile(snapshot_file)
        println("Error: File not found: $snapshot_file")
        return
    end

    data = load(snapshot_file)
    θ = haskey(data, "temperature") ? data["temperature"] : data["theta"]
    ID = data["id_map"]
    Z = data["z_faces"]
    NX, NY, NZ = data["nx"], data["ny"], data["nz"]
    mu = data["metadata"]["mu"]
    
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    Δh = (dx, dy, 1.0)
    SZ = size(θ)
    
    mkpath(out_dir)
    base_name = splitext(basename(snapshot_file))[1]
    
    # 1. Density map
    density_img_path = joinpath(out_dir, "$(base_name)_density_xy.png")
    p_mu = plot_density_map(mu, density_img_path; title="Density Map", save=save_individuals)
    
    # 2. ID map (geo_overlay)
    geo_img_path = joinpath(out_dir, "$(base_name)_geo_xy.png")
    if save_individuals
        plot_heatsource_tsv_overlay_nu_save(ID, zc, SZ, ox, Δh, Z, geo_img_path)
    end
    p_geo = plot_heatsource_tsv_overlay_nu_return(ID, zc, SZ, ox, Δh, Z)
    
    # 3. Temp map
    temp_img_path = joinpath(out_dir, "$(base_name)_temp_xy.png")
    if save_individuals
        plot_slice_xy_nu_save(3, 2, θ, zc, SZ, ox, Δh, Z, temp_img_path, base_name, clims=clims)
    end
    p_temp = plot_slice_xy_nu_return(3, 2, θ, zc, SZ, ox, Δh, Z, base_name, clims=clims)
    
    # 4. Combined 3-column plot
    p_combined = plot(p_mu, p_geo, p_temp, layout=(1, 3), size=(1800, 500))
    savefig(p_combined, joinpath(out_dir, "$(base_name)_snapshot_xy.png"))
    
    println("Saved snapshot visuals to: $out_dir")
end

"""
    plot_singular_values(singular_values::Vector{Float64}; out_dir="plots")
"""
function plot_singular_values(singular_values::Vector{Float64}; out_dir="plots")
    mkpath(out_dir)
    n_modes = length(singular_values)
    sq_sum = sum(singular_values .^ 2)
    ric = cumsum(singular_values .^ 2) ./ sq_sum
    
    p1 = plot(1:n_modes, singular_values, yscale=:log10, marker=:circle,
        title="Singular Values Decay (SVD)",
        xlabel="POD Mode Index", ylabel="Singular Value (log10)",
        label="Singular Value", legend=:topright, grid=true)
    
    p2 = plot(1:n_modes, ric, marker=:square, ylims=(0.0, 1.05),
        title="Cumulative Energy Fraction (RIC)",
        xlabel="POD Mode Index", ylabel="Fraction",
        label="Cumulative RIC", legend=:bottomright, grid=true)
    
    p_svd = plot(p1, p2, layout=(1, 2), size=(900, 400))
    savefig(p_svd, joinpath(out_dir, "svd_decay_ric.png"))
end

"""
    plot_rom_comparison(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, 
                         grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}, mu::Vector{Float64}; 
                         zc=0.33e-3, out_dir="plots", clims=nothing, save_individuals::Bool=false, normalize::Bool=false, sample_id::String="")

Plot a comparison of FVM vs ROM including density, FVM, ROM, and signed temperature difference side-by-side (1x4 plot).
"""
function plot_rom_comparison(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, 
                             grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}, mu::Vector{Float64}; 
                             zc=0.33e-3, out_dir="plots", clims=nothing, save_individuals::Bool=false, normalize::Bool=false, sample_id::String="")
    mkpath(out_dir)
    MX, MY, MZ = grid_size
    
    T_fvm = reshape(theta_fvm, MX, MY, MZ)
    T_rom = reshape(theta_rom, MX, MY, MZ)
    
    if normalize
        tmin_fvm = minimum(T_fvm)
        tmax_fvm = maximum(T_fvm)
        denom = (tmax_fvm - tmin_fvm) > 1e-12 ? (tmax_fvm - tmin_fvm) : 1.0
        T_fvm_plot = (T_fvm .- tmin_fvm) ./ denom
        T_rom_plot = (T_rom .- tmin_fvm) ./ denom
        plot_clims = (0.0, 1.0)
    else
        T_fvm_plot = T_fvm
        T_rom_plot = T_rom
        plot_clims = clims
    end
    
    T_diff = T_fvm .- T_rom
    
    use_ghost = MX > 2 && MY > 2
    NX = use_ghost ? MX - 2 : MX
    NY = use_ghost ? MY - 2 : MY
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    Δh = (dx, dy, 1.0)
    
    # 1. Density map
    prefix = sample_id != "" ? "$(sample_id)_" : ""
    density_img_path = joinpath(out_dir, "$(prefix)rom_fvm_density_xy.png")
    p_mu = plot_density_map(mu, density_img_path; title="Density Map", save=save_individuals)
    
    # 2. FVM Reference
    p_fvm = plot_slice_xy_nu_return(3, 2, T_fvm_plot, zc, grid_size, ox, Δh, Z, "FVM Reference", clims=plot_clims, normalize=normalize)
    if save_individuals
        fvm_img_path = joinpath(out_dir, "$(prefix)rom_fvm_fvm_xy.png")
        plot_slice_xy_nu_save(3, 2, T_fvm_plot, zc, grid_size, ox, Δh, Z, fvm_img_path, "FVM Reference", clims=plot_clims, normalize=normalize)
    end
    
    # 3. ROM Predicted
    p_rom = plot_slice_xy_nu_return(3, 2, T_rom_plot, zc, grid_size, ox, Δh, Z, "ROM Predicted", clims=plot_clims, normalize=normalize)
    if save_individuals
        rom_img_path = joinpath(out_dir, "$(prefix)rom_fvm_rom_xy.png")
        plot_slice_xy_nu_save(3, 2, T_rom_plot, zc, grid_size, ox, Δh, Z, rom_img_path, "ROM Predicted", clims=plot_clims, normalize=normalize)
    end
    
    # 4. Signed Difference (FVM - ROM)
    xs = use_ghost ? 2 : 1
    xe = use_ghost ? MX - 1 : MX
    ys = use_ghost ? 2 : 1
    ye = use_ghost ? MY - 1 : MY
    
    k = find_k(Z, zc, MZ, 3)
    s_diff = T_diff[xs:xe, ys:ye, k]
    x_coords = [(ox[1] + Δh[1] * (i - (use_ghost ? 1.5 : 0.5)))*1000.0 for i in xs:xe]
    y_coords = [(ox[2] + Δh[2] * (j - (use_ghost ? 1.5 : 0.5)))*1000.0 for j in ys:ye]
    
    max_diff = maximum(abs.(s_diff))
    if max_diff < 1e-5
        max_diff = 1e-5
    end
    
    p_diff = heatmap(x_coords, y_coords, s_diff',
        fill=true, c=:balance, aspect_ratio=:equal,
        clim=(-max_diff, max_diff),
        title="Temp Difference (FVM - ROM)\nMean Diff = $(round(mean(s_diff), digits=4))K",
        xlabel="X [mm]", ylabel="Y [mm]")
        
    if save_individuals
        diff_img_path = joinpath(out_dir, "$(prefix)rom_fvm_diff_xy.png")
        savefig(p_diff, diff_img_path)
    end
        
    # Combined 4-column plot
    p_comp = plot(p_mu, p_fvm, p_rom, p_diff, layout=(1, 4), size=(2400, 500))
    savefig(p_comp, joinpath(out_dir, "$(prefix)rom_fvm_comparison_xy.png"))
end

# --- Implementations matching legacy/official plotter.jl exactly ---

function plot_slice_xy_nu_save(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, fname, label::String=""; clims=nothing, normalize::Bool=false)
    use_ghost = SZ[1] > 2 && SZ[2] > 2
    xs = use_ghost ? 2 : 1
    xe = use_ghost ? SZ[1] - 1 : SZ[1]
    ys = use_ghost ? 2 : 1
    ye = use_ghost ? SZ[2] - 1 : SZ[2]
    k = find_k(Z, zc, SZ[3], 3)
    s = d[xs:xe, ys:ye, k]
    factor = 1000.0
    x_coords = [(ox[1] + Δh[1] * (i - (use_ghost ? 1.5 : 0.5)))*factor for i in xs:xe]
    y_coords = [(ox[2] + Δh[2] * (j - (use_ghost ? 1.5 : 0.5)))*factor for j in ys:ye]
    
    min_val, max_val = clims === nothing ? (minimum(s), maximum(s)) : clims
    
    if normalize
        title_str="Cross-section at Z=" * @sprintf("%.3f", zc*1000) * " [mm] (k=$k) (Norm) $label"
        p = contour(x_coords, y_coords, s', 
                    fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                    clim=(0.0, 1.0),
                    colorbar_title="Relative Temperature [-]",
                    xlabel="X-coordinate [mm]", ylabel="Y-coordinate [mm]", title=title_str, 
                    size=(1000, 600), aspect_ratio=:equal)
    else
        n_ticks = 6
        if min_val<=0.0; min_val = 1.0e-5; end
        if max_val<=0.0; max_val = 1.0e-5; end
        log_min = log10(min_val); log_max = log10(max_val)
        log_ticks = range(log_min, log_max, length=n_ticks)
        auto_tick_values = [10^x for x in log_ticks]
        auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
        title_str="Cross-section at Z=" * @sprintf("%.3f", zc*1000) * " [mm] (k=$k) $label"
        
        p = contour(x_coords, y_coords, s', 
                    fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                    clim=(min_val, max_val),
                    colorbar_ticks=(auto_tick_values, auto_tick_labels),
                    colorbar_title="Temperature [K]",
                    xlabel="X-coordinate [mm]", ylabel="Y-coordinate [mm]", title=title_str, 
                    size=(1000, 600), aspect_ratio=:equal)
    end
    savefig(p, fname)
end

function plot_heatsource_tsv_overlay_nu_save(ID::Array{UInt8,3}, zc, SZ, ox, dh, Z::Vector{Float64}, fname)
    use_ghost = SZ[1] > 2 && SZ[2] > 2
    xs = use_ghost ? 2 : 1
    xe = use_ghost ? SZ[1] - 1 : SZ[1]
    ys = use_ghost ? 2 : 1
    ye = use_ghost ? SZ[2] - 1 : SZ[2]
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    x_edges = [ (ox[1] + (i - 1)*dh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j - 1)*dh[2]) * 1000.0 for j in ys:ye+1 ]
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    title_str = "Material Distribution at Z=" * @sprintf("%.3f", zc*1000) * " mm"
    
    p = heatmap(x_edges, y_edges, s',
                c=cgrad(custom_palette, 7, categorical=true), clims=(0.5, 7.5), colorbar=false,
                xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                xlabel="Position X [mm]", ylabel="Position Y [mm]", title=title_str,
                size=(1000, 900), aspect_ratio=:equal, legend=false)
    savefig(p, fname)
end

function plot_slice_xy_nu_return(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, label::String=""; clims=nothing, normalize::Bool=false)
    use_ghost = SZ[1] > 2 && SZ[2] > 2
    xs = use_ghost ? 2 : 1
    xe = use_ghost ? SZ[1] - 1 : SZ[1]
    ys = use_ghost ? 2 : 1
    ye = use_ghost ? SZ[2] - 1 : SZ[2]
    k = find_k(Z, zc, SZ[3], 3)
    s = d[xs:xe, ys:ye, k]
    factor = 1000.0
    x_coords = [(ox[1] + Δh[1] * (i - (use_ghost ? 1.5 : 0.5)))*factor for i in xs:xe]
    y_coords = [(ox[2] + Δh[2] * (j - (use_ghost ? 1.5 : 0.5)))*factor for j in ys:ye]
    
    min_val, max_val = clims === nothing ? (minimum(s), maximum(s)) : clims
    
    if normalize
        title_str="Temp Z=" * @sprintf("%.3f", zc*1000) * "mm (Norm)\n$label"
        p = contour(x_coords, y_coords, s', 
                    fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                    clim=(0.0, 1.0),
                    colorbar_title="Relative Temperature [-]",
                    xlabel="X [mm]", ylabel="Y [mm]", title=title_str, aspect_ratio=:equal)
    else
        n_ticks = 6
        if min_val<=0.0; min_val = 1.0e-5; end
        if max_val<=0.0; max_val = 1.0e-5; end
        log_min = log10(min_val); log_max = log10(max_val)
        log_ticks = range(log_min, log_max, length=n_ticks)
        auto_tick_values = [10^x for x in log_ticks]
        auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
        title_str="Temp Z=" * @sprintf("%.3f", zc*1000) * "mm\n$label"
        
        p = contour(x_coords, y_coords, s', 
                    fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                    clim=(min_val, max_val),
                    colorbar_ticks=(auto_tick_values, auto_tick_labels),
                    colorbar_title="Temperature [K]",
                    xlabel="X [mm]", ylabel="Y [mm]", title=title_str, aspect_ratio=:equal)
    end
    return p
end

function plot_heatsource_tsv_overlay_nu_return(ID::Array{UInt8,3}, zc, SZ, ox, dh, Z::Vector{Float64})
    use_ghost = SZ[1] > 2 && SZ[2] > 2
    xs = use_ghost ? 2 : 1
    xe = use_ghost ? SZ[1] - 1 : SZ[1]
    ys = use_ghost ? 2 : 1
    ye = use_ghost ? SZ[2] - 1 : SZ[2]
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    x_edges = [ (ox[1] + (i - 1)*dh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j - 1)*dh[2]) * 1000.0 for j in ys:ye+1 ]
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    title_str = "ID Map Z=" * @sprintf("%.3f", zc*1000) * "mm"
    
    p = heatmap(x_edges, y_edges, s',
                c=cgrad(custom_palette, 7, categorical=true), clims=(0.5, 7.5), colorbar=false,
                xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                xlabel="X [mm]", ylabel="Y [mm]", title=title_str, aspect_ratio=:equal)
    return p
end

"""
    plot_density_map(mu::Vector{Float64}, out_path::String; title::String="TSV Density Map", save::Bool=true)

Plot the 4x4 (or dynamically shaped) TSV density map parameter.
Saves the plot to `out_path` as a heatmap with numerical value annotations if `save` is true.
"""
function plot_density_map(mu::Vector{Float64}, out_path::String; title::String="TSV Density Map", save::Bool=true)
    n = length(mu)
    gx = gy = floor(Int, sqrt(n))
    if gx * gy != n
        error("Density map size $(n) must be a perfect square (e.g. 16 for 4x4 grid)")
    end
    
    grid_data = reshape(mu, (gy, gx)) # gy rows, gx cols
    
    lx = 1.2 # mm
    dx = lx / gx
    x_centers = [dx * (i - 0.5) for i in 1:gx]
    y_centers = [dx * (j - 0.5) for j in 1:gy]
    
    annotations = Tuple{Float64, Float64, Any}[]
    for i in 1:gx
        for j in 1:gy
            val = grid_data[j, i]
            push!(annotations, (x_centers[i], y_centers[j], text(@sprintf("%.2f", val), 10, :black, :center)))
        end
    end
    
    p = heatmap(x_centers, y_centers, grid_data,
                c=:YlGnBu, clims=(0.0, 1.0),
                xlims=(0.0, lx), ylims=(0.0, lx),
                xlabel="X Position [mm]", ylabel="Y Position [mm]", title=title,
                aspect_ratio=:equal, size=(600, 500),
                colorbar_title="TSV Density")
    
    annotate!(p, annotations)
    
    if save
        mkpath(dirname(out_path))
        savefig(p, out_path)
    end
    return p
end

export plot_snapshot_xy, plot_singular_values, plot_rom_comparison, plot_density_map

end # module
