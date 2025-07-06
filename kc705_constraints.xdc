# KC705 MobileNetV3 Implementation Constraints
# Xilinx Design Constraints (XDC) file for KC705 evaluation board
# Kintex-7 XC7K325T-2FFG900C

#==============================================================================
# System Clock Constraints (200MHz differential)
#==============================================================================

# System clock 200MHz differential input
set_property -dict {PACKAGE_PIN AD12 IOSTANDARD LVDS} [get_ports sysclk_p]
set_property -dict {PACKAGE_PIN AD11 IOSTANDARD LVDS} [get_ports sysclk_n]

create_clock -period 5.000 -name sysclk [get_ports sysclk_p]

#==============================================================================
# Reset and Control Signals
#==============================================================================

# CPU Reset button (active high)
set_property -dict {PACKAGE_PIN AB7 IOSTANDARD LVCMOS25} [get_ports cpu_reset]

# GPIO LEDs (8 LEDs)
set_property -dict {PACKAGE_PIN AB8 IOSTANDARD LVCMOS25} [get_ports {gpio_led[0]}]
set_property -dict {PACKAGE_PIN AA8 IOSTANDARD LVCMOS25} [get_ports {gpio_led[1]}]
set_property -dict {PACKAGE_PIN AC9 IOSTANDARD LVCMOS25} [get_ports {gpio_led[2]}]
set_property -dict {PACKAGE_PIN AB9 IOSTANDARD LVCMOS25} [get_ports {gpio_led[3]}]
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS25} [get_ports {gpio_led[4]}]
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS25} [get_ports {gpio_led[5]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS25} [get_ports {gpio_led[6]}]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS25} [get_ports {gpio_led[7]}]

# GPIO Switches (8 DIP switches)
set_property -dict {PACKAGE_PIN Y29 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[0]}]
set_property -dict {PACKAGE_PIN W29 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[1]}]
set_property -dict {PACKAGE_PIN AA28 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[2]}]
set_property -dict {PACKAGE_PIN Y28 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[3]}]
set_property -dict {PACKAGE_PIN Y26 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[4]}]
set_property -dict {PACKAGE_PIN AA26 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[5]}]
set_property -dict {PACKAGE_PIN Y25 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[6]}]
set_property -dict {PACKAGE_PIN AA25 IOSTANDARD LVCMOS25} [get_ports {gpio_sw[7]}]

# GPIO Push Buttons (5 buttons: N, S, E, W, Center)
set_property -dict {PACKAGE_PIN G12 IOSTANDARD LVCMOS25} [get_ports {gpio_buttons[0]}]; # Center
set_property -dict {PACKAGE_PIN AC6 IOSTANDARD LVCMOS25} [get_ports {gpio_buttons[1]}]; # North
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS25} [get_ports {gpio_buttons[2]}]; # South
set_property -dict {PACKAGE_PIN AA12 IOSTANDARD LVCMOS25} [get_ports {gpio_buttons[3]}]; # East
set_property -dict {PACKAGE_PIN AC5 IOSTANDARD LVCMOS25} [get_ports {gpio_buttons[4]}]; # West

#==============================================================================
# DDR3 Memory Interface Constraints (1GB DDR3-1600)
#==============================================================================

# DDR3 Memory pins
set_property -dict {PACKAGE_PIN M2 IOSTANDARD SSTL15} [get_ports {ddr3_addr[0]}]
set_property -dict {PACKAGE_PIN M5 IOSTANDARD SSTL15} [get_ports {ddr3_addr[1]}]
set_property -dict {PACKAGE_PIN M3 IOSTANDARD SSTL15} [get_ports {ddr3_addr[2]}]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD SSTL15} [get_ports {ddr3_addr[3]}]
set_property -dict {PACKAGE_PIN L6 IOSTANDARD SSTL15} [get_ports {ddr3_addr[4]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD SSTL15} [get_ports {ddr3_addr[5]}]
set_property -dict {PACKAGE_PIN N3 IOSTANDARD SSTL15} [get_ports {ddr3_addr[6]}]
set_property -dict {PACKAGE_PIN N2 IOSTANDARD SSTL15} [get_ports {ddr3_addr[7]}]
set_property -dict {PACKAGE_PIN N1 IOSTANDARD SSTL15} [get_ports {ddr3_addr[8]}]
set_property -dict {PACKAGE_PIN L5 IOSTANDARD SSTL15} [get_ports {ddr3_addr[9]}]
set_property -dict {PACKAGE_PIN M6 IOSTANDARD SSTL15} [get_ports {ddr3_addr[10]}]
set_property -dict {PACKAGE_PIN R1 IOSTANDARD SSTL15} [get_ports {ddr3_addr[11]}]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD SSTL15} [get_ports {ddr3_addr[12]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD SSTL15} [get_ports {ddr3_addr[13]}]

set_property -dict {PACKAGE_PIN N4 IOSTANDARD SSTL15} [get_ports {ddr3_ba[0]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD SSTL15} [get_ports {ddr3_ba[1]}]
set_property -dict {PACKAGE_PIN N6 IOSTANDARD SSTL15} [get_ports {ddr3_ba[2]}]

set_property -dict {PACKAGE_PIN P2 IOSTANDARD SSTL15} [get_ports ddr3_cas_n]
set_property -dict {PACKAGE_PIN L3 IOSTANDARD DIFF_SSTL15} [get_ports ddr3_ck_p]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD DIFF_SSTL15} [get_ports ddr3_ck_n]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD SSTL15} [get_ports ddr3_cke]
set_property -dict {PACKAGE_PIN J6 IOSTANDARD SSTL15} [get_ports ddr3_cs_n]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD SSTL15} [get_ports ddr3_odt]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD SSTL15} [get_ports ddr3_ras_n]
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS15} [get_ports ddr3_reset_n]
set_property -dict {PACKAGE_PIN P6 IOSTANDARD SSTL15} [get_ports ddr3_we_n]

