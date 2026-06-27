using Pkg
Pkg.activate("H2-main-ext")

using Test
include("../src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

include("../src/ComponentGenerator/ComponentGenerator.jl")
using .ComponentGenerator
using .ComponentGenerator.Types
using .ComponentGenerator.Validator

@testset "Validator Unit Tests" begin
    # Helper to construct ModelConfig for testing
    function make_test_config(; lx=1.0e-3, ly=1.0e-3, radius=0.02e-3, p_min=0.1e-3)
        mfg = ManufacturingConfig(
            2 * radius, # d_tsv
            p_min,      # p_min
            1.0,        # ar_min
            10.0        # ar_max
        )
        tsv = TSVConfig(
            :manual,
            Tuple{Float64, Float64}[], # coords
            radius,     # radius
            0.1e-3,     # height
            nothing,    # density
            mfg,
            nothing     # ga
        )
        return ModelConfig(
            Material[], # materials
            Layer[],    # layers
            tsv,
            lx,
            ly,
            5.0e-6,     # pg_dpth
            0.0001,     # s_dpth
            5.0e-5,     # d_ufill
            3.0e-5,     # r_bump
            false,      # snapshot_enabled
            "data/work",# snapshot_dir
            nothing,    # fixed_silicon_lambda
            1e-6,       # epsilon
            10000       # max_iter
        )
    end

    @testset "Boundary violation tests" begin
        config = make_test_config(lx=1.0e-3, ly=1.0e-3, radius=0.02e-3)
        # Valid coordinates
        valid_coords = [Point2D(0.5e-3, 0.5e-3)]
        res = validate_physical_constraints(valid_coords, config)
        @test res.is_valid == true
        @test res.error_type == Types.NO_ERROR

        # Boundary violation (left: x < radius)
        coords_left = [Point2D(0.019e-3, 0.5e-3)]
        res_left = validate_physical_constraints(coords_left, config)
        @test res_left.is_valid == false
        @test res_left.error_type == Types.BOUNDARY_VIOLATION

        # Boundary violation (right: x > lx - radius)
        coords_right = [Point2D(0.981e-3, 0.5e-3)]
        res_right = validate_physical_constraints(coords_right, config)
        @test res_right.is_valid == false
        @test res_right.error_type == Types.BOUNDARY_VIOLATION

        # Boundary violation (bottom: y < radius)
        coords_bottom = [Point2D(0.5e-3, 0.019e-3)]
        res_bottom = validate_physical_constraints(coords_bottom, config)
        @test res_bottom.is_valid == false
        @test res_bottom.error_type == Types.BOUNDARY_VIOLATION

        # Boundary violation (top: y > ly - radius)
        coords_top = [Point2D(0.5e-3, 0.981e-3)]
        res_top = validate_physical_constraints(coords_top, config)
        @test res_top.is_valid == false
        @test res_top.error_type == Types.BOUNDARY_VIOLATION
    end

    @testset "Pitch violation tests" begin
        config = make_test_config(radius=0.02e-3, p_min=0.1e-3)
        # Pitch is below p_min (0.099998e-3 < 0.1e-3 - 1e-9)
        coords_violating = [
            Point2D(0.5e-3, 0.5e-3),
            Point2D(0.5e-3, 0.599998e-3)
        ]
        res = validate_physical_constraints(coords_violating, config)
        @test res.is_valid == false
        @test res.error_type == Types.PITCH_VIOLATION

        # Pitch is within tolerance (0.1e-3 - 0.5e-9 >= 0.1e-3 - 1e-9)
        coords_tol = [
            Point2D(0.5e-3, 0.5e-3),
            Point2D(0.5e-3, 0.5999999995e-3)
        ]
        res_tol = validate_physical_constraints(coords_tol, config)
        @test res_tol.is_valid == true
    end
end
