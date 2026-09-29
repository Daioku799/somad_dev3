using Test

include(joinpath(@__DIR__, "..", "src", "common.jl"))
include(joinpath(@__DIR__, "..", "src", "ResearchContracts", "ResearchContracts.jl"))
include(joinpath(@__DIR__, "..", "src", "ThermalOperators", "ThermalOperators.jl"))
include(joinpath(@__DIR__, "..", "src", "boundary_conditions.jl"))
include(joinpath(@__DIR__, "..", "src", "RHS.jl"))
include(joinpath(@__DIR__, "..", "src", "NonUniform.jl"))

using .Common
using .ResearchContracts
using .ThermalOperators
using .BoundaryConditions

@testset "FVM physical-face coefficients delegate to the shared operator" begin
    area = 1.7
    d_p, d_n = 0.2, 0.8
    center_distance = d_p + d_n
    k_p, k_n = 5.0, 11.0
    actual = NonUniform.fvm_face_conductance(
        area, d_p, d_n, center_distance, k_p, k_n, 1.0, 1.0,
    )
    expected = internal_face_conductance(area, d_p, d_n, k_p, k_n)
    @test actual == expected

    # The external ghost path remains the legacy boundary discretization and
    # is not sent to the internal two-physical-cell operator.
    boundary_actual = NonUniform.fvm_face_conductance(
        area, d_p, d_n, center_distance, k_p, k_n, 1.0, 0.0,
    )
    boundary_expected = Common.λf(k_p, k_n, 1.0, 0.0) * area / center_distance
    @test boundary_actual == boundary_expected

    @test_throws ContractError NonUniform.fvm_face_conductance(
        area, d_p, d_n, center_distance, k_p, k_n, 0.5, 1.0,
    )

    source = read(joinpath(@__DIR__, "..", "src", "NonUniform.jl"), String)
    @test count("cond_xm = fvm_face_conductance", source) == 5
    @test count("cond_xp = fvm_face_conductance", source) == 5
    @test count("cond_ym = fvm_face_conductance", source) == 5
    @test count("cond_yp = fvm_face_conductance", source) == 5
    @test count("cond_zm = fvm_face_conductance", source) == 5
    @test count("cond_zp = fvm_face_conductance", source) == 5
    @test !occursin(r"cond_[xyz][mp] = .*λf", source)
end

@testset "existing boundary conditions adapt to outward-positive heat rates" begin
    minus_face = BoundaryFace(:xminus, (2, 2, 2), 2.0, 0.25)
    plus_face = BoundaryFace(:xplus, (4, 2, 2), 2.0, 0.25)

    fixed = isothermal_bc(300.0)
    @test thermal_boundary_heat_rate(fixed, plus_face, 310.0; conductance_W_K=4.0) == 40.0
    @test_throws ContractError thermal_boundary_heat_rate(fixed, plus_face, 310.0)

    coordinate_flux = heat_flux_bc(3.0)
    @test thermal_boundary_heat_rate(coordinate_flux, minus_face, 310.0) == -6.0
    @test thermal_boundary_heat_rate(coordinate_flux, plus_face, 310.0) == 6.0

    convection = convection_bc(5.0, 290.0)
    @test thermal_boundary_heat_rate(convection, minus_face, 310.0) == 200.0
    @test thermal_boundary_heat_rate(convection, plus_face, 310.0) == 200.0
end
