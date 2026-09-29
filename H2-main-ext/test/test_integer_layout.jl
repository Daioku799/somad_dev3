using Test

include(joinpath(@__DIR__, "..", "src", "ResearchContracts", "ResearchContracts.jl"))
include(joinpath(@__DIR__, "..", "src", "ComponentGenerator", "IntegerLayout.jl"))
using .ResearchContracts
using .IntegerLayout

const DIAMETER = 40e-6
const PITCH = 80e-6
const LX = 1.2e-3
const LY = 1.2e-3
const MARGIN = 0.1e-3

@testset "canonical integer TSV expansion" begin
    counts = ntuple(i -> i == 1 ? 9 : (i == 2 ? 3 : 0), 16)
    spec = IntegerLayoutSpec(counts, DIAMETER, PITCH, "row-major-4x4-v1")
    first_layout = expand_integer_counts(spec, LX, LY; margin_m=MARGIN, required_total=12)
    second_layout = expand_integer_counts(spec, LX, LY; margin_m=MARGIN, required_total=12)

    @test length(first_layout.coordinates_m) == 12
    @test first_layout.coordinates_m == second_layout.coordinates_m
    @test first_layout.layout_signature == second_layout.layout_signature
    @test first_layout.physical_signature == second_layout.physical_signature
    @test startswith(first_layout.layout_signature, "layout:sha256:")
    @test startswith(first_layout.physical_signature, "physical-layout:sha256:")

    # The first selected point in a cell is its center. Equal-distance ties use
    # (distance2, y_index, x_index), so the next point is the lower-y neighbor.
    x_center = MARGIN + (LX - 2MARGIN) / 8
    y_center = MARGIN + (LY - 2MARGIN) / 8
    @test first_layout.coordinates_m[1][1] ≈ x_center atol=eps(LX)
    @test first_layout.coordinates_m[1][2] ≈ y_center atol=eps(LY)
    @test first_layout.coordinates_m[2][1] ≈ x_center atol=eps(LX)
    @test first_layout.coordinates_m[2][2] ≈ y_center - PITCH atol=eps(LY)

    radius = DIAMETER / 2
    for (x, y) in first_layout.coordinates_m
        @test MARGIN + radius <= x <= LX - MARGIN - radius
        @test MARGIN + radius <= y <= LY - MARGIN - radius
    end
    for i in eachindex(first_layout.coordinates_m), j in (i + 1):length(first_layout.coordinates_m)
        dx = first_layout.coordinates_m[i][1] - first_layout.coordinates_m[j][1]
        dy = first_layout.coordinates_m[i][2] - first_layout.coordinates_m[j][2]
        @test hypot(dx, dy) >= PITCH - 10eps(PITCH)
    end
end

@testset "fixed and variable totals, bounds, and signatures" begin
    fixed_counts = ntuple(i -> i <= 4 ? 9 : 0, 16)
    fixed = IntegerLayoutSpec(fixed_counts, DIAMETER, PITCH, "row-major-4x4-v1")
    @test length(expand_integer_counts(fixed, LX, LY; required_total=36).coordinates_m) == 36

    variable_counts = ntuple(i -> i <= 6 ? 9 : (i == 7 ? 6 : 0), 16)
    variable = IntegerLayoutSpec(variable_counts, DIAMETER, PITCH, "row-major-4x4-v1")
    @test length(expand_integer_counts(variable, LX, LY; allowed_total=36:60).coordinates_m) == 60
    @test_throws ContractError expand_integer_counts(variable, LX, LY; allowed_total=36:59)
    @test_throws ContractError expand_integer_counts(fixed, LX, LY; required_total=48)

    changed = IntegerLayoutSpec(ntuple(i -> i == 1 ? 8 : (i == 2 ? 1 : 0), 16), DIAMETER, PITCH, "row-major-4x4-v1")
    a = expand_integer_counts(IntegerLayoutSpec(ntuple(i -> i == 1 ? 9 : 0, 16), DIAMETER, PITCH, "row-major-4x4-v1"), LX, LY)
    b = expand_integer_counts(changed, LX, LY)
    @test a.layout_signature != b.layout_signature
    @test a.physical_signature != b.physical_signature

    @test_throws ContractError IntegerLayoutSpec(ntuple(i -> i == 16 ? 10 : 0, 16), DIAMETER, PITCH, "row-major-4x4-v1")
    @test_throws ContractError IntegerLayoutSpec(ntuple(_ -> 0, 16), DIAMETER, 0.0, "row-major-4x4-v1")
    @test_throws ContractError expand_integer_counts(fixed, 0.4e-3, 0.4e-3; margin_m=MARGIN)
end
