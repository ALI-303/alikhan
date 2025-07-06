####################################################################################
# KC705 OV7670 Camera Integration Constraint File
# Target Device: Kintex-7 XC7K325T-2FFG900C
# Board: KC705 Evaluation Board
####################################################################################

####################################################################################
# System Clock (200 MHz Differential Clock)
####################################################################################
set_property PACKAGE_PIN AD12 [get_ports sysclk_p]
set_property PACKAGE_PIN AD11 [get_ports sysclk_n]
set_property IOSTANDARD LVDS [get_ports sysclk_p]
set_property IOSTANDARD LVDS [get_ports sysclk_n]

# Create clock constraints
create_clock -period 5.000 -name sysclk [get_ports sysclk_p]

####################################################################################
# System Reset
####################################################################################
set_property PACKAGE_PIN AB7 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS15 [get_ports cpu_reset]

####################################################################################
# OV7670 Camera Interface
####################################################################################

# Camera Data Bus (D0-D7) - Using GPIO headers
set_property PACKAGE_PIN Y29 [get_ports {ov7670_data[0]}]
set_property PACKAGE_PIN W29 [get_ports {ov7670_data[1]}]
set_property PACKAGE_PIN AA28 [get_ports {ov7670_data[2]}]
set_property PACKAGE_PIN Y28 [get_ports {ov7670_data[3]}]
set_property PACKAGE_PIN AB8 [get_ports {ov7670_data[4]}]
set_property PACKAGE_PIN AA8 [get_ports {ov7670_data[5]}]
set_property PACKAGE_PIN AC9 [get_ports {ov7670_data[6]}]
set_property PACKAGE_PIN AB9 [get_ports {ov7670_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[*]}]

# Camera Control Signals
set_property PACKAGE_PIN H19 [get_ports ov7670_pclk]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_pclk]

set_property PACKAGE_PIN AE26 [get_ports ov7670_href]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_href]

set_property PACKAGE_PIN G19 [get_ports ov7670_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_vsync]

set_property PACKAGE_PIN E19 [get_ports ov7670_xclk]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_xclk]

# SCCB Interface (I2C compatible)
set_property PACKAGE_PIN F20 [get_ports ov7670_sioc]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_sioc]

set_property PACKAGE_PIN G12 [get_ports ov7670_siod]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_siod]

# Camera Reset and Power Down
set_property PACKAGE_PIN AC16 [get_ports ov7670_reset]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_reset]

set_property PACKAGE_PIN AC17 [get_ports ov7670_pwdn]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_pwdn]

####################################################################################
# VGA Interface (Using FMC LPC Connector)
####################################################################################

