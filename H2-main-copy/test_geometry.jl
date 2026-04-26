using Test
include("src/GeometryLogic/GeometryLogic.jl")
using .GeometryLogic

@testset "GeometryLogic: Absolute Identity of Primitives" begin
    # Test rectangle inclusion (100% overlap)
    @test is_included_rect((0.0,0.0,0.0), (1.0,1.0,1.0), (0.0,0.0,0.0), (2.0,2.0,2.0)) == true
    # Test rectangle inclusion (0% overlap)
    @test is_included_rect((0.0,0.0,0.0), (1.0,1.0,1.0), (2.0,2.0,2.0), (3.0,3.0,3.0)) == false
    # Test rectangle inclusion (Exactly 50% overlap on X axis)
    @test is_included_rect((0.0,0.0,0.0), (1.0,1.0,1.0), (-0.5, 0.0, 0.0), (0.5, 1.0, 1.0)) == true
    # Test rectangle inclusion (Less than 50% overlap)
    @test is_included_rect((0.0,0.0,0.0), (1.0,1.0,1.0), (-0.6, 0.0, 0.0), (0.4, 1.0, 1.0)) == false

    # Test cylinder inclusion (samples based)
    @test is_included_cyl((0.0,0.0,0.0), (0.5,0.5,1.0), (0.0,0.0), 1.0, 0.0, 1.0) == true
    @test is_included_cyl((2.0,2.0,0.0), (3.0,3.0,1.0), (0.0,0.0), 1.0, 0.0, 1.0) == false

    # Test sphere inclusion (samples based)
    @test is_included_sph((0.0,0.0,0.0), (0.5,0.5,0.5), (0.0,0.0,0.0), 1.0) == true
    @test is_included_sph((2.0,2.0,2.0), (3.0,3.0,3.0), (0.0,0.0,0.0), 1.0) == false
end

@testset "GeometryLogic: Chip Integration (Z-overlap)" begin
    # Use types re-exported by GeometryLogic
    # We need to construct GdsLayer and GdsPolygon manually for testing
    # Since they are exported, we can access them.
    
    poly = GdsPolygon([(0.0,0.0), (1.0,0.0), (1.0,1.0), (0.0,1.0), (0.0,0.0)], BBox(0.0,0.0,1.0,1.0))
    layer = GdsLayer(1, [poly])
    
    # Cell centers at (0.5, 0.5), Z ranges
    @test is_included_chip((0.0,0.0,0.1), (1.0,1.0,0.2), layer, 0.0, 1.0) == true
    @test is_included_chip((0.0,0.0,0.1), (1.0,1.0,0.2), layer, 0.0, 0.15) == true
    @test is_included_chip((0.0,0.0,0.1), (1.0,1.0,0.2), layer, 0.3, 0.4) == false
end
