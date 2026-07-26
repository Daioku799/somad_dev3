#!/usr/bin/env julia

# preview_id_map_resolutions.jl
# 異なる解像度における材料IDマップ（TSV幾何断面）の比較・出力スクリプト

using Plots

# H2-main-ext のロード
push!(LOAD_PATH, abspath("H2-main-ext/src"))
include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA

function main()
    resolutions = [60, 120, 240, 360, 480]
    output_dir = "plots/resolution_previews"
    mkpath(output_dir)

    println("==========================================================")
    println("      Generating ID Map Previews for Multi-Resolutions    ")
    println("==========================================================")
    println("Resolutions: ", resolutions)
    println("Output Directory: ", output_dir)

    plots_list = []

    for nxy in resolutions
        print("Building model for $(nxy) x $(nxy)... ")
        ID = modelA.model_test(nxy)
        nz = size(ID, 3)
        
        # Find representative TSV layer (layer with maximum non-background cells)
        best_z = 1
        max_tsv_cells = -1
        for z in 1:nz
            tsv_count = count(x -> x > 1, ID[:, :, z])
            if tsv_count > max_tsv_cells
                max_tsv_cells = tsv_count
                best_z = z
            end
        end
        
        slice_2d = Float64.(ID[:, :, best_z])
        
        # Individual high-res plot
        p_single = heatmap(
            slice_2d,
            title="Material ID Map - $(nxy)x$(nxy) (z=$(best_z))",
            color=:tab10,
            aspect_ratio=:equal,
            clims=(1, 10),
            legend=:outerright,
            xlabel="X Cell Index",
            ylabel="Y Cell Index",
            size=(700, 600)
        )
        single_path = joinpath(output_dir, "id_map_$(nxy)x$(nxy).png")
        savefig(p_single, single_path)
        println("Done. Saved to $single_path")

        # Subplot for overall grid comparison
        p_sub = heatmap(
            slice_2d,
            title="$(nxy) x $(nxy)",
            color=:tab10,
            aspect_ratio=:equal,
            clims=(1, 10),
            legend=false,
            xlabel="X",
            ylabel="Y"
        )
        push!(plots_list, p_sub)
    end

    # Overall comparison plot
    println("\nGenerating combined comparison plot...")
    plt_all = plot(
        plots_list...,
        layout=(1, length(resolutions)),
        size=(350 * length(resolutions), 380),
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
