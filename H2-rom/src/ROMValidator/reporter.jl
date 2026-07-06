using JSON3
using StructTypes
using Plots
using Printf

StructTypes.StructType(::Type{ValidationResult}) = StructTypes.Struct()
StructTypes.StructType(::Type{ValidationSummary}) = StructTypes.Struct()

"""
    generate_report(summary::ValidationSummary, output_dir::String)

Generate `validation.md` and `validation.json` in the specified directory `output_dir`
representing the summary of the ROM validation results.
"""
function generate_report(summary::ValidationSummary, output_dir::String)
    # Ensure directory exists
    mkpath(output_dir)

    # 1. JSON Report
    json_path = joinpath(output_dir, "validation.json")
    open(json_path, "w") do io
        JSON3.write(io, summary)
    end

    # 2. Markdown Report
    md_path = joinpath(output_dir, "validation.md")
    open(md_path, "w") do io
        println(io, "# ROM Validation Report\n")
        println(io, "## Executive Summary")
        println(io, "- **Overall Status**: `$(summary.overall_status)`")
        println(io, "- **Total Samples**: $(length(summary.results))\n")

        println(io, "## Metrics Summary")
        println(io, "| Metric | Mean | Max |")
        println(io, "| :--- | :---: | :---: |")
        println(io, "| Relative L2 Error | $(summary.mean_metrics["relative_l2_error"]) | $(summary.max_metrics["relative_l2_error"]) |")
        println(io, "| Tmax Error (K) | $(summary.mean_metrics["tmax_error"]) | $(summary.max_metrics["tmax_error"]) |")
        println(io, "| Hotspot Distance (mm) | $(summary.mean_metrics["hotspot_dist"]) | $(summary.max_metrics["hotspot_dist"]) |")
        println(io, "")

        println(io, "## Detailed Results")
        println(io, "| Sample ID | Relative L2 Error | Tmax Error (K) | Hotspot Distance (mm) | Status |")
        println(io, "| :--- | :---: | :---: | :---: | :---: |")
        for r in summary.results
            status_str = r.is_passed ? "PASS" : "FAIL"
            println(io, "| $(r.sample_id) | $(r.relative_l2_error) | $(r.tmax_error) | $(r.hotspot_dist) | $(status_str) |")
        end
    end
end

