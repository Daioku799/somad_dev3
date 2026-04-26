using Test

# Include the Types.jl file to test the structs
include("../src/ConfigLoader/Types.jl")
using .Types

@testset "ConfigLoader Types" begin
    @testset "Material" begin
        m = Material(1, "Copper", 386.0, 8960.0, 383.0)
        @test m.id == 1
        @test m.name == "Copper"
        @test m.lambda == 386.0
        @test m.rho == 8960.0
        @test m.cp == 383.0
    end

    @testset "Layer" begin
        l = Layer("Silicon", 0.0001, 10, 2.0)
        @test l.name == "Silicon"
        @test l.thickness == 0.0001
        @test l.divisions == 10
        @test l.grading == 2.0
    end

    @testset "TSVConfig" begin
        coords = [(0.3e-3, 0.3e-3), (0.5e-3, 0.5e-3)]
        tsv = TSVConfig(:manual, coords, 2.0e-5, 0.0001)
        @test tsv.mode == :manual
        @test tsv.coords == coords
        @test tsv.radius == 2.0e-5
        @test tsv.height == 0.0001
    end

    @testset "ModelConfig" begin
        materials = Dict("cu" => Material(1, "Copper", 386.0, 8960.0, 383.0))
        layers = [Layer("Silicon", 0.0001, 10, 2.0)]
        tsv = TSVConfig(:manual, [], 2.0e-5, 0.0001)
        
        config = ModelConfig(
            materials,
            layers,
            tsv,
            5.0e-5, # d_ufill
            3.0e-5, # r_bump
            0.0001, # s_dpth
            5.0e-6  # pg_dpth
        )
        
        @test config.materials["cu"].name == "Copper"
        @test length(config.layers) == 1
        @test config.d_ufill == 5.0e-5
    end
end
