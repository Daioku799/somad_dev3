module ModelBuilder

include("Grid.jl")
include("../ConfigLoader/ConfigLoader.jl")
include("../GeometryLogic/GeometryLogic.jl")
include("../ComponentGenerator/ComponentGenerator.jl")

using .Grid
using .ConfigLoader
using .GeometryLogic
using .ComponentGenerator

export build_model, CoordinateSystem, fill_power_grid!, fill_cylinder!, fill_sphere!, fill_plates!, set_properties!

"""
    build_model(config::ModelConfig, nxy::Int)

The master orchestration function to build the 3D simulation domain.
"""
function build_model(config::ModelConfig, nxy::Int)
    # 1. Coordinate System
    zm = calculate_zm(config)
    coordsys = generate_coordinate_system(zm)
    
    MX = MY = nxy + 2
    MZ = length(coordsys.Z)
    
    # Delta h (uniform in XY)
    dx = config.lx / nxy
    dy = config.ly / nxy
    dh = (dx, dy, 0.0) 
    ox = (0.0, 0.0, 0.0)
    SZ = (MX, MY, MZ)

    # 2. Initialize Maps
    ID = zeros(UInt8, MX, MY, MZ)
    
    # 3. Fill ID Map (Strict Original Order)
    # Order: PG > TSV > Silicon > Solder > Resin
    
    # Generate Components
    objects = generate_components(config, zm)
    
    # --- FILL LOGIC ---
    
    # A. PowerGrid 
    fill_power_grid!(ID, config, zm, ox, dh, coordsys.Z)
    
    # B. TSVs
    for obj in filter(o -> o.type == CYLINDER, objects)
        fill_cylinder!(ID, obj, ox, dh, coordsys.Z)
    end
    
    # C. Silicon Plates (GDS based)
    fill_plates!(ID, config, zm, ox, dh, coordsys.Z)
    
    # D. Solder Bumps
    for obj in filter(o -> o.type == SPHERE, objects)
        fill_sphere!(ID, obj, ox, dh, coordsys.Z)
    end
    
    # E. Resin (Fill remaining zero IDs)
    fill_resin!(ID, 6) # MAT_RESIN ID = 6
    
    # 4. Property Maps
    λ = zeros(Float64, size(ID))
    ρ = zeros(Float64, size(ID))
    cp = zeros(Float64, size(ID))
    set_properties!(λ, ρ, cp, ID, config.materials)
    
    return ID, λ, ρ, cp, coordsys
end

# --- Internal Helper Fillers with BBox Optimization and Boundary Guard ---

function fill_power_grid!(ID, config, zm, ox, dh, Z)
    SZ = size(ID)
    lx=0.2e-3; ly=0.2e-3
    s = config.s_dpth - config.pg_dpth
    for z_base in [zm[3]+s, zm[6]+s, zm[9]+s], y in [0.3e-3, 0.7e-3], x in [0.3e-3, 0.7e-3]
        bmin = (x, y, z_base)
        bmax = (x + lx, y + ly, z_base + config.pg_dpth)
        st, ed = get_index_range(bmin, bmax, ox, dh, SZ, Z)
        
        for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
            if ID[i,j,k] != 0 continue end
            c1 = (ox[1] + dh[1]*(i-1), ox[2] + dh[2]*(j-1), Z[k])
            c2 = (c1[1] + dh[1], c1[2] + dh[2], Z[k+1])
            if is_included_rect(c1, c2, bmin, bmax)
                ID[i,j,k] = 7 # MAT_PWRSRC
            end
        end
    end
end

function fill_cylinder!(ID, obj, ox, dh, Z)
    SZ = size(ID)
    ctr = (obj.pos[1], obj.pos[2])
    zmin = obj.pos[3]
    zmax = zmin + obj.dims[2]
    r = obj.dims[1]
    
    bmin = (ctr[1] - r, ctr[2] - r, zmin)
    bmax = (ctr[1] + r, ctr[2] + r, zmax)
    st, ed = get_index_range(bmin, bmax, ox, dh, SZ, Z)
    
    for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
        if ID[i,j,k] != 0 continue end
        c1 = (ox[1] + dh[1]*(i-1), ox[2] + dh[2]*(j-1), Z[k])
        c2 = (c1[1] + dh[1], c1[2] + dh[2], Z[k+1])
        if is_included_cyl(c1, c2, ctr, r, zmin, zmax, samples=10)
            ID[i,j,k] = obj.mat_id
        end
    end
