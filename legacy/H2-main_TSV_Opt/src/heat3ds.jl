using Printf
using LinearAlgebra
using FLoops
using ThreadsX

include("common.jl")
using Statistics

"""
    compute_metrics(T, Δh, SZ) -> (max_grad, std_dev)

Calculate thermal metrics:
1. Max Spatial Gradient [K/m]
2. Standard Deviation [K]
"""
function compute_metrics(T::Array{Float64,3}, Δh, SZ)
    max_grad = 0.0
    
    # Gradient Calculation (exclude boundary)
    for k in 2:SZ[3]-1, j in 2:SZ[2]-1, i in 2:SZ[1]-1
        # Central difference for internal nodes
        dTdx = (T[i+1,j,k] - T[i-1,j,k]) / (2 * Δh[1])
        dTdy = (T[i,j+1,k] - T[i,j-1,k]) / (2 * Δh[2])
        dTdz = (T[i,j,k+1] - T[i,j,k-1]) / (2 * Δh[3]) # Approximate for NonUniform Z if Δh[3] is average, but here we assume uniformity or use specific logic
        # Note: accurate gradient for NU grid requires actual Z coordinates. 
        # For metric comparison, using average dz (1.0 in Δh, scaled by actual physical) or just neighbor diff is sufficient proxy.
        # However, Δh stored in struct might be non-dimensional or uniform. 
        # Let's check main(): dx, dy are explicit. Δh[3] is 1.0. Z grid is NonUniform.
        # This function signature takes Δh, but we need Z for accurate Z-gradient.
        # For now, we ignore Z-gradient or approximate? 
        # Actually, let's just use Max(dT) for simplicity or strictly XY gradient?
        # Let's consider only Lateral Gradient for Warpage/Stress? 
        # No, vertical stress is also important.
        
        grad_mag = sqrt(dTdx^2 + dTdy^2) # Focus on In-Plane Gradient for now as Z-grid is irregular
        if grad_mag > max_grad
            max_grad = grad_mag
        end
    end

    # Standard Deviation (Population)
    # Using only internal non-boundary cells
    inner_temps = T[2:SZ[1]-1, 2:SZ[2]-1, 2:SZ[3]-1]
    std_dev = std(inner_temps, corrected=false) # Population std dev
    
    return max_grad, std_dev
end
include("modelA.jl")
include("boundary_conditions.jl")
include("Zcoord.jl")
include("RHS.jl")
include("NonUniform.jl")
include("plotter.jl")
include("convergence_history.jl")
include("parse_log_residuals.jl")

using .Common
using .Common: WorkBuffers, ItrMax, Q_src, get_backend
using .NonUniform
using .NonUniform: PBiCGSTAB!, CG!, calRHS!
using .RHSCore
using .BoundaryConditions

"""
Mode3用の境界条件（NonUniform格子のIC問題）  
Z下面: PCB温度、Z上面: 熱伝達、側面: 断熱
"""
function set_mode3_bc_parameters()
    θ_amb = 300.0 # [K]
    θ_pcb = 300.0 # [K]
    HT_top = 5.0 # 2.98e-4 # 5 [W/(m^2 K)] / (\rho C)_silicon > [m/s]
    HT_side = 5.0 # 2.98e-6 # 5 [W/(m^2 K)] / (\rho C)_silicon > [m/s]
    
    # 各面の境界条件を定義
    x_minus_bc = BoundaryConditions.convection_bc(HT_side, θ_amb)
    x_plus_bc  = BoundaryConditions.convection_bc(HT_side, θ_amb)
    y_minus_bc = BoundaryConditions.convection_bc(HT_side, θ_amb)  
    y_plus_bc  = BoundaryConditions.convection_bc(HT_side, θ_amb)
    z_minus_bc = BoundaryConditions.isothermal_bc(θ_pcb)                  # Z軸負方向面: PCB温度
    z_plus_bc  = BoundaryConditions.convection_bc(HT_top, θ_amb)          # Z軸正方向面: 熱伝達
    #z_plus_bc  = BoundaryConditions.heat_flux_bc(100000.0)          # Z軸正方向面: 5 [W/m^2] 熱流束
    
    # 境界条件セットを作成
    return BoundaryConditions.create_boundary_conditions(x_minus_bc, x_plus_bc,
                                      y_minus_bc, y_plus_bc,
                                      z_minus_bc, z_plus_bc)
end



