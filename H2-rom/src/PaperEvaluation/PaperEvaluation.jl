module PaperEvaluation

using LinearAlgebra
using Printf
using Statistics
using Plots

include("PairedDensityResolution.jl")
using .PairedDensityResolution

try
    using ROMInterpolator
catch
    if !isdefined(Main, :ROMInterpolator)
        path = joinpath(@__DIR__, "..", "ROMInterpolator", "ROMInterpolator.jl")
        Main.eval(:(include($path)))
    end
    using Main.ROMInterpolator
end

export plot_svd_decay, sweep_rbf_parameters, monitor_rom_size, measure_time, format_elapsed_time
export plot_density_resolution_sweep, plot_snapshot_count_sweep, plot_pod_modes_sweep, plot_sensitivity_summary_4panel
export MASTER_GRID_SIZE, TSV_COUNT, RESOLUTIONS
export generate_master_occupancy, aggregate_counts, counts_to_density

"""
    plot_svd_decay(singular_values::Vector{Float64}, output_path::String)
    
SVDの特異値減衰と累積寄与率(RIC)の推移をPlots.jlで描画し、output_pathに保存する。
"""
function plot_svd_decay(singular_values::Vector{Float64}, output_path::String)
    dir = dirname(output_path)
    if dir != "" && !isdir(dir)
        mkpath(dir)
    end
    
    n_modes = length(singular_values)
    sq_sum = sum(singular_values .^ 2)
    ric = cumsum(singular_values .^ 2) ./ sq_sum
    
    # Left Y axis: Singular values decay (log scale)
    p = plot(1:n_modes, singular_values, yscale=:log10, marker=:circle,
             xlabel="POD Mode Index", ylabel="Singular Value (log10)",
             label="Singular Value", legend=:topright, grid=true,
             title="SVD Singular Values Decay & RIC")
             
    # Right Y axis: Cumulative Energy Fraction (RIC)
    plot!(twinx(p), 1:n_modes, ric, marker=:square, ylims=(0.0, 1.05),
          ylabel="Cumulative RIC", label="Cumulative RIC",
          legend=:bottomright, color=:red)
          
    savefig(p, output_path)
end

"""
    sweep_rbf_parameters(...)
"""
function sweep_rbf_parameters(Mu_train::Matrix{Float64}, coeffs_train::Matrix{Float64},
                              Mu_val::Matrix{Float64}, val_temp_fields::Matrix{Float64},
                              grid_info::Dict, basis::Matrix{Float64}, mean_field::Vector{Float64},
                              epsilon_range::Vector{Float64}, lambda_range::Vector{Float64},
                              output_dir::String)
    if !isdir(output_dir)
        mkpath(output_dir)
    end

    n_eps = length(epsilon_range)
    n_lam = length(lambda_range)
    n_val_samples = size(Mu_val, 2)

    error_matrix_l2 = Matrix{Float64}(undef, n_lam, n_eps)
    error_matrix_tmax = Matrix{Float64}(undef, n_lam, n_eps)

    for (j, eps) in enumerate(epsilon_range)
        for (i, lam) in enumerate(lambda_range)
            interpolator = ROMInterpolator.RBFInterpolator(eps)
            ROMInterpolator.fit!(interpolator, Mu_train, coeffs_train; lambda=lam)

            sum_l2 = 0.0
            sum_tmax = 0.0

            for k in 1:n_val_samples
                mu = Mu_val[:, k]
                theta_true = val_temp_fields[:, k]

                coeffs_pred = ROMInterpolator.predict(interpolator, mu)
                theta_pred = ROMInterpolator.reconstruct_field(coeffs_pred, basis, mean_field)

                norm_true = norm(theta_true)
                l2_err = norm_true < 1e-12 ? 0.0 : norm(theta_true - theta_pred) / norm_true
                tmax_err = abs(maximum(theta_true) - maximum(theta_pred))

                sum_l2 += l2_err
                sum_tmax += tmax_err
            end

            error_matrix_l2[i, j] = sum_l2 / n_val_samples
            error_matrix_tmax[i, j] = sum_tmax / n_val_samples
        end
    end

    all_lam_positive = all(lambda_range .> 0)

    if all_lam_positive
        log_lambda = log10.(lambda_range)
        ytick_labels = string.(lambda_range)
        
        p_l2 = heatmap(epsilon_range, log_lambda, error_matrix_l2,
                       xlabel="Epsilon (\\epsilon)",
                       ylabel="Lambda (\\lambda)",
                       yticks=(log_lambda, ytick_labels),
                       title="RBF Parameter Sweep - L2 Relative Error",
                       colorbar_title="Mean L2 Relative Error",
                       color=:viridis)

        p_tmax = heatmap(epsilon_range, log_lambda, error_matrix_tmax,
                         xlabel="Epsilon (\\epsilon)",
                         ylabel="Lambda (\\lambda)",
                         yticks=(log_lambda, ytick_labels),
                         title="RBF Parameter Sweep - Tmax Absolute Error",
                         colorbar_title="Mean Tmax Absolute Error (K)",
                         color=:viridis)
    else
        p_l2 = heatmap(epsilon_range, lambda_range, error_matrix_l2,
                       xlabel="Epsilon (\\epsilon)",
                       ylabel="Lambda (\\lambda)",
                       title="RBF Parameter Sweep - L2 Relative Error",
                       colorbar_title="Mean L2 Relative Error",
                       color=:viridis)

        p_tmax = heatmap(epsilon_range, lambda_range, error_matrix_tmax,
                         xlabel="Epsilon (\\epsilon)",
                         ylabel="Lambda (\\lambda)",
                         title="RBF Parameter Sweep - Tmax Absolute Error",
                         colorbar_title="Mean Tmax Absolute Error (K)",
                         color=:viridis)
    end

    savefig(p_l2, joinpath(output_dir, "rbf_sweep_l2.png"))
    savefig(p_tmax, joinpath(output_dir, "rbf_sweep_tmax.png"))
