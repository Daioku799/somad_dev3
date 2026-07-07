using JSON3
using StructTypes
using Plots
using Printf

StructTypes.StructType(::Type{ValidationResult}) = StructTypes.Struct()
StructTypes.StructType(::Type{ValidationSummary}) = StructTypes.Struct()

"""
    generate_report(summary::ValidationSummary, output_dir::String)

Generate `validation.md` and `validation.json` in the specified directory `output_dir`
representing the summary of the ROM validation results.
"""
function generate_report(summary::ValidationSummary, output_dir::String)
    # Ensure directory exists
    mkpath(output_dir)

    # 1. JSON Report
    json_path = joinpath(output_dir, "validation.json")
    open(json_path, "w") do io
        JSON3.write(io, summary)
    end

    # 2. Markdown Report
    md_path = joinpath(output_dir, "validation.md")
    open(md_path, "w") do io
        println(io, "# ROM Validation Report\n")
        println(io, "## Executive Summary")
        println(io, "- **Overall Status**: `$(summary.overall_status)`")
        println(io, "- **Total Samples**: $(length(summary.results))\n")

        println(io, "## Metrics Summary")
        println(io, "| Metric | Mean | Max |")
        println(io, "| :--- | :---: | :---: |")
        println(io, "| Relative L2 Error | $(summary.mean_metrics["relative_l2_error"]) | $(summary.max_metrics["relative_l2_error"]) |")
        println(io, "| Tmax Error (K) | $(summary.mean_metrics["tmax_error"]) | $(summary.max_metrics["tmax_error"]) |")
        println(io, "| Hotspot Distance (mm) | $(summary.mean_metrics["hotspot_dist"]) | $(summary.max_metrics["hotspot_dist"]) |")
        println(io, "")

        if !isempty(summary.self_reproduction_metrics)
            println(io, "## Self-Reproduction Metrics")
            println(io, "| Metric | Mean | Max |")
            println(io, "| :--- | :---: | :---: |")
            
            mean_l2 = summary.self_reproduction_metrics["mean_l2_error"]
            max_l2 = summary.self_reproduction_metrics["max_l2_error"]
            mean_tmax = summary.self_reproduction_metrics["mean_tmax_error"]
            max_tmax = summary.self_reproduction_metrics["max_tmax_error"]
            
            println(io, "| Relative L2 Error | $mean_l2 | $max_l2 |")
            println(io, "| Tmax Error (K) | $mean_tmax | $max_tmax |")
            println(io, "")
            
            if get(summary.self_reproduction_metrics, "is_warning", false)
                println(io, "> [!WARNING]")
                println(io, "> Self-reproduction error exceeds the threshold of 0.5 K.")
                println(io, "")
            end
        end

        if !isempty(summary.performance_metrics)
            println(io, "## Performance Metrics")
            println(io, "| Metric | Value |")
            println(io, "| :--- | :--- |")
            
            fvm_total = get(summary.performance_metrics, "fvm_total_time", 0.0)
            fvm_avg = get(summary.performance_metrics, "fvm_avg_time", 0.0)
            rom_build = get(summary.performance_metrics, "rom_build_time", 0.0)
            rom_query = get(summary.performance_metrics, "rom_query_avg_time", 0.0)
            size_bytes = get(summary.performance_metrics, "dataset_disk_size_bytes", 0)
            total_eval = get(summary.performance_metrics, "total_evaluation_time", 0.0)
            
            @printf(io, "| FVM Total Time (s) | %.4f |\n", fvm_total)
            @printf(io, "| FVM Average Time (s) | %.4f |\n", fvm_avg)
            @printf(io, "| ROM Build Time (s) | %.4f |\n", rom_build)
            @printf(io, "| ROM Query Average Time (s) | %.6f |\n", rom_query)
            println(io, "| Dataset Disk Size (bytes) | $size_bytes |")
            @printf(io, "| Total Evaluation Time (s) | %.4f |\n", total_eval)
            println(io, "")
        end

        println(io, "## Detailed Results")
        println(io, "| Sample ID | Relative L2 Error | Tmax Error (K) | Hotspot Distance (mm) | Status | Comparison Plot |")
        println(io, "| :--- | :---: | :---: | :---: | :---: | :---: |")
        for r in summary.results
            status_str = r.is_passed ? "PASS" : "FAIL"
            plot_filename = "$(r.sample_id)_rom_fvm_comparison_xy.png"
            plot_link = "[$plot_filename]($plot_filename)"
            println(io, "| $(r.sample_id) | $(r.relative_l2_error) | $(r.tmax_error) | $(r.hotspot_dist) | $(status_str) | $(plot_link) |")
        end
        println(io, "")

        println(io, "## Comparison Plots")
        for r in summary.results
            plot_filename = "$(r.sample_id)_rom_fvm_comparison_xy.png"
            println(io, "### $(r.sample_id)")
            println(io, "![$(r.sample_id) Comparison Plot]($plot_filename)")
            println(io, "")
        end
    end
end

"""
    generate_comparison_plots(
        theta_fvm::Vector{Float64},
        theta_rom::Vector{Float64},
        grid_info::Dict{String, Any},
        output_dir::String,
        sample_id::String,
        mu::Vector{Float64};
        save_individuals::Bool=false,
        normalize::Bool=false
    )

Generate comparison slice plots comparing FVM vs ROM temperatures and error maps.
Calls `ValidationPlot.plot_rom_comparison` under the hood.
"""
function generate_comparison_plots(
    theta_fvm::Vector{Float64},
    theta_rom::Vector{Float64},
    grid_info::Dict{String, Any},
    output_dir::String,
    sample_id::String,
    mu::Vector{Float64};
    save_individuals::Bool=false,
    normalize::Bool=false
)
    # Ensure headless environment configuration
    ENV["GKSwstype"] = "100"

    # Make output directory
    mkpath(output_dir)

    # Grid parameters
    nx = grid_info["nx"]
    ny = grid_info["ny"]
    nz = grid_info["nz"]
    z_centers = convert(Vector{Float64}, grid_info["z_centers"])

    # Determine grid size (ghost cells included or not)
    mz = length(z_centers)
    ghost_grid_total = (nx + 2) * (ny + 2) * mz
    if length(theta_fvm) == ghost_grid_total
        grid_size = (nx + 2, ny + 2, mz)
    else
        grid_size = (nx, ny, nz)
    end

    # Use ValidationPlot to plot the comparison
    ValidationPlot.plot_rom_comparison(
        theta_fvm,
        theta_rom,
        grid_size,
        z_centers,
        mu;
        zc=0.35e-3, # Representative Z slice (around 0.35 mm)
        out_dir=output_dir,
        save_individuals=save_individuals,
        normalize=normalize,
        sample_id=sample_id
    )
end