end

function fill_sphere!(ID, obj, ox, dh, Z)
    SZ = size(ID)
    ctr = obj.pos
    r = obj.dims[1]
    
    bmin = (ctr[1] - r, ctr[2] - r, ctr[3] - r)
    bmax = (ctr[1] + r, ctr[2] + r, ctr[3] + r)
    st, ed = get_index_range(bmin, bmax, ox, dh, SZ, Z)
    
    for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
        if ID[i,j,k] != 0 continue end
        c1 = (ox[1] + dh[1]*(i-1), ox[2] + dh[2]*(j-1), Z[k])
        c2 = (c1[1] + dh[1], c1[2] + dh[2], Z[k+1])
        if is_included_sph(c1, c2, ctr, r, samples=10)
            ID[i,j,k] = obj.mat_id
        end
    end
end

function fill_plates!(ID, config, zm, ox, dh, Z)
    SZ = size(ID)
    ranges = [(zm[3], zm[5]), (zm[6], zm[8]), (zm[9], zm[11])]
    
    for (idx, r) in enumerate(ranges)
        gds_path = "../H2-main_TSV_Opt/org_chip$(idx).gds"
        if isfile(gds_path)
            layer = load_gds_layer(gds_path, 1)
            bmin = (0.09e-3, 0.09e-3, r[1])
            bmax = (1.11e-3, 1.11e-3, r[2])
            st, ed = get_index_range(bmin, bmax, ox, dh, SZ, Z)
            
            for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
                if ID[i,j,k] != 0 continue end
                c1 = (ox[1] + dh[1]*(i-1), ox[2] + dh[2]*(j-1), Z[k])
                c2 = (c1[1] + dh[1], c1[2] + dh[2], Z[k+1])
                if is_included_chip(c1, c2, layer, r[1], r[2], samples=3)
                    ID[i,j,k] = 2 # MAT_SILICON
                end
            end
        else
            fill_rect!(ID, (0.1e-3, 0.1e-3, r[1]), (1.1e-3, 1.1e-3, r[2]), 2, ox, dh, Z)
        end
    end
    
    fill_rect!(ID, (0.0, 0.0, zm[1]), (1.2e-3, 1.2e-3, zm[2]), 4, ox, dh, Z)
    fill_rect!(ID, (0.0, 0.0, zm[12]), (1.2e-3, 1.2e-3, zm[13]), 5, ox, dh, Z)
end

function fill_rect!(ID, b1, b2, mat_id, ox, dh, Z)
    SZ = size(ID)
    st, ed = get_index_range(b1, b2, ox, dh, SZ, Z)
    for k in max(1, st[3]-1):ed[3], j in max(1, st[2]-1):ed[2], i in max(1, st[1]-1):ed[1]
        if ID[i,j,k] != 0 continue end
        c1 = (ox[1] + dh[1]*(i-1), ox[2] + dh[2]*(j-1), Z[k])
        c2 = (c1[1] + dh[1], c1[2] + dh[2], Z[k+1])
        if is_included_rect(c1, c2, b1, b2)
            ID[i,j,k] = mat_id
        end
    end
end

function fill_resin!(ID, mat_id)
    for i in eachindex(ID)
        if ID[i] == 0
            ID[i] = mat_id
        end
    end
end

function set_properties!(λ, ρ, cp, ID, materials)
    mat_dict = Dict(m.id => m for m in materials)
    for i in eachindex(ID)
        id = ID[i]
        if haskey(mat_dict, id)
            m = mat_dict[id]
            λ[i] = m.lambda
            ρ[i] = m.rho
            cp[i] = m.cp
        end
    end
end

end # module
