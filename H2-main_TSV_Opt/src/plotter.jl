using Plots
using Printf

function chk_idx(i, nx)
    if i<1
        i = 1
    end
    if i>nx
        i = nx
    end
    return i
end

function find_i(x::Float64, x0, dx, nx)
    i = floor( Int32, (x-x0)/dx+1.5 )
    return chk_idx(i, nx)
end

function find_j(y::Float64, y0, dy, ny)
    j = floor( Int32, (y-y0)/dy+1.5 )
    return chk_idx(j, ny)
end

function find_k(Z::Vector{Float64}, zc, nz, mode)
    if mode==1 || mode==4
        if zc<Z[1] || zc>Z[nz+1]
            println("out of scope in Z : find_z()")
            println(zc, Z)
            exit()
        end

        for k in 1:nz
            if Z[k] ≤ zc < Z[k+1]
                return k
            end
        end
    else
        if zc<Z[1] || zc>Z[nz]
            println("out of scope in Z : find_z()")
            println(zc, Z)
            exit()
        end

        for k in 1:nz-1
            if Z[k] ≤ zc < Z[k+1]
                return k
            end
        end
    end
end

#=
@brief XZ断面
@param [in]     region 1--全領域, 2--内部, 3-- trim
@param [in]     d      解ベクトル
@param [in]     SZ     配列長
@param [in]     ox     原点座標
@param [in]     Δh     X,Y方向格子間隔（Uniform）
@param [in]     fname  ファイル名
=#
function plot_slice_xz(region::Int, mode, d::Array{Float64,3}, Z, y, SZ, ox, Δh, fname, label::String="")
    xs::Int=1
    xe::Int=SZ[1]
    zs::Int=1
    ze::Int=SZ[3]
    if region==2
        xs=2
        xe=SZ[1]-1
        zs=2
        ze=SZ[3]-1
    end
    if region==3
        xs=find_i(0.1e-3, ox[1], Δh[1], SZ[1])
        xe=find_i(1.1e-3, ox[1], Δh[1], SZ[1])
        zs=find_k(Z, 0.0, SZ[3], 4)
        ze=find_k(Z, 0.6e-3, SZ[3], 4)
    end
    #println(xs,":",xe," ",zs,":",ze)

    j = find_j(y, ox[2], Δh[2], SZ[2])
    s = d[xs:xe, j, zs:ze]
    
    # Grid Index -> Physical Coordinate [mm]
    x_coords = [ (ox[1] + (i-1)*Δh[1]) * 1000.0 for i in xs:xe ]
    z_coords = [ Z[k] * 1000.0 for k in zs:ze ]
    
    min_val = minimum(s)
    max_val = maximum(s)
    n_ticks = 6
    println("min=", min_val, " max=", max_val)

    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val)
    log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]

    p = contour(z_coords, x_coords, s, 
        fill=true, 
        c=:thermal, 
        colorbar_ticks=(auto_tick_values, auto_tick_labels),
        colorbar_title="Temperature [K]",
        xlims= (mode==4) ? (0.0, 0.6) : (0.0, 0.6), # Z-axis range
        ylims=(0.0, 1.2), # X-axis range
        xlabel="Position Z [mm]", 
        ylabel="Position X [mm]", 
        size=(800, 600),
        aspect_ratio=:equal)
    savefig(p, fname)
end


#=
@brief XZ断面
@param [in]     d      解ベクトル
@param [in]     SZ     配列長
@param [in]     ox     原点座標
@param [in]     Δh     X,Y方向格子間隔（Uniform）
@param [in]     fname  ファイル名
=#
function plot_slice_xy(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z, fname, label::String="")
    xs::Int=1
    xe::Int=SZ[1]
    ys::Int=1
    ye::Int=SZ[2]
    if region==2
        xs=2
        xe=SZ[1]-1
        ys=2
        ye=SZ[2]-1
    end
    if region==3
        xs=find_i(0.1e-3, ox[1], Δh[1], SZ[1])
        xe=find_i(1.1e-3, ox[1], Δh[1], SZ[1])
        ys=find_j(0.1e-3, ox[2], Δh[2], SZ[2])
        ye=find_j(1.1e-3, ox[2], Δh[2], SZ[2])
    end
    #println(xs,":",xe," ",ys,":",ye)
    
    k = find_k(Z, zc, SZ[3], 4)
    s = d[xs:xe, ys:ye, k]
    
    x_coords = [ (ox[1] + (i-1)*Δh[1]) * 1000.0 for i in xs:xe ]
    y_coords = [ (ox[2] + (j-1)*Δh[2]) * 1000.0 for j in ys:ye ]

    min_val = minimum(s)
    max_val = maximum(s)
    n_ticks = 6
    println("min=", min_val, " max=", max_val)

    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val)
    log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
    title_str="Cross-section at Z=" * @sprintf("%.3f", zc*1000) * " [mm] (k=$k) Uniform $label"

    p = contour(x_coords, y_coords, s, 
        fill=true, 
        c=:thermal,  
        xlims=(0.0, 1.2),
        ylims=(0.0, 1.2),
        colorbar_ticks=(auto_tick_values, auto_tick_labels),
        colorbar_title="Temperature [K]",
        xlabel="Position X [mm]", 
        ylabel="Position Y [mm]", 
        title=title_str, 
        size=(800, 600),
        aspect_ratio=:equal)
    savefig(p, fname)
