# legacy_run_wrapper.jl
# 外部プロセスでレガシーFVMソルバーを実行するためのラッパー

# レガシーのsrcディレクトリをロードパスに追加
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

# 必要なモジュールをロードするためのinclude
include(joinpath(@__DIR__, "src", "heat3ds.jl"))

using JLD2
using Printf
using LinearAlgebra

function run_wrapper()
    # 引数の解析
    id_map_path = ""
    i = 1
    while i <= length(ARGS)
        if ARGS[i] == "--id-map" && i < length(ARGS)
            id_map_path = ARGS[i+1]
            i += 2
        else
            i += 1
        end
    end

    if isempty(id_map_path)
        error("Usage: julia legacy_run_wrapper.jl --id-map <path_to_jld2>")
    end

    println("Loading input JLD2 file from: ", id_map_path)

    # ファイルのロード
    data = jldopen(id_map_path, "r") do file
        id_map = haskey(file, "id_map") ? file["id_map"] : file["ID"]
        lambda = haskey(file, "lambda") ? file["lambda"] : file["λ"]
        rho = haskey(file, "rho") ? file["rho"] : file["ρ"]
        cp = file["cp"]
        Z = file["Z"]
        return id_map, lambda, rho, cp, Z
    end
    id_map, lambda, rho, cp, Z = data

    MX, MY, MZ = size(id_map)
    NX = MX - 2
    NY = MY - 2
    NZ = MZ - 2

    println("Grid size: NX=$NX, NY=$NY, NZ=$NZ")

    # WorkBuffersの作成とデータ注入
    wk = WorkBuffers(MX, MY, MZ)
    wk.λ .= lambda
    wk.ρ .= rho
    wk.cp .= cp

    # 境界条件設定と適用
    bc_set = set_mode3_bc_parameters()
    θ_init = 300.0
    wk.θ .= θ_init

    # apply_boundary_conditions! の呼び出し
    BoundaryConditions.apply_boundary_conditions!(wk.θ, wk.λ, wk.ρ, wk.cp, wk.mask, bc_set)

    # 座標系の構築
    Z_gen, ZC, ΔZ = Zcoordinate.genZ!(NZ)

    # 物性値、境界条件を適用した状態で、mainを実行
    solver = "pbicgstab"
    smoother = "gs"
    epsilon = 1e-6
    par = "sequential"
    is_steady = true

    dx = 1.2e-3 / NX
    dy = 1.2e-3 / NY
    Δh = (dx, dy, 1.0)
    Δt = 10000.0

    global itr_tol = epsilon

    println("Running legacy FVM solver...")
    conv_data = main(Δh, Δt, wk, ZC, ΔZ, id_map, solver, smoother, bc_set, par; is_steady=is_steady)
    println("Solver finished.")

    # 出力パスの決定
    output_path = joinpath(dirname(id_map_path), "temp_legacy_temp.jld2")
    println("Saving results to: ", output_path)

    # 結果の保存
    jldsave(output_path; theta_legacy=wk.θ)
    println("Success.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_wrapper()
end