# VGA Red (8-bit)
set_property PACKAGE_PIN AH12 [get_ports {vga_red[0]}]
set_property PACKAGE_PIN AG12 [get_ports {vga_red[1]}]
set_property PACKAGE_PIN AH11 [get_ports {vga_red[2]}]
set_property PACKAGE_PIN AG11 [get_ports {vga_red[3]}]
set_property PACKAGE_PIN AF10 [get_ports {vga_red[4]}]
set_property PACKAGE_PIN AE10 [get_ports {vga_red[5]}]
set_property PACKAGE_PIN AF9 [get_ports {vga_red[6]}]
set_property PACKAGE_PIN AE9 [get_ports {vga_red[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vga_red[*]}]

# VGA Green (8-bit)
set_property PACKAGE_PIN AD8 [get_ports {vga_green[0]}]
set_property PACKAGE_PIN AC8 [get_ports {vga_green[1]}]
set_property PACKAGE_PIN AB10 [get_ports {vga_green[2]}]
set_property PACKAGE_PIN AA10 [get_ports {vga_green[3]}]
set_property PACKAGE_PIN AB11 [get_ports {vga_green[4]}]
set_property PACKAGE_PIN AA11 [get_ports {vga_green[5]}]
set_property PACKAGE_PIN Y10 [get_ports {vga_green[6]}]
set_property PACKAGE_PIN W10 [get_ports {vga_green[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vga_green[*]}]

# VGA Blue (8-bit)
set_property PACKAGE_PIN V9 [get_ports {vga_blue[0]}]
set_property PACKAGE_PIN V8 [get_ports {vga_blue[1]}]
set_property PACKAGE_PIN U10 [get_ports {vga_blue[2]}]
set_property PACKAGE_PIN T10 [get_ports {vga_blue[3]}]
set_property PACKAGE_PIN T9 [get_ports {vga_blue[4]}]
set_property PACKAGE_PIN T8 [get_ports {vga_blue[5]}]
set_property PACKAGE_PIN R8 [get_ports {vga_blue[6]}]
set_property PACKAGE_PIN R7 [get_ports {vga_blue[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vga_blue[*]}]

# VGA Sync Signals
set_property PACKAGE_PIN AH13 [get_ports vga_hsync]
set_property PACKAGE_PIN AG13 [get_ports vga_vsync]
set_property PACKAGE_PIN AG10 [get_ports vga_clk]
set_property IOSTANDARD LVCMOS18 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS18 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS18 [get_ports vga_clk]

####################################################################################
# Debug Interface (LEDs and Switches)
####################################################################################

# GPIO LEDs
set_property PACKAGE_PIN AB8 [get_ports {gpio_led[0]}]
set_property PACKAGE_PIN AA8 [get_ports {gpio_led[1]}]
set_property PACKAGE_PIN AC9 [get_ports {gpio_led[2]}]
set_property PACKAGE_PIN AB9 [get_ports {gpio_led[3]}]
set_property PACKAGE_PIN AE26 [get_ports {gpio_led[4]}]
set_property PACKAGE_PIN G19 [get_ports {gpio_led[5]}]
set_property PACKAGE_PIN E19 [get_ports {gpio_led[6]}]
set_property PACKAGE_PIN F20 [get_ports {gpio_led[7]}]
set_property IOSTANDARD LVCMOS15 [get_ports {gpio_led[*]}]

# DIP Switches  
set_property PACKAGE_PIN Y29 [get_ports {gpio_dip_sw[0]}]
set_property PACKAGE_PIN W29 [get_ports {gpio_dip_sw[1]}]
set_property PACKAGE_PIN AA28 [get_ports {gpio_dip_sw[2]}]
set_property PACKAGE_PIN Y28 [get_ports {gpio_dip_sw[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {gpio_dip_sw[*]}]

# Push Button Switches
set_property PACKAGE_PIN G12 [get_ports gpio_sw_n]
set_property PACKAGE_PIN AC16 [get_ports gpio_sw_s]
set_property PACKAGE_PIN AC17 [get_ports gpio_sw_w]
set_property PACKAGE_PIN AA12 [get_ports gpio_sw_e]
set_property PACKAGE_PIN AB12 [get_ports gpio_sw_c]
set_property IOSTANDARD LVCMOS25 [get_ports gpio_sw_*]

####################################################################################
# UART Interface (Optional Debug)
####################################################################################
set_property PACKAGE_PIN M19 [get_ports uart_tx]
set_property PACKAGE_PIN K24 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS25 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS25 [get_ports uart_rx]

####################################################################################
# Clock Constraints
####################################################################################

# Generated clocks from clock wizard
create_generated_clock -name clk_100mhz [get_pins clock_generator/clk_out1]
create_generated_clock -name clk_25mhz [get_pins clock_generator/clk_out2]
create_generated_clock -name clk_24mhz [get_pins clock_generator/clk_out3]

# Camera pixel clock (asynchronous)
create_clock -period 40.000 -name ov7670_pclk [get_ports ov7670_pclk]

# Clock domain crossing constraints
set_clock_groups -asynchronous \
    -group [get_clocks sysclk] \
    -group [get_clocks clk_100mhz] \
    -group [get_clocks clk_25mhz] \
    -group [get_clocks clk_24mhz] \
    -group [get_clocks ov7670_pclk]

####################################################################################
# Timing Constraints
####################################################################################

# Input delays for camera data (relative to PCLK)
set_input_delay -clock [get_clocks ov7670_pclk] -min 5.0 [get_ports {ov7670_data[*]}]
set_input_delay -clock [get_clocks ov7670_pclk] -max 15.0 [get_ports {ov7670_data[*]}]
set_input_delay -clock [get_clocks ov7670_pclk] -min 5.0 [get_ports ov7670_href]
set_input_delay -clock [get_clocks ov7670_pclk] -max 15.0 [get_ports ov7670_href]
set_input_delay -clock [get_clocks ov7670_pclk] -min 5.0 [get_ports ov7670_vsync]
set_input_delay -clock [get_clocks ov7670_pclk] -max 15.0 [get_ports ov7670_vsync]

# Output delays for VGA signals
set_output_delay -clock [get_clocks clk_25mhz] -min 2.0 [get_ports {vga_red[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -max 5.0 [get_ports {vga_red[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -min 2.0 [get_ports {vga_green[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -max 5.0 [get_ports {vga_green[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -min 2.0 [get_ports {vga_blue[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -max 5.0 [get_ports {vga_blue[*]}]
set_output_delay -clock [get_clocks clk_25mhz] -min 2.0 [get_ports vga_hsync]
set_output_delay -clock [get_clocks clk_25mhz] -max 5.0 [get_ports vga_hsync]
set_output_delay -clock [get_clocks clk_25mhz] -min 2.0 [get_ports vga_vsync]
set_output_delay -clock [get_clocks clk_25mhz] -max 5.0 [get_ports vga_vsync]

# SCCB timing constraints
set_output_delay -clock [get_clocks clk_100mhz] -min 2.0 [get_ports ov7670_sioc]
set_output_delay -clock [get_clocks clk_100mhz] -max 8.0 [get_ports ov7670_sioc]

# Relaxed constraints for control signals
set_output_delay -clock [get_clocks clk_24mhz] -min 5.0 [get_ports ov7670_xclk]
set_output_delay -clock [get_clocks clk_24mhz] -max 10.0 [get_ports ov7670_xclk]

####################################################################################
# Physical Constraints
####################################################################################

# Block RAM placement (to optimize routing)
set_property LOC RAMB36_X5Y10 [get_cells fb_controller/frame_buffer_inst/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramb36e1_0]

# Clock buffer placement
set_property LOC MMCME2_ADV_X1Y1 [get_cells clock_generator/mmcm_adv_inst]

####################################################################################
# Configuration Settings
####################################################################################

# Configuration mode
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

# DCI cascade
set_property DCI_CASCADE {34 32} [get_iobanks 35]

####################################################################################
# Debug Settings (for ChipScope/ILA)
####################################################################################

# Uncomment for debugging with ILA
# set_property MARK_DEBUG true [get_nets {ov7670_data[*]}]
# set_property MARK_DEBUG true [get_nets ov7670_href]
# set_property MARK_DEBUG true [get_nets ov7670_vsync]
# set_property MARK_DEBUG true [get_nets capture_we]
# set_property MARK_DEBUG true [get_nets frame_done]