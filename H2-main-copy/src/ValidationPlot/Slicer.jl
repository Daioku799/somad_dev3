module Slicer

export get_indices, get_xy_slice, get_yz_slice

"""
    get_indices(x::Float64, y::Float64, z::Float64, ox, dh, z_centers)

Find the closest (i, j, k) indices for given physical coordinates.
"""
function get_indices(x, y, z, ox, dh, z_centers)
    # Uniform XY
    i = floor(Int, (x - ox[1]) / dh[1] + 1.5)
    j = floor(Int, (y - ox[2]) / dh[2] + 1.5)
    
    # Non-uniform Z: find closest in z_centers
    k = argmin(abs.(z_centers .- z))
    
    return i, j, k
end

"""
    get_xy_slice(data::Array{T, 3}, k::Int) where T
"""
function get_xy_slice(data, k)
    return data[:, :, k]
end

"""
    get_yz_slice(data::Array{T, 3}, i::Int) where T
"""
function get_yz_slice(data, i)
    return data[i, :, :]
end

end # module
