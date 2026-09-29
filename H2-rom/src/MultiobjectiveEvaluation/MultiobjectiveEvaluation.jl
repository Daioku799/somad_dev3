"""Shared full-field `Tmax` and face-conductance-consistent `gmax` evaluation."""
module MultiobjectiveEvaluation

using ..ResearchContracts
using ..ThermalOperators

include("Types.jl")
include("FieldAdapter.jl")
include("Objectives.jl")
include("CandidateEvaluator.jl")

export FieldIdentity, FieldBundle
export TmaxResult, GmaxResult, ObjectiveEvaluation
export validate_field_bundle, evaluate_tmax, evaluate_gmax, evaluate_objectives

end
