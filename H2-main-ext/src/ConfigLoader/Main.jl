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

    # Parse density_map configuration
    density = nothing
    if haskey(t_json, "density_map")
        d_map = t_json["density_map"]
        gx = get(d_map, "gx", 4)
        gy = get(d_map, "gy", 4)
        
        raw_mu = get(d_map, "mu", Float64[])
        mu = Float64.(raw_mu)
        
        if mode == :density && length(mu) != gx * gy
            throw(ArgumentError("mu size ($(length(mu))) does not match gx * gy ($gx * $gy)"))
        end
        
        n_min = get(d_map, "n_min", 0)
        n_max = get(d_map, "n_max", 0)
        rho_cell_max = Float64(get(d_map, "rho_cell_max", 1.0))
        
        raw_prohibited = get(d_map, "prohibited_cells", [])
        prohibited_cells = Tuple{Int, Int}[]
        for cell in raw_prohibited
            if length(cell) == 2
                push!(prohibited_cells, (Int(cell[1]), Int(cell[2])))
            end
        end
        
        density = DensityMapConfig(gx, gy, mu, n_min, n_max, rho_cell_max, prohibited_cells)
    end

    # Parse manufacturing limits
    manufacturing = nothing
    if haskey(t_json, "manufacturing")
        m_conf = t_json["manufacturing"]
        d_tsv = Float64(get(m_conf, "d_tsv", 2*radius))
        p_min = Float64(get(m_conf, "p_min", 0.0))
        ar_min = Float64(get(m_conf, "ar_min", 0.0))
        ar_max = Float64(get(m_conf, "ar_max", 0.0))
        manufacturing = ManufacturingConfig(d_tsv, p_min, ar_min, ar_max)
    end

    # Parse GA settings
    ga = nothing
    if haskey(t_json, "ga_settings")
        ga_conf = t_json["ga_settings"]
        n_pop = get(ga_conf, "n_pop", 50)
        n_gen = get(ga_conf, "n_gen", 100)
        cx_rate = Float64(get(ga_conf, "cx_rate", 0.8))
        mut_rate = Float64(get(ga_conf, "mut_rate", 0.01))
        ga = GASettings(n_pop, n_gen, cx_rate, mut_rate)
    end

    tsv = TSVConfig(mode, coords, radius, h_tsv, density, manufacturing, ga)

    # 4. Global Dimensions & Offsets (from dimensions object)
    pg_dpth = get(dims, "pg_dpth", 5.0e-6)
    s_dpth = get(dims, "s_dpth", 0.0001)
    d_ufill = get(dims, "d_ufill", 5.0e-5)
    r_bump = get(dims, "r_bump", 3.0e-5)
    
    # lx, ly are not in JSON, using defaults
    lx = get(c_json, "lx", 1.2e-3)
    ly = get(c_json, "ly", 1.2e-3)

    # Additional model config parameters
    snapshot_enabled = get(c_json, "snapshot_enabled", false)
    snapshot_dir = get(c_json, "snapshot_dir", "data/work")
    fixed_silicon_lambda = haskey(c_json, "fixed_silicon_lambda") ? 
                           (c_json["fixed_silicon_lambda"] === nothing ? nothing : Float64(c_json["fixed_silicon_lambda"])) : 
                           nothing
    epsilon = Float64(get(c_json, "epsilon", 1e-6))
    max_iter = get(c_json, "max_iter", 10000)

    return ModelConfig(
        materials,
        layers,
        tsv,
        lx,
        ly,
        pg_dpth,
        s_dpth,
        d_ufill,
        r_bump,
        snapshot_enabled,
        snapshot_dir,
        fixed_silicon_lambda,
        epsilon,
        max_iter
    )
end

end # module
