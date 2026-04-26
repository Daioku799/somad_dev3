module Types

export Material, Layer, TSVConfig, ModelConfig

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

struct TSVConfig
    mode::Symbol # :manual or :random
    coords::Vector{Tuple{Float64, Float64}}
    radius::Float64
    height::Float64
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
end

end # module
