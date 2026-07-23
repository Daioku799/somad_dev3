using Test
using JLD2

@testset "Legacy Run Wrapper Test" begin
    # 1. 一時ファイル用のディレクトリとパス設定
    temp_dir = mktempdir()
    id_map_path = joinpath(temp_dir, "temp_id_map.jld2")
    expected_output_path = joinpath(temp_dir, "temp_legacy_temp.jld2")

    # 2. ダミーデータの生成
    NX, NY, NZ = 4, 4, 30
    MX, MY, MZ = NX + 2, NY + 2, NZ + 2
    
    # ダミーIDマップ
    id_map = zeros(UInt8, MX, MY, MZ)
    # 物性配列
    lambda = fill(150.0, MX, MY, MZ)
    rho = fill(2330.0, MX, MY, MZ)
    cp = fill(700.0, MX, MY, MZ)
    
    # Z座標データ生成 (NZ = 30)
    Z_face = collect(range(0.0, 1.0e-3, length=NZ+1))
    dz = diff(Z_face)
    dz_grid = zeros(Float64, NZ+2)
    dz_grid[2:NZ+1] .= dz
    dz_grid[1] = dz_grid[2]
    dz_grid[NZ+2] = dz_grid[NZ+1]
    
    ZC = zeros(Float64, NZ+2)
    ZC[1] = Z_face[1]
    ZC[NZ+2] = Z_face[NZ+1]
    for k in 2:(NZ+1)
        ZC[k] = (Z_face[k] + Z_face[k-1]) * 0.5
    end
    
    Z = zeros(Float64, NZ+3)
    Z[2:NZ+2] .= Z_face
    Z[1] = 2*Z_face[1] - Z_face[2]
    Z[NZ+3] = 2*Z_face[NZ+1] - Z_face[NZ]

    # JLD2にダミーデータを書き出す
    jldsave(id_map_path; ID=id_map, lambda=lambda, rho=rho, cp=cp, Z=Z, ZC=ZC, ΔZ=dz_grid)

    # 3. 外部プロセスとしてラッパースクリプトを実行
    wrapper_script = joinpath(@__DIR__, "..", "legacy", "H2-main-original", "legacy_run_wrapper.jl")
    project_path = abspath(joinpath(@__DIR__, "..", "H2-main-ext"))
    
    # 実行
    cmd = `julia --project=$project_path $wrapper_script --id-map $id_map_path`
    
    @testset "Run Wrapper Script" begin
        # 実行前の確認
        @test isfile(wrapper_script)
        
        # 実行
        success_run = false
        try
            success_run = success(cmd)
        catch e
            println("Execution failed: ", e)
        end
        @test success_run
        
        # 出力ファイルの確認
        @test isfile(expected_output_path)
        
        # 出力された温度データの確認
        output_data = jldopen(expected_output_path, "r")
        @test haskey(output_data, "theta_legacy")
        theta_legacy = output_data["theta_legacy"]
        @test size(theta_legacy) == (MX, MY, MZ)
        @test all(theta_legacy .>= 0.0)
        close(output_data)
    end
    
    # 後片付け
    rm(temp_dir, recursive=true)
end
