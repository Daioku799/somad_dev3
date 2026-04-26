using Test
include("src/modelA.jl")
using .modelA
include("src/ValidationPlot/ValidationPlot.jl")
using .ValidationPlot

@testset "ValidationPlot: Integrated Visualization" begin
    nxy = 240
    config = modelA.ModelBuilder.ConfigLoader.generate_test_config()
    zm = modelA.ModelBuilder.ConfigLoader.calculate_zm(config)
    
    # 1. Build Model
    ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, nxy)
    
    # 2. Generate Plots
    output_dir = "validation_results"
    plot_model_validation(ID, λ, coordsys, config, zm; output_dir=output_dir)
    
    # 3. Check for existence of files
    @test isfile(joinpath(output_dir, "validation_yz.png"))
    @test isfile(joinpath(output_dir, "validation_xy_chip1.png"))
    
    println("Validation plots generated successfully in $output_dir/")
end
