module Defaults

using ..Types

export generate_test_config

# Constants from H2-main-original/src/modelA.jl
const PG_DPTH = 0.005e-3
const S_DPTH = 0.1e-3
const D_UFILL = 0.05e-3
const R_BUMP = 0.03e-3
const R_TSV = 0.02e-3
const H_TSV = 0.1e-3

# Material constants
const MAT_COPPER    = Material(1, "Copper", 386.0, 8960.0, 383.0)
const MAT_SILICON   = Material(2, "Silicon", 149.0, 2330.0, 720.0)
const MAT_SOLDER    = Material(3, "Solder", 50.0, 8500.0, 197.0)
const MAT_PCB       = Material(4, "PCB", 0.4, 1850.0, 1000.0)
const MAT_HEATSINK  = Material(5, "Heatsink", 222.0, 2700.0, 921.0)
const MAT_RESIN     = Material(6, "Resin", 1.5, 2590.0, 1050.0)
const MAT_PWRSRC    = Material(7, "PowerSource", 149.0, 2330.0, 720.0)

function generate_test_config()
    materials = [MAT_COPPER, MAT_SILICON, MAT_SOLDER, MAT_PCB, MAT_HEATSINK, MAT_RESIN, MAT_PWRSRC]
    
    # Standard layers based on modelA.jl markers
    # zm0=0, zm1=0.05, zm2=0.1, zm4=0.2, zm5=0.25, zm7=0.35, zm8=0.4, zm10=0.5, zm11=0.55, zm12=0.6
    layers = [
        Layer("Substrate", 0.05e-3, 1, 1.0), # zm0 to zm1
        Layer("Underfill1", 0.05e-3, 1, 1.0), # zm1 to zm2
        Layer("Silicon1", 0.1e-3, 1, 1.0), # zm2 to zm4 (Note: zm3 is offset inside Silicon1)
        Layer("Underfill2", 0.05e-3, 1, 1.0), # zm4 to zm5
        Layer("Silicon2", 0.1e-3, 1, 1.0), # zm5 to zm7
        Layer("Underfill3", 0.05e-3, 1, 1.0), # zm7 to zm8
        Layer("Silicon3", 0.1e-3, 1, 1.0), # zm8 to zm10
        Layer("Underfill4", 0.05e-3, 1, 1.0), # zm10 to zm11
        Layer("Heatsink", 0.05e-3, 1, 1.0) # zm11 to zm12
    ]
    
    # TSV coordinates from original FillTSV!
    # y in [0.3, 0.5, 0.7, 0.9]mm, x in [0.3, 0.5, 0.7, 0.9]mm
    tsv_coords = Tuple{Float64, Float64}[]
    for y in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3], x in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3]
        push!(tsv_coords, (x, y))
    end
    
    tsv = TSVConfig(:manual, tsv_coords, R_TSV, H_TSV)
    
    return ModelConfig(
        materials,
        layers,
        tsv,
        1.2e-3, # Lx
        1.2e-3, # Ly
        PG_DPTH,
        S_DPTH,
        D_UFILL,
        R_BUMP
    )
end

end # module
