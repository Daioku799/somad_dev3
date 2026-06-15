module Defaults

using ..Types

export generate_default_materials, generate_default_layers
export LX, LY, PG_DPTH, S_DPTH, D_UFILL, R_BUMP, R_TSV, H_TSV
export generate_test_config

# Default dimensions from H2-main-original/src/modelA.jl
const LX = 1.2e-3
const LY = 1.2e-3
const PG_DPTH = 0.005e-3
const S_DPTH = 0.1e-3
const D_UFILL = 0.05e-3
const R_BUMP = 0.03e-3
const R_TSV = 0.02e-3
const H_TSV = 0.1e-3

"""
    generate_default_materials()

Returns a Vector{Material} with physical constants bit-for-bit identical to 
H2-main-original/src/modelA.jl.
"""
function generate_default_materials()
    return [
        Material(1, "Copper", 386.0, 8960.0, 383.0),
        Material(2, "Silicon", 149.0, 2330.0, 720.0),
        Material(3, "Solder", 50.0, 8500.0, 197.0),
        Material(4, "PCB", 0.4, 1850.0, 1000.0),
        Material(5, "Heatsink", 222.0, 2700.0, 921.0),
        Material(6, "Resin", 1.5, 2590.0, 1050.0),
        Material(7, "PowerSource", 149.0, 2330.0, 720.0)
    ]
end

"""
    generate_default_layers()

Returns a Vector{Layer} representing the 9 physical layers defined in 
H2-main-original/src/modelA.jl. Divisions match the Zcase2! refinement.
"""
function generate_default_layers()
    return [
        Layer("Substrate", 0.05e-3, 3, 1.0),   # zm0 to zm1
        Layer("Underfill1", 0.05e-3, 3, 1.0),  # zm1 to zm2
        Layer("Silicon1", 0.1e-3, 4, 1.0),    # zm2 to zm4 (inc. zm3)
        Layer("Underfill2", 0.05e-3, 3, 1.0),  # zm4 to zm5
        Layer("Silicon2", 0.1e-3, 4, 1.0),    # zm5 to zm7 (inc. zm6)
        Layer("Underfill3", 0.05e-3, 3, 1.0),  # zm7 to zm8
        Layer("Silicon3", 0.1e-3, 4, 1.0),    # zm8 to zm10 (inc. zm9)
        Layer("Underfill4", 0.05e-3, 3, 1.0),  # zm10 to zm11
        Layer("Heatsink", 0.05e-3, 3, 1.0)     # zm11 to zm12
    ]
end

"""
    generate_test_config()

Utility function to generate a ModelConfig that reproduces the H2-main-original environment.
"""
function generate_test_config()
    materials = generate_default_materials()
    layers = generate_default_layers()
    
    # TSV coordinates from original FillTSV!
    # y in [0.3, 0.5, 0.7, 0.9]mm, x in [0.3, 0.5, 0.7, 0.9]mm
    tsv_coords = Tuple{Float64, Float64}[]
    for y in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3], x in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3]
        push!(tsv_coords, (x, y))
    end
    
    tsv = TSVConfig(
        :manual, 
        tsv_coords, 
        R_TSV, 
        H_TSV, 
        nothing, # density
        nothing, # manufacturing
        nothing  # ga
    )
    
    return ModelConfig(
        materials,
        layers,
        tsv,
        LX,
        LY,
        PG_DPTH,
        S_DPTH,
        D_UFILL,
        R_BUMP,
        false,      # snapshot_enabled
        "data/work", # snapshot_dir
        nothing,    # fixed_silicon_lambda
        1e-6,       # epsilon
        10000       # max_iter
    )
end

end # module
