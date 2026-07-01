# Build functions for geometric model
# Ver. 1.0  2025-07-23
module modelA
export fillID!, setLambda!, model_test

using Printf
using LinearAlgebra
using Plots
using PolygonOps # Added for GDS point-in-polygon check
using JSON
using Random

# Load local GDS parser
include("../SimpleGDS.jl")
using .SimpleGDS

# Global storage for GDS polygons (Key: chip_id -> Layer -> List of {poly, bbox})

# Global storage for GDS polygons (Key: chip_id -> Layer -> List of {poly, bbox})
global const gds_chips = Dict{Int, Dict{Int, Vector{Dict{String, Any}}}}()

# Dimensions (Default values, overwritten by JSON)
global pg_dpth = 0.005e-3
global s_dpth = 0.1e-3
global d_ufill = 0.05e-3
global r_bump = 0.03e-3
global r_tsv = 0.02e-3
global h_tsv = 0.1e-3

# Unit [m] Z coords are now dynamic, these placeholders might be deprecated or updated.
global zm12 = 0.6e-3
global zm11 = 0.55e-3
global zm10 = 0.5e-3
global zm9  = zm10 - pg_dpth
global zm8 = 0.4e-3
global zm7 = 0.35e-3
global zm6 = zm7 - pg_dpth
global zm5 = 0.25e-3
global zm4 = 0.2e-3
global zm3 = zm4 - pg_dpth
global zm2 = 0.1e-3
global zm1 = 0.05e-3
global zm0 = 0.0

# boundary box of each element [mm]
global substrate = Dict(
    "x0" => 0.0, "y0" => 0.0, "z0" => zm0,
    "Lx" => 1.2e-3, "Ly" => 1.2e-3, "Lz" => 0.05e-3, "mat_id" => 4
)
global heatsink = Dict(
    "x0" => 0.0, "y0" => 0.0, "z0" => zm11,
    "Lx" => 1.2e-3, "Ly" => 1.2e-3, "Lz" => 0.05e-3, "mat_id" => 5
)

# geomに登録
global geom = Dict{String, Any}[]
push!(geom, substrate)
push!(geom, heatsink)


"""
    set_model_params!(config::Dict{String, Any})

JSON設定から、寸法定数と材質データを更新し、geomを初期化する。
また、層構造定義から zm0～zm12 のZ座標変数を自動計算する。
"""
function set_model_params!(config)
    println("Init model params from config...")
    
    # 1. Dimensions
    dims = config["dimensions"]
    global pg_dpth = Float64(dims["pg_dpth"])
    global s_dpth  = Float64(dims["s_dpth"])
    global d_ufill = Float64(dims["d_ufill"])
    global r_bump  = Float64(dims["r_bump"])
    global r_tsv   = Float64(dims["r_tsv"])
    global h_tsv   = Float64(dims["h_tsv"])

    # 2. Materials
    mats = config["materials"]
    global cupper = mats["cupper"]
    global silicon = mats["silicon"]
    global solder = mats["solder"]
    global FR4 = mats["FR4"]
    global A1060 = mats["A1060"]
    global Resin = mats["Resin"]
    global pwrsrc = mats["pwrsrc"]
    
    # Update material list
    empty!(mat)
    push!(mat, cupper)
    push!(mat, silicon)
    push!(mat, solder)
    push!(mat, FR4)
    push!(mat, A1060)
    push!(mat, Resin)
    push!(mat, pwrsrc)

    # 3. Z-coordinates automation (zm0...zm12)
    # Replaces hardcoded values with calculation from layers
    layers = config["layers"]
    
    # Mapping strategy:
    # zm0: Bottom (0.0)
    # zm1: Top of Substrate
    # zm2: Top of Underfill1 (Start of Si1)
    # zm3: Top of Si1 (PowerGrid plane) -> Note: zm3 was 0.2 - pg_dpth in original
    # Wait, original mapping:
    # Si1: zm2 to zm4? No.
    # Original:
    # zm0=0, zm1=0.05 (Substrate end)
    # zm2=0.1 (Underfill1 end / Si1 start)
    # zm3=zm4 - pg (inside Si1?) 
    # zm4=0.2 (Si1 end)
    # So zm2=Start Si1, zm4=End Si1. zm3 is PG plane near top of Si1.
    
    # We will reconstruct this sequence cumulatively.
    
    current_z = 0.0
    global zm0 = current_z
    
    # We assume the layers are ordered: Substrate, UF1, Si1, UF2, Si2, UF3, Si3, UF4, HS
    # Layer 1: Substrate
    l1 = layers[1]; current_z += Float64(l1["thickness"]); global zm1 = current_z
    
    # Layer 2: UF1
    l2 = layers[2]; current_z += Float64(l2["thickness"]); global zm2 = current_z
    
    # Layer 3: Si1 (Contains PG)
    l3 = layers[3]; si1_th = Float64(l3["thickness"])
    si1_end = current_z + si1_th
    global zm4 = si1_end
    global zm3 = zm4 - pg_dpth
    current_z = si1_end
    
    # Layer 4: UF2
    l4 = layers[4]; current_z += Float64(l4["thickness"]); global zm5 = current_z
    
    # Layer 5: Si2
    l5 = layers[5]; si2_th = Float64(l5["thickness"])
    si2_end = current_z + si2_th
    # Original: zm5 start of Si2, zm6 is PG? No, zm6 = zm7 - pg. zm7 is Si2 End??
    # Original: zm5=0.25 (Start Si2), zm7=0.35 (End Si2). zm6 = 0.35 - pg.
    global zm7 = si2_end
    global zm6 = zm7 - pg_dpth
    current_z = si2_end
    
    # Layer 6: UF3
    l6 = layers[6]; current_z += Float64(l6["thickness"]); global zm8 = current_z
    
    # Layer 7: Si3
    l7 = layers[7]; si3_th = Float64(l7["thickness"])
    si3_end = current_z + si3_th
    # Original: zm8 start Si3 (0.4), zm10 End Si3 (0.5). zm9 = zm10 - pg.
    global zm10 = si3_end
    global zm9  = zm10 - pg_dpth
    current_z = si3_end
    
    # Layer 8: UF4
    l8 = layers[8]; current_z += Float64(l8["thickness"]); global zm11 = current_z
    
    # Layer 9: Heatsink
    l9 = layers[9]; current_z += Float64(l9["thickness"]); global zm12 = current_z
    
    println("  - Z markers updated from JSON:")
    println("    zm0=$zm0, zm1=$zm1, zm2=$zm2 (Si1 Start)")
    println("    zm3=$zm3 (Si1 PG), zm4=$zm4 (Si1 End)")
    println("    zm12=$zm12 (Top)")
    
    # 4. Geometry Objects (Substrate, Heatsink) reconstruction
    # Reset geom
    empty!(geom)
    
    # Substrate (Layer 1)
    # defined from zm0 to zm1
    global substrate = Dict(
        "x0" => 0.0, "y0" => 0.0, "z0" => zm0,
        "Lx" => 1.2e-3, "Ly" => 1.2e-3, "Lz" => (zm1 - zm0), 
        "mat_id" => FR4["id"]
    )
    push!(geom, substrate)

    # Heatsink (Last Layer, Layer 9)
    # defined from zm11 to zm12
    global heatsink = Dict(
        "x0" => 0.0, "y0" => 0.0, "z0" => zm11,
        "Lx" => 1.2e-3, "Ly" => 1.2e-3, "Lz" => (zm12 - zm11), 
        "mat_id" => A1060["id"]
    )
    push!(geom, heatsink)
