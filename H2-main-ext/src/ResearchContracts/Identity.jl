function _write_token(io::IO, value)
    if value === nothing
        write(io, "nothing;")
    elseif value isa Bool
        write(io, value ? "bool:1;" : "bool:0;")
    elseif value isa Integer
        write(io, "int:", string(typeof(value)), ":", string(value), ";")
    elseif value isa AbstractFloat
        isfinite(value) || throw(ContractError("content identity rejects non-finite floating-point values"))
        x = Float64(value)
        write(io, "float64:", bitstring(x), ";")
    elseif value isa AbstractString
        write(io, "string:", string(ncodeunits(value)), ":", value, ";")
    elseif value isa Symbol
        name = String(value)
        write(io, "symbol:", string(ncodeunits(name)), ":", name, ";")
    elseif value isa VersionNumber
        write(io, "version:")
        _write_token(io, string(value))
    elseif value isa Enum
        write(io, "enum:", string(typeof(value)), ":", string(Int(value)), ";")
    elseif value isa NamedTuple
        write(io, "namedtuple:", string(length(value)), "{")
        for name in keys(value)
            _write_token(io, name)
            _write_token(io, getproperty(value, name))
        end
        write(io, "}")
    elseif value isa Tuple
        write(io, "tuple:", string(length(value)), "[")
        for item in value
            _write_token(io, item)
        end
        write(io, "]")
    elseif value isa AbstractDict
        entries = Tuple{String,Any,Any}[]
        for (key, item) in pairs(value)
            key_io = IOBuffer()
            _write_token(key_io, key)
            push!(entries, (String(take!(key_io)), key, item))
        end
        sort!(entries, by=first)
        write(io, "dict:", string(length(entries)), "{")
        for (_, key, item) in entries
            _write_token(io, key)
            _write_token(io, item)
        end
        write(io, "}")
    elseif value isa AbstractArray
        write(io, "array:")
        _write_token(io, size(value))
        for item in value
            _write_token(io, item)
        end
    elseif isstructtype(typeof(value))
        write(io, "struct:", string(nameof(typeof(value))), "{")
        for name in fieldnames(typeof(value))
            _write_token(io, name)
            _write_token(io, getfield(value, name))
        end
        write(io, "}")
    else
        throw(ContractError("unsupported content identity type: $(typeof(value))"))
    end
    return io
end

function content_hash(value)::String
    io = IOBuffer()
    _write_token(io, value)
    return bytes2hex(SHA.sha256(take!(io)))
end

function content_id(kind::AbstractString, value)::String
    isempty(kind) && throw(ContractError("content ID kind must not be empty"))
    return string(kind, ":sha256:", content_hash(value))
end

function policy_content_hash(policy::NumericalPolicy)::String
    return content_hash((
        policy_id=policy.policy_id,
        conductance_rtol=policy.conductance_rtol,
        gradient_rtol=policy.gradient_rtol,
        solver_relative_residual_max=policy.solver_relative_residual_max,
        energy_relative_imbalance_max=policy.energy_relative_imbalance_max,
    ))
end
