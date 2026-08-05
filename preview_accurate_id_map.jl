#!/usr/bin/env julia

# preview_accurate_id_map.jl
# 補間(interpolate=false)と高解像度出力を用いた、ピクセル完全なIDマップのプレビュースクリプト

using Plots
using Printf

push!(LOAD_PATH, abspath("H2-main-ext/src"))
push!(LOAD_PATH, abspath("H2-rom/src"))

include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
include(joinpath(abspath("H2-rom/src/ValidationPlot"), "ValidationPlot.jl"))

using .modelA
using .ValidationPlot

function main()
    resolutions = [600, 2400]
    output_dir = "plots/resolution_previews"
    mkpath(output_dir)

    println("==========================================================")
    println("      Generating Accurate ID Map Previews (Interpolate=false) ")
    println("==========================================================")
    println("Resolutions: ", resolutions)
    println("Output Directory: ", output_dir)

    lx, ly = 1.2e-3, 1.2e-3

    for nxy in resolutions
        print("Building model for $(nxy) x $(nxy)... ")
        config = modelA.ModelBuilder.ConfigLoader.generate_test_config()
        ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, nxy)
        
        SZ = size(ID) # (MX, MY, MZ)
        use_ghost = SZ[1] > 2 && SZ[2] > 2
        NX = use_ghost ? SZ[1] - 2 : SZ[1]
        NY = use_ghost ? SZ[2] - 2 : SZ[2]
        dx, dy = lx / NX, ly / NY
        ox = (0.0, 0.0, 0.0)
        dh = (dx, dy, 1.0)
        
        # H2-main Zcase2 coordinates; 0.15 mm is inside Silicon1/TSV1.
        z_faces = coordsys.Z
        zc = 0.15e-3
        SZ_plot = SZ
        
        # 1. Full Chip Accurate Plot
        p_full = ValidationPlot.plot_heatsource_tsv_overlay_nu_return(ID, zc, SZ_plot, ox, dh, z_faces)
        plot!(p_full, title="$(nxy) x $(nxy) (Accurate Full)", size=(1200, 1200))
        
        full_path = joinpath(output_dir, "accurate_id_map_full_$(nxy)x$(nxy).png")
        savefig(p_full, full_path)
        println("Saved full map to $full_path")

        # 2. Zoomed Accurate Plot (around x=0.3mm, y=0.3mm)
        p_zoom = ValidationPlot.plot_heatsource_tsv_overlay_nu_return(ID, zc, SZ_plot, ox, dh, z_faces)
        plot!(p_zoom,
              xlims=(0.25, 0.35),
              ylims=(0.25, 0.35),
              title="$(nxy) x $(nxy) (Accurate Zoomed)",
              size=(800, 800))
        
        zoom_path = joinpath(output_dir, "accurate_id_map_zoom_$(nxy)x$(nxy).png")
        savefig(p_zoom, zoom_path)
        println("Saved zoomed map to $zoom_path")
    end
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
