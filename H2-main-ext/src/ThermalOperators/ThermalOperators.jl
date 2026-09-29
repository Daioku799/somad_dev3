"""Finite-volume thermal operators shared by the solver and objectives."""
module ThermalOperators

using ..ResearchContracts

include("Types.jl")
include("Conductance.jl")
include("BoundaryOperators.jl")
include("EnergyBalance.jl")

export GridGeometry3D
export internal_face_conductance
export BoundaryFace, DirichletBoundary, NeumannBoundary, RobinBoundary
export BoundaryHeatRate, boundary_heat_rate, aggregate_boundary_heat_rates
export EnergyBalanceResult, energy_balance
export SolveStatus, PASS, FAIL, SolveQuality, assess_solve_quality

end