end

"""
    get_gds_bbox(layer::Int) -> (xmin, ymin, xmax, ymax) or nothing

指定レイヤーのGDSデータから、全ポリゴンを包含する外接矩形を計算する。
"""
function get_gds_bbox(chip_id::Int, layer::Int)
    if !haskey(gds_chips, chip_id) || !haskey(gds_chips[chip_id], layer)
        error("GDS Chip $chip_id Layer $layer is missing. GDS data is required.")
    end
    xmin = ymin = Inf
    xmax = ymax = -Inf
    for shape in gds_chips[chip_id][layer]
        bbox = shape["bbox"]
        xmin = min(xmin, bbox[1]); xmax = max(xmax, bbox[3])
        ymin = min(ymin, bbox[2]); ymax = max(ymax, bbox[4])
    end
    return xmin, ymin, xmax, ymax
end

"""
    update_geom_from_gds!()

GDSデータのレイヤー1（シリコン）とレイヤー2（熱源）のBBoxを計算し、
geom配列内の対応する要素の次元（x0, y0, Lx, Ly）を自動更新する。
"""

function update_geom_from_gds!(chip_id::Int, layer::Int, z0::Float64, mat_id::Int, name::String)
    # 全体のBBox計算
    xmin, ymin, xmax, ymax = get_gds_bbox(chip_id, layer)
    lx = xmax - xmin
    ly = ymax - ymin
    
    # 高さLzの決定
    # - Silicon: s_dpth (0.1mm)
    # - TSV (Cu): h_tsv (0.1mm)
    # - Others (PG): pg_dpth (0.005mm)
    lz = 0.0
    if mat_id == silicon["id"]
        lz = s_dpth
    elseif mat_id == cupper["id"]
        lz = h_tsv
    else
        lz = pg_dpth
    end

    push!(geom, Dict(
        "name" => name,
        "chip_id" => chip_id,
        "layer" => layer,
        "x0" => xmin, "y0" => ymin, "z0" => z0,
        "Lx" => lx, "Ly" => ly, "Lz" => lz,
        "mat_id" => mat_id,
        "shapes" => gds_chips[chip_id][layer]
    ))
    println("  - Added $name (Chip $chip_id, Layer $layer) to geom at Z=$z0, H=$lz")
end

# 物性値
# λ 熱伝導率 [W/mK]
# ρ 密度 [kg/m^3]
# C 比熱 [J/KgK]
# α 温度拡散率 [m^2/s]

# TSV : Yellow
cupper = Dict(
    "id" => 1, "λ" => 386.0, "ρ" => 8960.0, "C" => 383.0, "α" => 1.12e-4
)
# Silicon : Green
silicon = Dict(
    "id" => 2, "λ" => 149.0, "ρ" => 2330.0, "C" => 720.0, "α" => 8.88e-5
)
# bump ハンダ : Purple
solder = Dict(
    "id" => 3, "λ" => 50.0, "ρ" => 8500.0, "C" => 197.0, "α" => 2.99e-5
)
# PCB subtrate : Orange
FR4 = Dict(
    "id" => 4, "λ" => 0.4, "ρ" => 1850.0, "C" => 1000.0, "α" => 2.16e-7
)
# Heatsink : Blue
A1060 = Dict(
    "id" => 5, "λ" => 222.0, "ρ" => 2700.0, "C" => 921.0, "α" => 8.93e-5
)
# Underfill : Grey
Resin = Dict(
    "id" => 6, "λ" => 1.5, "ρ" => 2590.0, "C" => 1050.0, "α" => 5.52e-7
)
# Power grid, Silicon : Red
pwrsrc = Dict(
    "id" => 7, "λ" => 149.0, "ρ" => 2330.0, "C" => 720.0, "α" => 8.88e-5
)

