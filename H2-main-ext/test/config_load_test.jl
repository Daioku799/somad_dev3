using Test
using JSON

module ConfigLoadTest
    using Test
    using JSON
    src_path = joinpath(@__DIR__, "../src")
    include(joinpath(src_path, "ConfigLoader/ConfigLoader.jl"))
    using .ConfigLoader
    using .ConfigLoader.Types

    export run_tests
    function run_tests()
        @testset "Config Loading Test" begin
            # Create dummy JSON files
            config_json = Dict(
                "materials" => Dict(
                    "Copper" => Dict("id" => 1, "λ" => 386.0, "ρ" => 8960.0, "C" => 385.0)
                ),
                "layers" => [
                    Dict("name" => "L$(i)", "thickness" => 1e-4, "divisions" => 1, "grading" => 1.0) for i in 1:9
                ],
                "dimensions" => Dict(
                    "h_tsv" => 1.0e-4,
                    "pg_dpth" => 5.0e-6,
                    "s_dpth" => 1.0e-4,
                    "d_ufill" => 5.0e-5,
                    "r_bump" => 3.0e-5
                ),
                "lx" => 1.2e-3,
                "ly" => 1.2e-3
            )
            
            tsv_json = Dict(
                "tsv_mode" => "density",
                "gx" => 4,
                "gy" => 4,
                "density" => fill(0.5, 16),
                "n_total_max" => 1000,
                "p_min" => 3.0e-5,
                "m_edge" => 1.5e-5,
                "tsv_radius" => 5.0e-6
            )
            
            config_path = "test_config.json"
            tsv_path = "test_tsv_config.json"
            
            open(config_path, "w") do f
                JSON.print(f, config_json)
            end
            open(tsv_path, "w") do f
                JSON.print(f, tsv_json)
            end
            
            try
                config = load_config(config_path, tsv_path)
                
                @test config.tsv.mode == :density
                @test config.tsv.gx == 4
                @test config.tsv.gy == 4
                @test length(config.tsv.density) == 16
                @test config.tsv.density[1] == 0.5
                @test config.tsv.n_total_max == 1000
                @test config.tsv.p_min == 3.0e-5
                @test config.tsv.radius == 5.0e-6
                
            finally
                rm(config_path, force=true)
                rm(tsv_path, force=true)
            end
        end
    end
end

ConfigLoadTest.run_tests()
