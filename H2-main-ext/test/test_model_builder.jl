using Test

# 名前空間の分離
module Original
    # H2-main-original/src/modelA.jl をロード
    # 競合を避けるため、Original.modelA になる
    include("../../legacy/H2-main-original/src/modelA.jl")
end

module New
    # H2-main-ext/src/modelA.jl をロード
    # New.modelA になる
    include("../src/modelA.jl")
end

@testset "ModelBuilder - Bit-Identical Verification" begin
    nxy = 40
    nz = 30
    
    # 1. 座標系の準備 (Zの長さは 33 = nk + 3)
    # デフォルトの zm 値を新旧で揃える
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
    
    # 座標Zを生成する
    coordsys = New.modelA.ModelBuilder.Grid.generate_coordinate_system(zm)
    Z = coordsys.Z
    
    dx = 1.2e-3 / nxy
    dy = 1.2e-3 / nxy
    Δh = (dx, dy, 1.0)
    ox = (0.0, 0.0, 0.0)
    
    # 2. ID マップ配列のアロケート
    MX = MY = nxy + 2
    MZ = length(Z)
    
    ID_orig = zeros(UInt8, MX, MY, MZ)
    ID_new = zeros(UInt8, MX, MY, MZ)
    
    # 3. 充填実行
    Original.modelA.fillID!(ID_orig, ox, Δh, Z)
    New.modelA.fillID!(ID_new, ox, Δh, Z)
    
    # 4. 完全一致検証 (Bit-identical check)
    @test ID_orig == ID_new
    
    # 5. 物性値マッピングの検証
    λ_orig = zeros(Float64, MX, MY, MZ)
    ρ_orig = zeros(Float64, MX, MY, MZ)
    cp_orig = zeros(Float64, MX, MY, MZ)
    Original.modelA.setProperties!(λ_orig, ρ_orig, cp_orig, ID_orig)
    
    λ_new = zeros(Float64, MX, MY, MZ)
    ρ_new = zeros(Float64, MX, MY, MZ)
    cp_new = zeros(Float64, MX, MY, MZ)
    New.modelA.setProperties!(λ_new, ρ_new, cp_new, ID_new)
    
    @test λ_orig == λ_new
    @test ρ_orig == ρ_new
    @test cp_orig == cp_new
end
