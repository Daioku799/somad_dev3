push!(LOAD_PATH, "H2-main-ext/src")
using modelA
using Plots
using Printf

# Mocking the solver's coordinate setup
nxy = 60
nz = 33
ID = zeros(UInt8, nxy+2, nxy+2, nz)
ox = (0.0, 0.0, 0.0)
dx = 1.2e-3 / nxy
dy = 1.2e-3 / nxy
dh = (dx, dy, 0.0)

# We need Z markers for the new system. 
# ModelBuilder.build_model handles this, but since we are calling fillID!:
# modelA.fillID! internally calls generate_test_config() and calculate_zm.

# Let's use the internal build_model to see what happens.
ID = modelA.model_test(nxy)

# Plotting ID map slices to see geometry
include("H2-main-ext/src/plotter.jl")
# Z coordinates are needed for plotter. 
# We need to reach into ModelBuilder to get them or re-calculate.
import .modelA.ModelBuilder
config = ModelBuilder.ConfigLoader.generate_test_config()
zm = ModelBuilder.calculate_zm(config)
coordsys = ModelBuilder.Grid.generate_coordinate_system(zm)
Z = coordsys.Z

# Convert ID to Float64 for contour plot
ID_f = Float64.(ID)

# XY slice at Silicon 1 (zm[3] to zm[4])
# zm[3] is roughly 0.1, zm[4] is roughly 0.2. So zc=0.15
plot_slice_xy_nu(1, 1, ID_f, 0.15e-3, size(ID), ox, dh, Z, "test_id_si1.png", "ID Map Si1")

# YZ slice at center (x=0.6mm)
plot_slice_xz_nu(1, 1, ID_f, 0.6e-3, size(ID), ox, dh, Z, "test_id_yz.png", "ID Map YZ")

println("Plots saved: test_id_si1.png, test_id_yz.png")
