# Research & Design Decisions: rom-validator

## Summary
- **Feature**: rom-validator
- **Discovery Scope**: Extension (ROM construction pipeline)
- **Key Findings**:
  - ROM accuracy needs to be evaluated against unseen density maps to ensure generalization.
  - Primary metrics include Relative L2 error for global field accuracy and Tmax error for hotspot reliability.
  - Hotspot location accuracy is critical for power-integrity and thermal-aware design.
  - Validation data should be excluded from `pod-engine` and `rom-interpolator` training to avoid data leakage.

## Research Log

### Accuracy Metrics for Thermal ROM
- **Context**: How to quantitatively measure ROM quality?
- **Findings**:
  - **Relative L2 Error**: $\frac{||\theta_{FVM} - \theta_{ROM}||_2}{||\theta_{FVM}||_2}$ provides a global accuracy measure.
  - **Tmax Error**: $|\text{max}(\theta_{FVM}) - \text{max}(\theta_{ROM})|$ is critical because maximum temperature often determines design constraints.
  - **Hotspot Location Error**: Euclidean distance between $\text{argmax}(\theta_{FVM})$ and $\text{argmax}(\theta_{ROM})$ in 3D grid coordinates.
- **Implications**: The validator must implement these calculations and provide summary statistics (mean, max, std).

### Data Partitioning and Metadata
- **Context**: How to identify "unseen" snapshots?
- **Sources Consulted**: `pod-engine` design, `snapshot-generator` roadmap.
- **Findings**:
  - `pod-engine` saves the list of snapshots used for training in its metadata.
  - `rom-validator` should scan `data/raw/` and compare with the trained list.
- **Implications**: `pod-engine` metadata must include unique identifiers (e.g., file names or parameter hashes) of the training snapshots.

### Hotspot Detection
- **Context**: How to calculate hotspot location efficiently?
- **Findings**:
  - Julia's `argmax` on the 3D temperature array returns a Cartesian index.
  - This index can be converted to physical coordinates using the grid information (Z-markers and density map grid).
- **Implications**: The validator needs access to the grid specification to calculate physical distances.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Sequential Evaluator | Processes validation snapshots one by one. | Simple, low memory overhead. | Slower for very large datasets. | Sufficient for current project scale. |
| Batch Evaluator | Vectorized calculation across all validation cases. | Faster. | High memory usage (loading all FVM fields). | Only if performance becomes a bottleneck. |

## Design Decisions

### Decision: Selection of Validation Snapshots
- **Context**: Ensuring fair evaluation.
- **Selected Approach**: Automatic exclusion of training set based on `pod_model.jld2` metadata.
- **Rationale**: Prevents accidental evaluation on training data (overfitting check).
- **Trade-offs**: Requires `pod-engine` to faithfully record its training set.

### Decision: Visualization Level
- **Context**: How much to plot?
- **Selected Approach**: Generate comparison plots for "worst-case" (highest error) and "average-case" snapshots.
- **Rationale**: Helps identify where the ROM fails (e.g., specific density patterns).

## Risks & Mitigations
- **Grid Mismatch** — ROM and FVM results must be on the same grid. Mitigation: Validator must check grid dimensions before comparison.
- **Memory Exhaustion** — Loading many 3D fields. Mitigation: Process snapshots iteratively.

## References
- [Proper Orthogonal Decomposition](https://en.wikipedia.org/wiki/Proper_orthogonal_decomposition)
- [RBF Interpolation](https://en.wikipedia.org/wiki/Radial_basis_function)
