# Research Log: snapshot-generator

## Summary
- **Feature**: snapshot-generator
- **Discovery Scope**: Extension (Adding Density Map support and FVM orchestration)
- **Key Findings**:
  - `LatinHypercubeSampling.jl` is established in `tech.md` for parameter sampling.
  - `JLD2.jl` is the standard for snapshot persistence.
  - The project is shifting from individual TSV coordinates to a 4x4 (default) density map `mu`.
  - Integration with `component-generator` is required to expand `mu` to physical coordinates before FVM execution.
  - `heat3ds-ext` (heat3ds.jl) needs to be invoked with a `snapshot_path` to trigger auto-save.

## Research Log

### Density Map Representation
- **Context**: How is the density map `mu` structured?
- **Findings**: 
  - $G_x \times G_y$ grid (e.g., 4x4) covering the chip area.
  - Each cell $(i, j)$ has a density $\mu_{ij} \in [0, 1]$, where 1 means maximum possible TSVs in that cell.
  - Total TSVs $N_{total}$ is a global constraint.
- **Implications**: The sampler must produce vectors of length $G_x \times G_y$ and satisfy $\sum \mu_{ij} \times n_{max,ij} \le N_{limit}$.

### Latin Hypercube Sampling (LHS)
- **Context**: How to apply LHS to density maps?
- **Sources Consulted**: `LatinHypercubeSampling.jl` documentation.
- **Findings**: 
  - `randomLHC(n_samples, n_dims)` generates a plan.
  - `scaleLHC(plan, [ (low, high), ... ])` scales to physical ranges.
- **Implications**: We need to sample $G_x \times G_y$ dimensions. Each dimension is $[0, 1]$.

### FVM Orchestration
- **Context**: How to run `heat3ds.jl` in bulk?
- **Findings**: 
  - `H2-main-ext/run.jl` is the entry point.
  - It takes a `config.json`.
  - We need to generate a unique `config.json` per case or pass parameters via CLI.
  - Background execution with Julia's `Distributed` or `Base.Threads` is preferred.
- **Implications**: Each case needs a dedicated work directory to avoid file collisions (log.txt, etc.).

## Design Decisions

### Decision: Parameter Normalization
- **Selected Approach**: Sample in $[0, 1]^D$ space, then scale and apply constraints (total count) in the Runner or Sampler.
- **Rationale**: Keeps the sampling logic independent of physical constraints.

### Decision: Manifest Management
- **Selected Approach**: `manifest.json` as the single source of truth for the dataset.
- **Rationale**: Enables `pod-engine` and `rom-validator` to easily discover and filter snapshots.

### Decision: Integration with component-generator
- **Selected Approach**: `snapshot-generator` calls `component-generator` to get the list of TSVs, then updates the `ModelConfig` object before calling the solver.
- **Rationale**: Decouples sampling from geometry logic.

## Risks & Mitigations
- **Resource Exhaustion** — Parallel FVM runs can consume all RAM. Mitigation: Configurable `max_workers`.
- **Inconsistent Grids** — If `mu` changes the grid markers, POD will fail. Mitigation: Ensure fixed grid resolution or interpolation (out of scope for now, assume fixed grid).
- **Disk Space** — JLD2 files can be large. Mitigation: Option to store only necessary fields (theta).
