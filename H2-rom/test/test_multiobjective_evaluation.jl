using Test

include(joinpath(@__DIR__, "..", "..", "H2-main-ext", "src", "ResearchContracts", "ResearchContracts.jl"))
include(joinpath(@__DIR__, "..", "..", "H2-main-ext", "src", "ThermalOperators", "ThermalOperators.jl"))
include(joinpath(@__DIR__, "..", "src", "MultiobjectiveEvaluation", "MultiobjectiveEvaluation.jl"))
using .ResearchContracts
using .ThermalOperators
using .MultiobjectiveEvaluation

function physics_contract(; conductivities=(4.0, 4.0))
    metadata = PhysicsMetadata(
        "bc-test", "heat-test", "materials-test", "geometry-test", 1.0,
        40e-6, 80e-6, (240, 240, 30), "row-major-4x4-v1",
    )
    return PhysicsContract(
        "physics-test", content_hash(metadata), repeat("a", 64), repeat("b", 64),
        "row-major-4x4-v1", 40e-6, 80e-6, (UInt8(2), UInt8(7)),
        conductivities, metadata, UnitContract(),
    )
end

function geometry(x_faces, y_faces, z_faces;
                  ranges=(1:length(x_faces)-1, 1:length(y_faces)-1, 1:length(z_faces)-1))
    signature = content_id("grid", (
        x_faces=Float64.(x_faces), y_faces=Float64.(y_faces), z_faces=Float64.(z_faces),
        physical_ranges=ranges,
    ))
    return GridGeometry3D(x_faces, y_faces, z_faces, ranges, signature)
end

function field_bundle(temperature, material_id, conductivity, geom;
                      counts=ntuple(i -> i == 1 ? 9 : 0, 16),
                      physics=physics_contract(), case_id="case-1",
                      objective_definition_id="tmax-gmax-v1")
    layout_signature = content_id("layout", (
        counts=counts,
        tsv_diameter_m=physics.tsv_diameter_m,
        min_pitch_m=physics.min_pitch_m,
        rule_version=physics.layout_rule_version,
    ))
    identity = FieldIdentity(
        case_id,
        layout_signature,
        geom.grid_signature,
        content_hash(physics),
        content_id("material-field", material_id),
        content_id("conductivity-field", conductivity),
        objective_definition_id,
    )
    return FieldBundle(
        counts,
        Float64.(temperature),
        UInt8.(material_id),
        Float64.(conductivity),
        geom,
        identity,
        physics,
        :K,
    )
end

function center_coordinates(geom)
    return (
        (geom.x_faces[1:end-1] .+ geom.x_faces[2:end]) ./ 2,
        (geom.y_faces[1:end-1] .+ geom.y_faces[2:end]) ./ 2,
        (geom.z_faces[1:end-1] .+ geom.z_faces[2:end]) ./ 2,
    )
end

@testset "Tmax scans every physical cell and excludes ghosts" begin
    geom = geometry(0:1:5, 0:1:5, 0:1:5; ranges=(2:4, 2:4, 2:4))
    temperature = fill(300.0, 5, 5, 5)
    temperature[1, 1, 1] = 999.0
    temperature[3, 4, 2] = 410.0
    material = fill(UInt8(2), size(temperature))
    conductivity = fill(4.0, size(temperature))
    field = field_bundle(temperature, material, conductivity, geom)

    result = evaluate_tmax(field)
    @test result.value_K == 410.0
    @test result.index == CartesianIndex(3, 4, 2)
    @test result.coordinate_m == (2.5, 3.5, 1.5)
    @test result.unit == :K

    temperature[4, 3, 4] = 420.0
    updated = field_bundle(temperature, material, conductivity, geom)
    @test evaluate_tmax(updated).value_K == 420.0

    bad_temperature = copy(temperature)
    bad_temperature[3, 3, 3] = NaN
    @test_throws ContractError evaluate_tmax(field_bundle(bad_temperature, material, conductivity, geom))
end

@testset "constant and xyz-linear fields" begin
    geom = geometry(0.0:1.0:4.0, 0.0:2.0:8.0, 0.0:0.5:2.0)
    x, y, z = center_coordinates(geom)
    material = fill(UInt8(2), 4, 4, 4)
    conductivity = fill(4.0, 4, 4, 4)

    constant_field = field_bundle(fill(321.0, 4, 4, 4), material, conductivity, geom)
    constant_result = evaluate_gmax(constant_field)
    @test constant_result.value_K_per_m == 0.0
    @test constant_result.components_K_per_m == (0.0, 0.0, 0.0)

    slopes = (2.0, -3.0, 5.0)
    linear = [300.0 + slopes[1] * x[i] + slopes[2] * y[j] + slopes[3] * z[k]
              for i in eachindex(x), j in eachindex(y), k in eachindex(z)]
    linear_result = evaluate_gmax(field_bundle(linear, material, conductivity, geom))
    @test linear_result.components_K_per_m[1] ≈ slopes[1] rtol=1e-10
    @test linear_result.components_K_per_m[2] ≈ slopes[2] rtol=1e-10
    @test linear_result.components_K_per_m[3] ≈ slopes[3] rtol=1e-10
    @test linear_result.value_K_per_m ≈ sqrt(sum(abs2, slopes)) rtol=1e-10
