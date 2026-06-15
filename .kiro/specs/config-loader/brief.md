# Brief: config-loader Update

## Problem
Current physical parameters (TSV diameter, Silicon lambda) do not reflect the target experimental conditions.

## Current State
r_tsv = 20um, Silicon lambda = 149 W/mK.

## Desired Outcome
- r_tsv set to 2.5um (5um diameter).
- Silicon lambda set to 100 W/mK.

## Approach
- Update config.json with new physical values.

## Scope
- **In**: Parameter updates in JSON.
- **Out**: Structural changes to the config schema.
