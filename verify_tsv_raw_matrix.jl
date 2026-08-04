#!/usr/bin/env julia

# verify_tsv_raw_matrix.jl
# TSV境界の生の2D整数行列（部分行列）を切り出して補間なしピクセル描画＆テキスト検証するスクリプト

using Plots
using Printf

push!(LOAD_PATH, abspath("H2-main-ext/src"))
push!(LOAD_PATH, abspath("H2-rom/src"))

include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA

function main()
    resolutions = [60, 240, 600, 2400]
    output_dir = "plots/resolution_previews"
    mkpath(output_dir)

    println("==========================================================")
    println("      Verifying Raw TSV Matrix Sub-arrays (No Interpolation) ")
    println("==========================================================")

    lx, ly = 1.2e-3, 1.2e-3 # mm

    for nxy in resolutions
        println("\n--- Processing Nxy = $(nxy) ---")
        config = modelA.ModelBuilder.ConfigLoader.generate_test_config()
        ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, nxy)

        SZ = size(ID)
        use_ghost = SZ[1] > 2 && SZ[2] > 2
        NX = use_ghost ? SZ[1] - 2 : SZ[1]
        NY = use_ghost ? SZ[2] - 2 : SZ[2]
        dx, dy = lx / NX, ly / NY

        # TSV center is (0.3mm, 0.3mm), radius 0.02mm
        # Target box: [0.25mm, 0.35mm] -> [0.25e-3, 0.35e-3]
        x_min, x_max = 0.25e-3, 0.35e-3
        y_min, y_max = 0.25e-3, 0.35e-3

        i_st = clamp(round(Int, x_min / dx) + 2, 2, NX + 1)
        i_ed = clamp(round(Int, x_max / dx) + 2, 2, NX + 1)
        j_st = clamp(round(Int, y_min / dy) + 2, 2, NY + 1)
        j_ed = clamp(round(Int, y_max / dy) + 2, 2, NY + 1)

        zm = modelA.ModelBuilder.ConfigLoader.calculate_zm(config)
        z_faces = vcat(0.0, cumsum(zm))
        nz = length(z_faces) - 1
        k_tsv = min(8, nz)

        # Extract raw submatrix (no coordinates, pure integer matrix)
        sub_mat = ID[i_st:i_ed, j_st:j_ed, k_tsv]
        nx_sub, ny_sub = size(sub_mat)

        println("Submatrix dimensions: $(nx_sub) x $(ny_sub) cells")
        println("Material ID counts in submatrix:")
        for mat_id in sort(unique(sub_mat))
            count_id = count(x -> x == mat_id, sub_mat)
            println("  ID $(mat_id): $(count_id) cells")
        end

        # Print ASCII representation for smaller resolutions
        if nxy <= 240 && nx_sub <= 30
            println("\nASCII Art Representation (1=Copper 'O', 2=Silicon '.'):")
            for j in ny_sub:-1:1
                line = ""
                for i in 1:nx_sub
                    v = sub_mat[i, j]
                    line *= (v == 1 ? "O " : ". ")
                end
                println("  ", line)
            end
        end

        # Plot raw matrix without interpolation (interpolate=false)
        p_raw = heatmap(
            1:nx_sub, 1:ny_sub, Float64.(sub_mat)',
            interpolate=false,
            aspect_ratio=:equal,
            c=:coolwarm,
            title="Raw Matrix $(nxy)x$(nxy)\nGrid: $(nx_sub)x$(ny_sub) cells",
            xlabel="Grid Index X",
            ylabel="Grid Index Y",
            size=(600, 600)
        )

        out_path = joinpath(output_dir, "raw_matrix_$(nxy).png")
        savefig(p_raw, out_path)
        println("Saved raw matrix plot (interpolate=false) to: ", out_path)
    end
    println("\n==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