"""
@brief 計算領域内部の熱源項の設定
@param [in,out] hs   熱源
@param [in]     ID   識別子配列
"""
function HeatSrc!(hs::Array{Float64,3}, ID::Array{UInt8,3}, par)
    backend = get_backend(par)
    SZ = size(hs)
    
    @floop backend for k in 2:SZ[3]-1, j in 2:SZ[2]-1, i in 2:SZ[1]-1
        if ID[i,j,k] == modelA.pwrsrc["id"]
            hs[i,j,k] = Q_src
        end
    end
end


function conditions(F, SZ, Δh, solver, smoother)

    @printf(F, "Problem : IC on NonUniform grid (Opt. 13 layers)\n")

    @printf(F, "Grid  : %d %d %d\n", SZ[1], SZ[2], SZ[3])
    @printf(F, "Pitch : %6.4e %6.4e %6.4e\n", Δh[1], Δh[2], Δh[3])
    if solver=="pbicgstab" || solver=="cg"
        if isempty(smoother)
            @printf(F, "Solver: %s without preconditioner\n", solver)
        else
            @printf(F, "Solver: %s with smoother %s\n", solver, smoother)
        end
    else
        @printf(F, "Solver: %s\n", solver)
    end
    @printf(F, "ItrMax : %e\n", ItrMax)
    @printf(F, "ε      : %e\n", itr_tol)
end

"""
モデル作成
@param [in] λ   温度拡散係数
"""
function preprocess!(λ, ρ, cp, Z, ox, Δh, ID)
    SZ = size(λ)
    
    # GDSII連携: 3つのチップモデルを読み込み (Original Verification)
    modelA.load_gds_geometry!("org_chip1.gds", 1)
    modelA.load_gds_geometry!("org_chip2.gds", 2)
    modelA.load_gds_geometry!("org_chip3.gds", 3)

    modelA.fillID!(ID, ox, Δh, Z)
    modelA.setProperties!(λ, ρ, cp, ID)
end


"""
@param [in] Δh       セル幅
@param [in] Δt       時間積分幅
@param [in] wk       ベクトル群
@param [in] ZC       CVセンター座標
@param [in] ΔZ       CV幅
@param [in] solver   ["sor", "pbicgstab", "cg"]
@param [in] smoother ["gs", ""]
@param [in] is_steady 定常解析フラグ
"""
function main(Δh, Δt, wk, ZC, ΔZ, ID, solver, smoother, bc_set, par; is_steady::Bool=false)
  # 収束履歴の初期化
  conv_data = ConvergenceData(solver, smoother)

  SZ = size(wk.θ)

  qsrf = zeros(Float64, SZ[1], SZ[2])

  HeatSrc!(wk.hsrc, ID, par)

  # HC配列を生成（境界条件から）
  HC = BoundaryConditions.set_BC_coef(bc_set)

  F = open("log.txt", "w")
  conditions(F, SZ, Δh, solver, smoother)
  time::Float64 = 0.0
  nt::Int64 = 1

  for step in 1:nt
    time += Δt

    calRHS!(wk, Δh, Δt, ΔZ, bc_set, qsrf, par, is_steady=is_steady)

    # ソルバー呼び出しを修正
    if solver == "cg"
      smoother_sym = smoother == "gs" ? :gs : :none
      isconverged, itr, res0 = NonUniform.CG!(wk, Δh, Δt, ZC, ΔZ, HC,
                                   tol=itr_tol, smoother=smoother_sym,
                                   par=par, verbose=true, is_steady=is_steady)
    else
      smoother_sym = smoother == "gs" ? :gs : :none
      isconverged, itr, res0 = NonUniform.PBiCGSTAB!(wk, Δh, Δt, ZC, ΔZ, HC,
                                          tol=itr_tol, smoother=smoother_sym,
                                          par=par, verbose=true, is_steady=is_steady)
    end

    if !isconverged
      @warn "Solver did not converge at step $(step)"
    end

    s = @view wk.θ[2:SZ[1]-1, 2:SZ[2]-1, 2:SZ[3]-1]
    min_val = minimum(s)
    max_val = maximum(s)
    @printf(F, "%d %f : θmin=%e  θmax=%e  L2 norm of θ=%e\n", step, time, min_val, max_val, norm(s,2))
  end

  close(F)

  # ログファイルから残差データを解析してconv_dataに追加
  parse_residuals_from_log!(conv_data, "log.txt")

  # 収束履歴データを返す
  return conv_data
end


using JSON  # Added for config loading