end



#=
@brief XZ断面（全セル）- NonUniform格子対応
@param [in] d      解ベクトル
@param [in] y      Y座標
@param [in] SZ     配列長
@param [in] ox     原点座標
@param [in] Δh     X,Y方向格子間隔（Uniform）
@param [in] Z      Z方向格子点座標（NonUniform）
@param [in] fname  ファイル名
=#
function plot_slice_xz_nu(region::Int, mode, d::Array{Float64,3}, y, SZ, ox, Δh, Z::Vector{Float64}, fname, label::String="")
    xs::Int=1
    xe::Int=SZ[1]
    zs::Int=1
    ze::Int=SZ[3]
    if region==2
        xs=2
        xe=SZ[1]-1
        zs=2
        ze=SZ[3]-1
    end
    if region==3
        xs=find_i(0.1e-3, ox[1], Δh[1], SZ[1])
        xe=find_i(1.1e-3, ox[1], Δh[1], SZ[1])
        zs=find_k(Z, 0.0, SZ[3], 4)
        ze=find_k(Z, 0.6e-3, SZ[3], 4)
    end
    
    j = find_j(y, ox[2], Δh[2], SZ[2])
    s = d[xs:xe, j, zs:ze]

    # Contour/Line plots should use Cell Centers
    x_centers = [ (ox[1] + (i-0.5)*Δh[1]) * 1000.0 for i in xs:xe ]
    z_centers = [ (Z[k] + Z[k+1]) * 0.5 * 1000.0 for k in zs:ze ]

    min_val = minimum(s)
    max_val = maximum(s)
    n_ticks = 6
    println("min=", min_val, " max=", max_val)

    # 対数スケールでティック値を計算
    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val)
    log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
    
    p = contour(z_centers, x_centers, s, 
                fill=true, 
                c=:thermal, 
                xlims= (0.0, 0.6), # Z
                ylims= (0.0, 1.2), # X
                colorbar_ticks=(auto_tick_values, auto_tick_labels),
                #colorbar_title="Thermal Diffusion [m^2/s]",
                xlabel="Position Z [mm]", 
                ylabel="Position X [mm]", 
                #title="Cross-section at Y=$(y*1000) [mm] (j=$j) Uniform $label", 
                size=(800, 600),
                aspect_ratio=:equal)
     
    savefig(p, fname)
end

