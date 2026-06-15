module Types

export Material, Layer, DensityMapConfig, ManufacturingConfig, GASettings, TSVConfig, ModelConfig

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
end

end # module
