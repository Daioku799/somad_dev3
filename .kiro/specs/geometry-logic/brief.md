# Brief: geometry-logic Extension

## Problem
TSV diameter is currently 40um (too thick) and KOZ is not handled.

## Current State
r_tsv is fixed at 20um. Circular TSV is used. KOZ is not defined.

## Desired Outcome
- TSV diameter set to 5-10um.
- Square TSV support for grid efficiency.
- KOZ support (2.5x-3x TSV diameter).

## Approach
- Add koz_ratio to config.
- Implement square TSV mapping in geometry-logic.
- Add KOZ validation rules.

## Scope
- **In**: TSV size update, Square TSV logic, KOZ definition.
- **Out**: Dynamic TSV count.
