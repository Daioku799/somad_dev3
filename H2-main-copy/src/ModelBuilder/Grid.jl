module Grid

# Access Zcoord.jl from src/Zcoord.jl
include("../Zcoord.jl")
using .Zcoordinate

export generate_coordinate_system, get_index_range

struct CoordinateSystem
    Z::Vector{Float64}
    z_centers::Vector{Float64}
    dz_grid::Vector{Float64}
    nk::Int
end

"""
    generate_coordinate_system(zm::Vector{Float64})

Generate a full 3D coordinate system based on the dynamic Z-markers.
We need to modify the internal logic of Zcoord.jl or replicate it to use dynamic zm.
"""
function generate_coordinate_system(zm::Vector{Float64})
    # modelA.jl original NZ = 13 physical cells.
    # NZ in modelA.jl corresponds to nk in Zcoord.jl logic.
    # But wait, Zcase2! is hardcoded for nk=30.
    # Let's check original Zcoord.jl Zcase2! logic carefully.
    
    nk = 30 # Standard for 240x240x31 model in original.
    
    # We will use the original genZ! logic but we MUST ensure it uses our zm markers.
    # Since Zcoord.jl Zcase2! uses modelA.zmX constants, we'll implement a dynamic version here.
    
    p = 0.005e-3 # grading parameter from original
    
    z_face = zeros(Float64, nk+1)
    z_face[1] = zm[1] # zm0
    z_face[2] = zm[1] + p
    z_face[3] = zm[2] - p # zm1
    z_face[4] = zm[2]
    z_face[5] = zm[2] + p
    z_face[6] = zm[3] - p # zm2
    z_face[7] = zm[3]
    z_face[8] = zm[3] + p
    z_face[9] = zm[4] - p # zm3
    z_face[10]= zm[4]
    z_face[11]= zm[5] # zm4
    z_face[12]= zm[5] + p
    z_face[13]= zm[6] - p # zm5
    z_face[14]= zm[6]
    z_face[15]= zm[6] + p
    z_face[16]= zm[7] - p # zm6
    z_face[17]= zm[7]
    z_face[18]= zm[8] # zm7
    z_face[19]= zm[8] + p
    z_face[20]= zm[9] - p # zm8
    z_face[21]= zm[9]
    z_face[22]= zm[9] + p
    z_face[23]= zm[10]- p # zm9
    z_face[24]= zm[10]
    z_face[25]= zm[11] # zm10
    z_face[26]= zm[11] + p
    z_face[27]= zm[12] - p # zm11
    z_face[28]= zm[12]
    z_face[29]= zm[12] + p
    z_face[30]= zm[13] - p # zm12
    z_face[31]= zm[13]
    
    # Now follow genZ! logic exactly:
    dz = diff(z_face)
    
    dz_grid = zeros(Float64, nk+2)
    dz_grid[2:nk+1] = dz[1:nk]
    dz_grid[1] = dz_grid[2]
    dz_grid[nk+2] = dz_grid[nk+1]

    z_centers = zeros(Float64, nk+2)
    z_centers[1] = z_face[1]
    z_centers[nk+2] = z_face[nk+1]
    for k in 2:(nk+1)
        z_centers[k] = (z_face[k] + z_face[k-1]) * 0.5
    end

    Z = zeros(Float64, nk+3)
    Z[2:nk+2] = z_face[1:nk+1]
    Z[1] = 2*z_face[1] - z_face[2]
    Z[nk+3] = 2*z_face[nk+1] - z_face[nk]

    return CoordinateSystem(Z, z_centers, dz_grid, nk)
end

function find_idx(val::Float64, origin::Float64, delta::Float64, max_idx::Int)
    # Replicating original modelA.jl: floor(Int, (val - origin) / delta + 1.5)
    idx = floor(Int, (val - origin) / delta + 1.5)
    return clamp(idx, 1, max_idx)
end

function find_k(Z::Vector{Float64}, zc::Float64)
    nz = length(Z)
    eps_tol = 1e-12
    # Boundary check with tolerance
    if zc < Z[1] - eps_tol
        return 1
    end
    if zc > Z[nz] + eps_tol
        return nz - 1
    end
    
    for k in 1:nz-1
        if Z[k] <= zc < Z[k+1]
            return k
        end
    end
    
    if abs(zc - Z[nz]) < eps_tol
        return nz - 1
    end
    return 1
end

"""
    get_index_range(bmin, bmax, ox, dh, SZ, Z)
    
Calculate the index range [start, end] for each dimension based on a BBox.
Ensures results are within [1, size].
"""
function get_index_range(bmin, bmax, ox, dh, SZ, Z)
    st = [
        find_idx(bmin[1], ox[1], dh[1], SZ[1]),
        find_idx(bmin[2], ox[2], dh[2], SZ[2]),
        find_k(Z, bmin[3])
    ]
    ed = [
        find_idx(bmax[1], ox[1], dh[1], SZ[1]),
        find_idx(bmax[2], ox[2], dh[2], SZ[2]),
        find_k(Z, bmax[3])
    ]
    
    # Ensure st <= ed and within bounds
    for i in 1:3
        st[i] = max(1, st[i])
        ed[i] = max(st[i], ed[i])
    end
    
    return st, ed
end

end # module
