using Test

if !isdefined(Main, :PODEngine)
    include("../src/PODEngine/PODEngine.jl")
end
using .PODEngine

@testset "PODEngine Types Test" begin
    # Dummy fields for PODModel
    basis = [1.0 2.0; 3.0 4.0]
    singular_values = [5.0, 6.0]
    coefficients = [7.0 8.0; 9.0 10.0]
    mean_field = [11.0, 12.0]
    snapshot_ids = ["snap1", "snap2"]
    mu_vectors = [0.1 0.2; 0.3 0.4]
    metadata = Dict{String, Any}(
        "ric_threshold" => 0.999,
        "n_modes" => 2,
        "trained_snapshot_ids" => ["snap1", "snap2"],
        "grid" => Dict{String, Any}(
            "dims" => (2, 2, 1),
            "spacing" => (0.1, 0.1, 0.1),
            "physical_size" => (0.2, 0.2, 0.1)
        )
    )

    model = PODModel(
        basis,
        singular_values,
        coefficients,
        mean_field,
        snapshot_ids,
        mu_vectors,
        metadata
    )

    @test model.basis == basis
    @test model.singular_values == singular_values
    @test model.coefficients == coefficients
    @test model.mean_field == mean_field
    @test model.snapshot_ids == snapshot_ids
    @test model.mu_vectors == mu_vectors
    @test model.metadata == metadata
end
