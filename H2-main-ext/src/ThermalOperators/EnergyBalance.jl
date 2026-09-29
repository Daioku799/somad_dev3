"""Compute the dimensionless steady-state energy imbalance."""
function energy_balance(generated_heat_W::Real,
                        boundary_heat_rates_W::AbstractVector{<:Real})::EnergyBalanceResult
    generated = Float64(generated_heat_W)
    isfinite(generated) && generated >= 0.0 ||
        throw(ContractError("generated heat must be finite and non-negative"))
    rates = Float64.(boundary_heat_rates_W)
    all(isfinite, rates) || throw(ContractError("boundary heat rates contain non-finite values"))

    heat_in = generated + sum(max(-rate, 0.0) for rate in rates; init=0.0)
    heat_out = sum(max(rate, 0.0) for rate in rates; init=0.0)
    denominator = max(abs(heat_in), abs(heat_out), eps(Float64))
    relative_imbalance = abs(heat_in - heat_out) / denominator
    return EnergyBalanceResult(generated, rates, heat_in, heat_out, relative_imbalance)
end

"""Compute energy balance from identified faces after rejecting duplicates."""
function energy_balance(generated_heat_W::Real,
                        boundary_heat_rates::AbstractVector{BoundaryHeatRate})::EnergyBalanceResult
    # Reuse the same face identity rule as boundary aggregation before discarding
    # provenance for the compact numeric result.
    aggregate_boundary_heat_rates(boundary_heat_rates)
    return energy_balance(
        generated_heat_W,
        [rate.heat_rate_W for rate in boundary_heat_rates],
    )
end

function assess_solve_quality(converged::Bool,
                              final_relative_residual::Real,
                              balance::EnergyBalanceResult,
                              policy::NumericalPolicy,
                              approval_record::ApprovalRecord)::SolveQuality
    validate_numerical_policy(policy, approval_record)
    residual = Float64(final_relative_residual)
    isfinite(residual) && residual >= 0.0 ||
        throw(ContractError("final relative residual must be finite and non-negative"))
    isfinite(balance.relative_imbalance) && balance.relative_imbalance >= 0.0 ||
        throw(ContractError("energy relative imbalance must be finite and non-negative"))

    reasons = String[]
    converged || push!(reasons, "solver did not report convergence")
    residual <= policy.solver_relative_residual_max ||
        push!(reasons, "final relative residual exceeds policy")
    balance.relative_imbalance <= policy.energy_relative_imbalance_max ||
        push!(reasons, "energy relative imbalance exceeds policy")
    status = isempty(reasons) ? PASS : FAIL
    return SolveQuality(
        status,
        converged,
        residual,
        balance.relative_imbalance,
        policy.policy_id,
        reasons,
    )
end
