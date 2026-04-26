module modelA

# Wrap the new modular architecture into the original modelA.jl interface
include("ModelBuilder/ModelBuilder.jl")
using .ModelBuilder
using .ModelBuilder.ConfigLoader
using .ModelBuilder.Grid

export fillID!, setLambda!, model_test

"""
    fillID!(ID, ox, Δh, Z)
    
Original signature maintained for solver compatibility.
Note: In our new system, build_model handles the full lifecycle.
We use this wrapper to populate the ID array provided by the solver.
"""
function fillID!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    # Since the solver provides ID and Z, we need to ensure our logic matches.
    # For baseline, we assume generate_test_config() is used.
    config = generate_test_config()
    
    # We call build_model internally but since ID is already allocated, 
    # we manually run the filling part.
    nxy = size(ID, 1) - 2
    zm = calculate_zm(config)
    
    # Reuse the internal filling functions by making them accessible or duplicating
    # For Absolute Identity, we implement the filling here directly calling ModelBuilder logic.
    ModelBuilder.fill_power_grid!(ID, config, zm, ox, Δh, Z)
    
    objects = generate_components(config, zm)
    for obj in objects
        if obj.type == ModelBuilder.ComponentGenerator.CYLINDER
            ModelBuilder.fill_cylinder!(ID, obj, ox, Δh, Z)
        elseif obj.type == ModelBuilder.ComponentGenerator.SPHERE
            ModelBuilder.fill_sphere!(ID, obj, ox, Δh, Z)
        end
    end
    
    ModelBuilder.fill_plates!(ID, config, zm, ox, Δh, Z)
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

function model_test(nxy::Int, nz::Int=13)
    config = generate_test_config()
    ID, λ, ρ, cp, coordsys = build_model(config, nxy)
    println("Model built successfully. ID size: ", size(ID))
    return ID
end

end # module
