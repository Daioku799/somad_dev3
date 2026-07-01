
include("SimpleGDS.jl")
using .SimpleGDS

function create_circle_poly(center_x, center_y, radius, num_points=32)
    poly = SimpleGDS.Point[]
    for i in 0:num_points-1
        theta = 2 * π * i / num_points
        x = center_x + radius * cos(theta)
        y = center_y + radius * sin(theta)
        push!(poly, SimpleGDS.Point(round(Int, x), round(Int, y)))
    end
    push!(poly, poly[1])
    return poly
end

function create_standard_chip(filename, chip_name)
    lib = SimpleGDS.GdsLibrary(chip_name)
    cell = SimpleGDS.GdsStructure("TOP")

    # Layer 1: Silicon (10mm x 10mm -> 1000um x 1000um)
    # Domain is 1.2mm. Chip is 1.0mm centered (100 to 1100)
    silicon_poly = SimpleGDS.Boundary(1, 0, [
        SimpleGDS.Point(100, 100), SimpleGDS.Point(1100, 100), 
        SimpleGDS.Point(1100, 1100), SimpleGDS.Point(100, 1100), 
        SimpleGDS.Point(100, 100)
    ])
    SimpleGDS.add_element(cell, silicon_poly)

    # Layer 2: PowerGrid 
    # Original model used 4 separate sources defined by:
    # x,y in [0.3e-3, 0.7e-3] -> [300, 700] um
    # size lx=0.2mm (200um), ly=0.2mm (200um)
    # So 4 rects: (300,300), (700,300), (300,700), (700,700)
    
    pg_origins = [(300, 300), (700, 300), (300, 700), (700, 700)]
    for (px, py) in pg_origins
        pg_poly = SimpleGDS.Boundary(2, 0, [
            SimpleGDS.Point(px, py), SimpleGDS.Point(px+200, py), 
            SimpleGDS.Point(px+200, py+200), SimpleGDS.Point(px, py+200), 
            SimpleGDS.Point(px, py)
        ])
        SimpleGDS.add_element(cell, pg_poly)
    end

    # Layer 3: TSVs (Remvoed for Optimization Framework)
    # tsv_radius = 20
    # coords = [300, 500, 700, 900]
    # for x in coords, y in coords
    #     tsv_points = create_circle_poly(x, y, tsv_radius, 32)
    #     tsv_poly = SimpleGDS.Boundary(3, 0, tsv_points)
    #     SimpleGDS.add_element(cell, tsv_poly)
    # end

    SimpleGDS.add_structure(lib, cell)
    SimpleGDS.save(filename, lib)
    println("Generated $filename")
end

# Generate 3 identical chips
create_standard_chip("org_chip1.gds", "ORG_CHIP1")
create_standard_chip("org_chip2.gds", "ORG_CHIP2")
create_standard_chip("org_chip3.gds", "ORG_CHIP3")
