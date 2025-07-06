#================================================================================
# KC705 OV7670 Camera with HDMI Output - Build Script
# 
# Automated build script for Vivado synthesis and implementation
# Supports multiple HDMI modes and configurations
#================================================================================

# Set project parameters
set project_name "kc705_ov7670_hdmi"
set part_number "xc7k325tffg900-2"  # KC705 FPGA part
set board_part "xilinx.com:kc705:part0:1.6"

# Set HDMI configuration parameters
set HDMI_MODE "720p"              # Options: "720p", "1080p60", "1080p30"
set USE_EXTERNAL_HDMI_IC 1        # 1 for ADV7511, 0 for direct HDMI
set ENABLE_ILA 0                   # 1 to enable Integrated Logic Analyzer

puts "=========================================="
puts "Building KC705 OV7670 HDMI Project"
puts "HDMI Mode: $HDMI_MODE"
puts "External IC: $USE_EXTERNAL_HDMI_IC"
puts "Enable ILA: $ENABLE_ILA"
puts "=========================================="

# Create project directory
set project_dir "./${project_name}"
if {[file exists $project_dir]} {
    puts "Removing existing project directory..."
    file delete -force $project_dir
}

# Create new project
create_project $project_name $project_dir -part $part_number
set_property board_part $board_part [current_project]

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

#================================================================================
# Add Source Files
#================================================================================

puts "Adding source files..."

# Add HDL source files
add_files -norecurse {
    kc705_ov7670_hdmi_top.v
    hdmi_display_controller.v
    frame_buffer_controller.v
    ov7670_capture.v
    reset_generator.v
    uart_debug_tx.v
}

# Add constraints file
add_files -fileset constrs_1 -norecurse kc705_ov7670_hdmi.xdc

# Set top module
set_property top kc705_ov7670_hdmi_top [current_fileset]

#================================================================================
# Generate IP Cores
#================================================================================

puts "Generating IP cores..."

# 1. Clock Wizard for HDMI clocks
puts "Creating Clock Wizard IP for HDMI..."
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_hdmi

