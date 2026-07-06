using Test
using JLD2

if !isdefined(Main, :q3d)
    include("../src/heat3ds.jl")
end

@testset "heat3ds-ext tests" begin
    # テスト用パラメータ
    NX, NY, NZ = 10, 10, 30 # 小さいグリッドで高速実行
    solver = "cg"
    smoother = "gs"
    
    # 1. mu を指定した保存テスト
    snapshot_file = "test_snapshot_heat3ds_ext.jld2"
    if isfile(snapshot_file)
        rm(snapshot_file)
    end
    
    # テスト開始前に設定ファイルが元々存在していたか記録
    config_existed = isfile("config.json")
    tsv_config_existed = isfile("tsv_config.json")
    
    # 存在しない場合のみコピー
    if !config_existed
        cp("./H2-main-ext/config.json", "config.json", force=true)
    end
    if !tsv_config_existed
        cp("./H2-main-ext/tsv_config.json", "tsv_config.json", force=true)
    end
    
    mu_test = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    try
        # シミュレーションの実行 (ヘッドレスを保証)
        ENV["GKSwstype"] = "100"
        
        q3d(NX, NY, NZ, solver, smoother;
            epsilon=1.0e-3, par="sequential", is_steady=true,
            snapshot_path=snapshot_file, mu=mu_test)
            
        @test isfile(snapshot_file) == true
        
        # JLD2 のロードと確認
        data = JLD2.load(snapshot_file)
        @test haskey(data, "theta")
        @test haskey(data, "id_map")
        @test haskey(data, "mu")
        @test data["mu"] == mu_test
        @test data["nx"] == NX
        @test data["ny"] == NY
        @test data["nz"] == NZ
        
    finally
        if isfile(snapshot_file)
            rm(snapshot_file)
        end
        if !config_existed && isfile("config.json")
            rm("config.json")
        end
        if !tsv_config_existed && isfile("tsv_config.json")
            rm("tsv_config.json")
        end
    end
    
    # テスト開始前に設定ファイルが元々存在していたか記録
    config_existed_2 = isfile("config.json")
    tsv_config_existed_2 = isfile("tsv_config.json")
    
    if !config_existed_2
        cp("./H2-main-ext/config.json", "config.json", force=true)
    end
    if !tsv_config_existed_2
        cp("./H2-main-ext/tsv_config.json", "tsv_config.json", force=true)
    end
    
    try
        # 2. snapshot_path 未指定時のテスト (ファイルが作成されない)
        q3d(NX, NY, NZ, solver, smoother;
            epsilon=1.0e-3, par="sequential", is_steady=true)
        @test isfile(snapshot_file) == false
        
        # 3. 不正なパスでの例外安全性テスト (例外でクラッシュせず、正常終了する)
        invalid_path = "/nonexistent_dir/invalid_snapshot.jld2"
        @test_logs (:warn, r"Failed to save snapshot") q3d(NX, NY, NZ, solver, smoother;
            epsilon=1.0e-3, par="sequential", is_steady=true,
            snapshot_path=invalid_path, mu=mu_test)
    finally
        if !config_existed_2 && isfile("config.json")
            rm("config.json")
        end
        if !tsv_config_existed_2 && isfile("tsv_config.json")
            rm("tsv_config.json")
        end
    end
end
