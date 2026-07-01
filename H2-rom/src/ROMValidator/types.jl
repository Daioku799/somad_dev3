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
    overall_status::Symbol # :validated or :unfit
end
