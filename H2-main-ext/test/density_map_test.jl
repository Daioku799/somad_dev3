using Test

module DensityMapTest
    using Test
    src_path = joinpath(@__DIR__, "../src")
    include(joinpath(src_path, "ConfigLoader/ConfigLoader.jl"))
    
    # We need to make ConfigLoader available in the parent scope for .. to work
    # Or just include TSVCoordinateGenerator inside a module that has ConfigLoader
    
    module Inner
        using Test
        using ..ConfigLoader
        using ..ConfigLoader.Types
        
        # Now include TSVCoordinateGenerator here
        # But TSVCoordinateGenerator itself is a module
        # So it will be Inner.TSVCoordinateGenerator
        include(joinpath(@__DIR__, "../src/ModelBuilder/TSVCoordinateGenerator.jl"))
        using .TSVCoordinateGenerator

        export run_tests
        function run_tests()
            @testset "Density Map Expansion Test" begin
                # lx=1.2e-3, ly=1.2e-3
                # 4x4 density map
                # All densities 0.5
                
                materials = [Material(1, "Copper", 386.0, 8960.0, 385.0)]
                layers = [Layer("L$(i)", 1e-4, 1, 1.0) for i in 1:9]
                
                gx, gy = 4, 4
                density = fill(0.5, gx * gy)
                radius = 5.0e-6
                height = 1.0e-4
                n_total_max = 2000
                p_min = 3.0e-5
                m_edge = 1.5e-5 # max(5e-6, 3e-5/2) = 1.5e-5
                
                tsv = TSVConfig(:density, [], radius, height, gx, gy, density, n_total_max, p_min, m_edge)
                
                config = ModelConfig(
                    materials,
                    layers,
                    tsv,
                    1.2e-3, # lx
                    1.2e-3, # ly
                    5e-6, # pg_dpth
                    1e-4, # s_dpth
                    5e-5, # d_ufill
                    3e-5 # r_bump
                )
                
                coords = generate_tsv_coordinates(config)
                
                # Each cell is 300um x 300um
                # nx_cell = floor((300 - 2*15)/30) + 1 = floor(270/30) + 1 = 9 + 1 = 10
                # ny_cell = floor((300 - 2*15)/30) + 1 = 10
                # n_max_cell = 100
                # density 0.5 -> 50 TSVs per cell
                # 16 cells * 50 = 800 TSVs total
                
                @test length(coords) == 800
                
                # Check boundaries
                for (x, y) in coords
                    @test 0.0 <= x <= 1.2e-3
                    @test 0.0 <= y <= 1.2e-3
                end
                
                # Check minimum pitch
                # For 800 points, O(N^2) is 640,000 checks, should be fine.
                for i in 1:min(length(coords), 100) # Check first 100 points against all for speed
                    for j in i+1:length(coords)
                        dist = sqrt((coords[i][1] - coords[j][1])^2 + (coords[i][2] - coords[j][2])^2)
                        @test dist >= p_min - 1e-12
                    end
                end
            end
        end
    end
    using .Inner
    Inner.run_tests()
end
