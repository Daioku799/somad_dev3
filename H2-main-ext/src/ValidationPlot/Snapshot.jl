module Snapshot

using JLD2

export load_snapshot

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

end # module
