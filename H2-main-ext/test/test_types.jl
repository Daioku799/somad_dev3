using Pkg
Pkg.activate("H2-main-ext")

# Include the source Types file relative to this test file.
# Note: When running the test from the workspace root (somad_dev3), 
# this path works if we do include("H2-main-ext/src/ComponentGenerator/Types.jl")
include("../src/ComponentGenerator/Types.jl")
using .Types
using Test

@testset "Types Unit Tests" begin
    @testset "Point2D Tests" begin
        p = Point2D(1.0, 2.0)
        @test p.x == 1.0
        @test p.y == 2.0
    end

    @testset "DensityCell Tests" begin
        cell = DensityCell((0.0, 2.0), (1.0, 4.0))
        @test cell.x_bounds == (0.0, 2.0)
        @test cell.y_bounds == (1.0, 4.0)
        @test cell.center == (1.0, 2.5)

        cell2 = DensityCell((0.0, 2.0), (1.0, 4.0), (1.2, 2.6))
        @test cell2.center == (1.2, 2.6)
    end

    @testset "ValidationError Tests" begin
        # ValidationErrorType Enum
        @test Types.NO_ERROR isa Types.ValidationErrorType
        @test Types.BOUNDARY_VIOLATION isa Types.ValidationErrorType
        @test Types.PITCH_VIOLATION isa Types.ValidationErrorType

        res = ValidationResult(true, Types.NO_ERROR, "Success")
        @test res.is_valid == true
        @test res.error_type == Types.NO_ERROR
        @test res.message == "Success"

        res_err = ValidationResult(false, Types.BOUNDARY_VIOLATION, "Out of boundary")
        @test res_err.is_valid == false
        @test res_err.error_type == Types.BOUNDARY_VIOLATION
        @test res_err.message == "Out of boundary"
    end

    @testset "GeometryObject and GeometryLogic Compatibility Tests" begin
        # CYLINDER
        cyl = GeometryObject(CYLINDER, (1.0, 2.0, 3.0), (0.5, 2.0), 1)
        @test cyl.type == CYLINDER
        @test cyl.pos == (1.0, 2.0, 3.0)
        @test cyl.dims == (0.5, 2.0)
        @test cyl.mat_id == 1

        # GeometryLogic compatibility helpers
        # Cylinder components: cyl_ctr, cyl_r, cyl_zmin, cyl_zmax
        # pos is (x, y, z), dims is (radius, height)
        # We assume:
        # cyl_ctr = (x, y)
        # cyl_r = radius
        # cyl_zmin = z - height/2
        # cyl_zmax = z + height/2
        ctr, r, zmin, zmax = get_cylinder_params(cyl)
        @test ctr == (1.0, 2.0)
        @test r == 0.5
        @test zmin == 2.0  # 3.0 - 2.0/2 = 2.0
        @test zmax == 4.0  # 3.0 + 2.0/2 = 4.0

        # SPHERE
        sph = GeometryObject(SPHERE, (1.0, 2.0, 3.0), (0.8,), 2)
        # Sphere components: center, radius
        # pos is (x, y, z), dims is (radius,)
        center, radius = get_sphere_params(sph)
        @test center == (1.0, 2.0, 3.0)
        @test radius == 0.8

        # BOX
        box = GeometryObject(BOX, (2.0, 3.0, 4.0), (2.0, 4.0, 6.0), 3)
        # Box components: a1, a2 (diagonal points)
        # pos is (x, y, z) center, dims is (lx, ly, lz) sizes.
        # a1 = (x - lx/2, y - ly/2, z - lz/2)
        # a2 = (x + lx/2, y + ly/2, z + lz/2)
        a1, a2 = get_box_params(box)
        @test a1 == (1.0, 1.0, 1.0)
        @test a2 == (3.0, 5.0, 7.0)
    end
end
