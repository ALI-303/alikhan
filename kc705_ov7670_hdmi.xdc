#================================================================================
# KC705 OV7670 Camera with HDMI Output - Constraints File
# 
# Pin assignments and timing constraints for KC705 board
# Supports both external HDMI transmitter and direct HDMI output
#================================================================================

#================================================================================
# Clock Constraints
#================================================================================

# 200MHz differential system clock (SYSCLK)
set_property PACKAGE_PIN AD12 [get_ports clk_200mhz]
set_property PACKAGE_PIN AD11 [get_ports clk_200mhz_n]
set_property IOSTANDARD LVDS [get_ports clk_200mhz*]

# Create main clocks
create_clock -period 5.000 [get_ports clk_200mhz]

# Generated clocks (will be created by Clock Wizard IP)
# These are reference constraints - actual clocks created by IP
create_generated_clock -name clk_100mhz -source [get_pins clk_gen_inst/clk_in1] -divide_by 2 [get_pins clk_gen_inst/clk_out1]
create_generated_clock -name clk_24mhz -source [get_pins clk_gen_inst/clk_in1] -divide_by 8.333 [get_pins clk_gen_inst/clk_out2]

# HDMI pixel clocks (depends on resolution mode)
# 720p/1080p30: 74.25 MHz pixel clock
create_generated_clock -name clk_pixel_74m -source [get_pins clk_gen_inst/clk_in1] -divide_by 2.694 [get_pins clk_gen_inst/clk_out3]
# 1080p60: 148.5 MHz pixel clock  
create_generated_clock -name clk_pixel_148m -source [get_pins clk_gen_inst/clk_in1] -divide_by 1.347 [get_pins clk_gen_inst/clk_out3]

# TMDS clocks (5x pixel clock)
create_generated_clock -name clk_tmds_371m -source [get_pins clk_gen_inst/clk_out3] -multiply_by 5 [get_pins clk_gen_inst/clk_out4]
create_generated_clock -name clk_tmds_742m -source [get_pins clk_gen_inst/clk_out3] -multiply_by 5 [get_pins clk_gen_inst/clk_out4]

#================================================================================
# Reset and Control Signals
#================================================================================

# CPU Reset button (active low)
set_property PACKAGE_PIN AB7 [get_ports cpu_reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports cpu_reset_n]

# DIP Switches (SW1-SW4)
set_property PACKAGE_PIN Y29 [get_ports {dip_switches[0]}]
set_property PACKAGE_PIN W29 [get_ports {dip_switches[1]}]
set_property PACKAGE_PIN AA28 [get_ports {dip_switches[2]}]
set_property PACKAGE_PIN Y28 [get_ports {dip_switches[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports dip_switches*]

# Push Buttons (BTN0-BTN4)
set_property PACKAGE_PIN AC6 [get_ports {push_buttons[0]}]
set_property PACKAGE_PIN AB6 [get_ports {push_buttons[1]}]
set_property PACKAGE_PIN AC7 [get_ports {push_buttons[2]}]
set_property PACKAGE_PIN AB8 [get_ports {push_buttons[3]}]
set_property PACKAGE_PIN AC8 [get_ports {push_buttons[4]}]
set_property IOSTANDARD LVCMOS15 [get_ports push_buttons*]

#================================================================================
# Status LEDs (GPIO_LED_0 to GPIO_LED_7)
#================================================================================
set_property PACKAGE_PIN AC22 [get_ports {gpio_leds[0]}]
set_property PACKAGE_PIN AC24 [get_ports {gpio_leds[1]}]
set_property PACKAGE_PIN AE22 [get_ports {gpio_leds[2]}]
set_property PACKAGE_PIN AE23 [get_ports {gpio_leds[3]}]
set_property PACKAGE_PIN AB21 [get_ports {gpio_leds[4]}]
set_property PACKAGE_PIN AC21 [get_ports {gpio_leds[5]}]
set_property PACKAGE_PIN AD24 [get_ports {gpio_leds[6]}]
set_property PACKAGE_PIN AD25 [get_ports {gpio_leds[7]}]
set_property IOSTANDARD LVCMOS15 [get_ports gpio_leds*]

#================================================================================
# UART Interface
#================================================================================
set_property PACKAGE_PIN M19 [get_ports uart_tx]
set_property PACKAGE_PIN K24 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS25 [get_ports uart_*]

#================================================================================
# OV7670 Camera Interface
# Connected via FMC LPC Connector (J29)
#================================================================================

# Camera pixel clock input (from OV7670 PCLK)
set_property PACKAGE_PIN H19 [get_ports ov7670_pclk]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_pclk]
# Note: H19 is a clock-capable pin on FMC LPC

# Camera control signals
set_property PACKAGE_PIN G18 [get_ports ov7670_href]
set_property PACKAGE_PIN H18 [get_ports ov7670_vsync]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_href]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_vsync]