"""
    init_config(json_path) -> Dict

JSON設定ファイルを読み込み、辞書として返す。
"""
function init_config(json_path::String)
    if !isfile(json_path)
        error("Config file not found: $json_path")
    end
    return JSON.parsefile(json_path)
end

#=
@param NXY  Number of inner cells for X&Y dir.
@param NZ   Number of inner cells for Z dir.
@param [in] solver    ["jacobi", "sor", "pbicgstab"]
@param [in] smoother  ["jacobi", "gs", ""]
@param [in] is_steady 定常解析フラグ
=#
function q3d(NX::Int, NY::Int, NZ::Int,
         solver::String="sor", smoother::String="";
         epsilon::Float64=1.0e-6, par::String="thread", is_steady::Bool=false)
    global itr_tol = epsilon

    println("Julia version: $(VERSION)")

    if par=="sequential"
        println("Sequential execution")
    elseif par=="thread"
        println("Available num. of threads: ", Threads.nthreads())
    else
        println("Invalid paralle mode")
        exit()
    end

    if is_steady
        println("Analysis mode: Steady-state")
    else
        println("Analysis mode: Transient")
    end

    # 1. Load Configuration
    config_path = "config.json"
    if !isfile(config_path)
        println("Config not found, generating default...")
        include("generate_config.jl")
    end
    
    println("Loading configuration from $config_path")
    config = init_config(config_path)
    

    # 2. Setup Model Parameters (Materials & Dimensions)
    # This now sets zm0..zm12 globals from JSON layers
    modelA.set_model_params!(config)
    
    # 3. Generate Z-grid (Legacy Mode using updated zm Globals)
    # Note: NZ must be compatible with Zcase2 structure (e.g. 30).
    # If config layers change, Zcase2 might need adjustment, but for now we assume 30.
    
    println("Generating Z-grid using legacy genZ! with updated model params...")
    
    MX = NX + 2  # Number of CVs including boundaries
    MY = NY + 2  # Number of CVs including boundaries
    MZ = NZ + 2
    SZ = (MX, MY, MZ)
    
    println("="^60)
    println(SZ, "  Itr.ε= ", itr_tol)

    dx = 1.2e-3 / NX
    dy = 1.2e-3 / NY
    dx = round(dx,digits=8)
    dy = round(dy,digits=8)

    Δh = (dx, dy, 1.0)
    ox = (0.0, 0.0, 0.0) #原点を仮定

    ID   = zeros(UInt8, SZ[1], SZ[2], SZ[3])

    wk = WorkBuffers(MX, MY, MZ)

    # Legacy genZ! call (Using zm constants set by set_model_params!)
    Z, ZC, ΔZ = Zcoordinate.genZ!(NZ)

    @time preprocess!(wk.λ, wk.ρ, wk.cp, Z, ox, Δh, ID)

    mode::Int64 = 3
    plot_slice_xz_nu(1, mode, wk.λ, 0.3e-3, SZ, ox, Δh, Z, "alpha3.png", "α")



    # 2. 初期IDと物性値の分布を確認（GDS反映の確認用）
    println("Plotting material distribution...")
    
    # IDマップのプロット（シリコン、熱源、TSVを一括確認）
    # Float64に変換してプロット関数に渡す
    id_f = Float64.(ID)
    
    # Chip 1 (z=0.198mm付近: PowerGrid Layer)
    plot_slice_xy_nu(1, 1, id_f, 0.198e-3, SZ, ox, Δh, Z, "check_dist_id_z=0.198.png", "MatID")
    
    # Chip 2 (z=0.348mm付近: PowerGrid Layer) 
    # zm4=0.2 (Si1 End) + 0.05(UF2) = 0.25 (Si2 Start). Si2=0.1mm => End=0.35.
    # PG is near 0.35. Let's check 0.348.
    plot_slice_xy_nu(1, 1, id_f, 0.348e-3, SZ, ox, Δh, Z, "check_dist_id_z=0.348.png", "MatID")
    
    # Chip 3 (z=0.498mm付近: PowerGrid Layer)
    # zm7=0.35 + 0.05(UF3) = 0.4 (Si3 Start). Si3=0.1mm => End=0.5.
    # PG is near 0.5. Let's check 0.498.
    plot_slice_xy_nu(1, 1, id_f, 0.498e-3, SZ, ox, Δh, Z, "check_dist_id_z=0.498.png", "MatID")

    # シリコン層の確認用 (熱伝導率 λ をプロット)
    plot_slice_xy_nu(1, 1, wk.λ, 0.198e-3, SZ, ox, Δh, Z, "check_dist_silicon_z=0.198.png", "λ")
    plot_slice_xy_nu(1, 1, wk.λ, 0.448e-3, SZ, ox, Δh, Z, "check_dist_silicon_z=0.448.png", "λ")
    
    # 発熱層の確認用 (熱源分布 hsrc をプロット)
    HeatSrc!(wk.hsrc, ID, par) # プロット前に熱源をセット
    plot_slice_xy_nu(1, 1, wk.hsrc, 0.198e-3, SZ, ox, Δh, Z, "check_dist_heatsrc_z=0.198.png", "Q")
    plot_slice_xy_nu(1, 1, wk.hsrc, 0.498e-3, SZ, ox, Δh, Z, "check_dist_heatsrc_z=0.498.png", "Q")

    # 3. Solver Setup
    bc_set = set_mode3_bc_parameters()
    θ_init = 300.0
    Δt::Float64 = 10000.0

    wk.θ .= θ_init # 初期温度設定

    BoundaryConditions.print_boundary_conditions(bc_set)
    BoundaryConditions.apply_boundary_conditions!(wk.θ, wk.λ, wk.ρ, wk.cp, wk.mask, bc_set)

    tm = @elapsed conv_data = main(Δh, Δt, wk, ZC, ΔZ, ID, solver, smoother, bc_set, par, is_steady=is_steady)

    
    plot_slice_xz_nu(2, mode, wk.θ, 0.3e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.3.png")
    plot_slice_xz_nu(2, mode, wk.θ, 0.4e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.4.png")
    plot_slice_xz_nu(2, mode, wk.θ, 0.5e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.5.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.18e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.18.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.33e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.33.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.48e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.48.png")
    plot_line_z_nu(wk.θ, SZ, ox, Δh, Z, 0.6e-3, 0.6e-3,"temp3Z_ctr", "Center")
    plot_line_z_nu(wk.θ, SZ, ox, Δh, Z, 0.4e-3, 0.4e-3,"temp3Z_tsv", "TSV")
    
    # 収束履歴の出力（反復解法の場合のみ）
    if solver == "pbicgstab" || solver == "cg"
        # 収束グラフとCSV出力
        conv_filename = "convergence_$(solver)_$(NX)x$(NY)x$(NZ)"
        if !isempty(smoother)
            conv_filename *= "_$(smoother)"
        end

        # プロットとCSV出力
        try
            plot_convergence_curve(conv_data, "$(conv_filename).png", target_tol=itr_tol, show_markers=false)
            export_convergence_csv(conv_data, "$(conv_filename).csv")
        catch e
            println("Error in convergence history output: $e")
        end

        # 収束情報の表示
        info = get_convergence_info(conv_data)
        if !isempty(info)
            println("\n=== Convergence Information ===")
            println("Grid: $(NX)x$(NY)x$(NZ)")
            println("Solver: $(info["solver"]), Smoother: $(info["smoother"])")
            println("Iterations: $(info["iterations"])")
            initial_res_str = @sprintf("%.6E", info["initial_residual"])
            final_res_str = @sprintf("%.6E", info["final_residual"])
            conv_rate_str = @sprintf("%.6E", info["convergence_rate"])
            reduction_str = @sprintf("%.2f", info["reduction_factor"])
            println("Initial residual: $initial_res_str")
            println("Final residual: $final_res_str")
            println("Residual reduction factor: $conv_rate_str")
            println("Order reduction: $reduction_str")
            println("===============================")
        end
    end

    # Calculate Evaluation Metrics
    println("\n=== Thermal Metrics ===")
    max_grad, std_dev = compute_metrics(wk.θ, Δh, SZ)
    @printf("Max Gradient: %.4e [K/m]\n", max_grad)
    @printf("Std Deviation: %.4f [K]\n", std_dev)
    println("=======================\n")

    println(tm, "[sec]")
    println(" ")
end

if abspath(PROGRAM_FILE) == @__FILE__
  q3d(240, 240, 30, "pbicgstab", "gs", epsilon=1.0e-4, par="sequential", is_steady=true)
  #q3d(240, 240, 31, "cg", "gs", epsilon=1.0e-4, par="sequential", is_steady=true)
  #q3d(40, 40, 31, "cg", "", epsilon=1.0e-4, par="sequential")
  #q3d(40, 40, 31, "pbicgstab", "gs", epsilon=1.0e-4, par="sequential")
  #q3d(40, 40, 31, "cg", "gs", epsilon=1.0e-4, par="sequential")
end
