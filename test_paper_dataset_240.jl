#!/usr/bin/env julia

using JLD2
using JSON
using Statistics
using Test

include("run_paper_dataset_240.jl")

@testset "paper_240_v1 data contract" begin
    mktempdir() do directory
        manifest, manifest_path = load_or_prepare(directory)
        @test isfile(manifest_path)
        @test length(manifest["cases"]) == 100
        @test length(unique(case["layout_signature_sha256"] for case in manifest["cases"])) == 100

        expected = Dict(
            "train" => (80, 40, 72.725, 112),
            "validation" => (10, 55, 71.5, 87),
            "test" => (10, 63, 72.1, 89),
        )
        for (split, target) in expected
            counts = [case["tsv_count"] for case in manifest["cases"] if case["split"] == split]
            @test (length(counts), minimum(counts), mean(counts), maximum(counts)) == target
        end
        @test [manifest["cases"][i]["tsv_count"] for i in 1:3] == [112, 40, 104]
        @test all(case -> case["minimum_pitch_m"] + 1e-12 >= MIN_PITCH, manifest["cases"])

        reloaded, _ = load_or_prepare(directory)
        @test reloaded["cases"][1]["layout_signature_sha256"] ==
            manifest["cases"][1]["layout_signature_sha256"]
    end
end

@testset "snapshot validation contract" begin
    mktempdir() do directory
        nxy = 60
        shape = (nxy + 2, nxy + 2, NZ + 2)
        snapshot = joinpath(directory, "snapshot.jld2")
        log = joinpath(directory, "output.log")
        JLD2.save(snapshot, Dict(
            "theta" => fill(300.0, shape),
            "id_map" => zeros(UInt8, shape),
            "lambda" => ones(shape),
            "z_centers" => vcat(EXPECTED_Z_FACES[1],
                (EXPECTED_Z_FACES[1:(end - 1)] .+ EXPECTED_Z_FACES[2:end]) ./ 2,
                EXPECTED_Z_FACES[end]),
            "z_faces" => EXPECTED_Z_FACES,
            "nx" => nxy,
            "ny" => nxy,
            "nz" => NZ,
        ))
        open(log, "w") do io
            println(io, "Converged at 42 iterations")
        end
        validation = validate_snapshot(snapshot, log, nxy)
        @test validation.valid
        @test validation.shape == collect(shape)
        @test length(validation.snapshot_sha256) == 64
    end
end
