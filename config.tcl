# Global
# ------

# Name
set ::env(DESIGN_NAME) pyfive_top

# We're a top level
set ::env(DESIGN_IS_CORE) 1

# Diode insertion
	#  Spray
set ::env(DIODE_INSERTION_STRATEGY) 0

	# Smart-"ish"
#set ::env(DIODE_INSERTION_STRATEGY) 3
#set ::env(GLB_RT_MAX_DIODE_INS_ITERS) 10

# Timing configuration
set ::env(CLOCK_PERIOD) "15"
set ::env(CLOCK_PORT) "wb_clk_i"


# Sources
# -------

# Local sources + no2usb sources
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v $::env(DESIGN_DIR)/no2usb/rtl/*.v]

# Macros
set ::env(VERILOG_FILES_BLACKBOX) [glob $::env(DESIGN_DIR)/macros/bb/*.v]
set ::env(EXTRA_LEFS) [glob $::env(DESIGN_DIR)/macros/lef/*.lef]
set ::env(EXTRA_GDS_FILES) [glob $::env(DESIGN_DIR)/macros/gds/*.gds]

# Need blackbox for cells
set ::env(SYNTH_READ_BLACKBOX_LIB) 1


# Floorplanning
# -------------

# Fixed area and pin position
set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) [list 0.0 0.0 1748.0 1360.0]
set ::env(FP_PIN_ORDER_CFG) $::env(DESIGN_DIR)/pin_order.cfg

# Halo around the Macros
set ::env(FP_HORIZONTAL_HALO) 25
set ::env(FP_VERTICAL_HALO) 20

# PDN special config
	# Ensure we have met4 vertical stripes between SRAMs with
	# alternate polarity
set ::env(FP_PDN_VOFFSET) 7.11
set ::env(FP_PDN_VPITCH) [expr 861.37 / 7]

	# Ensure we have one horizontal stripe in the very top/bot
	# row of cell (not sure where 0.24 comes from ...)
set ::env(FP_PDN_HOFFSET) [expr 50 - (2.72 * 4) + 0.24]
set ::env(FP_PDN_HPITCH) 180

set ::env(PDN_CFG) $::env(DESIGN_DIR)/pdn.tcl



# Placement
# ---------

set ::env(PL_TARGET_DENSITY) 0.40

# SRAM is 386.480 BY 456.235, place 3 at the top
set ::env(MACRO_PLACEMENT_CFG) $::env(DESIGN_DIR)/macro_placement.cfg


# Routing
# -------

# Go fast
set ::env(ROUTING_CORES) 6

# It's overly worried about congestion, but it's fine
set ::env(GLB_RT_ALLOW_CONGESTION) 1

# Avoid li1 for routing if possible
set ::env(GLB_RT_MINLAYER) 2

# Don't route on met5
set ::env(GLB_RT_MAXLAYER) 5

# Obstructions
    # li1 over the SRAM areas
	# met5 over the whole design
set ::env(GLB_RT_OBS) "li1 0.00 22.68 1748.00 486.24, li1 0.00 851.08 1748.00 486.24, met5 0.0 0.0 1748.0 1360.0"


# DRC
# ---

# Can't run DRC on final GDS because SRAM
set ::env(MAGIC_DRC_USE_GDS) 0


# Tape Out
# --------

set ::env(MAGIC_ZEROIZE_ORIGIN) 0


# Cell library specific config
# ----------------------------

set filename $::env(DESIGN_DIR)/$::env(PDK)_$::env(STD_CELL_LIBRARY)_config.tcl
if { [file exists $filename] == 1} {
	source $filename
}
