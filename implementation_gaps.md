# Implementation Gaps and Proposed Actions (Updated)

## 1. TSV Geometry & Resolution
- **User Decision**: Keep cylindrical TSVs but increase grid resolution to handle 5-10um diameter.
- **Proposed Action**: 
    - Update config.json and modelA.jl to use 5um diameter (r_tsv = 2.5e-6).
    - Increase NX, NY default parameters in run.jl or via command line to resolve the smaller TSVs.

## 2. Thermal Conductivity (Silicon)
- **User Decision**: Use a constant value representing the average temperature (e.g., 100 W/mK at 100C) if the temperature range is small.
- **Proposed Action**:
    - Update config.json to set Silicon lambda = 100.0 W/mK.

## 3. Keep-Out Zone (KOZ)
- **User Decision**: Do not implement (ignored at macro heat source level).
- **Proposed Action**: No change required.

## 4. Boundary Conditions
- **User Decision**: Maintain current scope (lateral insulation is required as per progress report).
- **Proposed Action**:
    - Update set_mode3_bc_parameters in heat3ds.jl to use heat_flux_bc(0.0) for side walls.

## 5. Metrics & Validation
- **Gap**: Ensure compute_metrics handles the high-resolution grid correctly.
