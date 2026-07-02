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
    plot_snapshot_xy(snapshot_file::String; zc=0.33e-3, out_dir="plots", clims=nothing)

Plot XY cross-section using the EXACT same contour / colorbar settings as the solver (plotter.jl).
Supports fixing temperature scale limits via `clims=(tmin, tmax)`.
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
    
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    Δh = (dx, dy, 1.0)
    SZ = size(θ)
    
    mkpath(out_dir)
    base_name = splitext(basename(snapshot_file))[1]
    
    # 1. 公式 plotter.jl と同じ対数目盛り contour プロットを保存
    temp_img_path = joinpath(out_dir, "$(base_name)_temp_xy.png")
    plot_slice_xy_nu_save(3, 2, θ, zc, SZ, ox, Δh, Z, temp_img_path, base_name, clims=clims)
    
    # 2. 公式 plotter.jl と同じ黄色・グレー・赤の ID マップ (geo_overlay) を保存
    geo_img_path = joinpath(out_dir, "$(base_name)_geo_xy.png")
    plot_heatsource_tsv_overlay_nu_save(ID, zc, SZ, ox, Δh, Z, geo_img_path)
    
    # 3. サイドバイサイドプロットを生成
    p_temp = plot_slice_xy_nu_return(3, 2, θ, zc, SZ, ox, Δh, Z, base_name, clims=clims)
    p_geo = plot_heatsource_tsv_overlay_nu_return(ID, zc, SZ, ox, Δh, Z)
    p_side = plot(p_geo, p_temp, layout=(1, 2), size=(1300, 550))
    savefig(p_side, joinpath(out_dir, "$(base_name)_sidebyside_xy.png"))
    
    println("Saved snapshot visuals (official format) to: $out_dir")
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
                         grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}; 
                         zc=0.33e-3, out_dir="plots", clims=nothing)

