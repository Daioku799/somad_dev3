"""Shared, fail-closed contracts for reproducible thermal research artifacts."""
module ResearchContracts

using SHA

include("Types.jl")
include("Identity.jl")
include("Validation.jl")

export ContractError
export UnitContract, PhysicsMetadata, PhysicsContract
export NumericalPolicy, ApprovalRecord
export QualityState, UNVERIFIED, VERIFIED, LEGACY_UNVERIFIED
export ArtifactEnvelope, CURRENT_SCHEMA_VERSION
export content_hash, content_id, policy_content_hash
export validate_physics_contract, validate_baseline_physics
export approve_policy, validate_numerical_policy
export validate_artifact_envelope, promote_artifact

end
