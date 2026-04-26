using Test
include("src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

@testset "ConfigLoader: JSON Loading and zm Calculation" begin
    config_path = "../H2-main_TSV_Opt/config.json"
    tsv_config_path = "../H2-main_TSV_Opt/tsv_config.json"
    
    # 1. Test loading
    config = load_config(config_path, tsv_config_path)
    @test config isa ModelConfig
    @test length(config.layers) == 9
    @test length(config.materials) == 7
    @test config.tsv.mode == :manual
    
    # 2. Test zm calculation
    zm = calculate_zm(config)
    @test length(zm) == 13
    @test zm[1] == 0.0
    @test zm[13] == 0.6e-3 # Assuming original thickness in json
    
    println("Successfully loaded config from JSON and calculated Z-markers.")
    for (i, val) in enumerate(zm)
        println(" zm[$(i-1)] = $val")
    end
end