# Camera data bus (8-bit)
set_property PACKAGE_PIN F19 [get_ports {ov7670_data[0]}]
set_property PACKAGE_PIN E19 [get_ports {ov7670_data[1]}]
set_property PACKAGE_PIN F20 [get_ports {ov7670_data[2]}]
set_property PACKAGE_PIN E20 [get_ports {ov7670_data[3]}]
set_property PACKAGE_PIN D20 [get_ports {ov7670_data[4]}]
set_property PACKAGE_PIN C20 [get_ports {ov7670_data[5]}]
set_property PACKAGE_PIN G21 [get_ports {ov7670_data[6]}]
set_property PACKAGE_PIN F21 [get_ports {ov7670_data[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_data*]

# Camera control outputs
set_property PACKAGE_PIN L18 [get_ports ov7670_xclk]
set_property PACKAGE_PIN M20 [get_ports ov7670_pwdn]
set_property PACKAGE_PIN L20 [get_ports ov7670_reset]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_xclk]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_pwdn]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_reset]

# I2C for camera control (SCCB)
set_property PACKAGE_PIN K19 [get_ports ov7670_scl]
set_property PACKAGE_PIN K20 [get_ports ov7670_sda]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_scl]
set_property IOSTANDARD LVCMOS25 [get_ports ov7670_sda]
set_property PULLUP true [get_ports ov7670_scl]
set_property PULLUP true [get_ports ov7670_sda]

#================================================================================
# HDMI Output Interface
# Option 1: External HDMI Transmitter (ADV7511) via FMC HPC Connector (J22)
#================================================================================

# HDMI I2C Control (for external transmitter configuration)
set_property PACKAGE_PIN AB30 [get_ports hdmi_scl]
set_property PACKAGE_PIN AC30 [get_ports hdmi_sda]
set_property IOSTANDARD LVCMOS25 [get_ports hdmi_scl]
set_property IOSTANDARD LVCMOS25 [get_ports hdmi_sda]
set_property PULLUP true [get_ports hdmi_scl]
set_property PULLUP true [get_ports hdmi_sda]

# Hot Plug Detect
set_property PACKAGE_PIN AD30 [get_ports hdmi_hpd]
set_property IOSTANDARD LVCMOS25 [get_ports hdmi_hpd]

# Option 1: RGB Data to External HDMI Transmitter
# (Connect these when USE_EXTERNAL_HDMI_IC = 1)
# RGB data lines via FMC HPC
# set_property PACKAGE_PIN AA23 [get_ports {hdmi_rgb_r[0]}]
# set_property PACKAGE_PIN AB23 [get_ports {hdmi_rgb_r[1]}]
# ... (additional RGB pins would be defined here)

# Option 2: Direct HDMI/DVI Output (TMDS)
# Using high-speed capable pins via FMC HPC connector
# (Connect these when USE_EXTERNAL_HDMI_IC = 0)

# TMDS Data Channels (High-speed differential pairs)
set_property PACKAGE_PIN AE18 [get_ports {hdmi_tx_p[0]}]  # TMDS Channel 0+ (Blue)
set_property PACKAGE_PIN AF18 [get_ports {hdmi_tx_n[0]}]  # TMDS Channel 0- (Blue)
set_property PACKAGE_PIN AD19 [get_ports {hdmi_tx_p[1]}]  # TMDS Channel 1+ (Green)
set_property PACKAGE_PIN AE19 [get_ports {hdmi_tx_n[1]}]  # TMDS Channel 1- (Green)
set_property PACKAGE_PIN AC19 [get_ports {hdmi_tx_p[2]}]  # TMDS Channel 2+ (Red)
set_property PACKAGE_PIN AC20 [get_ports {hdmi_tx_n[2]}]  # TMDS Channel 2- (Red)

# TMDS Clock Channel
set_property PACKAGE_PIN AD21 [get_ports hdmi_clk_p]     # TMDS Clock+
set_property PACKAGE_PIN AE21 [get_ports hdmi_clk_n]     # TMDS Clock-

# TMDS I/O Standards
set_property IOSTANDARD TMDS_33 [get_ports hdmi_tx_p*]
set_property IOSTANDARD TMDS_33 [get_ports hdmi_tx_n*]
set_property IOSTANDARD TMDS_33 [get_ports hdmi_clk_*]

#================================================================================
# DDR3 Memory Interface (for frame buffering)
#================================================================================

