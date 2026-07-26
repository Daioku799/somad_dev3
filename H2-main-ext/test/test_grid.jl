using Test

if !isdefined(Main, :ModelBuilder)
    include("../src/ModelBuilder/ModelBuilder.jl")
end

using .ModelBuilder.Grid: generate_coordinate_system

@testset "ModelBuilder Grid Tests" begin
    # デフォルトの zm 値を準備
    pg_dpth = 0.005e-3
    zm = [
        0.0,
        0.05e-3,
        0.1e-3,
        0.2e-3 - pg_dpth,
        0.2e-3,
        0.25e-3,
        0.35e-3 - pg_dpth,
        0.35e-3,
        0.4e-3,
        0.5e-3 - pg_dpth,
        0.5e-3,
        0.55e-3,
        0.6e-3
    ]
    
    # 1. 新アーキテクチャの座標生成
    coordsys = generate_coordinate_system(zm)
    
    # 2. オリジナル z_face 期待値
    nk = 30
    p = 0.005e-3
    expected_z_face = zeros(Float64, nk+1)
    expected_z_face[1] = zm[1] # zm0
    expected_z_face[2] = zm[1] + p
    expected_z_face[3] = zm[2] - p # zm1
    expected_z_face[4] = zm[2]
    expected_z_face[5] = zm[2] + p
    expected_z_face[6] = zm[3] - p # zm2
    expected_z_face[7] = zm[3]
    expected_z_face[8] = zm[3] + p
    expected_z_face[9] = zm[4] - p # zm3
    expected_z_face[10]= zm[4]
    expected_z_face[11]= zm[5] # zm4
    expected_z_face[12]= zm[5] + p
    expected_z_face[13]= zm[6] - p # zm5
    expected_z_face[14]= zm[6]
    expected_z_face[15]= zm[6] + p
    expected_z_face[16]= zm[7] - p # zm6
    expected_z_face[17]= zm[7]
    expected_z_face[18]= zm[8] # zm7
    expected_z_face[19]= zm[8] + p
    expected_z_face[20]= zm[9] - p # zm8
    expected_z_face[21]= zm[9]
    expected_z_face[22]= zm[9] + p
    expected_z_face[23]= zm[10]- p # zm9
    expected_z_face[24]= zm[10]
    expected_z_face[25]= zm[11] # zm10
    expected_z_face[26]= zm[11] + p
    expected_z_face[27]= zm[12] - p # zm11
    expected_z_face[28]= zm[12]
    expected_z_face[29]= zm[12] + p
    expected_z_face[30]= zm[13] - p # zm12
    expected_z_face[31]= zm[13]
    
    # Z の期待値 (33個)
    expected_Z = zeros(Float64, nk+3)
    expected_Z[2:nk+2] = expected_z_face[1:nk+1]
    expected_Z[1] = 2*expected_z_face[1] - expected_z_face[2]
    expected_Z[nk+3] = 2*expected_z_face[nk+1] - expected_z_face[nk]
    
    # z_centers と dz_grid の期待値 (32個)
    mz = nk + 2
    expected_z_centers = zeros(Float64, mz)
    expected_dz_grid = zeros(Float64, mz)
    
    dz = diff(expected_z_face)
    expected_dz_grid[2:nk+1] = dz[1:nk]
    expected_dz_grid[1] = expected_dz_grid[2]
    expected_dz_grid[nk+2] = expected_dz_grid[nk+1]
    
    expected_z_centers[1] = expected_z_face[1]
    expected_z_centers[nk+2] = expected_z_face[nk+1]
    for k in 2:(nk+1)
        expected_z_centers[k] = (expected_z_face[k] + expected_z_face[k-1]) * 0.5
    end
    
    # 完全一致検証
    @test coordsys.Z == expected_Z
    @test coordsys.z_centers == expected_z_centers
    @test coordsys.dz_grid == expected_dz_grid
end