# Configure Clock Wizard based on HDMI mode
if {$HDMI_MODE == "720p" || $HDMI_MODE == "1080p30"} {
    set pixel_freq 74.25
    set tmds_freq 371.25
} elseif {$HDMI_MODE == "1080p60"} {
    set pixel_freq 148.5
    set tmds_freq 742.5
} else {
    puts "ERROR: Invalid HDMI_MODE specified"
    exit 1
}

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {200.000} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_USED {true} \
    CONFIG.CLKOUT5_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {24.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ $pixel_freq \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ $tmds_freq \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.CLKIN1_JITTER_PS {50.0} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {5.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {5.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {42} \
    CONFIG.MMCM_CLKOUT2_DIVIDE [expr {1000.0 / $pixel_freq}] \
    CONFIG.MMCM_CLKOUT3_DIVIDE [expr {1000.0 / $tmds_freq}] \
    CONFIG.MMCM_CLKOUT4_DIVIDE {5} \
    CONFIG.NUM_OUT_CLKS {5} \
] [get_ips clk_wiz_hdmi]

# 2. Block Memory Generator for frame buffer
puts "Creating Block Memory Generator IP..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name frame_buffer_bram

set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A {24} \
    CONFIG.Write_Depth_A {76800} \
    CONFIG.Read_Width_A {24} \
    CONFIG.Write_Width_B {24} \
    CONFIG.Read_Width_B {24} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Enable_Rate {100} \
] [get_ips frame_buffer_bram]

# 3. MIG DDR3 Controller (for larger frame buffer)
puts "Creating MIG DDR3 Controller IP..."
create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 -module_name mig_7series_0

# Configure MIG for KC705 DDR3
set_property -dict [list \
    CONFIG.XML_INPUT_FILE {mig_kc705_ddr3.prj} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
    CONFIG.BOARD_MIG_PARAM {Custom} \
] [get_ips mig_7series_0]

# 4. ILA (Integrated Logic Analyzer) - Optional
if {$ENABLE_ILA} {
    puts "Creating ILA IP for debugging..."
    create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
    
    set_property -dict [list \
        CONFIG.C_PROBE0_WIDTH {24} \
        CONFIG.C_PROBE1_WIDTH {19} \
        CONFIG.C_PROBE2_WIDTH {8} \
        CONFIG.C_PROBE3_WIDTH {4} \
        CONFIG.C_PROBE4_WIDTH {16} \
        CONFIG.C_NUM_OF_PROBES {5} \
        CONFIG.C_EN_STRG_QUAL {1} \
        CONFIG.C_INPUT_PIPE_STAGES {2} \
        CONFIG.C_ADV_TRIGGER {true} \
        CONFIG.ALL_PROBE_SAME_MU {true} \
        CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
    ] [get_ips ila_0]
}

# 5. FIFO Generator for clock domain crossing
puts "Creating FIFO Generator IP for CDC..."
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name async_fifo_24bit

set_property -dict [list \
    CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
    CONFIG.Input_Data_Width {24} \
    CONFIG.Input_Depth {512} \
    CONFIG.Output_Data_Width {24} \
    CONFIG.Output_Depth {512} \
    CONFIG.Use_Embedded_Registers {false} \
    CONFIG.Reset_Type {Asynchronous_Reset} \
    CONFIG.Full_Flags_Reset_Value {1} \
    CONFIG.Valid_Flag {true} \
    CONFIG.Data_Count_Width {9} \
    CONFIG.Write_Data_Count_Width {9} \
    CONFIG.Read_Data_Count_Width {9} \
    CONFIG.Full_Threshold_Assert_Value {511} \
    CONFIG.Full_Threshold_Negate_Value {510} \
] [get_ips async_fifo_24bit]

#================================================================================
# Generate all IP cores
#================================================================================
puts "Generating all IP cores..."
generate_target all [get_ips]

# Synthesize IP cores
puts "Synthesizing IP cores..."
create_ip_run [get_ips]
launch_runs -jobs 8 [get_runs clk_wiz_hdmi_synth_1]
launch_runs -jobs 8 [get_runs frame_buffer_bram_synth_1]
launch_runs -jobs 8 [get_runs mig_7series_0_synth_1]
launch_runs -jobs 8 [get_runs async_fifo_24bit_synth_1]

if {$ENABLE_ILA} {
    launch_runs -jobs 8 [get_runs ila_0_synth_1]
}

# Wait for IP synthesis to complete
wait_on_run clk_wiz_hdmi_synth_1
wait_on_run frame_buffer_bram_synth_1
wait_on_run mig_7series_0_synth_1
wait_on_run async_fifo_24bit_synth_1

if {$ENABLE_ILA} {
    wait_on_run ila_0_synth_1
}

#================================================================================
# Set Implementation Strategy
#================================================================================

puts "Setting implementation strategy..."

# Use high-performance synthesis strategy for HDMI timing
set_property strategy {Vivado Synthesis Defaults} [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Use timing-driven implementation strategy
set_property strategy {Performance_ExtraTimingOpt} [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Set additional implementation options for HDMI
set_property -name {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} -value {-timing_summary} -objects [get_runs impl_1]
set_property -name {STEPS.ROUTE_DESIGN.ARGS.MORE OPTIONS} -value {-timing_summary} -objects [get_runs impl_1]

#================================================================================
# Build Configuration
#================================================================================

# Set generic parameters for top module
set_property generic [list \
    HDMI_MODE=$HDMI_MODE \
    USE_EXTERNAL_HDMI_IC=$USE_EXTERNAL_HDMI_IC \
    ENABLE_ILA=$ENABLE_ILA \
] [current_fileset]

puts "Project configuration:"
puts "  HDMI_MODE = $HDMI_MODE"
puts "  USE_EXTERNAL_HDMI_IC = $USE_EXTERNAL_HDMI_IC"
puts "  ENABLE_ILA = $ENABLE_ILA"

#================================================================================
# Synthesis
#================================================================================

puts "Starting synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis completed successfully"

# Open synthesized design for reports
open_run synth_1
report_utilization -file utilization_synth.rpt
report_timing_summary -file timing_summary_synth.rpt

#================================================================================
# Implementation
#================================================================================

puts "Starting implementation..."
reset_run impl_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Implementation completed successfully"

# Open implemented design for reports
open_run impl_1
report_utilization -hierarchical -file utilization_impl.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file timing_summary_impl.rpt
report_clock_utilization -file clock_utilization.rpt
report_power -file power_analysis.rpt

#================================================================================
# Generate Bitstream
#================================================================================

puts "Generating bitstream..."
reset_run impl_1 -quiet
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

puts "Bitstream generated successfully"

# Copy bitstream to project root
file copy -force "${project_dir}/${project_name}.runs/impl_1/kc705_ov7670_hdmi_top.bit" "./kc705_ov7670_hdmi.bit"

#================================================================================
# Generate Reports
#================================================================================

puts "Generating final reports..."

# Resource utilization
report_utilization -hierarchical -file utilization_final.rpt

# Timing analysis
check_timing -verbose -file timing_check.rpt
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file timing_final.rpt

# Clock analysis
report_clocks -file clocks_final.rpt
report_clock_interaction -delay_type min_max -significant_digits 3 -file clock_interaction.rpt

# Power analysis
report_power -file power_final.rpt

# I/O analysis
report_io -file io_final.rpt

#================================================================================
# Performance Summary
#================================================================================

puts ""
puts "=========================================="
puts "BUILD COMPLETED SUCCESSFULLY"
puts "=========================================="
puts "Project: $project_name"
puts "Part: $part_number"
puts "HDMI Mode: $HDMI_MODE"
puts ""
puts "Output files:"
puts "  Bitstream: kc705_ov7670_hdmi.bit"
puts "  Reports: *.rpt files"
puts ""

# Check timing closure
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

puts "Timing Summary:"
puts "  Setup WNS: ${wns} ns"
puts "  Hold WNS: ${whs} ns"

if {$wns < 0.0} {
    puts "WARNING: Setup timing violation detected!"
}
if {$whs < 0.0} {
    puts "WARNING: Hold timing violation detected!"
}

puts "=========================================="

# Create hardware definition file for SDK (if needed)
if {[file exists "${project_dir}/${project_name}.runs/impl_1/kc705_ov7670_hdmi_top.sysdef"]} {
    file copy -force "${project_dir}/${project_name}.runs/impl_1/kc705_ov7670_hdmi_top.sysdef" "./kc705_ov7670_hdmi.hdf"
    puts "Hardware definition file created: kc705_ov7670_hdmi.hdf"
}

puts "Build script completed at [clock format [clock seconds]]"