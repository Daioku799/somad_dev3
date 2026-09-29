using Test

include(joinpath(@__DIR__, "..", "src", "ResearchContracts", "ResearchContracts.jl"))
include(joinpath(@__DIR__, "..", "src", "ThermalOperators", "ThermalOperators.jl"))
using .ResearchContracts
using .ThermalOperators

@testset "internal face conductance" begin
    @test internal_face_conductance(2.0, 0.5, 0.5, 4.0, 4.0) ≈ 8.0 rtol=1e-12 atol=0.0

    expected_mixed = 3.0 / (0.25 / 2.0 + 0.25 / 8.0)
    @test internal_face_conductance(3.0, 0.25, 0.25, 2.0, 8.0) ≈ expected_mixed rtol=1e-12 atol=0.0

    expected_asymmetric = 1.7 / (0.2 / 5.0 + 0.8 / 11.0)
    @test internal_face_conductance(1.7, 0.2, 0.8, 5.0, 11.0) ≈ expected_asymmetric rtol=1e-12 atol=0.0

    for bad in (0.0, -1.0, Inf, NaN)
        @test_throws ContractError internal_face_conductance(bad, 1.0, 1.0, 1.0, 1.0)
        @test_throws ContractError internal_face_conductance(1.0, bad, 1.0, 1.0, 1.0)
        @test_throws ContractError internal_face_conductance(1.0, 1.0, bad, 1.0, 1.0)
        @test_throws ContractError internal_face_conductance(1.0, 1.0, 1.0, bad, 1.0)
        @test_throws ContractError internal_face_conductance(1.0, 1.0, 1.0, 1.0, bad)
    end
end

@testset "boundary heat rates and unique six-face aggregation" begin
    sides = (:xminus, :xplus, :yminus, :yplus, :zminus, :zplus)
    faces = [BoundaryFace(side, (i, 2, 3), 2.0, 0.25) for (i, side) in enumerate(sides)]

    dirichlet = DirichletBoundary(300.0, 4.0)
    neumann = NeumannBoundary(-3.0)
    robin = RobinBoundary(5.0, 290.0)
    for face in faces
        @test boundary_heat_rate(dirichlet, face, 310.0) == 40.0
        @test boundary_heat_rate(neumann, face, 310.0) == -6.0
        @test boundary_heat_rate(robin, face, 310.0) == 200.0
    end

    rates = [BoundaryHeatRate(face, Float64(i)) for (i, face) in enumerate(faces)]
    @test aggregate_boundary_heat_rates(rates) == 21.0
    @test_throws ContractError aggregate_boundary_heat_rates(vcat(rates, rates[1:1]))
    @test_throws ContractError BoundaryFace(:invalid, (1, 1, 1), 1.0, 1.0)
end

@testset "energy balance and solver quality are fail closed" begin
    balance = energy_balance(10.0, [-2.0, 12.0])
    @test balance.heat_in_W == 12.0
    @test balance.heat_out_W == 12.0
    @test balance.relative_imbalance == 0.0

    imbalanced = energy_balance(10.0, [9.0])
    @test imbalanced.relative_imbalance ≈ 0.1

    draft = NumericalPolicy("numerical-vv-v1", "approval-001", 1e-12, 1e-10, 1e-6, 1e-4, false)
    record = ApprovalRecord("approval-001", "numerical-vv-v1", policy_content_hash(draft), true)
    policy = approve_policy(draft, record)

    pass = assess_solve_quality(true, 1e-7, balance, policy, record)
    @test pass.status == PASS
    @test isempty(pass.reasons)
    @test pass.policy_id == "numerical-vv-v1"

    @test assess_solve_quality(false, 1e-7, balance, policy, record).status == FAIL
    @test assess_solve_quality(true, 1e-5, balance, policy, record).status == FAIL
    @test assess_solve_quality(true, 1e-7, imbalanced, policy, record).status == FAIL
    @test_throws ContractError assess_solve_quality(true, 1e-7, balance, draft, record)
    forged = NumericalPolicy("numerical-vv-v1", "approval-001", 1e-12, 1e-10, 1e-6, 1e-4, true)
    wrong_record = ApprovalRecord("approval-001", "numerical-vv-v1", repeat("0", 64), true)
    @test_throws ContractError assess_solve_quality(true, 1e-7, balance, forged, wrong_record)
    @test_throws ContractError energy_balance(-1.0, [1.0])
end