#=
@brief XZ断面（全セル）- NonUniform格子対応
@param [in] d      解ベクトル
@param [in] y      Y座標
@param [in] SZ     配列長
@param [in] ox     原点座標
@param [in] Δh     X,Y方向格子間隔（Uniform）
@param [in] Z      Z方向格子点座標（NonUniform）
@param [in] fname  ファイル名
=#
function plot_slice_xy_nu(region, mode, d::Array{Float64,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, fname, label::String="")
    xs::Int=1
    xe::Int=SZ[1]
    ys::Int=1
    ye::Int=SZ[2]
    if region==2
        xs=2
        xe=SZ[1]-1
        ys=2
        ye=SZ[2]-1
    end
    if region==3
        xs=find_i(0.1e-3, ox[1], Δh[1], SZ[1])
        xe=find_i(1.1e-3, ox[1], Δh[1], SZ[1])
        ys=find_j(0.1e-3, ox[2], Δh[2], SZ[2])
        ye=find_j(1.1e-3, ox[2], Δh[2], SZ[2])
    end
    
    k = find_k(Z, zc, SZ[3], 3)
    s = d[xs:xe, ys:ye, k]

    x_centers = [ (ox[1] + (i-0.5)*Δh[1]) * 1000.0 for i in xs:xe ]
    y_centers = [ (ox[2] + (j-0.5)*Δh[2]) * 1000.0 for j in ys:ye ]

    min_val = minimum(s)
    max_val = maximum(s)
    n_ticks = 6
    println("min=", min_val, " max=", max_val)

    if min_val<=0.0; min_val = 1.0e-5; end
    if max_val<=0.0; max_val = 1.0e-5; end
    log_min = log10(min_val)
    log_max = log10(max_val)
    log_ticks = range(log_min, log_max, length=n_ticks)
    auto_tick_values = [10^x for x in log_ticks]
    auto_tick_labels = [@sprintf("%.1E", v) for v in auto_tick_values]
    title_str="Cross-section at Z=" * @sprintf("%.3f", zc*1000) * " [mm] (k=$k) Uniform $label"
    
    p = contour(x_centers, y_centers, s, 
                fill=true, 
                c=:thermal, 
                xlims=(0.0, 1.2),
                ylims=(0.0, 1.2),
                colorbar_ticks=(auto_tick_values, auto_tick_labels),
                colorbar_title="Temperature [K]",
                xlabel="Position X [mm]", 
                ylabel="Position Y [mm]", 
                title=title_str, 
                size=(800, 600),
                aspect_ratio=:equal)
    savefig(p, fname)
end

function plot_line_z_nu(d::Array{Float64,3}, SZ, ox, Δh, Z::Vector{Float64}, xc, yc, filename, label::String="")
    zs::Int=2
    ze::Int=SZ[3]-1
    i = find_i(xc, ox[1], Δh[1], SZ[1])
    j = find_j(yc, ox[2], Δh[2], SZ[2])
    s = d[i, j, zs:ze]
    
    # Line plot uses Centers
    z_centers = [ (Z[k] + Z[k+1]) * 0.5 * 1000.0 for k in zs:ze ]
    println(s)

    min_val = minimum(s)
    max_val = maximum(s)
    println("At ($(xc*1000), $(yc*1000) [mm]: min=", min_val, " max=", max_val)

    p = plot(z_centers, s, 
            marker=:circle, 
            markersize=3,
            xlabel="Position Z [mm]", 
            ylabel="Temperature [K]", 
            title="Z-Line at (x=$(xc*1e3), y=$(yc*1e3)) [mm] $label", 
            label="",
            size=(600, 600)
    )
    _fname = "$(filename).png"
    savefig(p, _fname)

    export_zline_csv(z_centers, s, filename) # CSV uses centers too
end

function plot_line_z(d::Array{Float64,3}, SZ, ox, Δh, xc, yc, filename, label::String="")
    zs::Int=2
    ze::Int=SZ[3]-1

    i = find_i(xc, ox[1], Δh[1], SZ[1])
    j = find_j(yc, ox[2], Δh[2], SZ[2])
    s = d[i, j, zs:ze]
    z_coords = zs:ze
    println(s)

    min_val = minimum(s)
    max_val = maximum(s)
    println("At ($(xc*1000), $(yc*1000) [mm]: min=", min_val, " max=", max_val)

    p = plot(z_coords, s,
        marker=:circle, 
        markersize=3,
        xlabel="Grid Index Z", 
        ylabel="Temperature [K]", 
        title="Z-Line at (x=$(xc*1e3), y=$(yc*1e3)) [mm] $label", 
        label="",
        size=(600, 600)
        )
    _fname = "$(filename).png"
    savefig(p, _fname)
end

"""
export_zline_csv(data, filename)
"""
function export_zline_csv(Z, d, filename::String)

    _fname = "$(filename).csv"
    
    open(_fname, "w") do f
        # ヘッダー
        println(f, "Z [mm], Temperature [K]")
        
        # データ
        for i in 1:length(d)
            _str = @sprintf("%f, %f", Z[i], d[i])
        println(f, "$_str")
        end
    end
    
    println("Z-line CSV saved: $_fname")
end

"""
    plot_material_xy_nu(ID, zc, SZ, ox, Δh, Z, fname)

XY平面の材料分布を可視化（TSV配置確認用）
"""
function plot_material_xy_nu(ID::Array{UInt8,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, fname)
    xs = 2
    xe = SZ[1] - 1
    ys = 2
    ye = SZ[2] - 1
    
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    
    # Heatmap uses Edges for accurate pixel boundaries
    x_edges = [ (ox[1] + (i-1)*Δh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j-1)*Δh[2]) * 1000.0 for j in ys:ye+1 ]
    
    # 材料ID: 1=Copper, 2=Silicon, 3=Solder, 4=FR4, 5=Aluminum, 6=Resin, 7=PowerGrid
    material_names = ["", "1:TSV(Orange)", "2:Si(Gray)", "3:Solder(Yel)", "4:Sub(LBlue)", "5:HS(Blue)", "6:Resin(Grn)", "7:PG(Red)"]
    # Custom Palette: 1:Orange, 2:Gray, 3:Yellow, 4:LightBlue, 5:Blue, 6:Green, 7:Red
    custom_palette = [:orange, :gray, :yellow, :lightblue, :blue, :green, :red]

    title_str = "Material Distribution at Z=" * @sprintf("%.3f", zc*1000) * " mm (k=$k)"
    
    p = heatmap(x_edges, y_edges, s',
                c=palette(custom_palette),
                clims=(0.5, 7.5),
                colorbar=false,
                xlims=(0.0, 1.2),
                ylims=(0.0, 1.2),
                xlabel="Position X [mm]",
                ylabel="Position Y [mm]",
                title=title_str,
                size=(1000, 800),
                aspect_ratio=:equal)
    
    savefig(p, fname)
    println("Saved material XY plot: $fname")
end

"""
    plot_material_yz_nu(ID, xc, SZ, ox, Δh, Z, fname)

YZ平面の材料分布を可視化（層構造確認用）
"""
function plot_material_yz_nu(ID::Array{UInt8,3}, xc, SZ, ox, Δh, Z::Vector{Float64}, fname)
    ys = 2
    ye = SZ[2] - 1
    zs = 2
    ze = SZ[3] - 1
    
    i = find_i(xc, ox[1], Δh[1], SZ[1])
    s = Float64.(ID[i, ys:ye, zs:ze])
    
    y_edges = [ (ox[2] + (j-1)*Δh[2]) * 1000.0 for j in ys:ye+1 ]
    z_edges = [ Z[k] * 1000.0 for k in zs:ze+1 ]
    
    # Custom Palette
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    
    title_str = "Material Distribution at X=" * @sprintf("%.3f", xc*1000) * " mm (i=$i)"
    
    # Rotate: Y on Horizontal, Z on Vertical (Heat Sink Up)
    # s is (ny, nz). heatmap(x, y, A) -> A should be (Nx, Ny).
    # Here X=y_edges (Ny), Y=z_edges (Nz). So s matches (Ny, Nz).
    # Transposing to align dimensions: (Nz, Ny) for (Y-axis, X-axis) mapping?
    # If Y-axis is Z (30), X-axis is Y (240). Matrix should be (30, 240).
    # s is (240, 30). s' is (30, 240).
    p = heatmap(y_edges, z_edges, s',
                c=palette(custom_palette),
                clims=(0.5, 7.5),
                colorbar=false,
                xlims=(0.0, 1.2),  # Y range
                ylims=(0.0, 0.6),  # Z range
                xlabel="Position Y [mm]",
                ylabel="Position Z [mm]",
                title=title_str,
                size=(1000, 800),
                aspect_ratio=:equal)
    
    savefig(p, fname)
    println("Saved material YZ plot: $fname")
end

"""
    plot_heatsource_tsv_overlay_nu(ID, zc, SZ, ox, Δh, Z, fname)

熱源（PowerGrid）とTSV配置を重ねて表示
"""
function plot_heatsource_tsv_overlay_nu(ID::Array{UInt8,3}, zc, SZ, ox, Δh, Z::Vector{Float64}, fname)
    xs = 2
    xe = SZ[1] - 1
    ys = 2
    ye = SZ[2] - 1
    
    k = find_k(Z, zc, SZ[3], 3)
    s = Float64.(ID[xs:xe, ys:ye, k])
    
    # Use Edges for accurate heatmap
    x_edges = [ (ox[1] + (i-1)*Δh[1]) * 1000.0 for i in xs:xe+1 ]
    y_edges = [ (ox[2] + (j-1)*Δh[2]) * 1000.0 for j in ys:ye+1 ]
    
    # Custom Palette: 1:Yellow, 2:Gray, 3:Purple, 4:Orange, 5:Blue, 6:Green, 7:Red
    custom_palette = [:yellow, :gray, :purple, :orange, :blue, :green, :red]
    
    title_str = "Material Distribution at Z=" * @sprintf("%.3f", zc*1000) * " mm"
    
    # Integrated heatmap using the custom palette
    # This automatically handles TSV(1)=Yellow, Si(2)=Gray, Resin(6)=Green, PG(7)=Red
    p = heatmap(x_edges, y_edges, s',
                c=palette(custom_palette),
                clims=(0.5, 7.5),
                colorbar=false,
                xlims=(0.0, 1.2),
                ylims=(0.0, 1.2),
                xlabel="Position X [mm]",
                ylabel="Position Y [mm]",
                title=title_str,
                size=(1000, 900),
                aspect_ratio=:equal,
                legend=false)
    
    savefig(p, fname)
    println("Saved heat source & TSV overlay: $fname")
end
