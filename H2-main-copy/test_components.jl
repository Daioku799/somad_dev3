using Test
include("src/ComponentGenerator/ComponentGenerator.jl")
using .ComponentGenerator: generate_components, GeometryObject, CYLINDER, SPHERE
include("src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

@testset "ComponentGenerator: Stack Generation and Sync" begin
    config = generate_test_config()
    zm = calculate_zm(config)
    
    objects = generate_components(config, zm)
    
    # 1. Count verification
    # 16 TSV positions * 3 Silicon layers = 48 TSVs
    # 16 Bump positions * 4 Underfill layers = 64 Bumps
    # Total = 112
    @test length(objects) == 112
    
    # 2. Vertical Sync Check
    # Pick a coordinate from config and ensure it exists in all expected layers
    target_xy = config.tsv.coords[1]
    
    layer_counts = filter(obj -> (obj.pos[1], obj.pos[2]) == target_xy, objects)
    @test length(layer_counts) == 7 # 3 TSVs + 4 Bumps
    
    # 3. Shape Type Check
    tsvs = filter(obj -> obj.type == CYLINDER, objects)
    bumps = filter(obj -> obj.type == SPHERE, objects)
    @test length(tsvs) == 48
    @test length(bumps) == 64
    
    # 4. Dimension Check (Absolute Identity)
    @test tsvs[1].dims[1] == 2.0e-5 # r_tsv from Defaults.jl
    @test bumps[1].dims[1] == 3.0e-5 # r_bump from Defaults.jl

    println("Successfully generated 112 components with perfect vertical sync.")
end