end

"""
    plot_density_resolution_sweep(res_list, l2_errors, build_times, output_dir)
"""
function plot_density_resolution_sweep(res_list::Vector{Int}, l2_errors::Vector{Float64}, build_times::Vector{Float64}, output_dir::String)
    p1 = plot(res_list, l2_errors .* 100, marker=:circle, linewidth=2,
              xlabel="Density Grid Resolution (Gx=Gy)", ylabel="Mean Relative L2 Error [%]",
              title="Accuracy vs Density Map Resolution", legend=false, grid=true)
    savefig(p1, joinpath(output_dir, "accuracy_vs_density_res.png"))

    p2 = plot(res_list, build_times, marker=:square, linewidth=2, color=:orange,
              xlabel="Density Grid Resolution (Gx=Gy)", ylabel="Build Time [sec]",
              title="Build Time vs Density Map Resolution", legend=false, grid=true)
    savefig(p2, joinpath(output_dir, "runtime_vs_density_res.png"))
    return p1, p2
end

"""
    plot_snapshot_count_sweep(nsnap_list, l2_errors, svd_times, output_dir)
"""
function plot_snapshot_count_sweep(nsnap_list::Vector{Int}, l2_errors::Vector{Float64}, svd_times::Vector{Float64}, output_dir::String)
    p1 = plot(nsnap_list, l2_errors .* 100, marker=:diamond, linewidth=2, color=:green,
              xlabel="Number of Training Snapshots Nsnap", ylabel="Mean Relative L2 Error [%]",
              title="Accuracy vs Snapshot Count", legend=false, grid=true)
    savefig(p1, joinpath(output_dir, "accuracy_vs_nsnap.png"))

    p2 = plot(nsnap_list, svd_times, marker=:utriangle, linewidth=2, color=:purple,
              xlabel="Number of Training Snapshots Nsnap", ylabel="SVD Computation Time [sec]",
              title="SVD Compute Time vs Snapshot Count", legend=false, grid=true)
    savefig(p2, joinpath(output_dir, "runtime_vs_nsnap.png"))
    return p1, p2
end

"""
    plot_pod_modes_sweep(k_list, l2_errors, output_dir)
"""
function plot_pod_modes_sweep(k_list::Vector{Int}, l2_errors::Vector{Float64}, output_dir::String)
    p1 = plot(k_list, l2_errors .* 100, marker=:circle, linewidth=2, color=:red,
              xlabel="Number of Retained POD Modes k", ylabel="Mean Relative L2 Error [%]",
              title="Accuracy vs Retained POD Modes", legend=false, grid=true)
    savefig(p1, joinpath(output_dir, "accuracy_vs_pod_modes.png"))
    return p1
end

"""
    plot_sensitivity_summary_4panel(p_a1, p_b1, p_c1, p_a2, output_path)
"""
function plot_sensitivity_summary_4panel(p_a1, p_b1, p_c1, p_a2, output_path::String)
    p_summary = plot(p_a1, p_b1, p_c1, p_a2, layout=(2, 2), size=(1200, 800),
                     plot_title="3D-IC Heat ROM - Sensitivity & Performance Summary")
    savefig(p_summary, output_path)
end

function monitor_rom_size(basis::Matrix{Float64}, rom_model::ROMInterpolator.RBFInterpolator)::String
    u_elements = length(basis)
    u_bytes = u_elements * 8
    w_elements = length(rom_model.weights)
    w_bytes = w_elements * 8
    total_elements = u_elements + w_elements
    total_bytes = u_bytes + w_bytes
    
    function format_bytes(bytes::Int)
        if bytes >= 1024 * 1024
            return @sprintf("%.2f MB", bytes / (1024 * 1024))
        else
            return @sprintf("%.2f KB", bytes / 1024)
        end
    end
    
    return """
    === ROM Model Size Report ===
    Basis Matrix U (size: $(size(basis, 1))x$(size(basis, 2))):
      - Elements: $u_elements
      - Size: $(format_bytes(u_bytes))
    RBF Weight Matrix W (size: $(size(rom_model.weights, 1))x$(size(rom_model.weights, 2))):
      - Elements: $w_elements
      - Size: $(format_bytes(w_bytes))
    Total ROM Size:
      - Total Elements: $total_elements
      - Total Size: $(format_bytes(total_bytes))
    =============================
    """
end

function measure_time(f::Function)
    t0 = time()
    result = f()
    return result, time() - t0
end

function format_elapsed_time(elapsed_seconds::Float64)::String
    return @sprintf("%.4f seconds", elapsed_seconds)
end

end # module
