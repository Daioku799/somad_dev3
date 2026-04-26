module Main

using Plots
include("Slicer.jl")
using .Slicer
# Access GeometryLogic for GDS data
include("../GeometryLogic/GeometryLogic.jl")
using .GeometryLogic

export plot_model_validation

"""
    plot_model_validation(ID, λ, coordsys, config, zm; output_dir="plots")

Generate validation plots for the model: YZ and XY slices.
"""
function plot_model_validation(ID, λ, coordsys, config, zm; output_dir="plots")
    if !isdir(output_dir)
        mkdir(output_dir)
    end

    # Define common DH/OX for Slicer
    nxy = size(ID, 1) - 2
    dx = config.lx / nxy
    dy = config.ly / nxy
    dh = (dx, dy, 0.0)
    ox = (0.0, 0.0, 0.0)

    # 1. YZ Slice (Check vertical sync at TSV location)
    # TSVs are at X=0.3, 0.5, 0.7, 0.9 mm. Let's pick 0.5 mm.
    i_tsv, _, _ = get_indices(0.5e-3, 0.5e-3, 0.3e-3, ox, dh, coordsys.z_centers)
    yz_data = get_yz_slice(ID, i_tsv) # size: (MY, MZ)
    
    y_axis = [(j - 1.0) * dy for j in 1:size(ID, 2)] .* 1e3 # mm
    z_axis = coordsys.Z .* 1e3 # mm
    
    p1 = heatmap(y_axis, z_axis, yz_data', 
                 title="YZ Slice (X=0.5mm, TSV Plane)",
                 xlabel="Y [mm]", ylabel="Z [mm]",
                 aspect_ratio=:auto, color=:tab10)
    savefig(p1, joinpath(output_dir, "validation_yz.png"))

    # 2. XY Slice (Check chip mapping)
    # Silicon 1 center
    z_silicon = (zm[3] + zm[5]) * 0.5
    _, _, k_si = get_indices(0.6e-3, 0.6e-3, z_silicon, ox, dh, coordsys.z_centers)
    xy_data = get_xy_slice(ID, k_si) # size: (MX, MY)
    
    x_axis = [(i - 1.0) * dx for i in 1:size(ID, 1)] .* 1e3 # mm
    
    p2 = heatmap(x_axis, y_axis, xy_data',
                 title="XY Slice (Z=$(round(z_silicon*1e3, digits=3))mm)",
                 xlabel="X [mm]", ylabel="Y [mm]",
                 aspect_ratio=:equal, color=:tab10)
                 
    # Overlay GDS
    gds_path = "../H2-main_TSV_Opt/org_chip1.gds"
    if isfile(gds_path)
        layer = load_gds_layer(gds_path, 1)
        plot_data = get_plot_data(layer)
        for poly_mat in plot_data
            px = poly_mat[:, 1] .* 1e3 # mm
            py = poly_mat[:, 2] .* 1e3 # mm
            plot!(p2, px, py, color=:white, lw=1.5, label="")
        end
    end
    savefig(p2, joinpath(output_dir, "validation_xy_chip1.png"))

    println("Validation plots saved to $output_dir/")
end

end # module
