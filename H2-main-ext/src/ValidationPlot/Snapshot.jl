module Snapshot

using JLD2
using Plots
using ..Palettes

export load_snapshot, plot_snapshot_validation

"""
    load_snapshot(filepath::String)

Load snapshot data from a JLD2 file.
Returns a NamedTuple containing id_map, theta, z_centers, nx, ny, and nz.
"""
function load_snapshot(filepath::String)
    if !isfile(filepath)
        error("Snapshot file not found: $filepath")
    end

    data = jldopen(filepath, "r")
    
    try
        # Check required keys
        required_keys = ["id_map", "theta", "z_centers", "nx", "ny", "nz"]
        available_keys = keys(data)
        for k in required_keys
            if !(k in available_keys)
                error("Snapshot file missing required key: $k")
            end
        end

        # Read data
        id_map = data["id_map"]
        theta = data["theta"]
        z_centers = data["z_centers"]
        nx = data["nx"]
        ny = data["ny"]
        nz = data["nz"]

        return (
            id_map = id_map,
            theta = theta,
            z_centers = z_centers,
            nx = nx,
            ny = ny,
            nz = nz
        )
    finally
        close(data)
    end
end

"""
    plot_snapshot_validation(filepath::String; output_dir="plots", temp_lims=(300.0, 400.0), z_level=0.00015)

Plot id_map and temperature side-by-side for a given snapshot.
"""
function plot_snapshot_validation(filepath::String; output_dir="plots", temp_lims=(300.0, 400.0), z_level=0.00015)
    data = load_snapshot(filepath)
    
    # Find z index
    k = argmin(abs.(data.z_centers .- z_level))
    
    id_slice = data.id_map[:, :, k]
    temp_slice = data.theta[:, :, k]
    
    p1 = heatmap(id_slice', 
                 c=LEGACY_COLOR_PALETTE, 
                 clims=(0.5, 7.5), 
                 aspect_ratio=:equal, 
                 title="ID Map (z=$(round(data.z_centers[k], digits=5)))")
    
    p2 = heatmap(temp_slice', 
                 c=:thermal, 
                 clims=temp_lims, 
                 aspect_ratio=:equal, 
                 title="Temperature")
    
    p = plot(p1, p2, layout=(1, 2), size=(1200, 500))
    
    if !ispath(output_dir)
        mkpath(output_dir)
    end
    
    basename_str = basename(filepath)
    name_noext = splitext(basename_str)[1]
    output_path = joinpath(output_dir, "$(name_noext)_validation.png")
    
    savefig(p, output_path)
    return output_path
end

end # module