# DDR3 Data
set_property PACKAGE_PIN AA16 [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN Y16 [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN AB17 [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN AA17 [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN AB15 [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN AA15 [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN AC14 [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN AB14 [get_ports {ddr3_dq[7]}]
# ... (additional DDR3 pins would be defined here)

# DDR3 Address
set_property PACKAGE_PIN AE13 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN AF13 [get_ports {ddr3_addr[1]}]
# ... (additional address pins)

# DDR3 Control
set_property PACKAGE_PIN AE15 [get_ports ddr3_ras_n]
set_property PACKAGE_PIN AE16 [get_ports ddr3_cas_n]
set_property PACKAGE_PIN AD15 [get_ports ddr3_we_n]

# DDR3 Clock
set_property PACKAGE_PIN AD14 [get_ports {ddr3_ck_p[0]}]
set_property PACKAGE_PIN AE14 [get_ports {ddr3_ck_n[0]}]

# DDR3 I/O Standards
set_property IOSTANDARD SSTL15 [get_ports ddr3_*]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ddr3_ck_*]

#================================================================================
# Timing Constraints
#================================================================================

# Camera clock constraint (create input clock for OV7670 PCLK)
create_clock -period 83.333 [get_ports ov7670_pclk]  # ~12MHz typical

# Set input delay for camera data relative to PCLK
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -min 2.0 [get_ports ov7670_data*]
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -max 8.0 [get_ports ov7670_data*]
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -min 2.0 [get_ports ov7670_href]
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -max 8.0 [get_ports ov7670_href]
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -min 2.0 [get_ports ov7670_vsync]
set_input_delay -clock [get_clocks -of_objects [get_ports ov7670_pclk]] -max 8.0 [get_ports ov7670_vsync]

# Set output delay for camera control signals
set_output_delay -clock [get_clocks clk_24mhz] -min 0.0 [get_ports ov7670_xclk]
set_output_delay -clock [get_clocks clk_24mhz] -max 2.0 [get_ports ov7670_xclk]

# HDMI output timing constraints
# Set output delay for TMDS signals (these will be overridden by OSERDESE2 timing)
set_output_delay -clock [get_clocks clk_pixel_*] -min -1.0 [get_ports hdmi_tx_*]
set_output_delay -clock [get_clocks clk_pixel_*] -max 1.0 [get_ports hdmi_tx_*]
set_output_delay -clock [get_clocks clk_pixel_*] -min -1.0 [get_ports hdmi_clk_*]
set_output_delay -clock [get_clocks clk_pixel_*] -max 1.0 [get_ports hdmi_clk_*]

# Clock domain crossing constraints
set_clock_groups -asynchronous \
    -group [get_clocks clk_200mhz] \
    -group [get_clocks ov7670_pclk] \
    -group [get_clocks clk_pixel_*] \
    -group [get_clocks clk_tmds_*]

# TMDS data rate constraints for high-speed serialization
# These ensure proper setup/hold for OSERDESE2 primitives
set_max_delay -from [get_clocks clk_pixel_*] -to [get_ports hdmi_tx_*] 2.0
set_min_delay -from [get_clocks clk_pixel_*] -to [get_ports hdmi_tx_*] -2.0

#================================================================================
# I/O Timing and Electrical Constraints
#================================================================================

# Set drive strength for outputs
set_property DRIVE 8 [get_ports gpio_leds*]
set_property DRIVE 8 [get_ports uart_tx]
set_property DRIVE 8 [get_ports ov7670_xclk]

# Set slew rate for high-speed signals
set_property SLEW FAST [get_ports hdmi_tx_*]
set_property SLEW FAST [get_ports hdmi_clk_*]

# Disable DCI cascade for TMDS signals
set_property DCI_CASCADE {32 34} [get_iobanks 33]

#================================================================================
# Implementation Constraints
#================================================================================

# Place HDMI-related logic close to I/O
create_pblock hdmi_region
add_cells_to_pblock hdmi_region [get_cells hdmi_display]
resize_pblock hdmi_region -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y1}

# Place frame buffer controller near memory interface
create_pblock memory_region  
add_cells_to_pblock memory_region [get_cells frame_buffer]
resize_pblock memory_region -add {CLOCKREGION_X0Y2:CLOCKREGION_X1Y3}

#================================================================================
# Power Analysis Constraints
#================================================================================

# Set switching activity for power estimation
set_switching_activity -default_input_io_toggle_rate 12.5
set_switching_activity -default_register_toggle_rate 12.5

#================================================================================
# Debug Constraints (for Integrated Logic Analyzer)
#================================================================================

# ILA clock connection (uncomment when ENABLE_ILA = 1)
# set_property C_CLK_INPUT_FREQ_HZ 74250000 [get_debug_cores dbg_hub]
# set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]