mat = Dict{String, Any}[]
push!(mat, cupper)
push!(mat, silicon)
push!(mat, solder)
push!(mat, FR4)
push!(mat, A1060)
push!(mat, Resin)
push!(mat, pwrsrc)

# =======================================

function searchMat(m::Int64)
    for i in 1:length(mat)
        if mat[i]["id"] == m
            return i
        end
    end
    # if exit for-loop
    println("search material error")
    exit(0)
end

"""
GDSIIファイルを読み込み、ポリゴンデータを内部メモリに保持する。
"""
function load_gds_geometry!(filename::String, chip_id::Int=1)
    println("Loading GDS geometry (Chip $chip_id): $filename")
    if !haskey(gds_chips, chip_id)
        gds_chips[chip_id] = Dict{Int, Vector{Dict{String, Any}}}()
    end
    
    if !isfile(filename)
        println("Warning: GDS file $filename not found.")
        return
    end

    lib = SimpleGDS.load(filename)
    scale_to_meter = 1e-6 # GDS units (um) to meters
    
    count = 0
    for str in lib.structures
        for element in str.elements
            if element isa SimpleGDS.Boundary
                layer = element.layer
                if !haskey(gds_chips[chip_id], layer)
                    gds_chips[chip_id][layer] = []
                end
                
                # [[x,y], [x,y], ...] の形式に変換 (メートル単位)
                poly = [[Float64(p.x * scale_to_meter), Float64(p.y * scale_to_meter)] for p in element.xy]
                
                # ポリゴンごとのBBoxを事前計算
                xmin = ymin = Inf
                xmax = ymax = -Inf
                for p in poly
                    xmin = min(xmin, p[1]); xmax = max(xmax, p[1])
                    ymin = min(ymin, p[2]); ymax = max(ymax, p[2])
                end
                
                push!(gds_chips[chip_id][layer], Dict(
                    "poly" => poly,
                    "bbox" => (xmin, ymin, xmax, ymax)
                ))
                count += 1
            end
        end
    end
    println("Successfully loaded $count elements into Chip $chip_id. Layers: ", keys(gds_chips[chip_id]))
end




function chk_idx(i, nx)
    if i<1
        i = 1
    end
    if i>nx
        i = nx
    end
    return i
end

function find_Ri(x::Float64, r, x0, dx, nx)
    is = floor( Int64, (x-r-x0)/dx+1.5 )
    ie = floor( Int64, (x+r-x0)/dx+1.5 )
    is = chk_idx(is, nx)
    ie = chk_idx(ie, nx)
    return is, ie
end

function find_Rj(y::Float64, r, y0, dy, ny)
    js = floor( Int64, (y-r-y0)/dy+1.5 )
    je = floor( Int64, (y+r-y0)/dy+1.5 )
    js = chk_idx(js, ny)
    je = chk_idx(je, ny)
    return js, je
end

function find_i(x::Float64, x0, dx, nx)
    i = floor( Int64, (x-x0)/dx+1.5 )
    return chk_idx(i, nx)
end

function find_j(y::Float64, y0, dy, ny)
    j = floor( Int64, (y-y0)/dy+1.5 )
    return chk_idx(j, ny)
end

function find_k(Z::Vector{Float64}, zc, nz)

    # 浮動小数点誤差を考慮した範囲チェック
    eps_tol = 1e-12
    if zc < Z[1] - eps_tol || zc > Z[nz] + eps_tol
        println("out of scope in Z : find_z()")
        println(zc, " ", round(Z[nz],digits=8))
        exit()
    end

    for k in 1:nz-1
        if Z[k] ≤ zc < Z[k+1]
            return k
        end
    end

    # zcがZ[nz]とほぼ等しい場合（浮動小数点誤差を考慮）
    if abs(zc - Z[nz]) < eps_tol
        return nz - 1
    end
end


# ジオメトリのbboxを計算
function find_index(b, L, ox, Δh, SZ, Z::Vector{Float64})
    st = zeros(Int64, 3)
    ed = zeros(Int64, 3)

    st[1] = chk_idx( find_i(b[1], ox[1], Δh[1], SZ[1]), SZ[1])
    st[2] = chk_idx( find_i(b[2], ox[2], Δh[2], SZ[2]), SZ[2])
    st[3] = find_k(Z, b[3], SZ[3])
    ed[1] = chk_idx( find_i(b[1]+L[1], ox[1], Δh[1], SZ[1]), SZ[1])
    ed[2] = chk_idx( find_i(b[2]+L[2], ox[2], Δh[2], SZ[2]), SZ[2])
    ed[3] = find_k(Z, b[3]+L[3], SZ[3])
    return st, ed
end


"""
    is_included_rect(a1, a2, b1, b2) -> Bool

セルA(a1,a2) が直方体のジオメトリ領域B(b1,b2) に 50%以上含まれている場合 true を返す。
a1,a2,b1,b2 は対角をなす2点の座標 (x,y,z) タプル。
"""
function is_included_rect(a1, a2, b1, b2)
    # Aの体積
    volA = abs((a2[1] - a1[1]) * (a2[2] - a1[2]) * (a2[3] - a1[3]))

    # 重なり体積
    axlo, aylo, azlo = min.(a1, a2)
    axhi, ayhi, azhi = max.(a1, a2)
    bxlo, bylo, bzlo = min.(b1, b2)
    bxhi, byhi, bzhi = max.(b1, b2)

    ox = max(0.0, min(axhi, bxhi) - max(axlo, bxlo))
    oy = max(0.0, min(ayhi, byhi) - max(aylo, bylo))
    oz = max(0.0, min(azhi, bzhi) - max(azlo, bzlo))

    overlap_vol = ox * oy * oz

    return overlap_vol >= 0.5 * volA
