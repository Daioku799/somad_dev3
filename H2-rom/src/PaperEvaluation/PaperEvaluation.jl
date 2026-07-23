module PaperEvaluation

using LinearAlgebra
using Printf

using Plots

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
    sweep_rbf_parameters(Mu_train::Matrix{Float64}, coeffs_train::Matrix{Float64},
                         Mu_val::Matrix{Float64}, val_temp_fields::Matrix{Float64},
                         grid_info::Dict, basis::Matrix{Float64}, mean_field::Vector{Float64},
                         epsilon_range::Vector{Float64}, lambda_range::Vector{Float64},
                         output_dir::String)
                         
RBFパラメータ(epsilon, lambda)を総当たりでスイープし、相対L2誤差・Tmax誤差を評価して
感度分析ヒートマッププロットをoutput_dirに保存する。
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
            # Build and fit the RBF model
            interpolator = ROMInterpolator.RBFInterpolator(eps)
            ROMInterpolator.fit!(interpolator, Mu_train, coeffs_train; lambda=lam)

            sum_l2 = 0.0
            sum_tmax = 0.0

            # Evaluate on validation samples
            for k in 1:n_val_samples
                mu = Mu_val[:, k]
                theta_true = val_temp_fields[:, k]

                # Prediction and reconstruction
                coeffs_pred = ROMInterpolator.predict(interpolator, mu)
                theta_pred = ROMInterpolator.reconstruct_field(coeffs_pred, basis, mean_field)

                # L2 relative error
                norm_true = norm(theta_true)
                l2_err = norm_true < 1e-12 ? 0.0 : norm(theta_true - theta_pred) / norm_true

                # Tmax absolute error
                tmax_err = abs(maximum(theta_true) - maximum(theta_pred))

                sum_l2 += l2_err
                sum_tmax += tmax_err
            end

            error_matrix_l2[i, j] = sum_l2 / n_val_samples
            error_matrix_tmax[i, j] = sum_tmax / n_val_samples
        end
    end

    # Generate plots
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
    monitor_rom_size(basis::Matrix{Float64}, rom_model::ROMInterpolator.RBFInterpolator) -> String
    
基底行列 U (size: N x r) および RBF重み行列 W (size: r x M) の要素数と
データサイズ(KB/MB)を計測し、可読な文字列レポートを返す。
"""
function monitor_rom_size(basis::Matrix{Float64}, rom_model::ROMInterpolator.RBFInterpolator)::String
    u_elements = length(basis)
    u_bytes = u_elements * 8 # Float64 size is 8 bytes
    
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
    
    u_size_str = format_bytes(u_bytes)
    w_size_str = format_bytes(w_bytes)
    total_size_str = format_bytes(total_bytes)
    
    report = """
    === ROM Model Size Report ===
    Basis Matrix U (size: $(size(basis, 1))x$(size(basis, 2))):
      - Elements: $u_elements
      - Size: $u_size_str
    RBF Weight Matrix W (size: $(size(rom_model.weights, 1))x$(size(rom_model.weights, 2))):
      - Elements: $w_elements
      - Size: $w_size_str
    Total ROM Size:
      - Total Elements: $total_elements
      - Total Size: $total_size_str
    =============================
    """
    
    return report
end

"""
    measure_time(f::Function) -> Tuple{Any, Float64}

指定された関数 `f` の実行時間を計測し、(fの結果, 経過時間(秒)) を返す。
"""
function measure_time(f::Function)
    t0 = time()
    result = f()
    elapsed = time() - t0
    return result, elapsed
end

"""
    format_elapsed_time(elapsed_seconds::Float64) -> String

経過時間（秒）を可読な形式にフォーマットした文字列を返す。
"""
function format_elapsed_time(elapsed_seconds::Float64)::String
    return @sprintf("%.4f seconds", elapsed_seconds)
end

end # module

