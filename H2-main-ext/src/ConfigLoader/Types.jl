module Types

export Material, Layer, DensityMapConfig, ManufacturingConfig, GASettings, TSVConfig, ModelConfig
export PowerSourceConfig, is_uniform_power

struct Material
    id::Int
    name::String
    lambda::Float64
    rho::Float64
    cp::Float64
end

struct Layer
    name::String
    thickness::Float64
    divisions::Int
    grading::Float64
end

struct DensityMapConfig
    gx::Int
    gy::Int
    mu::Vector{Float64}
    n_min::Int
    n_max::Int
    rho_cell_max::Float64
    prohibited_cells::Vector{Tuple{Int, Int}}
end

struct ManufacturingConfig
    d_tsv::Float64
    p_min::Float64
    ar_min::Float64
    ar_max::Float64
end

struct GASettings
    n_pop::Int
    n_gen::Int
    cx_rate::Float64
    mut_rate::Float64
    n_elite::Int
end

struct TSVConfig
    mode::Symbol # :manual, :random, or :density
    coords::Vector{Tuple{Float64, Float64}}
    radius::Float64
    height::Float64
    density::Union{Nothing, DensityMapConfig}
    manufacturing::Union{Nothing, ManufacturingConfig}
    ga::Union{Nothing, GASettings}
end

"""
    PowerSourceConfig

発熱源ブロックの配置と発熱密度倍率。

ブロックは各ダイの `positions_x` x `positions_y` 格子上に置かれ、体積発熱密度は
`q_ref * scale[die, block]` である。`scale` の列は1ダイ内のブロックを x を内側に
した順（`(iy-1)*length(positions_x) + ix`）で並べる。これは
`ModelBuilder.fill_power_grid!` の元のループ順と一致する。

既定値は H2-main-original の固定発熱源（3ダイ x 4ブロック、全て等倍）を再現する。
"""
struct PowerSourceConfig
    q_ref::Float64
    block_lx::Float64
    block_ly::Float64
    positions_x::Vector{Float64}
    positions_y::Vector{Float64}
    scale::Matrix{Float64}
end

# Default reproduces the previously hard-coded sources in ModelBuilder.fill_power_grid!
PowerSourceConfig() = PowerSourceConfig(
    1.6e11,
    0.2e-3, 0.2e-3,
    [0.3e-3, 0.7e-3],
    [0.3e-3, 0.7e-3],
    ones(3, 4)
)

"""
    is_uniform_power(p::PowerSourceConfig) -> Bool

全ブロックが等倍かどうか。真なら発熱項は従来の一様 `Q_src` と一致するため、
呼び出し側は従来経路をそのまま使ってビット一致を保証できる。
"""
is_uniform_power(p::PowerSourceConfig) = all(==(1.0), p.scale)

struct ModelConfig
    materials::Vector{Material}
    layers::Vector{Layer}
    tsv::TSVConfig
    lx::Float64
    ly::Float64
    pg_dpth::Float64
    s_dpth::Float64
    d_ufill::Float64
    r_bump::Float64
    snapshot_enabled::Bool
    snapshot_dir::String
    fixed_silicon_lambda::Union{Nothing, Float64}
    epsilon::Float64
    max_iter::Int
    power::PowerSourceConfig
end

# Backward-compatible 14-argument constructor. Existing call sites predate the
# `power` field and must keep building the default (uniform) heat source.
# NOTE: call sites that copy fields from another config do NOT inherit that
# config's `power` through this path; they must pass it explicitly.
ModelConfig(materials, layers, tsv, lx, ly, pg_dpth, s_dpth, d_ufill, r_bump,
            snapshot_enabled, snapshot_dir, fixed_silicon_lambda, epsilon, max_iter) =
    ModelConfig(materials, layers, tsv, lx, ly, pg_dpth, s_dpth, d_ufill, r_bump,
                snapshot_enabled, snapshot_dir, fixed_silicon_lambda, epsilon, max_iter,
                PowerSourceConfig())

end # module