end

"""
    is_half_or_more_included_cuboid_in_cylinder(a1, a2, cyl_center, cyl_radius, cyl_zmin, cyl_zmax; samples=50)

直方体(a1,a2)の体積のうち、円柱（Z軸方向）に含まれる割合が50%以上ならtrue。
円柱は中心xy座標 `cyl_center`、半径 `cyl_radius`、
高さ範囲 [cyl_zmin, cyl_zmax] で指定。
"""
function is_included_cyl(a1, a2, cyl_ctr, cyl_r, cyl_zmin, cyl_zmax; samples=50)
    # 直方体の境界
    xlo, ylo, zlo = min.(a1, a2)
    xhi, yhi, zhi = max.(a1, a2)

    volA = (xhi - xlo) * (yhi - ylo) * (zhi - zlo)

    inside_count = 0
    total_count = 0

    for i in 1:samples, j in 1:samples, k in 1:samples
        # 小セルの中心座標
        x = xlo + (i - 0.5) * (xhi - xlo) / samples
        y = ylo + (j - 0.5) * (yhi - ylo) / samples
        z = zlo + (k - 0.5) * (zhi - zlo) / samples

        # 円柱内判定
        dx = x - cyl_ctr[1]
        dy = y - cyl_ctr[2]
        r2 = dx^2 + dy^2
        if r2 <= cyl_r^2 && cyl_zmin <= z <= cyl_zmax
            inside_count += 1
        end
        total_count += 1
    end

    overlap_vol = volA * inside_count / total_count
    return overlap_vol >= 0.5 * volA
end

"""
    is_half_or_more_included_cuboid_in_sphere(a1, a2, center, radius; samples=50) -> Bool

直方体 A (対角点 a1, a2) の体積のうち、球 (center, radius) に含まれる割合が50%以上なら true を返す。
評価は一様グリッドサンプリングで行い、samples^3 点で近似する（samplesを増やすと精度↑, 計算量↑）。

引数:
- a1, a2 :: (x,y,z) 直方体の対角点（順不同）
- center :: (cx,cy,cz) 球の中心
- radius :: 半径
- samples :: 各軸の分割数（既定 50）

注意:
- 直方体は軸平行（AABB）を仮定
- 早期判定: 直方体の8頂点がすべて球内なら即 true（完全包含）
"""
function is_included_sph(a1, a2, center, radius; samples::Int=50)
    # 直方体の境界（昇順にそろえる）
    xlo, ylo, zlo = min.(a1, a2)
    xhi, yhi, zhi = max.(a1, a2)

    # 体積
    volA = (xhi - xlo) * (yhi - ylo) * (zhi - zlo)
    volA ≤ 0 && return false  # 退避：変な入力

    cx, cy, cz = center
    r2 = radius^2

    # 早期 true 判定：8頂点がすべて球内なら完全包含
    corners = ((xlo,ylo,zlo),(xlo,ylo,zhi),(xlo,yhi,zlo),(xlo,yhi,zhi),
               (xhi,ylo,zlo),(xhi,ylo,zhi),(xhi,yhi,zlo),(xhi,yhi,zhi))
    all_inside = all(((x - cx)^2 + (y - cy)^2 + (z - cz)^2 ≤ r2) for (x,y,z) in corners)
    if all_inside
        return true
    end

    # サンプリング（セル中心）
    inside_count = 0
    total_count  = samples^3

    dx = (xhi - xlo) / samples
    dy = (yhi - ylo) / samples
    dz = (zhi - zlo) / samples

    x = xlo + dx/2
    for i in 1:samples
        y = ylo + dy/2
        for j in 1:samples
            z = zlo + dz/2
            for k in 1:samples
                # 点が球内か
                if (x - cx)^2 + (y - cy)^2 + (z - cz)^2 ≤ r2
                    inside_count += 1
                end
                z += dz
            end
            y += dy
        end
        x += dx
    end

    overlap_vol_est = volA * (inside_count / total_count)
    return overlap_vol_est ≥ 0.5 * volA
end


"""
    is_included_gds_cell(c1, c2, shape; samples=5) -> Bool

セル(c1,c2)のXY平面における面積のうち、GDS形状(shape)に含まれる割合が50%以上ならtrueを返す。
samples x samples の分割サンプリングを行う。
"""
function is_included_gds_cell(c1, c2, shape; samples=5)
    poly = shape["poly"]
    # Z方向は呼び出し元でチェック済みと仮定
    
    x_min = min(c1[1], c2[1])
    y_min = min(c1[2], c2[2])
    dx = abs(c2[1] - c1[1]) / samples
    dy = abs(c2[2] - c1[2]) / samples
    
    inside_count = 0
    total_count = samples^2
    
    for i in 1:samples
        px = x_min + (i - 0.5) * dx
        for j in 1:samples
            py = y_min + (j - 0.5) * dy
            if PolygonOps.inpolygon([px, py], poly) >= 0.5
                inside_count += 1
            end
        end
    end
    
    return (inside_count / total_count) >= 0.5
end

