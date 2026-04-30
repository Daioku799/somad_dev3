module Palettes

export LEGACY_COLOR_PALETTE, MATERIAL_LABELS

"""
    LEGACY_COLOR_PALETTE
材料ID (1-7) に対応するレガシー互換のカラーパレット。
1: TSV (Orange)
2: Si (Gray)
3: Solder (Yellow)
4: Substrate (LightBlue)
5: HeatSink (Blue)
6: Resin (Green)
7: PowerGrid (Red)
"""
const LEGACY_COLOR_PALETTE = [:orange, :gray, :yellow, :lightblue, :blue, :green, :red]

"""
    MATERIAL_LABELS
材料ID (1-7) に対応するラベル。
"""
const MATERIAL_LABELS = ["TSV", "Si", "Solder", "Substrate", "HeatSink", "Resin", "PowerGrid"]

end # module Palettes
