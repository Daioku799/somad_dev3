#!/usr/bin/env julia

# preview_id_map_resolutions.jl
# ValidationPlot モジュールを利用した材料IDマップ高解像度比較プレビュースクリプト

using Plots
using Printf

push!(LOAD_PATH, abspath("H2-main-ext/src"))
push!(LOAD_PATH, abspath("H2-rom/src"))

include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
include(joinpath(abspath("H2-rom/src/ValidationPlot"), "ValidationPlot.jl"))

using .modelA
using .ValidationPlot

function main()
    resolutions = [60, 120, 240, 360, 480]
    output_dir = "plots/resolution_previews"
    mkpath(output_dir)

    println("==========================================================")
    println("      Generating ID Map Previews via ValidationPlot       ")
    println("==========================================================")
    println("Resolutions: ", resolutions)
    println("Output Directory: ", output_dir)

    plots_list = []
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
        
        zm = modelA.ModelBuilder.ConfigLoader.calculate_zm(config)
        z_faces = vcat(0.0, cumsum(zm))
        
        # Select z height in the middle of TSV/Silicon region
        nz = length(z_faces) - 1
        zc = z_faces[min(8, nz)]
        SZ_plot = (SZ[1], SZ[2], nz)
        
        # Call official ValidationPlot function
        p_sub = ValidationPlot.plot_heatsource_tsv_overlay_nu_return(ID, zc, SZ_plot, ox, dh, z_faces)
        plot!(p_sub, title="$(nxy) x $(nxy)")
        
        single_path = joinpath(output_dir, "id_map_$(nxy)x$(nxy).png")
        savefig(p_sub, single_path)
        println("Done. Saved to $single_path")

        push!(plots_list, p_sub)
    end

    println("\nGenerating combined comparison plot...")
    plt_all = plot(
        plots_list...,
        layout=(1, length(resolutions)),
        size=(360 * length(resolutions), 400),
        plot_title="TSV Material ID Map Resolution Comparison (60 to 480)"
    )
    all_path = joinpath(output_dir, "id_map_comparison_all.png")
    savefig(plt_all, all_path)
    println("Successfully saved combined plot to: ", all_path)
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
