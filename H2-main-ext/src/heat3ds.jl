using Printf
using LinearAlgebra
using FLoops
using ThreadsX
using JLD2 # Added

include("common.jl")
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
using .modelA 

"""
Mode3用の境界条件（NonUniform格子のIC問題）  
Z下面: PCB温度、Z上面: 熱伝達、側面: 断熱
"""
function set_mode3_bc_parameters()
    θ_amb = 300.0 # [K]
    θ_pcb = 300.0 # [K]
    HT_top = 5.0 
    HT_side = 5.0 
    
    x_minus_bc = BoundaryConditions.convection_bc(HT_side, θ_amb)
    x_plus_bc  = BoundaryConditions.convection_bc(HT_side, θ_amb)
    y_minus_bc = BoundaryConditions.convection_bc(HT_side, θ_amb)  
    y_plus_bc  = BoundaryConditions.convection_bc(HT_side, θ_amb)
    z_minus_bc = BoundaryConditions.isothermal_bc(θ_pcb)                  
    z_plus_bc  = BoundaryConditions.convection_bc(HT_top, θ_amb)          
    
    return BoundaryConditions.create_boundary_conditions(x_minus_bc, x_plus_bc,
                                      y_minus_bc, y_plus_bc,
                                      z_minus_bc, z_plus_bc)
end

"""
@brief 計算領域内部の熱源項の設定
"""
function HeatSrc!(hs::Array{Float64,3}, ID::Array{UInt8,3}, par)
    backend = get_backend(par)
    SZ = size(hs)
    # PowerSource ID is fixed to 7 in Defaults.jl
    @floop backend for k in 2:SZ[3]-1, j in 2:SZ[2]-1, i in 2:SZ[1]-1
        if ID[i,j,k] == 7
            hs[i,j,k] = Q_src
        end
    end
end

function conditions(F, SZ, Δh, solver, smoother)
    @printf(F, "Problem : IC on NonUniform grid (Dynamic Config)\n")
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

function main(Δh, Δt, wk, ZC, ΔZ, ID, solver, smoother, bc_set, par; is_steady::Bool=false)
  conv_data = ConvergenceData(solver, smoother)
  SZ = size(wk.θ)
  qsrf = zeros(Float64, SZ[1], SZ[2])
  HeatSrc!(wk.hsrc, ID, par)
  HC = BoundaryConditions.set_BC_coef(bc_set)
  F = open("log.txt", "w")
  conditions(F, SZ, Δh, solver, smoother)
  time::Float64 = 0.0
  nt::Int64 = 1
  for step in 1:nt
    time += Δt
    calRHS!(wk, Δh, Δt, ΔZ, bc_set, qsrf, par, is_steady=is_steady)
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
  parse_residuals_from_log!(conv_data, "log.txt")
  return conv_data
end

function q3d(NX::Int, NY::Int, NZ::Int,
         solver::String="sor", smoother::String="";
         epsilon::Float64=1.0e-6, par::String="thread", is_steady::Bool=false,
         snapshot_path::String="")
    global itr_tol = epsilon
    println("Julia version: $(VERSION)")

    # 1. Model Building using new architecture
    println("Building model...")
    # Use load_config if config.json exists, else generate_test_config
    config = isfile("config.json") ? modelA.ModelBuilder.ConfigLoader.load_config("config.json", "tsv_config.json") : 
                                    modelA.ModelBuilder.ConfigLoader.generate_test_config()
    ID, λ, ρ, cp, coordsys = modelA.ModelBuilder.build_model(config, NX)
    
    SZ = size(ID)
    MX, MY, MZ = SZ
    
    dx = config.lx / NX
    dy = config.ly / NY
    Δh = (dx, dy, 1.0)
    ox = (0.0, 0.0, 0.0)
    Z = coordsys.Z
    ZC = coordsys.z_centers
    ΔZ = coordsys.dz_grid

    println(SZ, "  Itr.ε= ", itr_tol)

    wk = WorkBuffers(MX, MY, MZ)
    wk.λ .= λ
    wk.ρ .= ρ
    wk.cp .= cp

    mode::Int64 = 3
    plot_slice_xz_nu(1, mode, wk.λ, 0.3e-3, SZ, ox, Δh, Z, "alpha3.png", "α")

    # 3. Boundary conditions
    bc_set = set_mode3_bc_parameters()
    θ_init = 300.0
    Δt::Float64 = 10000.0
    wk.θ .= θ_init 

    BoundaryConditions.print_boundary_conditions(bc_set)
    BoundaryConditions.apply_boundary_conditions!(wk.θ, wk.λ, wk.ρ, wk.cp, wk.mask, bc_set)

    # 4. Simulation
    tm = @elapsed conv_data = main(Δh, Δt, wk, ZC, ΔZ, ID, solver, smoother, bc_set, par, is_steady=is_steady)

    # 5. Result Plots
    plot_slice_xz_nu(2, mode, wk.θ, 0.3e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.3.png")
    plot_slice_xz_nu(2, mode, wk.θ, 0.4e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.4.png")
    plot_slice_xz_nu(2, mode, wk.θ, 0.5e-3, SZ, ox, Δh, Z, "temp3_xz_nu_y=0.5.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.18e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.18.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.33e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.33.png")
    plot_slice_xy_nu(2, mode, wk.θ, 0.48e-3, SZ, ox, Δh, Z, "temp3_xy_nu_z=0.48.png")
    plot_line_z_nu(wk.θ, SZ, ox, Δh, Z, 0.6e-3, 0.6e-3,"temp3Z_ctr", "Center")
    plot_line_z_nu(wk.θ, SZ, ox, Δh, Z, 0.4e-3, 0.4e-3,"temp3Z_tsv", "TSV")
    
    if solver == "pbicgstab" || solver == "cg"
        conv_filename = "convergence_$(solver)_$(NX)x$(NY)x$(NZ)"
        if !isempty(smoother)
            conv_filename *= "_$(smoother)"
        end
        try
            plot_convergence_curve(conv_data, "$(conv_filename).png", target_tol=itr_tol, show_markers=false)
            export_convergence_csv(conv_data, "$(conv_filename).csv")
        catch e
            println("Error in convergence history output: $e")
        end
        info = get_convergence_info(conv_data)
        if !isempty(info)
            println("\n=== Convergence Information ===")
            println("Grid: $(NX)x$(NY)x$(NZ)")
            println("Solver: $(info["solver"]), Smoother: $(info["smoother"])")
            println("Iterations: $(info["iterations"])")
            println("Initial residual: ", @sprintf("%.6E", info["initial_residual"]))
            println("Final residual: ", @sprintf("%.6E", info["final_residual"]))
            println("===============================")
        end
    end
    println(tm, "[sec]")
    println(" ")

    # 6. Save snapshot
    if !isempty(snapshot_path)
        println("Saving snapshot to: $snapshot_path")
        JLD2.save(snapshot_path, Dict(
            "theta" => wk.θ,
            "id_map" => ID,
            "lambda" => wk.λ,
            "z_centers" => ZC,
            "z_faces" => Z,
            "nx" => NX, "ny" => NY, "nz" => NZ,
            "config_summary" => Dict(
                "tsv_count" => length(config.tsv.coords),
                "tsv_radius" => config.tsv.radius,
                "tsv_coords" => config.tsv.coords
            )
        ))
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
  q3d(240, 240, 30, "pbicgstab", "gs", epsilon=1.0e-4, par="sequential", is_steady=true)
end
