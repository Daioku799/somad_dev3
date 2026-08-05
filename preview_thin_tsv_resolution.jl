#!/usr/bin/env julia

# Compare XY material-map resolution for a thin TSV without running the FVM.
#
# Rasterization follows H2-main-ext: an FVM cell becomes copper when at least
# 50% of its volume is inside the TSV cylinder. At the TSV midplane this is a
# 2-D circle/cell area test.
#
# Usage:
#   julia --project=H2-main-ext preview_thin_tsv_resolution.jl [diameter_um ...]

using Plots
using Plots.PlotMeasures
using Printf

const CHIP_SIZE_M = 1.2e-3
const SILICON_MIN_M = 0.1e-3
const SILICON_MAX_M = 1.1e-3
const TSV_COORDS_M = [(x, y) for y in (0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3)
                            for x in (0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3)]
const REQUESTED_RESOLUTIONS = [240, 480, 600]
const FINE_RESOLUTIONS = [1200, 2400]
const FINE_DIAMETER_UM = 5.0
const SUBCELL_SAMPLES = 50

"""Return true when at least half of a square FVM cell lies in the circle."""
function cell_is_copper(xlo, xhi, ylo, yhi, cx, cy, radius)
    if xhi < cx - radius || xlo > cx + radius ||
       yhi < cy - radius || ylo > cy + radius
        return false
    end

    r2 = radius^2
    corners = ((xlo, ylo), (xlo, yhi), (xhi, ylo), (xhi, yhi))
    if all((x - cx)^2 + (y - cy)^2 <= r2 for (x, y) in corners)
        return true
    end

    dx = (xhi - xlo) / SUBCELL_SAMPLES
    dy = (yhi - ylo) / SUBCELL_SAMPLES
    inside = 0
    threshold = cld(SUBCELL_SAMPLES^2, 2)
    for j in 1:SUBCELL_SAMPLES, i in 1:SUBCELL_SAMPLES
        x = xlo + (i - 0.5) * dx
        y = ylo + (j - 0.5) * dy
        inside += (x - cx)^2 + (y - cy)^2 <= r2
    end
    return inside >= threshold
end

"""Build a 2-D material ID slice: copper=1, silicon=2, resin=6."""
function build_id_slice(nxy::Int, radius::Float64)
    dx = CHIP_SIZE_M / nxy
    id = fill(UInt8(6), nxy, nxy)

    # These resolutions align exactly with the 0.1--1.1 mm silicon box.
    for j in 1:nxy, i in 1:nxy
        xc = (i - 0.5) * dx
        yc = (j - 0.5) * dx
        if SILICON_MIN_M <= xc <= SILICON_MAX_M &&
           SILICON_MIN_M <= yc <= SILICON_MAX_M
            id[i, j] = 2
        end
    end

    for (cx, cy) in TSV_COORDS_M
        i0 = max(1, floor(Int, (cx - radius) / dx) + 1)
        i1 = min(nxy, floor(Int, (cx + radius) / dx) + 1)
        j0 = max(1, floor(Int, (cy - radius) / dx) + 1)
        j1 = min(nxy, floor(Int, (cy + radius) / dx) + 1)
        for j in j0:j1, i in i0:i1
            xlo, xhi = (i - 1) * dx, i * dx
            ylo, yhi = (j - 1) * dx, j * dx
            if cell_is_copper(xlo, xhi, ylo, yhi, cx, cy, radius)
                id[i, j] = 1
            end
        end
    end
    return id, dx
end

function id_plot(id, nxy, diameter_um; zoom=false)
    n = size(id, 1)
    dx_mm = 1.2 / n
    if zoom
        plot_min_mm, plot_max_mm = 0.275, 0.325
        i0 = max(1, floor(Int, plot_min_mm / dx_mm) + 1)
        i1 = min(n, ceil(Int, plot_max_mm / dx_mm))
        data = id[i0:i1, i0:i1]
        edges_mm = collect(range((i0 - 1) * dx_mm, i1 * dx_mm, length=size(data, 1) + 1))
    else
        plot_min_mm, plot_max_mm = 0.0, 1.2
        data = id
        edges_mm = collect(range(0.0, 1.2, length=n + 1))
    end

    palette = cgrad([:yellow, :gray, :gray, :gray, :gray, :green], 6; categorical=true)
    return heatmap(
        edges_mm, edges_mm, permutedims(data),
        c=palette, clims=(0.5, 6.5), colorbar=false, interpolate=false,
        xlims=(plot_min_mm, plot_max_mm), ylims=(plot_min_mm, plot_max_mm),
        aspect_ratio=:equal,
        size=zoom ? (600, 600) : (nxy >= 2400 ? (2400, 2400) : (1200, 1200)),
        xlabel="X [mm]", ylabel="Y [mm]",
        title="$(nxy)×$(nxy), d=$(diameter_um) µm",
    )
