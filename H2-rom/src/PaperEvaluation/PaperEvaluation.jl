module PaperEvaluation

using LinearAlgebra
using Printf

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
    # TODO: Implement in Task 2.1
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
    # TODO: Implement in Task 2.2
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