# DDR3 Data pins (64-bit interface)
set_property -dict {PACKAGE_PIN G2 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[0]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[1]}]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[2]}]
set_property -dict {PACKAGE_PIN J1 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[3]}]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[4]}]
set_property -dict {PACKAGE_PIN H3 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[5]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[6]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dq[7]}]

# Continue for all 64 data bits...
# (Additional DDR3 constraints would continue here for the full 64-bit interface)

# DDR3 Data Strobe pins
set_property -dict {PACKAGE_PIN G3 IOSTANDARD DIFF_SSTL15_T_DCI} [get_ports {ddr3_dqs_p[0]}]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD DIFF_SSTL15_T_DCI} [get_ports {ddr3_dqs_n[0]}]

# DDR3 Data Mask pins
set_property -dict {PACKAGE_PIN G1 IOSTANDARD SSTL15_T_DCI} [get_ports {ddr3_dm[0]}]

#==============================================================================
# PCIe Interface Constraints
#==============================================================================

# PCIe reference clock (100MHz)
set_property -dict {PACKAGE_PIN AB5 IOSTANDARD LVDS} [get_ports pcie_clk_p]
set_property -dict {PACKAGE_PIN AB4 IOSTANDARD LVDS} [get_ports pcie_clk_n]

create_clock -period 10.000 -name pcie_clk [get_ports pcie_clk_p]

# PCIe reset
set_property -dict {PACKAGE_PIN AE18 IOSTANDARD LVCMOS25 PULLUP true} [get_ports pcie_rst_n]

# PCIe differential pairs (x8 lanes)
set_property PACKAGE_PIN L8 [get_ports {pcie_tx_p[0]}]
set_property PACKAGE_PIN L7 [get_ports {pcie_tx_n[0]}]
set_property PACKAGE_PIN M8 [get_ports {pcie_rx_p[0]}]
set_property PACKAGE_PIN M7 [get_ports {pcie_rx_n[0]}]

set_property PACKAGE_PIN N8 [get_ports {pcie_tx_p[1]}]
set_property PACKAGE_PIN N7 [get_ports {pcie_tx_n[1]}]
set_property PACKAGE_PIN P8 [get_ports {pcie_rx_p[1]}]
set_property PACKAGE_PIN P7 [get_ports {pcie_rx_n[1]}]

set_property PACKAGE_PIN R8 [get_ports {pcie_tx_p[2]}]
set_property PACKAGE_PIN R7 [get_ports {pcie_tx_n[2]}]
set_property PACKAGE_PIN T8 [get_ports {pcie_rx_p[2]}]
set_property PACKAGE_PIN T7 [get_ports {pcie_rx_n[2]}]

set_property PACKAGE_PIN U8 [get_ports {pcie_tx_p[3]}]
set_property PACKAGE_PIN U7 [get_ports {pcie_tx_n[3]}]
set_property PACKAGE_PIN V8 [get_ports {pcie_rx_p[3]}]
set_property PACKAGE_PIN V7 [get_ports {pcie_rx_n[3]}]

set_property PACKAGE_PIN W8 [get_ports {pcie_tx_p[4]}]
set_property PACKAGE_PIN W7 [get_ports {pcie_tx_n[4]}]
set_property PACKAGE_PIN Y8 [get_ports {pcie_rx_p[4]}]
set_property PACKAGE_PIN Y7 [get_ports {pcie_rx_n[4]}]

set_property PACKAGE_PIN AA8 [get_ports {pcie_tx_p[5]}]
set_property PACKAGE_PIN AA7 [get_ports {pcie_tx_n[5]}]
set_property PACKAGE_PIN AB8 [get_ports {pcie_rx_p[5]}]
set_property PACKAGE_PIN AB7 [get_ports {pcie_rx_n[5]}]

