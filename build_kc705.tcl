#!/usr/bin/env vivado -mode batch -source
#
# KC705 OV7670 Camera Integration Build Script
# Vivado TCL Script for automated build process
#

# Set project properties
set project_name "KC705_OV7670"
set project_dir "./vivado_project"
set part_name "xc7k325tffg900-2"

# Create project
create_project $project_name $project_dir -part $part_name -force

# Set project properties
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# Add source files
add_files -norecurse {
    kc705_ov7670_top.v
    ov7670_controller.v
    ov7670_capture.v
    ov7670_registers.v
    vga_controller.v
    frame_buffer_controller.v
    vga_display_gen.v
    reset_generator.v
    uart_debug_tx.v
}

# Add constraint file
add_files -fileset constrs_1 -norecurse kc705_ov7670.xdc

# Create IP cores
puts "Creating Clock Wizard IP..."
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {200.000} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {24.000} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.LOCKED_PORT {locked} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {sys_diff_clock} \
    CONFIG.RESET_BOARD_INTERFACE {reset} \
] [get_ips clk_wiz_0]

puts "Creating Block Memory Generator IP for Frame Buffer..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name frame_buffer_bram
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Write_Width_A {16} \
    CONFIG.Write_Depth_A {307200} \
    CONFIG.Read_Width_A {16} \
    CONFIG.Write_Width_B {16} \
    CONFIG.Read_Width_B {16} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Enable_Rate {100} \
] [get_ips frame_buffer_bram]

# Optional: Create ILA for debugging
puts "Creating ILA IP for debugging..."
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
    CONFIG.C_PROBE0_WIDTH {8} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {19} \
    CONFIG.C_PROBE5_WIDTH {16} \
    CONFIG.C_NUM_OF_PROBES {6} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.C_INPUT_PIPE_STAGES {0} \
    CONFIG.C_ADV_TRIGGER {false} \
    CONFIG.ALL_PROBE_SAME_MU {true} \
] [get_ips ila_0]

# Generate IP
generate_target all [get_ips]

# Update compile order
update_compile_order -fileset sources_1

# Set top module
set_property top kc705_ov7670_top [current_fileset]

# Run synthesis
puts "Starting Synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

# Report synthesis results
open_run synth_1 -name synth_1
report_utilization -file utilization_synth.rpt
report_timing_summary -file timing_synth.rpt

# Run implementation
puts "Starting Implementation..."
reset_run impl_1
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Check implementation results
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

# Report implementation results
open_run impl_1
report_utilization -file utilization_impl.rpt
report_timing_summary -file timing_impl.rpt
report_route_status -file route_status.rpt
report_drc -file drc.rpt
report_power -file power.rpt

# Generate bitstream
puts "Generating Bitstream..."
reset_run impl_1 -quiet
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Check bitstream generation
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Bitstream generation failed"
}

puts "Build completed successfully!"
puts "Bitstream location: [get_property DIRECTORY [get_runs impl_1]]/kc705_ov7670_top.bit"

# Optional: Program device if connected
# open_hw_manager
# connect_hw_server
# open_hw_target
# set_property PROGRAM.FILE {./vivado_project/KC705_OV7670.runs/impl_1/kc705_ov7670_top.bit} [get_hw_devices xc7k325t_0]
# program_hw_devices [get_hw_devices xc7k325t_0]
# close_hw_manager

# Create reports directory and move reports
file mkdir reports
file rename utilization_synth.rpt reports/
file rename timing_synth.rpt reports/
file rename utilization_impl.rpt reports/
file rename timing_impl.rpt reports/
file rename route_status.rpt reports/
file rename drc.rpt reports/
file rename power.rpt reports/

puts "Reports saved to ./reports/ directory"
puts "Project saved to $project_dir"

# Close project
close_project