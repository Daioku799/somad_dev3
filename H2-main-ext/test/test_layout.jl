using Pkg
Pkg.activate("H2-main-ext")

using Test
include("../src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

include("../src/ComponentGenerator/ComponentGenerator.jl")
using .ComponentGenerator
using .ComponentGenerator.Types
using .ComponentGenerator.Layout

@testset "Layout Generation Tests" begin
    # Helper to construct TSVConfig and ModelConfig for testing
    function make_test_density_config(; lx=1.0e-3, ly=1.0e-3, gx=2, gy=2, mu=[1.0, 1.0, 1.0, 1.0], p_min=0.1e-3)
        density = DensityMapConfig(
            gx,
            gy,
            mu,
            0,    # n_min
            100,  # n_max
            1.0,  # rho_cell_max
            Tuple{Int, Int}[] # prohibited_cells
        )
        mfg = ManufacturingConfig(
            0.02e-3, # d_tsv
            p_min,   # p_min
            1.0,     # ar_min
            10.0     # ar_max
        )
        tsv = TSVConfig(
            :density,
            Tuple{Float64, Float64}[], # coords
            0.01e-3, # radius
            0.1e-3,  # height
            density,
            mfg,
            nothing  # ga
        )
        return tsv, lx, ly
    end

    @testset "get_cell_capacities" begin
        tsv, lx, ly = make_test_density_config(lx=1.0e-3, ly=1.0e-3, gx=2, gy=2, p_min=0.1e-3)
        capacities = get_cell_capacities(tsv, lx, ly)
        # Expected:
        # cell bounds: 0.5 x 0.5. g = 0.05.
        # Lx_grid = 0.5 - 2*0.05 = 0.4
        # Nx = floor(0.4 / 0.1) + 1 = 5
        # n_max = 5 * 5 = 25
        @test size(capacities) == (2, 2)
        @test all(capacities .== 25)
    end

    @testset "adjust_density_constraints" begin
        # mu = [1.0, 1.0, 1.0, 1.0], capacities = [25 25; 25 25], N_limit = 50
        mu = [1.0, 1.0, 1.0, 1.0]
        capacities = fill(25, 2, 2)
        
        # S = 100 > 50 -> should scale
        scaled_mu = adjust_density_constraints(mu, capacities, 50)
        
        # Calculate resulting sum
        n_ij = [round(Int, scaled_mu[k] * capacities[k]) for k in 1:4]
        @test sum(n_ij) <= 50
        
        # If N_limit is large enough, no scaling
        scaled_mu_noscales = adjust_density_constraints(mu, capacities, 120)
        @test scaled_mu_noscales == mu
    end

    @testset "expand_coordinates (density mode)" begin
        # Let's test with simple mu to verify coordinate selection and grid guard
        mu = [1.0, 0.4, 0.0, 0.2] # 2x2 grid
        # n_max = 25.
        # n_ij for each cell:
        # cell 1: round(1.0 * 25) = 25
        # cell 2: round(0.4 * 25) = 10
        # cell 3: round(0.0 * 25) = 0
        # cell 4: round(0.2 * 25) = 5
        tsv, lx, ly = make_test_density_config(lx=1.0e-3, ly=1.0e-3, gx=2, gy=2, mu=mu, p_min=0.1e-3)
        pts = expand_coordinates(tsv, lx, ly)
        
        # Total points should be 25 + 10 + 0 + 5 = 40
        @test length(pts) == 40
        
        # Check boundary constraint and pitch constraint of generated points
        p_min = 0.1e-3
        # Check all pair distances
        for i in 1:length(pts)
            pt_i = pts[i]
            # Check chip boundaries
            @test 0.0 <= pt_i.x <= lx
            @test 0.0 <= pt_i.y <= ly
            for j in (i+1):length(pts)
                pt_j = pts[j]
                dist = sqrt((pt_i.x - pt_j.x)^2 + (pt_i.y - pt_j.y)^2)
                @test dist >= p_min - 1e-9 # allow small float tolerance
            end
        end
        
        # Verify points distribution per cell
        # Cell 1 (x in [0, 0.5], y in [0, 0.5]): 25 pts
        # Cell 2 (x in [0.5, 1.0], y in [0, 0.5]): 10 pts
        # Cell 3 (x in [0, 0.5], y in [0.5, 1.0]): 0 pts
        # Cell 4 (x in [0.5, 1.0], y in [0.5, 1.0]): 5 pts
        cell1_count = count(p -> 0.0 <= p.x <= 0.5e-3 && 0.0 <= p.y <= 0.5e-3, pts)
        cell2_count = count(p -> 0.5e-3 <= p.x <= 1.0e-3 && 0.0 <= p.y <= 0.5e-3, pts)
        cell3_count = count(p -> 0.0 <= p.x <= 0.5e-3 && 0.5e-3 <= p.y <= 1.0e-3, pts)
        cell4_count = count(p -> 0.5e-3 <= p.x <= 1.0e-3 && 0.5e-3 <= p.y <= 1.0e-3, pts)
        
        @test cell1_count == 25
        @test cell2_count == 10
        @test cell3_count == 0
        @test cell4_count == 5
    end
end