Plot a comparison of FVM vs ROM using the official contour plot logic.
"""
function plot_rom_comparison(theta_fvm::Vector{Float64}, theta_rom::Vector{Float64}, 
                             grid_size::Tuple{Int,Int,Int}, Z::Vector{Float64}; 
                             zc=0.33e-3, out_dir="plots", clims=nothing)
    mkpath(out_dir)
    MX, MY, MZ = grid_size
    
    T_fvm = reshape(theta_fvm, MX, MY, MZ)
    T_rom = reshape(theta_rom, MX, MY, MZ)
    T_diff = abs.(T_fvm .- T_rom)
    
    NX, NY = MX - 2, MY - 2
    lx, ly = 1.2e-3, 1.2e-3
    dx, dy = lx / NX, ly / NY
    ox = (0.0, 0.0, 0.0)
    Δh = (dx, dy, 1.0)
    
    # 公式の等高線プロット（対数スケール）をメモリ上に生成
    p_fvm = plot_slice_xy_nu_return(3, 2, T_fvm, zc, grid_size, ox, Δh, Z, "FVM Reference", clims=clims)
    p_rom = plot_slice_xy_nu_return(3, 2, T_rom, zc, grid_size, ox, Δh, Z, "ROM Predicted", clims=clims)
    
    # 差分（絶対誤差）は線形スケールで描画
    k = find_k(Z, zc, MZ, 3)
    s_diff = T_diff[2:NX+1, 2:NY+1, k]
    x_coords = [(ox[1] + Δh[1] * (i - 1.5))*1000.0 for i in 2:MX-1]
    y_coords = [(ox[2] + Δh[2] * (j - 1.5))*1000.0 for j in 2:MY-1]
    
    p_diff = heatmap(x_coords, y_coords, s_diff',
        fill=true, c=:reds, aspect_ratio=:equal,
        title="Absolute Error (K)\nMean Err = $(round(mean(s_diff), digits=4))K",
        xlabel="X [mm]", ylabel="Y [mm]")
        
    p_comp = plot(p_fvm, p_rom, p_diff, layout=(1, 3), size=(1350, 450))
    savefig(p_comp, joinpath(out_dir, "rom_fvm_comparison_xy.png"))
end

# --- Implementations matching legacy/official plotter.jl exactly ---

function plot_slice_xy_nu_save(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, fname, label::String=""; clims=nothing)
    xs=2; xe=SZ[1]-1; ys=2; ye=SZ[2]-1
    k = find_k(Z, zc, SZ[3], 3)
    s = d[xs:xe, ys:ye, k]
    factor = 1000.0
    x_coords = [(ox[1] + Δh[1] * (i - 1.5))*factor for i in xs:xe]
    y_coords = [(ox[2] + Δh[2] * (j - 1.5))*factor for j in ys:ye]
    
    min_val, max_val = clims === nothing ? (minimum(s), maximum(s)) : clims
    
    n_ticks = 6
    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val); log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
    title_str="Cross-section at Z=" * @sprintf("%.3f", zc*1000) * " [mm] (k=$k) $label"
    
    p = contour(x_coords, y_coords, s, 
                fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                clim=(min_val, max_val),
                colorbar_ticks=(auto_tick_values, auto_tick_labels),
                colorbar_title="Temperature [K]",
                xlabel="X-coordinate [mm]", ylabel="Y-coordinate [mm]", title=title_str, 
                size=(1000, 600), aspect_ratio=:equal)
    savefig(p, fname)
end

function plot_heatsource_tsv_overlay_nu_save(ID::Array{UInt8,3}, zc, SZ, ox, dh, Z::Vector{Float64}, fname)
    xs = 2; xe = SZ[1] - 1; ys = 2; ye = SZ[2] - 1
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    x_edges = [ (ox[1] + (i-1)*dh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j-1)*dh[2]) * 1000.0 for j in ys:ye+1 ]
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    title_str = "Material Distribution at Z=" * @sprintf("%.3f", zc*1000) * " mm"
    
    p = heatmap(x_edges, y_edges, s',
                c=palette(custom_palette), clims=(0.5, 7.5), colorbar=false,
                xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                xlabel="Position X [mm]", ylabel="Position Y [mm]", title=title_str,
                size=(1000, 900), aspect_ratio=:equal, legend=false)
    savefig(p, fname)
end

function plot_slice_xy_nu_return(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, label::String=""; clims=nothing)
    xs=2; xe=SZ[1]-1; ys=2; ye=SZ[2]-1
    k = find_k(Z, zc, SZ[3], 3)
    s = d[xs:xe, ys:ye, k]
    factor = 1000.0
    x_coords = [(ox[1] + Δh[1] * (i - 1.5))*factor for i in xs:xe]
    y_coords = [(ox[2] + Δh[2] * (j - 1.5))*factor for j in ys:ye]
    
    min_val, max_val = clims === nothing ? (minimum(s), maximum(s)) : clims
    
    n_ticks = 6
    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val); log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
    title_str="Temp Z=" * @sprintf("%.3f", zc*1000) * "mm\n$label"
    
    p = contour(x_coords, y_coords, s, 
                fill=true, c=:thermal, xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                clim=(min_val, max_val),
                colorbar_ticks=(auto_tick_values, auto_tick_labels),
                colorbar_title="Temperature [K]",
                xlabel="X [mm]", ylabel="Y [mm]", title=title_str, aspect_ratio=:equal)
    return p
end

function plot_heatsource_tsv_overlay_nu_return(ID::Array{UInt8,3}, zc, SZ, ox, dh, Z::Vector{Float64})
    xs = 2; xe = SZ[1] - 1; ys = 2; ye = SZ[2] - 1
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    x_edges = [ (ox[1] + (i-1)*dh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j-1)*dh[2]) * 1000.0 for j in ys:ye+1 ]
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    title_str = "ID Map Z=" * @sprintf("%.3f", zc*1000) * "mm"
    
    p = heatmap(x_edges, y_edges, s',
                c=palette(custom_palette), clims=(0.5, 7.5), colorbar=false,
                xlims=(0.0, 1.2), ylims=(0.0, 1.2),
                xlabel="X [mm]", ylabel="Y [mm]", title=title_str, aspect_ratio=:equal)
    return p
end

export plot_snapshot_xy, plot_singular_values, plot_rom_comparison

end # module