"""
    is_included_gds(c1, c2, polygons, z_min, z_max; samples=5) -> Bool

セル(c1,c2)の体積のうち、GDSポリゴンと指定のZ範囲[z_min, z_max]に含まれる割合が50%以上か判定。
XY平面を samples^2 でサンプリングし、Z方向の重なり割合を乗じて判定する。
"""
function is_included_gds(c1, c2, shapes, z_min, z_max; samples=5)
    # Z方向の重なり具合を計算
    z_lo = max(min(c1[3], c2[3]), z_min)
    z_hi = min(max(c1[3], c2[3]), z_max)
    overlap_z = max(0.0, z_hi - z_lo)
    cell_dz = abs(c2[3] - c1[3])
    
    if overlap_z <= 0 || cell_dz <= 0
        return false
    end

    # XY平面の重なりをサンプリングで推定
    inside_count = 0
    total_count = samples^2
    
    dx = abs(c2[1] - c1[1]) / samples
    dy = abs(c2[2] - c1[2]) / samples
    x_min = min(c1[1], c2[1])
    y_min = min(c1[2], c2[2])
    
    for i in 1:samples, j in 1:samples
        px = x_min + (i - 0.5) * dx
        py = y_min + (j - 0.5) * dy
        
        # いずれかのポリゴンに含まれればカウント
        for shape in shapes
            bbox = shape["bbox"]
            # BBox判定による高速化
            if px < bbox[1] || px > bbox[3] || py < bbox[2] || py > bbox[4]
                continue
            end
            if PolygonOps.inpolygon([px, py], shape["poly"]) >= 0.5
                inside_count += 1
                break
            end
        end
    end
    
    # (XY面積の含有率) * (Z高さの含有率) >= 0.5
    vol_ratio = (inside_count / total_count) * (overlap_z / cell_dz)
    return vol_ratio >= 0.5
end

# ジオメトリのbboxをフィル
function FillPlate!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    SZ = size(ID)
    c1= zeros(Float64, 3)
    c2= zeros(Float64, 3)

    for m in 1:length(geom)
        b0 = [geom[m]["x0"], geom[m]["y0"], geom[m]["z0"]]
        L0 = [geom[m]["Lx"], geom[m]["Ly"], geom[m]["Lz"]]
        mat_id = geom[m]["mat_id"]

        # 形状リストを持っているか確認
        if haskey(geom[m], "shapes")
            for shape in geom[m]["shapes"]
                # 個別形状のBBoxでループ範囲を極小化
                bbox = shape["bbox"]
                b = [bbox[1], bbox[2], b0[3]]
                L = [bbox[3]-bbox[1], bbox[4]-bbox[2], L0[3]]
                st, ed = find_index(b, L, ox, Δh, SZ, Z)
                
                for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
                    if ID[i,j,k] == 0
                        c1[1] = ox[1] + Δh[1]*(i-1); c2[1] = c1[1] + Δh[1]
                        c1[2] = ox[2] + Δh[2]*(j-1); c2[2] = c1[2] + Δh[2]
                        c1[3] = Z[k];                c2[3] = Z[k+1]
                        
                        # 単一形状(shape)に対して判定
                        if is_included_gds(c1, c2, [shape], b0[3], b0[3]+L0[3])
                             l = searchMat( mat_id )
                             ID[i,j,k] = mat[l]["id"]
                        end
                    end
                end
            end
        else
            # 従来通りの直方体判定
            st, ed = find_index(b0, L0, ox, Δh, SZ, Z)
            d1 = b0
            d2 = b0 + L0
            for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
                if ID[i,j,k] == 0
                    c1[1] = ox[1] + Δh[1]*(i-1); c2[1] = c1[1] + Δh[1]
                    c1[2] = ox[2] + Δh[2]*(j-1); c2[2] = c1[2] + Δh[2]
                    c1[3] = Z[k];                c2[3] = Z[k+1]
                    if is_included_rect(c1, c2, d1, d2)
                        l = searchMat( mat_id )
                        ID[i,j,k] = mat[l]["id"]
                    end
                end
            end
        end
    end
end


# 厚さ5µの領域
function FillPowerGrid!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64}, lx=0.2e-3, ly=0.2e-3)
    SZ = size(ID)
    c1= zeros(Float64, 3)
    c2= zeros(Float64, 3)
    
    # geomの中からPowerGridの設定（GDS形状リストを持つもの）を探して適用
    println("Filling PowerGrid from GDS layers defined in geom")
    for m in 1:length(geom)
        if geom[m]["mat_id"] == pwrsrc["id"] && haskey(geom[m], "shapes")
            z_min = geom[m]["z0"]
            z_max = z_min + geom[m]["Lz"]
            
            for shape in geom[m]["shapes"]
                bbox = shape["bbox"]
                b = [bbox[1], bbox[2], z_min]
                L = [bbox[3]-bbox[1], bbox[4]-bbox[2], geom[m]["Lz"]]
                st, ed = find_index(b, L, ox, Δh, SZ, Z)

                for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
                    if ID[i,j,k] == 0
                        c1[1] = ox[1] + Δh[1]*(i-1); c2[1] = c1[1] + Δh[1]
                        c1[2] = ox[2] + Δh[2]*(j-1); c2[2] = c1[2] + Δh[2]
                        c1[3] = Z[k];                c2[3] = Z[k+1]
                        
                        if is_included_gds(c1, c2, [shape], z_min, z_max)
                            ID[i,j,k] = pwrsrc["id"]
                        end
                    end
                end
            end
        end
    end
end
 


function FillResin!(ID::Array{UInt8,3})
    SZ = size(ID)
    for k in 1:SZ[3], j in 1:SZ[2], i in 1:SZ[1]
        if 0 == ID[i,j,k]
            ID[i,j,k] = Resin["id"]
        end
    end
end


