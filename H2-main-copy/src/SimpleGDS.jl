module SimpleGDS

export GdsLibrary, GdsStructure, Boundary, add_element, add_structure, save, load, Point

# =========================================================
# GDSII Record Constants
# =========================================================
const HEADER    = 0x0002
const BGNLIB    = 0x0102
const LIBNAME   = 0x0206
const UNITS     = 0x0305
const ENDLIB    = 0x0400
const BGNSTR    = 0x0502
const STRNAME   = 0x0606
const ENDSTR    = 0x0700
const BOUNDARY  = 0x0800
const PATH      = 0x0900
const SREF      = 0x0A00
const AREF      = 0x0B00
const TEXT      = 0x0C00
const LAYER     = 0x0D02
const DATATYPE  = 0x0E02
const WIDTH     = 0x0F03
const XY        = 0x1003
const ENDEL     = 0x1100

# =========================================================
# Data Structures
# =========================================================
struct Point
    x::Float64
    y::Float64
end

abstract type Element end

mutable struct Boundary <: Element
    layer::Int
    datatype::Int
    xy::Vector{Point}
end
Boundary(layer::Int, datatype::Int) = Boundary(layer, datatype, Point[])

mutable struct GdsStructure
    name::String
    elements::Vector{Element}
end
GdsStructure(name::String) = GdsStructure(name, Element[])

mutable struct GdsLibrary
    name::String
    units::Vector{Float64} # [User units, Physical units]
    structures::Vector{GdsStructure}
end
GdsLibrary(name::String) = GdsLibrary(name, [0.001, 1e-9], GdsStructure[])

function add_element(s::GdsStructure, e::Element)
    push!(s.elements, e)
end

function add_structure(l::GdsLibrary, s::GdsStructure)
    push!(l.structures, s)
end

# =========================================================
# Writer
# =========================================================
function write_record(io::IO, rec_type::UInt16, data::Vector{UInt8})
    len = length(data) + 4
    if len % 2 != 0
        push!(data, 0x00) # Pad to even
        len += 1
    end
    write(io, hton(UInt16(len)))
    write(io, hton(rec_type))
    write(io, data)
end

function write_int2(io::IO, rt::UInt16, val::Integer)
    buf = IOBuffer()
    write(buf, hton(Int16(val)))
    write_record(io, rt, take!(buf))
end

function write_int4(io::IO, rt::UInt16, val::Integer)
    buf = IOBuffer()
    write(buf, hton(Int32(val)))
    write_record(io, rt, take!(buf))
end

function write_string(io::IO, rt::UInt16, s::String)
    data = Vector{UInt8}(s)
    if length(data) % 2 != 0
        push!(data, 0x00)
    end
    write_record(io, rt, data)
end

function write_int4_array(io::IO, rt::UInt16, vals::Vector{Int32})
    buf = IOBuffer()
    for v in vals
        write(buf, hton(v))
    end
    write_record(io, rt, take!(buf))
end

# GDSII Real8 format (IBM 360 float format)
function double_to_gds(val::Float64)
    if val == 0.0
        return zeros(UInt8, 8)
    end
    
    sign = (val < 0) ? 0x80 : 0x00
    val = abs(val)
    
    exponent = floor(Int, log(val) / log(16.0)) + 64
    mantissa = val / (16.0^(exponent - 64))
    
    # Mantissa is 56 bits (7 bytes)
    m_long = floor(UInt64, mantissa * (2.0^56))
    
    bytes = zeros(UInt8, 8)
    bytes[1] = sign | (UInt8(exponent) & 0x7F)
    
    for i in 1:7
        shift = (7 - i) * 8
        bytes[i+1] = UInt8((m_long >> shift) & 0xFF)
    end
    return bytes
end

function write_real8_array(io::IO, rt::UInt16, vals::Vector{Float64})
    buf = IOBuffer()
    for v in vals
        write(buf, double_to_gds(v))
    end
    write_record(io, rt, take!(buf))
end

