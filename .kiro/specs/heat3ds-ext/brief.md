# Brief: heat3ds-ext Boundary Update

## Problem
Lateral boundaries are not adiabatic as required by the simulation scope (zero lateral heat transfer).

## Current State
Side boundaries use convection (HT=5.0).

## Desired Outcome
- Lateral boundaries (X+, X-, Y+, Y-) set to Adiabatic (Heat Flux = 0.0).

## Approach
- Update set_mode3_bc_parameters in heat3ds.jl to use heat_flux_bc(0.0).

## Scope
- **In**: Boundary condition modification.
- **Out**: Silicon lambda temperature dependency.
