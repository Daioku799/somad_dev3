using Test

if !isdefined(Main, :GdsMapping)
    include("../src/GdsMapping/GdsMapping.jl")
end

using .GdsMapping: load_gds_layer, is_point_in_layer, get_plot_data, GdsPolygon, GdsLayer, BBox
using .GdsMapping.Validator: validate_and_create_polygon

@testset "GdsMapping - Polygon Quality Assurance (Validator)" begin
    # 1. 未閉路ポリゴン (第一点と最終点が異なる) が自動で閉じるか
    raw1 = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    poly1 = validate_and_create_polygon(raw1)
    @test poly1 !== nothing
    @test length(poly1.vertices) == 5 # (0,0)->(1,0)->(1,1)->(0,1)->(0,0)
    @test poly1.vertices[end] == poly1.vertices[1]
    
    # 2. 重複頂点の除去 (1e-12m以下の距離にある連続頂点)
    raw2 = [(0.0, 0.0), (1e-13, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    poly2 = validate_and_create_polygon(raw2)
    @test poly2 !== nothing
    @test length(poly2.vertices) == 5 # 重複頂点 (1e-13, 0) がマージされ 5 点になる
    @test poly2.vertices[1] == (0.0, 0.0)
    @test poly2.vertices[2] == (1.0, 0.0)

    # 3. 縮退チェック (有効頂点が少なすぎる)
    raw3 = [(0.0, 0.0), (1e-15, 1e-15)]
    poly3 = validate_and_create_polygon(raw3)
    @test poly3 === nothing
end

@testset "GdsMapping - Point In Polygon Consistency" begin
    # テスト用レイヤーの定義
    raw = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    poly = validate_and_create_polygon(raw)
    layer = GdsLayer(1, [poly])
    
    # 1. 完全に内側
    @test is_point_in_layer(0.5, 0.5, layer) == true
    
    # 2. 完全に外側
    @test is_point_in_layer(2.0, 2.0, layer) == false
    
    # 3. 境界線上
    @test is_point_in_layer(0.5, 0.0, layer) == true
    
    # 4. 頂点上
    @test is_point_in_layer(0.0, 0.0, layer) == true
end

@testset "GdsMapping - Plot Data Export" begin
    raw = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    poly = validate_and_create_polygon(raw)
    layer = GdsLayer(1, [poly])
    
    plot_data = get_plot_data(layer)
    @test length(plot_data) == 1
    @test size(plot_data[1]) == (5, 2) # 5 vertices, 2 coordinates (x, y)
    @test plot_data[1][1, 1] == 0.0
    @test plot_data[1][1, 2] == 0.0
    @test plot_data[1][end, 1] == 0.0
    @test plot_data[1][end, 2] == 0.0
end

@testset "GdsMapping - Boundary Violation Warning" begin
    # 一時的な config.json を用意
    cfg_data = "{\"lx\": 0.5e-3, \"ly\": 0.5e-3}"
    write("config.json", cfg_data)
    
    try
        # テスト用のダミー GDS ファイルは SimpleGDS 経由で読み込む必要があるため、
        # 既存の org_chip1.gds をロードして範囲逸脱をチェックする。
        # org_chip1.gds 内のポリゴンは [0.1e-3, 1.1e-3] にあり、lx=0.5e-3 を超えているため、
        # load_gds_layer を実行した際に `@warn` が発生するはず。
        gds_path = "./H2-main_TSV_Opt/org_chip1.gds"
        if isfile(gds_path)
            # 警告が発生することを確認
            @test_logs (:warn, r"Polygon boundary exceeds chip range") load_gds_layer(gds_path, 1)
        end
    finally
        # テスト終了後に一時ファイルを削除
        if isfile("config.json")
            rm("config.json")
        end
    end
end