"""
    generate_comparison_plots(
        theta_fvm::Vector{Float64},
        theta_rom::Vector{Float64},
        grid_info::Dict{String, Any},
        output_dir::String,
        sample_id::String
    )

Generate comparison slice plots comparing FVM vs ROM temperatures and error maps.
- XY Slices at z = 0.15 mm, 0.35 mm, 0.55 mm
- YZ Slice at x = 0.5 mm
"""
function generate_comparison_plots(
    theta_fvm::Vector{Float64},
    theta_rom::Vector{Float64},
    grid_info::Dict{String, Any},
    output_dir::String,
    sample_id::String
)
    # Ensure headless environment configuration
    ENV["GKSwstype"] = "100"

    # Make output directory
    mkpath(output_dir)

    # Grid parameters
    nx = grid_info["nx"]
    ny = grid_info["ny"]
    nz = grid_info["nz"]
    lx = grid_info["lx"]
    ly = grid_info["ly"]
    z_centers = convert(Vector{Float64}, grid_info["z_centers"])

    dx = lx / nx
    dy = ly / ny

    # Reshape vectors to 3D Arrays (Column-major layout)
    mz = length(z_centers)
    ghost_grid_total = (nx + 2) * (ny + 2) * mz
    if length(theta_fvm) == ghost_grid_total
        fvm_full = reshape(theta_fvm, nx + 2, ny + 2, mz)
        rom_full = reshape(theta_rom, nx + 2, ny + 2, mz)
        fvm_3d = fvm_full[2:(nx+1), 2:(ny+1), :]
        rom_3d = rom_full[2:(nx+1), 2:(ny+1), :]
    else
        fvm_3d = reshape(theta_fvm, nx, ny, nz)
        rom_3d = reshape(theta_rom, nx, ny, nz)
    end

    # Coordinates in mm
    x_coords_mm = [(i - 0.5) * dx * 1000.0 for i in 1:nx]
    y_coords_mm = [(j - 0.5) * dy * 1000.0 for j in 1:ny]
    z_coords_mm = z_centers .* 1000.0

    # XY Slice target z levels (in mm)
    z_targets_mm = [0.15, 0.35, 0.55]

    for z_target in z_targets_mm
        # Find index k closest to z_target
        z_target_m = z_target / 1000.0
        k = argmin(abs.(z_centers .- z_target_m))
        actual_z_mm = z_coords_mm[k]

        fvm_slice = fvm_3d[:, :, k]
        rom_slice = rom_3d[:, :, k]
        err_slice = abs.(fvm_slice .- rom_slice)

        t_min = min(minimum(fvm_slice), minimum(rom_slice))
        t_max = max(maximum(fvm_slice), maximum(rom_slice))
        
        p1 = heatmap(x_coords_mm, y_coords_mm, fvm_slice',
            title="FVM", c=:thermal, aspect_ratio=:equal, clims=(t_min, t_max),
            xlabel="X [mm]", ylabel="Y [mm]")
        p2 = heatmap(x_coords_mm, y_coords_mm, rom_slice',
            title="ROM", c=:thermal, aspect_ratio=:equal, clims=(t_min, t_max),
            xlabel="X [mm]", ylabel="Y [mm]")
        p3 = heatmap(x_coords_mm, y_coords_mm, err_slice',
            title="Abs Error", c=:inferno, aspect_ratio=:equal,
            xlabel="X [mm]", ylabel="Y [mm]")

        p = plot(p1, p2, p3, layout=(1, 3), size=(1200, 400),
            plot_title="XY Slice at Z = $(round(actual_z_mm, digits=2)) mm")

        filename = @sprintf("%s_comparison_xy_z_%.2f.png", sample_id, z_target)
        savefig(p, joinpath(output_dir, filename))
    end

    # YZ Slice target x level (in mm)
    x_target_mm = 0.5
    x_target_m = x_target_mm / 1000.0
    x_coords_m = [(i - 0.5) * dx for i in 1:nx]
    i = argmin(abs.(x_coords_m .- x_target_m))
    actual_x_mm = x_coords_mm[i]

    fvm_slice_yz = fvm_3d[i, :, :]
    rom_slice_yz = rom_3d[i, :, :]
    err_slice_yz = abs.(fvm_slice_yz .- rom_slice_yz)

    t_min_yz = min(minimum(fvm_slice_yz), minimum(rom_slice_yz))
    t_max_yz = max(maximum(fvm_slice_yz), maximum(rom_slice_yz))

    p1 = heatmap(z_coords_mm, y_coords_mm, fvm_slice_yz,
        title="FVM", c=:thermal, aspect_ratio=:equal, clims=(t_min_yz, t_max_yz),
        xlabel="Z [mm]", ylabel="Y [mm]")
    p2 = heatmap(z_coords_mm, y_coords_mm, rom_slice_yz,
        title="ROM", c=:thermal, aspect_ratio=:equal, clims=(t_min_yz, t_max_yz),
        xlabel="Z [mm]", ylabel="Y [mm]")
    p3 = heatmap(z_coords_mm, y_coords_mm, err_slice_yz,
        title="Abs Error", c=:inferno, aspect_ratio=:equal,
        xlabel="Z [mm]", ylabel="Y [mm]")

    p = plot(p1, p2, p3, layout=(1, 3), size=(1200, 400),
        plot_title="YZ Slice at X = $(round(actual_x_mm, digits=2)) mm")

    filename_yz = @sprintf("%s_comparison_yz_x_%.2f.png", sample_id, x_target_mm)
    savefig(p, joinpath(output_dir, filename_yz))
end

