using Test
using Printf
include("src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

# Hardcoded constants from H2-main-original/src/modelA.jl
const pg_dpth = 0.005e-3
const zm12 = 0.6e-3
const zm11 = 0.55e-3
const zm10 = 0.5e-3
const zm9  = zm10 - pg_dpth
const zm8 = 0.4e-3
const zm7 = 0.35e-3
const zm6 = zm7 - pg_dpth
const zm5 = 0.25e-3
const zm4 = 0.2e-3
const zm3 = zm4 - pg_dpth
const zm2 = 0.1e-3
const zm1 = 0.05e-3
const zm0 = 0.0

@testset "Absolute Identity: Z-markers" begin
    config = generate_test_config()
    zm_calc = calculate_zm(config)
    
    expected_zm = [zm0, zm1, zm2, zm3, zm4, zm5, zm6, zm7, zm8, zm9, zm10, zm11, zm12]
    
    for i in 1:13
        @printf("zm[%2d]: Calculated=%.10e, Expected=%.10e, Diff=%.10e\n", 
                i-1, zm_calc[i], expected_zm[i], zm_calc[i] - expected_zm[i])
        @test zm_calc[i] == expected_zm[i]
    end
end
