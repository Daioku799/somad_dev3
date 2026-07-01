#!/usr/bin/env julia

"""
材料分布の可視化スクリプト

TSV配置（XY平面）と層構造（YZ平面）を可視化します。
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

include("src/common.jl")
include("src/modelA.jl")
include("src/Zcoord.jl")
include("src/plotter.jl")

using .Common
using .Zcoordinate

# グリッドサイズ（XY方向を3倍に細分化: 80->240）
NX = 240
NY = 240
NZ = 30

MX = NX + 2
MY = NY + 2
MZ = NZ + 2
SZ = (MX, MY, MZ)

# グリッド間隔
dx = 1.2e-3 / NX
dy = 1.2e-3 / NY
Δh = (dx, dy, 1.0)
ox = (0.0, 0.0, 0.0)

# Z座標生成
Z, ZC, ΔZ = Zcoordinate.genZ!(NZ)

# ID配列の初期化
ID = zeros(UInt8, SZ[1], SZ[2], SZ[3])

# モデル構築
println("Building model...")
@time modelA.fillID!(ID, ox, Δh, Z)

println("\nGenerating material distribution plots...")

# XY平面（TSV配置確認）
# 各チップ層でプロット
plot_material_xy_nu(ID, 0.15e-3, SZ, ox, Δh, Z, "material_xy_chip1.png")  # Chip 1
plot_material_xy_nu(ID, 0.30e-3, SZ, ox, Δh, Z, "material_xy_chip2.png")  # Chip 2
plot_material_xy_nu(ID, 0.45e-3, SZ, ox, Δh, Z, "material_xy_chip3.png")  # Chip 3

# YZ平面（層構造確認）
# 中心と端でプロット
plot_material_yz_nu(ID, 0.6e-3, SZ, ox, Δh, Z, "material_yz_center.png")  # 中心
plot_material_yz_nu(ID, 0.3e-3, SZ, ox, Δh, Z, "material_yz_x=0.3.png")   # X=0.3mm
plot_material_yz_nu(ID, 0.9e-3, SZ, ox, Δh, Z, "material_yz_x=0.9.png")   # X=0.9mm

# 熱源とTSVの重ね合わせ図
println("\nGenerating heat source & TSV overlay plots...")
# PowerGrid位置: zm + s_dpth - pg_dpth = 0.1 + 0.1 - 0.005 = 0.195mm
plot_heatsource_tsv_overlay_nu(ID, 0.198e-3, SZ, ox, Δh, Z, "overlay_chip1.png")  # Chip 1 PowerGrid
plot_heatsource_tsv_overlay_nu(ID, 0.348e-3, SZ, ox, Δh, Z, "overlay_chip2.png")  # Chip 2 PowerGrid
plot_heatsource_tsv_overlay_nu(ID, 0.498e-3, SZ, ox, Δh, Z, "overlay_chip3.png")  # Chip 3 PowerGrid

println("\n✓ Material distribution plots generated successfully!")
println("  - material_xy_chip*.png : TSV layout in each chip")
println("  - material_yz_*.png     : Layer structure")
println("  - overlay_chip*.png     : Heat source & TSV overlay")
