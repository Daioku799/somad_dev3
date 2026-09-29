using Test

include(joinpath(@__DIR__, "..", "src", "ResearchContracts", "ResearchContracts.jl"))
using .ResearchContracts

function sample_metadata(; diameter=40e-6)
    PhysicsMetadata(
        "bc-baseline-v1",
        "heat-baseline-v1",
        "materials-baseline-v1",
        "geometry-baseline-v1",
        1.0,
        diameter,
        80e-6,
        (240, 240, 30),
        "row-major-4x4-v1",
    )
end

function sample_physics(; diameter=40e-6)
    metadata = sample_metadata(diameter=diameter)
    PhysicsContract(
        "physics-baseline-v1",
        content_hash(metadata),
        repeat("a", 64),
        repeat("b", 64),
        "row-major-4x4-v1",
        diameter,
        80e-6,
        (UInt8(2), UInt8(7)),
        (130.0, 130.0),
        metadata,
        UnitContract(),
    )
end

@testset "Research contracts: explicit physics and units" begin
    units = UnitContract()
    @test units.temperature == :K
    @test units.gradient == :K_per_m
    @test units.length == :m
    @test units.conductivity == :W_per_mK
    @test units.heat_rate == :W
    @test units.heat_flux == :W_per_m2

    physics = sample_physics()
    @test validate_physics_contract(physics) === physics
    @test physics.metadata.grid_shape == (240, 240, 30)
    @test physics.tsv_diameter_m == 40e-6
    @test physics.min_pitch_m == 80e-6

    @test_throws ContractError sample_physics(diameter=10e-6) |> validate_baseline_physics
    @test validate_baseline_physics(physics) === physics
end

@testset "Research contracts: stable content identity" begin
    a = Dict("b" => [2, 3], "a" => (x=1.0, y=:K))
    b = Dict("a" => (x=1.0, y=:K), "b" => [2, 3])
    @test content_hash(a) == content_hash(b)
    @test content_hash(a) != content_hash(Dict("a" => (x=2.0, y=:K), "b" => [2, 3]))
    @test content_hash(:K) != content_hash("K")
    @test startswith(content_id("case", a), "case:sha256:")
    @test length(content_hash(a)) == 64
    @test_throws ContractError content_hash(NaN)
end

@testset "Research contracts: approval-derived numerical policy" begin
    draft = NumericalPolicy("numerical-vv-v1", "approval-001", 1e-12, 1e-10, 1e-6, 1e-4, false)
    approved_hash = policy_content_hash(draft)
    record = ApprovalRecord("approval-001", "numerical-vv-v1", approved_hash, true)
    approved = approve_policy(draft, record)
    @test approved.approved
    @test validate_numerical_policy(approved, record) === approved

    wrong = ApprovalRecord("approval-001", "numerical-vv-v1", repeat("0", 64), true)
    @test_throws ContractError approve_policy(draft, wrong)
    @test_throws ContractError validate_numerical_policy(draft, record)
    @test_throws ContractError NumericalPolicy("bad", "approval", -1.0, 1e-10, 1e-6, 1e-4, false)
end

@testset "Research contracts: schema and legacy isolation" begin
    current = ArtifactEnvelope(CURRENT_SCHEMA_VERSION, "dataset", "dataset:sha256:" * repeat("c", 64), VERIFIED, "run-1")
    @test validate_artifact_envelope(current; expected_kind="dataset") === current

    legacy = ArtifactEnvelope(v"0.0.0", "dataset", "legacy-424", LEGACY_UNVERIFIED, "legacy-run")
    @test_throws ContractError validate_artifact_envelope(legacy; expected_kind="dataset")
    @test_throws ContractError promote_artifact(legacy, VERIFIED)
    @test_throws ContractError promote_artifact(current, VERIFIED)

    candidate = ArtifactEnvelope(CURRENT_SCHEMA_VERSION, "snapshot", "snapshot:sha256:" * repeat("d", 64), UNVERIFIED, "run-2")
    promoted = promote_artifact(candidate, VERIFIED)
    @test promoted.quality == VERIFIED
    @test candidate.quality == UNVERIFIED
end
