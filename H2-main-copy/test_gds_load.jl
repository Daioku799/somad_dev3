using Test
include("src/GdsMapping/GdsMapping.jl")
using .GdsMapping

@testset "GdsMapping: Load and Query" begin
    gds_path = "../H2-main_TSV_Opt/org_chip1.gds"
    
    # 1. Test loading
    # Silicon chip is usually on layer 1 in this project
    layer = load_gds_layer(gds_path, 1)
    @test layer isa GdsLayer
    @test length(layer.polygons) > 0
    
    # 2. Test point query
    # org_chip1 is a rectangle from (0.1, 0.1) to (1.1, 1.1) mm
    # Inside: (0.5, 0.5) mm
    @test is_point_in_layer(0.5e-3, 0.5e-3, layer) == true
    
    # Outside: (0.05, 0.05) mm
    @test is_point_in_layer(0.05e-3, 0.05e-3, layer) == false
    
    # Boundary: (0.1, 0.1) mm (Should be true because of >= 0.5)
    @test is_point_in_layer(0.1e-3, 0.1e-3, layer) == true

    println("Successfully loaded GDS and performed point queries.")
    println("Polygon count: ", length(layer.polygons))
    println("First polygon vertices: ", length(layer.polygons[1].vertices))
end
