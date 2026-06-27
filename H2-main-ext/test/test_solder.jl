using Pkg
Pkg.activate("H2-main-ext")

using Test
include("../src/ConfigLoader/ConfigLoader.jl")
using .ConfigLoader

include("../src/ComponentGenerator/ComponentGenerator.jl")
using .ComponentGenerator
using .ComponentGenerator.Types

@testset "Solder Bump and Vertical Alignment Tests" begin
    # 1. 正常な設定での生成テスト
    config = generate_test_config()
    objects = generate_all_components(config)
    
    tsvs = filter(obj -> obj.type == CYLINDER, objects)
    bumps = filter(obj -> obj.type == SPHERE, objects)
    
    # TSVのユニーク座標数とバンプのユニーク座標数が一致することを確認
    tsv_coords = Set((obj.pos[1], obj.pos[2]) for obj in tsvs)
    bump_coords = Set((obj.pos[1], obj.pos[2]) for obj in bumps)
    
    @test length(tsv_coords) == length(bump_coords)
    @test tsv_coords == bump_coords
    
    # 各 (x, y) 座標において、TSV は 3 層、バンプは 4 層に存在することを確認 (垂直アライメント)
    zm = calculate_zm(config)
    silicon_starts = [zm[3], zm[6], zm[9]]
    dp = config.d_ufill * 0.5
    underfill_starts = [zm[2], zm[5], zm[8], zm[11]]
    
    for (x, y) in tsv_coords
        tsv_z_coords = [obj.pos[3] for obj in tsvs if obj.pos[1] == x && obj.pos[2] == y]
        @test length(tsv_z_coords) == 3
        @test sort(tsv_z_coords) ≈ sort(silicon_starts)
        
        bump_z_coords = [obj.pos[3] for obj in bumps if obj.pos[1] == x && obj.pos[2] == y]
        @test length(bump_z_coords) == 4
        @test sort(bump_z_coords) ≈ sort(underfill_starts .+ dp)
    end
    
    # 2. バンプ半径の算出公式の適用テスト (r_bump <= 0.0 のとき)
    config_formula = ModelConfig(
        config.materials,
        config.layers,
        config.tsv,
        config.lx,
        config.ly,
        config.pg_dpth,
        config.s_dpth,
        config.d_ufill,
        0.0, # r_bump = 0.0 に設定して自動計算をトリガー
        config.snapshot_enabled,
        config.snapshot_dir,
        config.fixed_silicon_lambda,
        config.epsilon,
        config.max_iter
    )
    
    objects_formula = generate_all_components(config_formula)
    bumps_formula = filter(obj -> obj.type == SPHERE, objects_formula)
    
    expected_r = max(calculate_solder_radius(config.d_ufill), config.tsv.radius)
    
    for bump in bumps_formula
        # バンプのサイズ (半径) が expected_r になっているか
        @test bump.dims[1] ≈ expected_r
    end
end
