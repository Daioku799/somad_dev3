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

@testset "PODEngine Snapshot Loader Test" begin
    using JLD2
    mktempdir() do tmpdir
        JLD2.jldopen(joinpath(tmpdir, "snap1.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_1", "mu" => [0.1, 0.2])
            file["z_centers"] = [0.05, 0.15]
        end
        
        JLD2.jldopen(joinpath(tmpdir, "snap2.jld2"), "w") do file
            file["temperature"] = reshape(collect(19.0:36.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_2", "mu" => [0.3, 0.4])
            file["z_centers"] = [0.05, 0.15]
        end
        
        X, snapshot_ids, mu_vectors, grid_info = load_snapshot_matrix(tmpdir)
        
        @test size(X) == (18, 2)
        @test X[:, 1] == collect(1.0:18.0)
        @test X[:, 2] == collect(19.0:36.0)
        @test snapshot_ids == ["snap_1", "snap_2"]
        @test size(mu_vectors) == (2, 2)
        @test mu_vectors[:, 1] == [0.1, 0.2]
        @test mu_vectors[:, 2] == [0.3, 0.4]
        @test grid_info["nx"] == 3
        @test grid_info["ny"] == 3
        @test grid_info["nz"] == 2
        @test grid_info["z_centers"] == [0.05, 0.15]
    end

    mktempdir() do tmpdir
        JLD2.jldopen(joinpath(tmpdir, "snap1.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 3
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_1", "mu" => [0.1, 0.2])
        end
        
        JLD2.jldopen(joinpath(tmpdir, "snap2.jld2"), "w") do file
            file["temperature"] = reshape(collect(1.0:18.0), 3, 3, 2)
            file["nx"] = 4 # Mismatched nx
            file["ny"] = 3
            file["nz"] = 2
            file["metadata"] = Dict("snapshot_id" => "snap_2", "mu" => [0.3, 0.4])
        end
        
        @test_throws ErrorException load_snapshot_matrix(tmpdir)
    end
end
