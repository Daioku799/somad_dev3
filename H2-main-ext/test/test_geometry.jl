using Test

if !isdefined(Main, :GeometryLogic)
    include("../src/GeometryLogic/GeometryLogic.jl")
end
using .GeometryLogic: is_included_rect, is_included_cyl, is_included_sph, is_included_chip, GdsLayer, GdsPolygon, BBox

@testset "GeometryLogic Primitives - rect" begin
    # 1. 完全包含
    @test is_included_rect((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0), (2.0, 2.0, 2.0)) == true

    # 2. 完全除外
    @test is_included_rect((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (2.0, 2.0, 2.0), (3.0, 3.0, 3.0)) == false

    # 3. ちょうど 50% 重なり
    @test is_included_rect((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0), (0.5, 1.0, 1.0)) == true

    # 4. 50% 未満重なり
    @test is_included_rect((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0), (0.49, 1.0, 1.0)) == false
end

@testset "GeometryLogic Primitives - cyl" begin
    # 1. 占有率が 50% 以上 (中心(0.5, 0.5)で半径0.6 of 円柱は、1x1x1のセルに50%以上重なる)
    @test is_included_cyl((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.5, 0.5), 0.6, 0.0, 1.0) == true

    # 2. 占有率が 50% 未満 (半径0.3の円柱は最大でも 28.2% しか重ならない)
    @test is_included_cyl((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.5, 0.5), 0.3, 0.0, 1.0) == false

    # 3. Z範囲が重ならない
    @test is_included_cyl((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.5, 0.5), 0.6, 2.0, 3.0) == false
end

@testset "GeometryLogic Primitives - sph" begin
    # 1. 占有率が 50% 以上 (中心(0.5, 0.5, 0.5)で半径0.6の球は、1x1x1のセルに50%以上重なる)
    @test is_included_sph((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.5, 0.5, 0.5), 0.6) == true

    # 2. 占有率が 50% 未満 (半径0.4の球は最大でも 26.8% しか重ならない)
    @test is_included_sph((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (0.5, 0.5, 0.5), 0.4) == false
end

@testset "GeometryLogic GdsIntegration - chip" begin
    bbox = BBox(0.0, 0.0, 1.0, 1.0)
    polygon = GdsPolygon([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)], bbox)
    layer = GdsLayer(1, [polygon])

    # 1. Z重なりが 50% 以上 (Z範囲 [0.0, 0.8] はセルの 80% を占有)
    @test is_included_chip((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), layer, 0.0, 0.8; samples=3) == true

    # 2. Z重なりが 50% 未満 (Z範囲 [0.0, 0.4] はセルの 40% を占有)
    @test is_included_chip((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), layer, 0.0, 0.4; samples=3) == false

    # 3. XYで GDS ポリゴン外
    @test is_included_chip((2.0, 2.0, 0.0), (3.0, 3.0, 1.0), layer, 0.0, 1.0; samples=3) == false
end

@testset "GeometryLogic BBox and Tolerance Tests" begin
    # 1. BBox 早期棄却テスト (直方体判定)
    # 重なりがない場合、早期に false が返る
    @test is_included_rect((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), (10.0, 10.0, 10.0), (11.0, 11.0, 11.0)) == false

    # 2. Tolerance (1e-12) の検証
    # 球の中心 (0.5, 0.5, 0.5)、半径 0.5。
    # 頂点 (1.0, 0.5, 0.5) は境界ぴったり。
    # 頂点 (1.0 + 1e-13, 0.5, 0.5) は球の外部だが 1e-12 の許容誤差以内。
    # この頂点のみを球内に配置し、1x1x1のセルの8頂点すべてが Tolerance 以内で球内に入るようにする。
    # セル: [0.5, 0.5, 0.5] から [0.5 + 0.35, 0.5 + 0.35, 0.5 + 0.35]
    # 対角距離 = sqrt(3 * 0.35^2) = 0.35 * sqrt(3) ≈ 0.606
    # セルを極小 (例えば 1e-14 の大きさ) にして球の境界ぎりぎり外側 (例えば 0.5 + 1e-13) に置くと、
    # 本来は球の外だが、Tolerance (1e-12) のおかげで all_inside が true になり、球内と判定される。
    # 球の中心 (0.0, 0.0, 0.0)、半径 1.0。
    # セルの対角点 (0.9999999999999, 0.0, 0.0) から (1.0000000000001, 1e-14, 1e-14)。
    # この極小セルは球の境界 (1.0) を極めてわずかに (1e-13) はみ出している。
    # ですが、Tolerance 1e-12m 以内であるため、all_inside (8頂点がすべて内側) として判定され true になるはずです。
    @test is_included_sph(
        (0.9999999999999, 0.0, 0.0), 
        (1.0000000000001, 1e-14, 1e-14), 
        (0.0, 0.0, 0.0), 
        1.0
    ) == true
end