function FillTSV!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    SZ = size(ID)
    c1= zeros(Float64, 3)
    c2= zeros(Float64, 3)
    cyl_ctr= zeros(Float64, 2)
    cyl_r = r_tsv

    for z in [zm2, zm5, zm8], y in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3], x in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3]
        cyl_ctr[1] = x
        cyl_ctr[2] = y
        cyl_zmin = z
        cyl_zmax = z + h_tsv
        is, ie = find_Ri(x, cyl_r, ox[1], Δh[1], SZ[1])
        js, je = find_Rj(y, cyl_r, ox[2], Δh[2], SZ[2])
        ks = find_k(Z, cyl_zmin, SZ[3])
        ke = find_k(Z, cyl_zmax, SZ[3])
        #@printf(stdout, "TSV : [%d - %d]\n",ks, ke)

        for k in max(1, ks-1):ke, j in max(1, js-1):je, i in max(1, is-1):ie
            c1[1] = ox[1] + Δh[1]*(i-1)
            c1[2] = ox[2] + Δh[2]*(j-1)
            c1[3] = Z[k]
            c2[1] = c1[1] + Δh[1]
            c2[2] = c1[2] + Δh[2]
            c2[3] = Z[k+1]
            if (0 == ID[i,j,k]) && is_included_cyl(c1, c2, cyl_ctr, cyl_r, cyl_zmin, cyl_zmax)
                ID[i,j,k] = cupper["id"]
            end
        end
    end
end


function FillSolder!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    SZ = size(ID)
    r = r_bump # ball radius
    c1= zeros(Float64, 3)
    c2= zeros(Float64, 3)
    ctr= zeros(Float64, 3)
    dp = d_ufill*0.5

    for z in [zm1+dp, zm4+dp, zm7+dp, zm10+dp], y in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3], x in [0.3e-3, 0.5e-3, 0.7e-3, 0.9e-3]
        ctr[1] = x
        ctr[2] = y
        ctr[3] = z
        is, ie = find_Ri(x, r, ox[1], Δh[1], SZ[1])
        js, je = find_Rj(y, r, ox[2], Δh[2], SZ[2])
        ks = find_k(Z, z-dp, SZ[3])
        ke = find_k(Z, z+dp, SZ[3])
        #@printf(stdout, "BUMP: [%d %d %d - %d %d %d]\n", is, js, ks, ie, je, ke)

        for k in max(1, ks-1):ke, j in max(1, js-1):je, i in max(1, is-1):ie
            c1[1] = ox[1] + Δh[1]*(i-1)
            c1[2] = ox[2] + Δh[2]*(j-1)
            c1[3] = Z[k]
            c2[1] = c1[1] + Δh[1]
            c2[2] = c1[2] + Δh[2]
            c2[3] = Z[k+1]
            if (0 == ID[i,j,k]) && is_included_sph(c1, c2, ctr, r)
                ID[i,j,k] = solder["id"]
            end
        end
    end
end




function setProperties!(λ::Array{Float64,3},
                        ρ::Array{Float64,3},
                        cp::Array{Float64,3},
                        ID::Array{UInt8,3})
    SZ = size(λ)
    for k in 1:SZ[3], j in 1:SZ[2], i in 1:SZ[1]
        t = ID[i,j,k]
        if t == pwrsrc["id"]
            λ[i,j,k] = pwrsrc["λ"]
            ρ[i,j,k] = pwrsrc["ρ"]
           cp[i,j,k] = pwrsrc["C"]

        elseif t == cupper["id"]
            λ[i,j,k] = cupper["λ"]
            ρ[i,j,k] = cupper["ρ"]
           cp[i,j,k] = cupper["C"]

        elseif t == silicon["id"]
            λ[i,j,k] = silicon["λ"]
            ρ[i,j,k] = silicon["ρ"]
           cp[i,j,k] = silicon["C"]

        elseif t == FR4["id"]
            λ[i,j,k] = FR4["λ"]
            ρ[i,j,k] = FR4["ρ"]
           cp[i,j,k] = FR4["C"]

        elseif t == A1060["id"]
            λ[i,j,k] = A1060["λ"]
            ρ[i,j,k] = A1060["ρ"]
           cp[i,j,k] = A1060["C"]

        elseif t == solder["id"]
            λ[i,j,k] = solder["λ"]
            ρ[i,j,k] = solder["ρ"]
           cp[i,j,k] = solder["C"]

        else
            λ[i,j,k] = Resin["λ"]
            ρ[i,j,k] = Resin["ρ"]
           cp[i,j,k] = Resin["C"]
        end
    end
end

"""
    generate_tsv_coordinates(chip_idx) -> (coords, radius, height)

JSON設定からTSVの座標リスト(x, y)を生成して返す。
"""
function generate_tsv_coordinates(chip_idx)
    # 1. Load Config
    config_path = "tsv_config.json"
    if !isfile(config_path)
        println("Warning: $config_path not found. Skipping TSV generation.")
        return [], 0.0, 0.0
    end
    
    tsv_conf = JSON.parsefile(config_path)
    
    mode  = get(tsv_conf, "tsv_mode", "uniform")
    count = get(tsv_conf, "tsv_count", 100)
    r_tsv = get(tsv_conf, "tsv_radius", 5.0e-6)
    seed_base = get(tsv_conf, "random_seed", 12345)
    
    # TSV height is fixed or configurable? Assuming standard height from dimensions
    height = h_tsv
    
    # 2. Set Random Seed
    current_seed = (mode == "uniform") ? seed_base : (seed_base + chip_idx * 1000)
    rng = MersenneTwister(current_seed)
    
    # 3. Define Chip Area
    x_min, x_max = 150e-6, 1050e-6
    y_min, y_max = 150e-6, 1050e-6
    
    coords = Vector{Tuple{Float64, Float64}}()
    
    if mode == "manual"
        # Manual Mode: Read from "manual_coordinates"
        manual_list = get(tsv_conf, "manual_coordinates", [])
        if isempty(manual_list)
             println("Warning: Manual mode selected but 'manual_coordinates' is empty. No TSVs generated.")
        else
             println("  - Generating $(length(manual_list)) Manual TSVs for Chip $chip_idx (Mode: manual)")
             for pt in manual_list
                 # Ensure proper type conversion
                 cx = Float64(pt[1])
                 cy = Float64(pt[2])
                 push!(coords, (cx, cy))
             end
        end
    else
        # Random Mode
        println("  - Generating $count TSV Coordinates for Chip $chip_idx (Mode: $mode, R=$r_tsv)")
        for n in 1:count
            cx = x_min + rand(rng) * (x_max - x_min)
            cy = y_min + rand(rng) * (y_max - y_min)
            push!(coords, (cx, cy))
        end
    end
    
    return coords, r_tsv, height
