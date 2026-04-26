module Main

using JSON
using ..Types

export load_config

"""
    load_config(config_path::String, tsv_config_path::String)

Load configuration from JSON files (H2-main_TSV_Opt format) and return a ModelConfig object.
"""
function load_config(config_path::String, tsv_config_path::String)
    if !isfile(config_path)
        throw(ArgumentError("Config file not found: $config_path"))
    end
    if !isfile(tsv_config_path)
        throw(ArgumentError("TSV Config file not found: $tsv_config_path"))
    end

    c_json = JSON.parsefile(config_path)
    t_json = JSON.parsefile(tsv_config_path)

    # 1. Materials (H2-main_TSV_Opt format: Dict with name as key)
    if !haskey(c_json, "materials")
        throw(ArgumentError("Missing 'materials' in config.json"))
    end
    materials = Material[]
    for (m_name, m_data) in c_json["materials"]
        # Required fields: id, λ, ρ, C
        for key in ["id", "λ", "ρ", "C"]
            if !haskey(m_data, key)
                throw(ArgumentError("Material '$m_name' missing field: $key"))
            end
        end
        push!(materials, Material(
            m_data["id"], 
            m_name, 
            Float64(m_data["λ"]), 
            Float64(m_data["ρ"]), 
            Float64(m_data["C"])
        ))
    end

    # 2. Layers (Array format)
    if !haskey(c_json, "layers")
        throw(ArgumentError("Missing 'layers' in config.json"))
    end
    layers = Layer[]
    for l in c_json["layers"]
        for key in ["name", "thickness", "divisions", "grading"]
            if !haskey(l, key)
                throw(ArgumentError("Layer missing field: $key"))
            end
        end
        push!(layers, Layer(l["name"], l["thickness"], l["divisions"], l["grading"]))
    end
    if length(layers) != 9
        throw(ArgumentError("Expected 9 layers, found $(length(layers))"))
    end

    # 3. TSV (H2-main_TSV_Opt format)
    mode_str = get(t_json, "tsv_mode", "manual")
    mode = Symbol(mode_str)
    
    radius = get(t_json, "tsv_radius", 2.0e-5)
    # Note: h_tsv is in config.json -> dimensions
    dims = get(c_json, "dimensions", Dict())
    h_tsv = get(dims, "h_tsv", 0.0001)

    coords = Tuple{Float64, Float64}[]
    if mode == :manual
        raw_coords = get(t_json, "manual_coordinates", [])
        for c in raw_coords
            push!(coords, (c[1], c[2]))
        end
    end

    tsv = TSVConfig(mode, coords, radius, h_tsv)

    # 4. Global Dimensions & Offsets (from dimensions object)
    pg_dpth = get(dims, "pg_dpth", 5.0e-6)
    s_dpth = get(dims, "s_dpth", 0.0001)
    d_ufill = get(dims, "d_ufill", 5.0e-5)
    r_bump = get(dims, "r_bump", 3.0e-5)
    
    # lx, ly are not in JSON, using defaults
    lx = get(c_json, "lx", 1.2e-3)
    ly = get(c_json, "ly", 1.2e-3)

    return ModelConfig(
        materials,
        layers,
        tsv,
        lx,
        ly,
        pg_dpth,
        s_dpth,
        d_ufill,
        r_bump
    )
end

end # module
