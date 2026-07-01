
# check_geometry.jl
include("src/heat3ds.jl")
using .NonUniform
using .Common

function check_geo(NX, NY, NZ)
    println("Checking Geometry with Grid: $NX x $NY x $NZ")
    
    # 1. Load Configuration
    config_path = "config.json"
    if !isfile(config_path)
        println("Config not found, generating default...")
        include("generate_config.jl")
    end
    config = init_config(config_path)
    
    # 2. Setup Model Parameters
    modelA.set_model_params!(config)
    
    # Load GDS Geometry (CRITICAL FIX)
    println("Loading GDS files...")
    modelA.load_gds_geometry!("org_chip1.gds", 1)
    modelA.load_gds_geometry!("org_chip2.gds", 2)
    modelA.load_gds_geometry!("org_chip3.gds", 3)
    
    # 3. Generate Grid
    MX = NX + 2
    MY = NY + 2
    MZ = NZ + 2
    SZ = (MX, MY, MZ)
    
    dx = 1.2e-3 / NX
    dy = 1.2e-3 / NY
    Δh = (dx, dy, 1.0)
    ox = (0.0, 0.0, 0.0)

    ID = zeros(UInt8, SZ[1], SZ[2], SZ[3])
    
    # Generate Z-coordinates
    Z, ZC, ΔZ = Zcoordinate.genZ!(NZ)
    
    # 4. Fill Geometry (This places Si, PowerGrid, TSVs)
    modelA.fillID!(ID, ox, Δh, Z)
    
    # 5. Visualization
    println("Generating Visualization...")
    
    function print_slice_stats(ID, z_val, label)
        k = find_k(Z, z_val, SZ[3], 3)
        slice_data = ID[:, :, k]
        
        c_silicon = count(x -> x == modelA.silicon["id"], slice_data)
        c_pg = count(x -> x == modelA.pwrsrc["id"], slice_data)
        c_tsv = count(x -> x == modelA.cupper["id"], slice_data)
        c_solder = count(x -> x == modelA.solder["id"], slice_data)
        
        println("Stats for $label (Z=$z_val, k=$k):")
        println("  Silicon: $c_silicon")
        println("  PowerGrid: $c_pg")
        println("  TSV: $c_tsv")
        println("  Solder: $c_solder")
    end

    # Chip 1 TSV Check (Si1 Top)
    z_c1 = 0.198e-3
    print_slice_stats(ID, z_c1, "Chip 1 TSV")
    plot_heatsource_tsv_overlay_nu(ID, z_c1, SZ, ox, Δh, Z, "geo_overlay_chip1.png")
    
    # Chip 1 Solder Check (UF1 Center)
    # UF1: zm1(0.05) ~ zm2(0.1). Center ~ 0.075.
    z_s1 = 0.075e-3
    print_slice_stats(ID, z_s1, "Chip 1 Solder (UF1)")
    plot_material_xy_nu(ID, z_s1, SZ, ox, Δh, Z, "geo_solder_chip1.png")

    # Chip 2 TSV Check (Si2 Top)
    z_c2 = 0.348e-3
    print_slice_stats(ID, z_c2, "Chip 2 TSV")
    plot_heatsource_tsv_overlay_nu(ID, z_c2, SZ, ox, Δh, Z, "geo_overlay_chip2.png")
    
    # Chip 2 Solder Check (UF2 Center)
    # UF2: zm4(0.2) ~ zm5(0.25). Center ~ 0.225.
    z_s2 = 0.225e-3
    print_slice_stats(ID, z_s2, "Chip 2 Solder (UF2)")
    plot_material_xy_nu(ID, z_s2, SZ, ox, Δh, Z, "geo_solder_chip2.png")

    # Chip 3 TSV Check (Si3 Top)
    z_c3 = 0.498e-3
    print_slice_stats(ID, z_c3, "Chip 3 TSV")
    plot_heatsource_tsv_overlay_nu(ID, z_c3, SZ, ox, Δh, Z, "geo_overlay_chip3.png")

    # Chip 3 Solder Check (UF3 Center)
    # UF3: zm7(0.35) ~ zm8(0.4). Center ~ 0.375.
    z_s3 = 0.375e-3
    print_slice_stats(ID, z_s3, "Chip 3 Solder (UF3)")
    plot_material_xy_nu(ID, z_s3, SZ, ox, Δh, Z, "geo_solder_chip3.png")

    # Top Solder Check (Between Si3 and HeatSink)
    # zm10(0.5) ~ zm11(0.55). Center ~ 0.525.
    z_s_top = 0.525e-3
    print_slice_stats(ID, z_s_top, "Top Solder (UF4?)")
    plot_material_xy_nu(ID, z_s_top, SZ, ox, Δh, Z, "geo_solder_top.png")

    # YZ Plane (Cross-section) at X=0.3mm (TSV Line)
    # Manual grid includes X = 0.3e-3
    xc = 0.3e-3
    plot_material_yz_nu(ID, xc, SZ, ox, Δh, Z, "geo_section_yz_manual.png")

    println("Geometry Check Completed.")
end

check_geo(240, 240, 30)
