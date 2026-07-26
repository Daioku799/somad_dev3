#!/usr/bin/env julia

# evaluate_rom_paper.jl
# 論文用ROM総合評価・データ収集スクリプト

using JLD2
using JSON3
using Printf
using LinearAlgebra
using Plots

# モジュールロードパスの設定
push!(LOAD_PATH, abspath("H2-main-ext/src"))
include(joinpath(abspath("H2-main-ext/src"), "modelA.jl"))
using .modelA

if !isdefined(Main, :PODEngine)
    include(abspath("H2-rom/src/PODEngine/PODEngine.jl"))
end
using .PODEngine

if !isdefined(Main, :ROMInterpolator)
    include(abspath("H2-rom/src/ROMInterpolator/ROMInterpolator.jl"))
end
using .ROMInterpolator

if !isdefined(Main, :ROMValidator)
    include(abspath("H2-rom/src/ROMValidator/ROMValidator.jl"))
end
using .ROMValidator

if !isdefined(Main, :PaperEvaluation)
    include(abspath("H2-rom/src/PaperEvaluation/PaperEvaluation.jl"))
end
using .PaperEvaluation

function main_paper_evaluation()
    println("==========================================================")
    println("      3D-IC Heat ROM - Paper Evaluation & Data Collection")
    println("==========================================================")

    paper_plots_dir = "plots/paper_evaluation"
    mkpath(paper_plots_dir)

    # 1. Manifestのパース
    manifest_path = "data/manifest.json"
    if !isfile(manifest_path)
        error("manifest.json not found. Run generate_snapshots.jl first!")
    end

    manifest_content = JSON3.read(read(manifest_path, String))
    cases = manifest_content.cases
    success_cases = filter(c -> c.status == "success", cases)
    println("[1/6] Manifest Loaded: ", length(success_cases), " successful snapshots found.")

    if length(success_cases) < 5
        error("Insufficient successful snapshots for evaluation.")
    end

    # 訓練・検証分割 (80% / 20%)
    n_total = length(success_cases)
    n_train = round(Int, n_total * 0.8)
    n_val = n_total - n_train
    println("      Dataset Split: Training = $n_train, Validation = $n_val")

    train_cases = success_cases[1:n_train]
    val_cases = success_cases[(n_train+1):end]
    trained_snapshot_ids = String[string(c.id) for c in train_cases]

    # 2. 訓練用スナップショットデータの読み込み
    println("[2/6] Loading Training Snapshots...")
    temp_fields_train = Vector{Float64}[]
    mu_list_train = Vector{Float64}[]

    grid_info = Dict{String, Any}()

    for (idx, c) in enumerate(train_cases)
        filepath = c.filepath
        if !isfile(filepath) && startswith(filepath, "../data/")
            filepath = replace(filepath, "../data/" => "data/")
        end
        
        jld = jldopen(filepath, "r")
        temp = jld["temperature"]
        meta = jld["metadata"]
        
        if idx == 1
            nx = jld["nx"]
            ny = jld["ny"]
            nz = jld["nz"]
            z_centers = vec(jld["z_centers"])
            z_faces = vec(jld["z_faces"])
            
            grid_info = Dict{String, Any}(
                "nx" => nx,
                "ny" => ny,
                "nz" => nz,
                "lx" => 1.2e-3,
                "ly" => 1.2e-3,
                "z_centers" => z_centers
            )
        end
        
        push!(temp_fields_train, vec(temp))
        push!(mu_list_train, vec(meta["mu"]))
        close(jld)
    end

    X_snap_train = reduce(hcat, temp_fields_train)
    Mu_train = reduce(hcat, mu_list_train)

    # 検証用スナップショットデータの読み込み
    temp_fields_val = Vector{Float64}[]
    mu_list_val = Vector{Float64}[]

    for c in val_cases
        filepath = c.filepath
        if !isfile(filepath) && startswith(filepath, "../data/")
            filepath = replace(filepath, "../data/" => "data/")
        end
        jld = jldopen(filepath, "r")
        push!(temp_fields_val, vec(jld["temperature"]))
        push!(mu_list_val, vec(jld["metadata"]["mu"]))
        close(jld)
    end

    X_snap_val = reduce(hcat, temp_fields_val)
    Mu_val = reduce(hcat, mu_list_val)

    # 3. POD基底計算とSVD特異値減衰プロット
    println("[3/6] Computing POD & Generating SVD Decay Plots...")
    ric_threshold = 0.999
    
    # 時間計測
    (pod_result, pod_time) = PaperEvaluation.measure_time() do
        PODEngine.compute_pod(X_snap_train; ric_threshold=ric_threshold)
    end
    basis, singular_values, coeffs_train, mean_field = pod_result
    
    println("      POD computation completed in: ", PaperEvaluation.format_elapsed_time(pod_time))
    println("      Total Modes Extracted: ", size(basis, 2))

    svd_plot_path = joinpath(paper_plots_dir, "svd_decay_ric.png")
    PaperEvaluation.plot_svd_decay(singular_values, svd_plot_path)
    println("      Saved SVD Decay Plot to: ", svd_plot_path)

    # 4. RBFパラメータスイープ
    println("[4/6] Performing RBF Parameter Sweep (Epsilon & Lambda)...")
    epsilon_range = [0.5, 1.0, 1.5, 2.0, 3.0]
    lambda_range = [1e-8, 1e-6, 1e-4, 1e-2, 1e-1]

    PaperEvaluation.sweep_rbf_parameters(
        Mu_train, coeffs_train,
        Mu_val, X_snap_val,
        grid_info, basis, mean_field,
        epsilon_range, lambda_range,
        paper_plots_dir
    )
    println("      Saved RBF Sweep Heatmaps to: ", paper_plots_dir)

    # 5. メインROMモデル構築とモデルサイズ・時間の計測
    println("[5/6] Training Main ROM Model & Monitoring Size...")
    rom_model_dir = "data/models"
    mkpath(rom_model_dir)
    rom_model_path = joinpath(rom_model_dir, "trained_rom_model.jld2")

    (rom_model, rbf_time) = PaperEvaluation.measure_time() do
        ROMInterpolator.train_rom(Mu_train, coeffs_train, rom_model_path; epsilon=1.0, lambda=1e-6)
    end
    
    total_build_time = pod_time + rbf_time
    println("      RBF Fit Time: ", PaperEvaluation.format_elapsed_time(rbf_time))
    println("      Total ROM Construction Time: ", PaperEvaluation.format_elapsed_time(total_build_time))

    # ROMモデルサイズレポート
    size_report = PaperEvaluation.monitor_rom_size(basis, rom_model)
    println(size_report)

    # レポートファイルへの保存
    report_file_path = joinpath(paper_plots_dir, "paper_evaluation_summary.txt")
    open(report_file_path, "w") do io
        println(io, "=== Paper Evaluation Summary Report ===")
        println(io, "Dataset Split: Training = $n_train, Validation = $n_val")
        println(io, "Total POD Modes: ", size(basis, 2))
        println(io, "POD Computation Time: ", PaperEvaluation.format_elapsed_time(pod_time))
        println(io, "RBF Training Time: ", PaperEvaluation.format_elapsed_time(rbf_time))
        println(io, "Total ROM Build Time: ", PaperEvaluation.format_elapsed_time(total_build_time))
        println(io, "\n" * size_report)
    end

    # 6. ROMバリデーションの実行
    println("[6/6] Running Full Validation Suite...")
    validation_output_dir = "plots/validation"
    summary = ROMValidator.run_validation(
        rom_model_path,
        "data/raw",
        validation_output_dir,
        trained_snapshot_ids,
        grid_info,
        basis,
        mean_field;
        tmax_threshold=2.0,
        rom_build_time=total_build_time,
        save_individuals=true,
        normalize_plots=false
    )

    println("\n==========================================================")
    println("             PAPER EVALUATION COMPLETE                    ")
    println("==========================================================")
    println("Overall ROM Status:       ", summary.overall_status)
    println("Mean L2 Relative Error:   ", summary.mean_metrics["relative_l2_error"])
    println("Max L2 Relative Error:    ", summary.max_metrics["relative_l2_error"])
    println("Mean Tmax Absolute Error: ", summary.mean_metrics["tmax_error"], " K")
    println("Max Tmax Absolute Error:  ", summary.max_metrics["tmax_error"], " K")
    println("Summary report written to: ", report_file_path)
    println("==========================================================")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_paper_evaluation()
end
