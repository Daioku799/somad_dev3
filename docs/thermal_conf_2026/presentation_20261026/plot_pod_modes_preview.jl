ENV["GKSwstype"] = "100"

using JLD2
using Plots
using Printf
using SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const MODEL_PATH = joinpath(ROOT, "runs", "paper_final_20260824T0140JST",
                            "rom", "rom_model.jld2")
const SNAPSHOT_PATH = joinpath(ROOT, "runs", "paper_final_20260824T0140JST",
                               "verify", "uniform_N48", "snapshot.jld2")
const OUTPUT_PATH = joinpath(@__DIR__, "pod_modes_preview.png")

const MODEL_SHA256 = "cebb89c36ca5fe63cab3db8200b41d00b0583b30c7f47ed0c5f7146d248dca6d"
const SNAPSHOT_SHA256 = "7db1ba15e96ffef4899d13af9a0e59dcb86192eb61e72902ed9d64efdd081cee"
const TARGET_Z = 0.3475e-3

file_sha256(path) = bytes2hex(open(sha256, path))

function verify_input(path, expected)
    actual = file_sha256(path)
    actual == expected ||
        error("Input hash mismatch: $(path) expected=$(expected) actual=$(actual)")
end

function main()
    verify_input(MODEL_PATH, MODEL_SHA256)
    verify_input(SNAPSHOT_PATH, SNAPSHOT_SHA256)

    basis, singular_values, inner_shape = jldopen(MODEL_PATH, "r") do f
        (f["basis"], f["singular_values"], Tuple(Int.(f["inner_shape"])))
    end
    size(basis) == (prod(inner_shape), 24) ||
        error("Unexpected POD basis size: $(size(basis)); shape=$(inner_shape)")

    z_centers = jldopen(SNAPSHOT_PATH, "r") do f
        Float64.(f["z_centers"][2:end-1])
    end
    length(z_centers) == inner_shape[3] ||
        error("z coordinate count does not match basis shape")
    k = argmin(abs.(z_centers .- TARGET_Z))
    z_mm = z_centers[k] * 1e3

    mode1 = reshape(@view(basis[:, 1]), inner_shape)
    mode2 = reshape(@view(basis[:, 2]), inner_shape)
    plane1 = copy(@view mode1[:, :, k])
    plane2 = copy(@view mode2[:, :, k])
    common_limit = maximum(abs, vcat(vec(plane1), vec(plane2)))

    energy = singular_values .^ 2
    ratio = energy ./ sum(energy)
    mode1_pct = 100 * ratio[1]
    mode2_pct = 100 * ratio[2]
    cumulative2_pct = 100 * sum(ratio[1:2])

    nx, ny, _ = inner_shape
    x_edges = collect(range(0.0, 1.2; length=nx + 1))
    y_edges = collect(range(0.0, 1.2; length=ny + 1))
    common = (
        color=:balance,
        clims=(-common_limit, common_limit),
        xlims=(0.0, 1.2),
        ylims=(0.0, 1.2),
        aspect_ratio=:equal,
        xlabel="Position X [mm]",
        ylabel="Position Y [mm]",
        colorbar_title="Basis amplitude [-]",
        titlefontsize=15,
        guidefontsize=11,
        tickfontsize=9,
        colorbar_titlefontsize=9,
        colorbar_tickfontsize=8,
        fontfamily="DejaVu Sans",
        framestyle=:box,
    )

    p1 = heatmap(x_edges, y_edges, plane1';
                 title=@sprintf("POD mode 1 at z = %.4f mm\nvariance contribution: %.2f%%",
                                z_mm, mode1_pct),
                 common...)
    p2 = heatmap(x_edges, y_edges, plane2';
                 title=@sprintf("POD mode 2 at z = %.4f mm\nadditional: %.2f%%  (cumulative: %.2f%%)",
                                z_mm, mode2_pct, cumulative2_pct),
                 common...)

    figure = plot(
        p1,
        p2;
        layout=(1, 2),
        size=(1800, 780),
        dpi=220,
        background_color=:white,
        left_margin=8Plots.mm,
        right_margin=8Plots.mm,
        bottom_margin=12Plots.mm,
        top_margin=5Plots.mm,
    )
    savefig(figure, OUTPUT_PATH)

    @printf("output=%s\n", OUTPUT_PATH)
    @printf("basis_size=%s inner_shape=%s slice_index=%d z_mm=%.4f\n",
            string(size(basis)), string(inner_shape), k, z_mm)
    @printf("mode1_pct=%.6f mode2_pct=%.6f cumulative2_pct=%.6f common_limit=%.9g\n",
            mode1_pct, mode2_pct, cumulative2_pct, common_limit)
end

main()