function save(filename::String, lib::GdsLibrary)
    open(filename, "w") do io
        write_int2(io, HEADER, 600)
        
        buf = IOBuffer()
        write(buf, hton(UInt16(2025))); write(buf, hton(UInt16(1))); write(buf, hton(UInt16(1))); write(buf, hton(UInt16(1)))
        write(buf, hton(UInt16(2025))); write(buf, hton(UInt16(1))); write(buf, hton(UInt16(1))); write(buf, hton(UInt16(1)))
        write_record(io, BGNLIB, take!(buf))
        
        write_string(io, LIBNAME, lib.name)
        write_real8_array(io, UNITS, lib.units)
        
        for s in lib.structures
            buf = IOBuffer()
            for _ in 1:12 write(buf, 0x00) end
            write_record(io, BGNSTR, take!(buf))
            write_string(io, STRNAME, s.name)
            
            for elm in s.elements
                if elm isa Boundary
                    write_record(io, BOUNDARY, UInt8[])
                    write_int2(io, LAYER, elm.layer)
                    write_int2(io, DATATYPE, elm.datatype)
                    coords = Int32[]
                    for p in elm.xy
                        push!(coords, round(Int32, p.x))
                        push!(coords, round(Int32, p.y))
                    end
                    write_int4_array(io, XY, coords)
                    write_record(io, ENDEL, UInt8[])
                end
            end
            write_record(io, ENDSTR, UInt8[])
        end
        write_record(io, ENDLIB, UInt8[])
    end
end

# =========================================================
# Reader
# =========================================================
function load(filename::String)
    data = read(filename)
    io = IOBuffer(data)
    
    lib = GdsLibrary("UNK")
    current_str = nothing
    current_element = nothing # Type: Union{Boundary, Nothing}
    
    while !eof(io)
        if bytesavailable(io) < 4 break end
        
        rlen = ntoh(read(io, UInt16))
        if rlen < 4 
            if rlen == 0 break end
            break 
        end
        
        rtype = ntoh(read(io, UInt16))
        dlen = rlen - 4
        dbytes = read(io, dlen)
        
        if rtype == BGNLIB
        elseif rtype == LIBNAME
             # lib.name = String(dbytes) 
        elseif rtype == UNITS
             # skip parsing units for now or implement reader
        elseif rtype == BGNSTR
            current_str = GdsStructure("UNK")
            push!(lib.structures, current_str)
        elseif rtype == STRNAME
            s = String(dbytes)
            # Remove nulls
            s = replace(s, "\0" => "")
            if current_str !== nothing 
                current_str.name = s 
            end
        elseif rtype == ENDSTR
            current_str = nothing
        elseif rtype == ENDLIB
            break
            
        elseif rtype == BOUNDARY
            current_element = Boundary(0, 0, Point[])
            if current_str !== nothing
                push!(current_str.elements, current_element)
            end
        elseif rtype == LAYER
            if current_element !== nothing
                 val = Int(ntoh(reinterpret(Int16, dbytes)[1]))
                 current_element.layer = val
            end
        elseif rtype == DATATYPE
            if current_element !== nothing
                 val = Int(ntoh(reinterpret(Int16, dbytes)[1]))
                 current_element.datatype = val
            end
        elseif rtype == XY
             if current_element !== nothing
                 coords = Vector{Int32}(undef, div(dlen, 4))
                 for i in 1:length(coords)
                     # Big Endian Int32
                     b1 = Int32(dbytes[(i-1)*4+1]); b2 = Int32(dbytes[(i-1)*4+2])
                     b3 = Int32(dbytes[(i-1)*4+3]); b4 = Int32(dbytes[(i-1)*4+4])
                     coords[i] = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
                 end
                 for i in 1:2:length(coords)
                     push!(current_element.xy, Point(Float64(coords[i]), Float64(coords[i+1])))
                 end
             end
        elseif rtype == ENDEL
             current_element = nothing
        end
    end
    
    return lib
end

end # module
