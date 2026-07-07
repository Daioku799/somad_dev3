struct ValidationResult
    sample_id::String
    relative_l2_error::Float64
    tmax_error::Float64
    hotspot_dist::Float64
    is_passed::Bool
end

struct ValidationSummary
    results::Vector{ValidationResult}
    mean_metrics::Dict{String, Float64}
    max_metrics::Dict{String, Float64}
    overall_status::Symbol # :validated, :unfit, or :warning
    performance_metrics::Dict{String, Any}
    self_reproduction_metrics::Dict{String, Any}
end

# Outer constructor for backward compatibility
function ValidationSummary(
    results::Vector{ValidationResult},
    mean_metrics::Dict{String, Float64},
    max_metrics::Dict{String, Float64},
    overall_status::Symbol
)
    return ValidationSummary(
        results,
        mean_metrics,
        max_metrics,
        overall_status,
        Dict{String, Any}(),
        Dict{String, Any}()
    )
end

