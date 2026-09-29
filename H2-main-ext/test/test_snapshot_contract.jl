using Test
using JLD2

include(joinpath(@__DIR__, "..", "src", "ResearchContracts", "ResearchContracts.jl"))
include(joinpath(@__DIR__, "..", "src", "ThermalOperators", "ThermalOperators.jl"))
include(joinpath(@__DIR__, "..", "src", "SnapshotContract", "SnapshotContract.jl"))
using .ResearchContracts
using .ThermalOperators
using .SnapshotContract

function snapshot_physics()
    metadata = PhysicsMetadata(
        "bc-test", "heat-test", "materials-test", "geometry-test", 1.0,
        40e-6, 80e-6, (240, 240, 30), "row-major-4x4-v1",
    )
    return PhysicsContract(
        "physics-test", content_hash(metadata), repeat("a", 64), repeat("b", 64),
        "row-major-4x4-v1", 40e-6, 80e-6, (UInt8(2), UInt8(7)),
        (4.0, 4.0), metadata, UnitContract(),
    )
end

function approved_quality()
    draft = NumericalPolicy("numerical-vv-v1", "approval-001", 1e-12, 1e-10, 1e-6, 1e-4, false)
    record = ApprovalRecord("approval-001", "numerical-vv-v1", policy_content_hash(draft), true)
    policy = approve_policy(draft, record)
    balance = energy_balance(10.0, [10.0])
    quality = assess_solve_quality(true, 1e-7, balance, policy, record)
    return quality, policy, record
end

function valid_snapshot()
    physics = snapshot_physics()
    faces = [0.0, 1.0, 2.0, 3.0]
    ranges = (1:3, 1:3, 1:3)
    grid_signature = content_id("grid", (
        x_faces=faces, y_faces=faces, z_faces=faces, physical_ranges=ranges,
    ))
    geometry = GridGeometry3D(faces, faces, faces, ranges, grid_signature)
    counts = ntuple(i -> i == 1 ? 9 : 0, 16)
    layout_signature = content_id("layout", (
        counts=counts, tsv_diameter_m=physics.tsv_diameter_m,
        min_pitch_m=physics.min_pitch_m, rule_version=physics.layout_rule_version,
    ))
    temperature = reshape(collect(300.0:326.0), 3, 3, 3)
    material = fill(UInt8(2), 3, 3, 3)
    conductivity = fill(4.0, 3, 3, 3)
    quality, policy, record = approved_quality()
    return build_snapshot(
        counts,
        temperature,
        material,
        conductivity,
        geometry,
        physics,
        "case-1",
        layout_signature,
        quality,
        policy,
        record;
        run_id="run-1",
    )
end

@testset "verified snapshot round trip and immutable path" begin
    snapshot = valid_snapshot()
    @test validate_snapshot(snapshot) === snapshot
    @test snapshot.envelope.quality == VERIFIED
    @test startswith(snapshot.envelope.artifact_id, "snapshot:sha256:")
    @test validate_snapshot_for_dataset(snapshot) === snapshot

    mktempdir() do directory
        path = joinpath(directory, "snapshot.jld2")
        @test save_snapshot(path, snapshot) == path
        loaded = load_snapshot(path)
        @test loaded.envelope == snapshot.envelope
        @test loaded.identity == snapshot.identity
        @test loaded.temperature == snapshot.temperature
        @test loaded.material_id == snapshot.material_id
        @test loaded.conductivity == snapshot.conductivity
        @test loaded.geometry.grid_signature == snapshot.geometry.grid_signature
        @test_throws ContractError save_snapshot(path, snapshot)
    end
end

@testset "shape, signature, quality, and approval failures are closed" begin
    snapshot = valid_snapshot()
    bad_shape = ThermalSnapshot(
        snapshot.envelope, snapshot.counts, snapshot.temperature[1:2, :, :],
        snapshot.material_id, snapshot.conductivity, snapshot.geometry,
        snapshot.identity, snapshot.physics, snapshot.quality, snapshot.policy,
        snapshot.approval_record, snapshot.temperature_unit,
    )
    @test_throws ContractError validate_snapshot(bad_shape)

    changed_temperature = copy(snapshot.temperature)
    changed_temperature[2, 2, 2] += 1.0
    tampered = ThermalSnapshot(
        snapshot.envelope, snapshot.counts, changed_temperature,
        snapshot.material_id, snapshot.conductivity, snapshot.geometry,
        snapshot.identity, snapshot.physics, snapshot.quality, snapshot.policy,
        snapshot.approval_record, snapshot.temperature_unit,
    )
    @test_throws ContractError validate_snapshot(tampered)

    failed_quality = SolveQuality(
        FAIL, false, 1e-2, 1e-1, snapshot.policy.policy_id,
        ["solver did not report convergence"],
    )
    @test_throws ContractError build_snapshot(
        snapshot.counts, snapshot.temperature, snapshot.material_id,
        snapshot.conductivity, snapshot.geometry, snapshot.physics,
        snapshot.identity.case_id, snapshot.identity.layout_signature,
        failed_quality, snapshot.policy, snapshot.approval_record;
        run_id="run-failed",
    )

    legacy = ThermalSnapshot(
        ArtifactEnvelope(v"0.0.0", "snapshot", "legacy-1", LEGACY_UNVERIFIED, "legacy-run"),
        snapshot.counts, snapshot.temperature, snapshot.material_id,
        snapshot.conductivity, snapshot.geometry, snapshot.identity,
        snapshot.physics, snapshot.quality, snapshot.policy,
        snapshot.approval_record, snapshot.temperature_unit,
    )
    @test_throws ContractError validate_snapshot_for_dataset(legacy)

    mktempdir() do directory
        path = joinpath(directory, "tampered.jld2")
        JLD2.save(path, Dict("snapshot" => tampered))
        @test_throws ContractError load_snapshot(path)
    end
end