end

function generate_for_diameter(diameter_um::Float64)
    diameter_um > 0 || error("diameter_um must be positive")
    radius = diameter_um * 0.5e-6
    diameter_label = replace(@sprintf("%.3g", diameter_um), "." => "p")
    output_dir = joinpath("plots", "resolution_previews", "thin_tsv_d$(diameter_label)um")
    mkpath(output_dir)

    requested_full_plots = Any[]
    fine_full_plots = Any[]
    zoom_plots = Any[]
    fine_zoom_plots = Any[]
    rows = NamedTuple[]
    include_fine = isapprox(diameter_um, FINE_DIAMETER_UM; atol=1e-12)
    resolutions = include_fine ? vcat(REQUESTED_RESOLUTIONS, FINE_RESOLUTIONS) : REQUESTED_RESOLUTIONS

    for nxy in resolutions
        @printf("Building thin-TSV ID slice for %d×%d ... ", nxy, nxy)
        id, dx = build_id_slice(nxy, radius)
        copper_total = count(==(UInt8(1)), id)
        copper_per_tsv = copper_total / length(TSV_COORDS_M)
        effective_area = copper_per_tsv * dx^2
        exact_area = pi * radius^2
        equivalent_diameter = 2sqrt(effective_area / pi)
        area_error_pct = 100 * (effective_area / exact_area - 1)

        push!(rows, (
            nxy=nxy,
            dx_um=dx * 1e6,
            cells_across=diameter_um / (dx * 1e6),
            copper_cells_per_tsv=copper_per_tsv,
            effective_diameter_um=equivalent_diameter * 1e6,
            area_error_pct=area_error_pct,
        ))

        p_zoom = id_plot(id, nxy, diameter_um; zoom=true)
        savefig(p_zoom, joinpath(output_dir, "zoom_$(nxy)x$(nxy).png"))
        push!(zoom_plots, p_zoom)
        if nxy in FINE_RESOLUTIONS
            push!(fine_zoom_plots, p_zoom)
        end

        p_full = id_plot(id, nxy, diameter_um; zoom=false)
        savefig(p_full, joinpath(output_dir, "full_$(nxy)x$(nxy).png"))
        if nxy in REQUESTED_RESOLUTIONS
            push!(requested_full_plots, p_full)
        else
            push!(fine_full_plots, p_full)
        end
        println("done")
    end

    p_full_all = plot(
        requested_full_plots..., layout=(1, 3), size=(1800, 700),
        plot_title="TSV full-chip material map comparison, d=$(diameter_um) µm",
        margin=5mm, left_margin=10mm, bottom_margin=7mm,
    )
    savefig(p_full_all, joinpath(output_dir, "full_comparison.png"))

    if include_fine
        p_fine_all = plot(
            fine_full_plots..., layout=(1, 2), size=(1600, 800),
            plot_title="Fine-grid TSV material map comparison, d=$(diameter_um) µm",
            margin=5mm, left_margin=10mm, bottom_margin=7mm,
        )
        savefig(p_fine_all, joinpath(output_dir, "fine_full_comparison_1200_2400.png"))

        p_fine_zoom = plot(
            fine_zoom_plots..., layout=(1, 2), size=(1200, 600),
            plot_title="Fine-grid TSV boundary comparison, d=$(diameter_um) µm",
            margin=5mm,
        )
        savefig(p_fine_zoom, joinpath(output_dir, "fine_zoom_comparison_1200_2400.png"))
    end

    zoom_layout = include_fine ? (2, 3) : (1, 3)
    zoom_size = include_fine ? (1800, 1100) : (1800, 600)
    p_zoom_all = plot(
        zoom_plots..., layout=zoom_layout, size=zoom_size,
        plot_title="Thin TSV boundary resolution comparison",
        margin=4mm,
    )
    savefig(p_zoom_all, joinpath(output_dir, "zoom_comparison.png"))

    open(joinpath(output_dir, "resolution_metrics.tsv"), "w") do io
        println(io, "Nxy\tdx_um\tcells_across_diameter\tcopper_cells_per_tsv\teffective_diameter_um\tarea_error_pct")
        for row in rows
            @printf(io, "%d\t%.6f\t%.6f\t%.3f\t%.6f\t%.6f\n",
                row.nxy, row.dx_um, row.cells_across,
                row.copper_cells_per_tsv, row.effective_diameter_um,
                row.area_error_pct)
        end
    end

    println("Saved results to $(output_dir)")
end

function main()
    diameters_um = isempty(ARGS) ? [10.0] : parse.(Float64, ARGS)
    for diameter_um in diameters_um
        generate_for_diameter(diameter_um)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