set_property PACKAGE_PIN AC8 [get_ports {pcie_tx_p[6]}]
set_property PACKAGE_PIN AC7 [get_ports {pcie_tx_n[6]}]
set_property PACKAGE_PIN AD8 [get_ports {pcie_rx_p[6]}]
set_property PACKAGE_PIN AD7 [get_ports {pcie_rx_n[6]}]

set_property PACKAGE_PIN AE8 [get_ports {pcie_tx_p[7]}]
set_property PACKAGE_PIN AE7 [get_ports {pcie_tx_n[7]}]
set_property PACKAGE_PIN AF8 [get_ports {pcie_rx_p[7]}]
set_property PACKAGE_PIN AF7 [get_ports {pcie_rx_n[7]}]

#==============================================================================
# Ethernet Interface Constraints (1Gb Ethernet)
#==============================================================================

# Ethernet RGMII interface
set_property -dict {PACKAGE_PIN R23 IOSTANDARD LVCMOS25} [get_ports eth_rx_clk]
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[0]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[1]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[2]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS25} [get_ports {eth_rxd[3]}]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVCMOS25} [get_ports eth_rx_dv]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS25} [get_ports eth_rx_er]

set_property -dict {PACKAGE_PIN R22 IOSTANDARD LVCMOS25} [get_ports eth_tx_clk]
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS25} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS25} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS25} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS25} [get_ports {eth_txd[3]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS25} [get_ports eth_tx_en]

# Ethernet MDIO interface
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS25} [get_ports eth_mdc]
set_property -dict {PACKAGE_PIN N23 IOSTANDARD LVCMOS25} [get_ports eth_mdio]
set_property -dict {PACKAGE_PIN L25 IOSTANDARD LVCMOS25} [get_ports eth_reset_n]

#==============================================================================
# UART Interface Constraints
#==============================================================================

# UART interface
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS25} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN K24 IOSTANDARD LVCMOS25} [get_ports uart_tx]

#==============================================================================
# User SMA Connectors
#==============================================================================

# User SMA clock input (differential)
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVDS} [get_ports user_sma_clock_p]
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVDS} [get_ports user_sma_clock_n]

# User SMA GPIO (differential output)
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVDS} [get_ports user_sma_gpio_p]
set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVDS} [get_ports user_sma_gpio_n]

#==============================================================================
# Timing Constraints
#==============================================================================

# Create derived clocks
create_generated_clock -name clk_200mhz -source [get_ports sysclk_p] -multiply_by 1 [get_pins clk_gen/inst/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name clk_100mhz -source [get_ports sysclk_p] -divide_by 2 [get_pins clk_gen/inst/mmcm_adv_inst/CLKOUT1]
create_generated_clock -name clk_50mhz -source [get_ports sysclk_p] -divide_by 4 [get_pins clk_gen/inst/mmcm_adv_inst/CLKOUT2]

# Set input delay constraints for critical paths
set_input_delay -clock [get_clocks clk_200mhz] -min 1.0 [get_ports {gpio_sw[*]}]
set_input_delay -clock [get_clocks clk_200mhz] -max 3.0 [get_ports {gpio_sw[*]}]

set_output_delay -clock [get_clocks clk_200mhz] -min 1.0 [get_ports {gpio_led[*]}]
set_output_delay -clock [get_clocks clk_200mhz] -max 3.0 [get_ports {gpio_led[*]}]

# Clock domain crossing constraints
set_clock_groups -asynchronous -group [get_clocks clk_200mhz] -group [get_clocks pcie_clk]
set_clock_groups -asynchronous -group [get_clocks clk_200mhz] -group [get_clocks eth_rx_clk]

# False paths for reset signals
set_false_path -from [get_ports cpu_reset]
set_false_path -from [get_ports pcie_rst_n]

# MobileNetV3 specific timing constraints
set_max_delay -from [get_pins mobilenet_core/*/clk] -to [get_pins mobilenet_core/*/rst_n] 5.0

#==============================================================================
# Implementation Strategy Constraints
#==============================================================================

# Set utilization constraints for Kintex-7 resources
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

# Optimize for performance
set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

#==============================================================================
# Physical Constraints for High-Performance Implementation
#==============================================================================

# Place MobileNetV3 core in center of device for optimal routing
create_pblock pblock_mobilenet
add_cells_to_pblock [get_pblocks pblock_mobilenet] [get_cells mobilenet_core]
resize_pblock [get_pblocks pblock_mobilenet] -add {SLICE_X100Y100:SLICE_X200Y200}
resize_pblock [get_pblocks pblock_mobilenet] -add {DSP48_X5Y40:DSP48_X8Y80}
resize_pblock [get_pblocks pblock_mobilenet] -add {RAMB36_X7Y20:RAMB36_X12Y40}

# Place DDR3 interface close to pins
create_pblock pblock_ddr3
add_cells_to_pblock [get_pblocks pblock_ddr3] [get_cells ddr3_ctrl]
resize_pblock [get_pblocks pblock_ddr3] -add {SLICE_X0Y150:SLICE_X50Y250}