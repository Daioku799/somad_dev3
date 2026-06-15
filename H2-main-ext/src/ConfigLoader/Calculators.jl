module Calculators

using ..Types

export calculate_zm, calculate_solder_radius

"""
    calculate_zm(layers::Vector{Layer}, pg_dpth::Float64)

Calculate the Z-marker coordinates (zm0 to zm12) based on layer thicknesses.
Returns a Vector{Float64} of length 13.
Uses rounding to ensure bit-identical results with original hardcoded constants
where necessary to counteract floating point accumulation.
"""
function calculate_zm(layers::Vector{Layer}, pg_dpth::Float64)
    zm = zeros(Float64, 13)
    
    # zm0 is always 0.0
    zm[1] = 0.0
    
    # Accumulate layer thicknesses and round to 10 decimal places to match common precision
    # or handle the floating point accumulation for exact values.
    
    # zm1 (Substrate)
    zm[2] = zm[1] + layers[1].thickness
    
    # zm2 (Underfill1)
    zm[3] = zm[2] + layers[2].thickness
    
    # zm4 (Silicon1)
    zm[5] = zm[3] + layers[3].thickness
    # zm3 (Silicon1 PowerGrid offset)
    zm[4] = zm[5] - pg_dpth
    
    # zm5 (Underfill2)
    zm[6] = zm[5] + layers[4].thickness
    
    # zm7 (Silicon2)
    zm[8] = zm[6] + layers[5].thickness
    # zm6 (Silicon2 PowerGrid offset)
    zm[7] = zm[8] - pg_dpth
    
    # zm8 (Underfill3)
    zm[9] = zm[8] + layers[6].thickness
    
    # zm10 (Silicon3)
    zm[11] = zm[9] + layers[7].thickness
    # zm9 (Silicon3 PowerGrid offset)
    zm[10] = zm[11] - pg_dpth
    
    # zm11 (Underfill4)
    zm[12] = zm[11] + layers[8].thickness
    
    # zm12 (Heatsink)
    zm[13] = zm[12] + layers[9].thickness
    
    # Final fix for floating point accumulation at the top boundary
    # If it's effectively 0.6e-3, ensure it is exactly that.
    for i in 1:13
        # Round to 1e-15 precision which is far beyond simulation needs
        # but fixes the 1e-19 jitter.
        zm[i] = round(zm[i], digits=15)
    end
    
    return zm
end

"""
    calculate_zm(config::ModelConfig)

Wrapper to calculate the Z-marker coordinates from a ModelConfig object.
"""
function calculate_zm(config::ModelConfig)
    return calculate_zm(config.layers, config.pg_dpth)
end

"""
    calculate_solder_radius(d_ufill::Float64)

Calculate the recommended solder bump radius: 1.3 * d_ufill / 2.0
"""
function calculate_solder_radius(d_ufill::Float64)
    return 1.3 * d_ufill / 2.0
end

end # module
