module Validator

using ..Types: Point2D, ValidationErrorType, NO_ERROR, BOUNDARY_VIOLATION, PITCH_VIOLATION, ValidationResult
using ...ConfigLoader: ModelConfig

export validate_physical_constraints

"""
    validate_physical_constraints(coords::Vector{Point2D}, config::ModelConfig) -> ValidationResult

Validate physical constraints (boundary violations, pitch violations).
"""
function validate_physical_constraints(coords::Vector{Point2D}, config::ModelConfig)
    radius = config.tsv.radius
    lx = config.lx
    ly = config.ly

    # 1. Boundary checks
    for (idx, pt) in enumerate(coords)
        if pt.x < radius || pt.x > lx - radius || pt.y < radius || pt.y > ly - radius
            return ValidationResult(
                false,
                BOUNDARY_VIOLATION,
                "Boundary violation at index $idx: point ($(pt.x), $(pt.y)) is out of bounds for chip size ($lx, $ly) with TSV radius $radius"
            )
        end
    end

    # 2. Pitch checks
    p_min = config.tsv.manufacturing !== nothing ? config.tsv.manufacturing.p_min : 2.0 * radius
    tol = 1e-9

    n = length(coords)
    for i in 1:n
        pt_i = coords[i]
        for j in (i+1):n
            pt_j = coords[j]
            dx = pt_i.x - pt_j.x
            dy = pt_i.y - pt_j.y
            dist = sqrt(dx^2 + dy^2)
            if dist < p_min - tol
                return ValidationResult(
                    false,
                    PITCH_VIOLATION,
                    "Pitch violation between points $i ($(pt_i.x), $(pt_i.y)) and $j ($(pt_j.x), $(pt_j.y)): distance is $dist, which is less than p_min $p_min"
                )
            end
        end
    end

    return ValidationResult(true, NO_ERROR, "All physical constraints are satisfied.")
end

end # module

