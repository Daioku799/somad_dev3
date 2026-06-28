using Test
if !isdefined(Main, :SnapshotGenerator)
    include("../src/SnapshotGenerator/SnapshotGenerator.jl")
end
using .SnapshotGenerator: SnapshotManifest, SnapshotCase
using .SnapshotGenerator.Manifest: save_manifest, load_manifest, add_case!, update_case_status!

@testset "Manifest Logic Test" begin
    # Test loading from a non-existent path should return an empty manifest
    test_path = "test_manifest_temp.json"
    if isfile(test_path)
        rm(test_path)
    end
    
    manifest = load_manifest(test_path)
    @test manifest isa SnapshotManifest
    @test isempty(manifest.cases)
    
    # Add a new case
    mu_val = [0.1, 0.5, 0.9]
    new_case = add_case!(manifest, mu_val)
    @test new_case isa SnapshotCase
    @test new_case.id == 1
    @test new_case.status == "pending"
    @test new_case.mu == mu_val
    @test new_case.filepath == ""
    @test new_case.runtime == 0.0
    
    # Update case status
    update_case_status!(manifest, 1, "success"; filepath="dummy_path.jld2", runtime=12.3)
    @test manifest.cases[1].status == "success"
    @test manifest.cases[1].filepath == "dummy_path.jld2"
    @test manifest.cases[1].runtime == 12.3
    
    # Save manifest and reload it
    save_manifest(manifest, test_path)
    @test isfile(test_path)
    
    loaded = load_manifest(test_path)
    @test loaded isa SnapshotManifest
    @test length(loaded.cases) == 1
    @test loaded.cases[1].id == 1
    @test loaded.cases[1].status == "success"
    @test loaded.cases[1].mu == mu_val
    @test loaded.cases[1].filepath == "dummy_path.jld2"
    @test loaded.cases[1].runtime == 12.3
    
    # Cleanup
    rm(test_path)
end
