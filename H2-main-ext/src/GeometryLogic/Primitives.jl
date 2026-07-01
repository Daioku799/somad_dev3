module Primitives

export is_included_rect, is_included_cyl, is_included_sph

const TOLERANCE = 1e-12

"""
    check_bbox_overlap(a1, a2, b1, b2; tol=TOLERANCE) -> Bool

Check if bounding box A (a1, a2) overlaps with bounding box B (b1, b2) under tolerance.
"""
function check_bbox_overlap(a1, a2, b1, b2; tol=TOLERANCE)
    axlo, aylo, azlo = min.(a1, a2)
    axhi, ayhi, azhi = max.(a1, a2)
    bxlo, bylo, bzlo = min.(b1, b2)
    bxhi, byhi, bzhi = max.(b1, b2)

    return (axlo - tol <= bxhi) && (axhi + tol >= bxlo) &&
           (aylo - tol <= byhi) && (ayhi + tol >= bylo) &&
           (azlo - tol <= bzhi) && (azhi + tol >= bzlo)
end

"""
    is_included_rect(a1, a2, b1, b2) -> Bool

セルA(a1,a2) が直方体のジオメトリ領域B(b1,b2) に 50%以上含まれている場合 true を返す。
"""
function is_included_rect(a1, a2, b1, b2)
    # BBox early rejection
    if !check_bbox_overlap(a1, a2, b1, b2)
        return false
    end

    # Aの体積
    volA = abs((a2[1] - a1[1]) * (a2[2] - a1[2]) * (a2[3] - a1[3]))
    if volA <= 0.0
        return false
    end

    # 重なり体積
    axlo, aylo, azlo = min.(a1, a2)
    axhi, ayhi, azhi = max.(a1, a2)
    bxlo, bylo, bzlo = min.(b1, b2)
    bxhi, byhi, bzhi = max.(b1, b2)

    ox = max(0.0, min(axhi, bxhi) - max(axlo, bxlo))
    oy = max(0.0, min(ayhi, byhi) - max(aylo, bylo))
    oz = max(0.0, min(azhi, bzhi) - max(azlo, bzlo))

    overlap_vol = ox * oy * oz

    return overlap_vol >= 0.5 * volA
end

"""
    is_included_cyl(a1, a2, cyl_ctr, cyl_r, cyl_zmin, cyl_zmax; samples=50)

直方体(a1,a2)の体積のうち、円柱（Z軸方向）に含まれる割合が50%以上ならtrue。
"""
function is_included_cyl(a1, a2, cyl_ctr, cyl_r, cyl_zmin, cyl_zmax; samples=50)
    # BBox early rejection
    b1 = (cyl_ctr[1] - cyl_r, cyl_ctr[2] - cyl_r, cyl_zmin)
    b2 = (cyl_ctr[1] + cyl_r, cyl_ctr[2] + cyl_r, cyl_zmax)
    if !check_bbox_overlap(a1, a2, b1, b2)
        return false
    end

    xlo, ylo, zlo = min.(a1, a2)
    xhi, yhi, zhi = max.(a1, a2)
    volA = (xhi - xlo) * (yhi - ylo) * (zhi - zlo)
    if volA <= 0.0
        return false
    end

    # Early true: 8 corners inside cylinder
    corners = ((xlo,ylo,zlo),(xlo,ylo,zhi),(xlo,yhi,zlo),(xlo,yhi,zhi),
               (xhi,ylo,zlo),(xhi,ylo,zhi),(xhi,yhi,zlo),(xhi,yhi,zhi))
    all_inside = all(((x - cyl_ctr[1])^2 + (y - cyl_ctr[2])^2 <= (cyl_r + TOLERANCE)^2 && cyl_zmin - TOLERANCE <= z <= cyl_zmax + TOLERANCE) for (x,y,z) in corners)
    if all_inside
        return true
    end

    inside_count = 0
    total_count = 0

    for i in 1:samples, j in 1:samples, k in 1:samples
        x = xlo + (i - 0.5) * (xhi - xlo) / samples
        y = ylo + (j - 0.5) * (yhi - ylo) / samples
        z = zlo + (k - 0.5) * (zhi - zlo) / samples

        dx = x - cyl_ctr[1]
        dy = y - cyl_ctr[2]
        r2 = dx^2 + dy^2
        if r2 <= (cyl_r + TOLERANCE)^2 && (cyl_zmin - TOLERANCE <= z <= cyl_zmax + TOLERANCE)
            inside_count += 1
        end
        total_count += 1
    end

    overlap_vol = volA * inside_count / total_count
    return overlap_vol >= 0.5 * volA
end

"""
    is_included_sph(a1, a2, center, radius; samples=50) -> Bool

直方体 A (対角点 a1, a2) の体積のうち、球 (center, radius) に含まれる割合が50%以上なら true。
"""
function is_included_sph(a1, a2, center, radius; samples::Int=50)
    # BBox early rejection
    b1 = (center[1] - radius, center[2] - radius, center[3] - radius)
    b2 = (center[1] + radius, center[2] + radius, center[3] + radius)
    if !check_bbox_overlap(a1, a2, b1, b2)
        return false
    end

    xlo, ylo, zlo = min.(a1, a2)
    xhi, yhi, zhi = max.(a1, a2)
    volA = (xhi - xlo) * (yhi - ylo) * (zhi - zlo)
    if volA <= 0.0
        return false
    end

    cx, cy, cz = center
    r2_with_tol = (radius + TOLERANCE)^2

    # Early true: 8 corners inside sphere
    corners = ((xlo,ylo,zlo),(xlo,ylo,zhi),(xlo,yhi,zlo),(xlo,yhi,zhi),
               (xhi,ylo,zlo),(xhi,ylo,zhi),(xhi,yhi,zlo),(xhi,yhi,zhi))
    all_inside = all(((x - cx)^2 + (y - cy)^2 + (z - cz)^2 <= r2_with_tol) for (x,y,z) in corners)
    if all_inside
        return true
    end

    inside_count = 0
    total_count  = samples^3
    dx = (xhi - xlo) / samples
    dy = (yhi - ylo) / samples
    dz = (zhi - zlo) / samples

    x = xlo + dx/2
    for i in 1:samples
        y = ylo + dy/2
        for j in 1:samples
            z = zlo + dz/2
            for k in 1:samples
                if (x - cx)^2 + (y - cy)^2 + (z - cz)^2 <= r2_with_tol
                    inside_count += 1
                end
                z += dz
            end
            y += dy
        end
        x += dx
    end

    overlap_vol_est = volA * (inside_count / total_count)
    return overlap_vol_est >= 0.5 * volA
end

end # module