end

"""
    FillTSV_Random!(ID, ox, Δh, Z, z_start, height, coords, radius)

指定された座標リストに基づいてTSVを配置する。
"""
function FillTSV_Random!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64}, z_start, height, coords, r_tsv)
    SZ = size(ID)
    r2 = r_tsv^2
    
    for (cx, cy) in coords
        # BBox for this TSV
        b_x_min = cx - r_tsv
        b_x_max = cx + r_tsv
        b_y_min = cy - r_tsv
        b_y_max = cy + r_tsv
        b_z_min = z_start
        b_z_max = z_start + height
        
        # Search Index
        d1 = [b_x_min, b_y_min, b_z_min]
        l_shape = [2*r_tsv, 2*r_tsv, height]
        st, ed = find_index(d1, l_shape, ox, Δh, SZ, Z)
        
        cyl_ctr = [cx, cy]
        cyl_zmin = z_start
        cyl_zmax = z_start + height

        for k in max(1, st[3]):min(SZ[3], ed[3])
             z_c = (Z[k] + Z[k+1]) / 2.0
             if z_c < b_z_min || z_c > b_z_max continue end
             
             for j in max(1, st[2]):min(SZ[2], ed[2]), i in max(1, st[1]):min(SZ[1], ed[1])
                c1 = zeros(Float64, 3)
                c2 = zeros(Float64, 3)
                c1[1] = ox[1] + Δh[1]*(i-1); c2[1] = c1[1] + Δh[1]
                c1[2] = ox[2] + Δh[2]*(j-1); c2[2] = c1[2] + Δh[2]
                c1[3] = Z[k];                c2[3] = Z[k+1]
                
                # Volume Fraction Check (samples=20 -> 20^3 points)
                if is_included_cyl(c1, c2, cyl_ctr, r_tsv, cyl_zmin, cyl_zmax, samples=20)
                    # TSV Overwrite Check: Only overwrite Silicon
                    if ID[i,j,k] == silicon["id"]
                        ID[i,j,k] = cupper["id"]
                    end
                end
            end
        end
    end
end

"""
    FillSolder_Random!(ID, ox, Δh, Z, z_center, coords, radius)

指定された座標リストに基づいて球状はんだバンプを配置する。
"""
function FillSolder_Random!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64}, z_center, coords, radius)
    SZ = size(ID)
    r2 = radius^2
    
    for (cx, cy) in coords
        ctr = [cx, cy, z_center]
        
        # BBox for this Solder Ball
        b_x_min = cx - radius
        b_x_max = cx + radius
        b_y_min = cy - radius
        b_y_max = cy + radius
        b_z_min = z_center - radius
        b_z_max = z_center + radius
        
        # Search Index
        d1 = [b_x_min, b_y_min, b_z_min]
        l_shape = [2*radius, 2*radius, 2*radius]
        st, ed = find_index(d1, l_shape, ox, Δh, SZ, Z)
        
        c1 = zeros(Float64, 3)
        c2 = zeros(Float64, 3)

        for k in max(1, st[3]):min(SZ[3], ed[3]), j in max(1, st[2]):min(SZ[2], ed[2]), i in max(1, st[1]):min(SZ[1], ed[1])
            c1[1] = ox[1] + Δh[1]*(i-1)
            c1[2] = ox[2] + Δh[2]*(j-1)
            c1[3] = Z[k]
            c2[1] = c1[1] + Δh[1]
            c2[2] = c1[2] + Δh[2]
            c2[3] = Z[k+1]
            
            # ユーザー要望: "他の素材を書き換えないように" (Do not overwrite)
            # すでに Silicon(2), PG(7), TSV(1), Substrate(4), Heatsink(5) がある場所はスキップ
            # Resin(6) または Empty(0) の場合のみ上書きする
            current_id = ID[i,j,k]
            if (current_id == 0 || current_id == Resin["id"])
                # Volume Fraction Check (samples=20)
                if is_included_sph(c1, c2, ctr, radius, samples=20)
                    ID[i,j,k] = solder["id"]
                end
            end
        end
    end
end


