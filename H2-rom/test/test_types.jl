using Test

if !isdefined(Main, :SnapshotGenerator)
    include("../src/SnapshotGenerator/SnapshotGenerator.jl")
end
using .SnapshotGenerator: SnapshotManifest, SnapshotCase

@testset "Snapshot Types Test" begin
    # SnapshotCase のインスタンス化テスト
    # フィールド: id (Int), status (String), mu (Vector{Float64}), filepath (String), runtime (Float64)
    case = SnapshotCase(
        1,
        "success",
        [0.1, 0.2, 0.3],
        "data/raw/snapshot_1.jld2",
        15.5
    )
    
    @test case.id == 1
    @test case.status == "success"
    @test case.mu == [0.1, 0.2, 0.3]
    @test case.filepath == "data/raw/snapshot_1.jld2"
    @test case.runtime == 15.5

    # SnapshotManifest のインスタンス化テスト
    # フィールド: created_at (String), param_range (Dict), constraints (Dict), cases (Vector{SnapshotCase})
    manifest = SnapshotManifest(
        "2026-06-27T17:00:00",
        Dict("min" => 0.0, "max" => 1.0),
        Dict("n_limit" => 16),
        [case]
    )

    @test manifest.created_at == "2026-06-27T17:00:00"
    @test manifest.param_range["min"] == 0.0
    @test manifest.constraints["n_limit"] == 16
    @test length(manifest.cases) == 1
    @test manifest.cases[1].id == 1
end
