module Zcoordinate
export Zcase1!, Zcase2!, Zcase3!, genZ!

using Printf
import ..modelA

"""
    read_grid_file(filename)

ASCIIファイルから格子点座標を読み込む

# Arguments
- `filename::String`: 入力ファイル名

# Returns
- `coord::Vector{Float64}`: 格子点座標配列
- `numNodes::Int`: 格子点数
"""
function read_grid_file(filename::String="grid.txt")
  if !isfile(filename)
    error("ファイルが見つかりません: $filename")
  end
  
  coord = Float64[]
  numNodes = 0
  
  open(filename, "r") do f
    # 1行目: 格子点数を読み込み
    line = readline(f)
    numNodes = parse(Int, strip(line))
    
    # 座標配列を初期化
    coord = zeros(Float64, numNodes)
    
    # 格子点データを読み込み
    for i in 1:numNodes
      line = readline(f)
      parts = split(strip(line))
      
      if length(parts) != 2
        error("ファイル形式エラー（行$(i+1)）: $line")
      end
      
      grid_index = parse(Int, parts[1])
      grid_coord = parse(Float64, parts[2])
      
      # 格子点番号の整合性チェック（1オリジン）
      if grid_index != i
        @warn "格子点番号が期待値と異なります: 期待値=$i, 実際値=$grid_index"
      end
      
      coord[i] = grid_coord
    end
  end
    
  println("格子点データ読み込み完了:")
  @printf("  ファイル: %s\n", filename)
  @printf("  格子点数: %d\n", numNodes)
  @printf("  座標範囲: [%.6f, %.6f]\n", minimum(coord), maximum(coord))
  
  return coord, numNodes
end


function Zcase1!(Z::Vector{Float64})
    if length(Z) != 15
        println("MZ must be 15")
        exit(0)
    end
    p = 0.005e-3
    Z[1] = 2.0*modelA.zm0-modelA.zm1
    Z[2] = modelA.zm0
    Z[3] = modelA.zm1
    Z[4] = modelA.zm2
    Z[5] = modelA.zm3
    Z[6] = modelA.zm4
    Z[7] = modelA.zm5
    Z[8] = modelA.zm6
    Z[9] = modelA.zm7
    Z[10]= modelA.zm8
    Z[11]= modelA.zm9
    Z[12]= modelA.zm10
    Z[13]= modelA.zm11
    Z[14]= modelA.zm12
    Z[15]= 2.0*modelA.zm12-modelA.zm11
end


function Zcase2!(nk::Int64)
  # NOTE: nk argument is kept for compatibility but logic is hardcoded for specific structure
  # If we want truly dynamic, Zcase2 needs to be smarter or we trust modelA.zm markers are set correctly.
  # Original code used hardcoded index logic.
  # We will assume a specific standard mesh count or dynamic sizing based on layers?
  # Original code had fixed size array Z=zeros(nk+1) where nk was likely 30.
  
  # For the reverted logic to work with JSON-driven "divisions", we need to know total nodes.
  # Or we reconstruct Z vector dynamically using modelA's markers.
  
  # Wait, the user wants zm0~12 constants to be calculated from JSON.
  # And Zcoord to use them.
  # If the layer count/structure changes, Zcase2 logic (indices 1..31) breaks.
  # Assuming the topology (3 chips, 4 underfills, etc.) is FIXED for now, just dimensions change.
  # If so, we keep the original index logic.
  
  # Original Zcase2! logic:
  Z = zeros(Float64, 31) # Fixed 30 defined intervals as per original code

    p = 0.005e-3
    Z[1] = modelA.zm0
    Z[2] = modelA.zm0 + p
    Z[3] = modelA.zm1 - p
    Z[4] = modelA.zm1
    Z[5] = modelA.zm1 + p
    Z[6] = modelA.zm2 - p
    Z[7] = modelA.zm2
    Z[8] = modelA.zm2 + p
    Z[9] = modelA.zm3 - p
    Z[10]= modelA.zm3
    Z[11]= modelA.zm4
    Z[12]= modelA.zm4 + p
    Z[13]= modelA.zm5 - p
    Z[14]= modelA.zm5
    Z[15]= modelA.zm5 + p
    Z[16]= modelA.zm6 - p
    Z[17]= modelA.zm6
    Z[18]= modelA.zm7
    Z[19]= modelA.zm7 + p
    Z[20]= modelA.zm8 - p
    Z[21]= modelA.zm8
    Z[22]= modelA.zm8 + p
    Z[23]= modelA.zm9 - p
    Z[24]= modelA.zm9 
    Z[25]= modelA.zm10
    Z[26]= modelA.zm10 + p
    Z[27]= modelA.zm11 - p
    Z[28]= modelA.zm11
    Z[29]= modelA.zm11 + p
    Z[30]= modelA.zm12 - p
    Z[31]= modelA.zm12
    return Z
end

function Zcase3!(Z::Vector{Float64}, ox, dz)
    for k in 1:length(Z)
        Z[k] = ox[3] + (k-2)*dz
    end
end

# Z軸座標の生成（CommonSolver準拠版）
function genZ!(nk)
  # nk is ignored/checked against hardcoded 30?
  # If user changed divisions, nk will change.
  # But Zcase2! above is HARDCODED to 31 points (30 cells).
  # This implies the JSON "divisions" are IGNORED in this reverted path, 
  # or we must update Zcase2 to be dynamic using zm list.
  
  # For strict reversion requested:
  z_face = Zcase2!(nk)
  
  # If nk != 30, this asserts. But user wants JSON control.
  # "JSONで厚さを与え、zmの定数を計算するように" -> implied topology is same?
  # If topology is same, nk=30 is fine?
  # But "Z方向の分割数が増えている" check implies user Liked the refined mesh.
  # Reverting this makes it coarse again? 
  # USER SAID "Zcoordに関しては他(JSON logic)には変更しなくてよい" -> Revert to "using zm constants".
  # User wants to set zm0..12 from JSON.
  
  @assert length(z_face) == nk + 1 "z_face length must equal nk + 1"

  dz = diff(z_face) # dz[nk]

  # dz_grid（ガイドセル込み、nk+2個）
  dz_grid = zeros(Float64, nk+2)
  dz_grid[2:nk+1] = dz[1:nk]
  dz_grid[1] = dz_grid[2]
  dz_grid[nk+2] = dz_grid[nk+1]

  # z_centers（ガイドセル込み、nk+2個）
  z_centers = zeros(Float64, nk+2)

  # ガイドセル
  z_centers[1] = z_face[1]        # 底面ガイドセル
  z_centers[nk+2] = z_face[nk+1]  # 表面ガイドセル

  # 全物理セル（k=2からnk+1まで）を中点で計算
  # 底面・表面セルも含めて隣接境界面の中点とする（CommonSolver準拠）
  for k in 2:(nk+1)
    z_centers[k] = (z_face[k] + z_face[k-1]) * 0.5
  end

  # Z配列（境界座標の拡張版、nk+3個）
  # z_face配列の前後に線形外挿で1点ずつ追加
  Z = zeros(Float64, nk+3)
  Z[2:nk+2] = z_face[1:nk+1]
  Z[1] = 2*z_face[1] - z_face[2]           # 前方外挿
  Z[nk+3] = 2*z_face[nk+1] - z_face[nk]    # 後方外挿

  return Z, z_centers, dz_grid
end

end # end of module