function FillTSV_gds!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    SZ = size(ID)
    b  = zeros(Float64, 3)
    L  = zeros(Float64, 3) # Lx, Ly, Lz
    d1 = zeros(Float64, 3)
    d2 = zeros(Float64, 3)
    c1 = zeros(Float64, 3)
    c2 = zeros(Float64, 3)

    for m in 1:length(geom)
        # "name"が"tsv"を含む要素のみを対象とする
        if !haskey(geom[m], "name") || !occursin("tsv", geom[m]["name"])
            continue
        end

        b[1] = geom[m]["x0"]
        b[2] = geom[m]["y0"]
        b[3] = geom[m]["z0"]
        L[1] = geom[m]["Lx"]
        L[2] = geom[m]["Ly"]
        L[3] = geom[m]["Lz"]
        
        # GDS形状（shapes）が登録されている場合のみ処理
        if haskey(geom[m], "shapes")
            shapes = geom[m]["shapes"]
            println("  - Filling TSV from GDS (Layer 3) with $(length(shapes)) shapes")

            # 各形状ごとのBBoxに基づいて充填
            for shape in shapes
                poly = shape["poly"]
                bbox = shape["bbox"]
                
                # 形状ごとのBBoxで探索範囲を限定
                d1[1] = bbox[1]; d1[2] = bbox[2]; d1[3] = b[3]
                l_shape = [bbox[3]-bbox[1], bbox[4]-bbox[2], L[3]] 
                
                st, ed = find_index(d1, l_shape, ox, Δh, SZ, Z)

                for k in st[3]:ed[3]
                    z_c = (Z[k] + Z[k+1]) / 2.0
                    # Z方向はLzの範囲内かチェック
                    if z_c < b[3] || z_c > b[3] + L[3] 
                        continue 
                    end
                    
                    for j in st[2]:ed[2], i in st[1]:ed[1]
                        c1[1] = ox[1] + Δh[1]*(i-1)
                        c1[2] = ox[2] + Δh[2]*(j-1)
                        
                        c2[1] = c1[1] + Δh[1]
                        c2[2] = c1[2] + Δh[2]
                        
                        # エリアサンプリング判定 (samples=5)
                        if is_included_gds_cell(c1, c2, shape, samples=5)
                            ID[i, j, k] = geom[m]["mat_id"]
                        end
                    end
                end
            end
        end
    end
end


function fillID!(ID::Array{UInt8,3}, ox, Δh, Z::Vector{Float64})
    # 各層に異なるGDSチップをマッピング
    # 優先順位: PowerGrid (薄膜) -> Silicon (母材) の順に登録する
    # FillPlateは ID==0 の場所のみ埋めるため、小さい/重要な形状を先に定義する。

    # Chip 1
    # 1. PowerGrid (geomに追加)
    update_geom_from_gds!(1, 2, zm2 + s_dpth - pg_dpth, pwrsrc["id"], "powergrid1")
    # 2. Silicon
    update_geom_from_gds!(1, 1, zm2, silicon["id"], "silicon1")

    # Chip 2
    update_geom_from_gds!(2, 2, zm5 + s_dpth - pg_dpth, pwrsrc["id"], "powergrid2")
    update_geom_from_gds!(2, 1, zm5, silicon["id"], "silicon2")

    # Chip 3
    update_geom_from_gds!(3, 2, zm8 + s_dpth - pg_dpth, pwrsrc["id"], "powergrid3")
    update_geom_from_gds!(3, 1, zm8, silicon["id"], "silicon3")

    println("FillPowerGrid (Legacy/Global)")
    FillPowerGrid!(ID, ox, Δh, Z)
    
    println("FillPlate (Base Geometry: PG & Si)")
    FillPlate!(ID, ox, Δh, Z)

    # TSV generation (Random/Manual)
    println("Generating & Filling TSVs...")
    
    c1, r1, h1 = generate_tsv_coordinates(1)
    FillTSV_Random!(ID, ox, Δh, Z, zm2, s_dpth, c1, r1)

    c2, r2, h2 = generate_tsv_coordinates(2)
    FillTSV_Random!(ID, ox, Δh, Z, zm5, s_dpth, c2, r2)

    c3, r3, h3 = generate_tsv_coordinates(3)
    FillTSV_Random!(ID, ox, Δh, Z, zm8, s_dpth, c3, r3)

    println("FillTSV (GDS)")
    FillTSV_gds!(ID, ox, Δh, Z)
    
    # println("FillSolder (Legacy GDS)")
    # FillSolder!(ID, ox, Δh, Z)
    
    # ユーザー要望: はんだバンプ生成を一番最後に行う
    println("FillResin")
    FillResin!(ID) # ここで 0 -> Resin

    println("Filling Solder Bump (Overwriting Resin)...")
    # 半径計算: 層間厚さ(d_ufill) の 1.3倍の直径 => 半径 = 1.3 * d / 2
    r_solder = (1.3 * d_ufill) / 2.0
    
    z_solder1 = (zm1 + zm2) / 2.0
    FillSolder_Random!(ID, ox, Δh, Z, z_solder1, c1, r_solder)

    z_solder2 = (zm4 + zm5) / 2.0
    FillSolder_Random!(ID, ox, Δh, Z, z_solder2, c2, r_solder)

    z_solder3 = (zm7 + zm8) / 2.0
    FillSolder_Random!(ID, ox, Δh, Z, z_solder3, c3, r_solder)

    # Top Layer Solder (Between Si3 and HeatSink)
    # Si3 Top = zm10 (0.5), HeatSink Bottom = zm11 (0.55)
    z_solder_top = (zm10 + zm11) / 2.0
    FillSolder_Random!(ID, ox, Δh, Z, z_solder_top, c3, r_solder)
end

# @param NXY  Number of inner cells for X&Y dir.
# @param NZ   Number of inner cells for Z dir.
function model_test(NXY::Int64, NZ::Int64=13)
    MX = MY = NXY + 2  # Number of CVs including boundary cells
    NZ = 13

    MZ = NZ + 2

    dx::Float64 = 1.2e-3 / NXY
    dy::Float64 = 1.2e-3 / NXY
    dz::Float64 = zm12 / NZ
    Δh = (dx, dy, dz) 
    ox = (0.0, 0.0, 0.0)
    SZ = (MX, MY, MZ)
    println(SZ)
    println(Δh)
    
    ID = zeros(UInt8, SZ[1], SZ[2], SZ[3])
    genZ!(Z, SZ, ox, Δh[3])

    @time fillID!(ID, ox, Δh, Z)


    #plot_slice(ID, SZ, "id.png")
end

end # end of moduleA

if abspath(PROGRAM_FILE) == @__FILE__
    using .modelA
    model_test(240,120)
end

