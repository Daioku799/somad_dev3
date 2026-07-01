module modelA

# Wrap the new modular architecture into the original modelA.jl interface
include("ModelBuilder/ModelBuilder.jl")
using .ModelBuilder
using .ModelBuilder.ConfigLoader
using .ModelBuilder.Grid
using .ModelBuilder.ComponentGenerator

export fillID!, setLambda!, setProperties!, model_test

"""
    fillID!(ID, ox, Δh, Z)
    
Original signature maintained for solver compatibility.
Note: In our new system, build_model handles the full lifecycle.
We use this wrapper to populate the ID array provided by the solver.
"""
function fillID!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    config = generate_test_config()
    
    zm = calculate_zm(config)
    objects = generate_components(config, zm)
    
    # A. PowerGrid
    ModelBuilder.fill_power_grid!(ID, config, zm, ox, Δh, Z)
    
    # B. TSVs (CYLINDER)
    for obj in objects
        if obj.type == ModelBuilder.ComponentGenerator.CYLINDER
            ModelBuilder.fill_cylinder!(ID, obj, ox, Δh, Z)
        end
    end
    
    # C. Silicon Plates
    ModelBuilder.fill_plates!(ID, config, zm, ox, Δh, Z)
    
    # D. Solder Bumps (SPHERE)
    for obj in objects
        if obj.type == ModelBuilder.ComponentGenerator.SPHERE
            ModelBuilder.fill_sphere!(ID, obj, ox, Δh, Z)
        end
    end
    
    # E. Resin
    ModelBuilder.fill_resin!(ID, 6) # MAT_RESIN
end

"""
    setLambda!(λ, ρ, cp, ID)
    
Original signature maintained.
"""
function setLambda!(λ::Array{Float64,3}, ρ::Array{Float64,3}, cp::Array{Float64,3}, ID::Array{UInt8,3})
    config = generate_test_config()
    ModelBuilder.set_properties!(λ, ρ, cp, ID, config.materials)
end

function setProperties!(λ::Array{Float64,3}, ρ::Array{Float64,3}, cp::Array{Float64,3}, ID::Array{UInt8,3})
    config = generate_test_config()
    ModelBuilder.set_properties!(λ, ρ, cp, ID, config.materials)
end

function model_test(nxy::Int, nz::Int=13)
    config = generate_test_config()
    ID, λ, ρ, cp, coordsys = build_model(config, nxy)
    println("Model built successfully. ID size: ", size(ID))
    return ID
end

end # module