end

@testset "nonuniform z and identical conductivity across material IDs" begin
    geom = geometry(0.0:1.0:4.0, 0.0:1.0:4.0, [0.0, 0.2, 0.7, 1.7, 3.0])
    x, _, z = center_coordinates(geom)
    temperature = [280.0 + 3.0 * x[i] + 7.0 * z[k] for i in 1:4, j in 1:4, k in 1:4]
    material = [i <= 2 ? UInt8(2) : UInt8(7) for i in 1:4, j in 1:4, k in 1:4]
    conductivity = fill(4.0, 4, 4, 4)
    result = evaluate_gmax(field_bundle(temperature, material, conductivity, geom))
    @test result.value_K_per_m ≈ sqrt(3.0^2 + 7.0^2) rtol=1e-10
    @test result.components_K_per_m[1] ≈ 3.0 rtol=1e-10
    @test result.components_K_per_m[3] ≈ 7.0 rtol=1e-10
end

@testset "two-material one-dimensional steady conduction" begin
    geom = geometry(0.0:1.0:6.0, 0.0:1.0:3.0, 0.0:1.0:3.0)
    x, _, _ = center_coordinates(geom)
    k_left, k_right = 2.0, 8.0
    heat_flux = 16.0
    interface_x = 3.0
    temperature = Array{Float64}(undef, 6, 3, 3)
    material = Array{UInt8}(undef, 6, 3, 3)
    conductivity = Array{Float64}(undef, 6, 3, 3)
    for k in 1:3, j in 1:3, i in 1:6
        if x[i] < interface_x
            material[i, j, k] = 2
            conductivity[i, j, k] = k_left
            temperature[i, j, k] = 300.0 - heat_flux / k_left * (x[i] - interface_x)
        else
            material[i, j, k] = 7
            conductivity[i, j, k] = k_right
            temperature[i, j, k] = 300.0 - heat_flux / k_right * (x[i] - interface_x)
        end
    end
    physics = physics_contract(conductivities=(k_left, k_right))
    field = field_bundle(temperature, material, conductivity, geom; physics=physics)
    result = evaluate_gmax(field)
    @test result.value_K_per_m ≈ heat_flux / k_left rtol=1e-10
    @test result.components_K_per_m[1] ≈ -heat_flux / k_left rtol=1e-10
    @test result.material_id == UInt8(2)
    left_gradient = MultiobjectiveEvaluation._axis_gradient(field, 3, 2, 2, 1)
    right_gradient = MultiobjectiveEvaluation._axis_gradient(field, 4, 2, 2, 1)
    @test left_gradient ≈ -heat_flux / k_left rtol=1e-10
    @test right_gradient ≈ -heat_flux / k_right rtol=1e-10
    @test -k_left * left_gradient ≈ -k_right * right_gradient rtol=1e-10
end

@testset "identity, geometry, material, and mask failures are explicit" begin
    geom = geometry(0.0:1.0:3.0, 0.0:1.0:3.0, 0.0:1.0:3.0)
    temperature = fill(300.0, 3, 3, 3)
    material = fill(UInt8(2), 3, 3, 3)
    conductivity = fill(4.0, 3, 3, 3)
    field = field_bundle(temperature, material, conductivity, geom)

    wrong_identity = FieldIdentity(
        field.identity.case_id, field.identity.layout_signature, "wrong-grid",
        field.identity.physics_contract_hash, field.identity.material_field_signature,
        field.identity.conductivity_field_signature, field.identity.objective_definition_id,
    )
    wrong_grid = FieldBundle(
        field.counts, field.temperature, field.material_id, field.conductivity,
        field.geometry, wrong_identity, field.physics, field.temperature_unit,
    )
    @test_throws ContractError evaluate_objectives(wrong_grid)

    wrong_k = copy(conductivity)
    wrong_k[2, 2, 2] = 5.0
    @test_throws ContractError evaluate_gmax(field_bundle(temperature, material, wrong_k, geom))

    no_target = fill(UInt8(1), 3, 3, 3)
    @test_throws ContractError evaluate_gmax(field_bundle(temperature, no_target, conductivity, geom))
    @test_throws ContractError FieldBundle(
        field.counts, field.temperature[1:2, :, :], field.material_id, field.conductivity,
        field.geometry, field.identity, field.physics, :K,
    ) |> evaluate_tmax
end

@testset "combined objective preserves counts and provenance" begin
    geom = geometry(0.0:1.0:3.0, 0.0:1.0:3.0, 0.0:1.0:3.0)
    x, y, z = center_coordinates(geom)
    temperature = [300.0 + x[i] + 2y[j] + 3z[k]
                   for i in 1:3, j in 1:3, k in 1:3]
    material = fill(UInt8(2), 3, 3, 3)
    conductivity = fill(4.0, 3, 3, 3)
    counts = ntuple(i -> i <= 4 ? 9 : 0, 16)
    field = field_bundle(temperature, material, conductivity, geom; counts=counts)
    result = evaluate_objectives(field)
    @test result.total_count == 36
    @test result.identity == field.identity
    @test result.temperature_unit == :K
    @test result.gradient_unit == :K_per_m
    @test result.gmax ≈ sqrt(14.0) rtol=1e-10
end
