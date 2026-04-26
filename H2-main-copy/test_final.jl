using Test
include("src/modelA.jl")
using .modelA

@testset "ModelBuilder: Final Integration and Identity" begin
    nxy = 240
    # Original model build call
    ID = model_test(nxy)
    
    # Basic health checks
    @test size(ID) == (242, 242, 33)
    @test count(ID .== 1) == 16 * 3 * 201 # Approx TSV cells (Check original logic)
    # count(ID .== 1) should be 16 * 3 * (number of Z cells per TSV)
    
    # Specific landmark checks
    # (0,0,0) offset should be Resin (ID=6)
    @test ID[1,1,1] == 6
    
    # Center cells at Silicon layer should be Silicon (ID=2)
    # Silicon1 starts at zm[3], which is Z[7] approx.
    @test ID[121, 121, 10] == 2
    
    println("ModelBuilder test passed basic validation.")
end
