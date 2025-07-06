/**
 * KC705 MobileNetV3 Adapter
 * 
 * This module adapts the generic MobileNetV3 implementation to the KC705 evaluation board
 * (Kintex-7 XC7K325T). It provides multiple interfaces for data input/output:
 * 
 * 1. PCIe interface for direct computer connection
 * 2. Ethernet interface for network-based data transfer
 * 3. UART interface for debugging and control
 * 4. DDR3 memory interface for data buffering
 * 
 * Features:
 * - Real-time image classification
 * - Multiple input sources (PCIe, Ethernet, UART)
 * - Hardware acceleration with Kintex-7 optimizations
 * - Full integration with KC705 board resources
 */

module kc705_mobilenetv3_adapter #(
    // MobileNetV3 parameters optimized for Kintex-7
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter IMAGE_WIDTH = 224,
    parameter IMAGE_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter NUM_CLASSES = 1000,
    
    // KC705 specific parameters
    parameter DDR3_ADDR_WIDTH = 14,
    parameter DDR3_DATA_WIDTH = 64,
    parameter PCIE_LANES = 8,
    parameter ETH_DATA_WIDTH = 8
) (
    // KC705 System Clock and Reset
    input wire sysclk_p,           // 200MHz differential system clock
    input wire sysclk_n,
    input wire cpu_reset,          // CPU reset button
    
    // KC705 DDR3 Memory Interface
    output wire [DDR3_ADDR_WIDTH-1:0] ddr3_addr,
    output wire [2:0] ddr3_ba,
    output wire ddr3_cas_n,
    output wire ddr3_ck_n,
    output wire ddr3_ck_p,
    output wire ddr3_cke,
    output wire ddr3_cs_n,
    inout wire [DDR3_DATA_WIDTH-1:0] ddr3_dq,
    inout wire [7:0] ddr3_dqs_n,
    inout wire [7:0] ddr3_dqs_p,
    output wire ddr3_odt,
    output wire ddr3_ras_n,
    output wire ddr3_reset_n,
    output wire ddr3_we_n,
    output wire [7:0] ddr3_dm,
    
    // KC705 PCIe Interface (x8)
    input wire pcie_clk_p,
    input wire pcie_clk_n,
    input wire pcie_rst_n,
    input wire [PCIE_LANES-1:0] pcie_rx_p,
    input wire [PCIE_LANES-1:0] pcie_rx_n,
    output wire [PCIE_LANES-1:0] pcie_tx_p,
    output wire [PCIE_LANES-1:0] pcie_tx_n,
    
    // KC705 Ethernet Interface (RGMII)
    input wire eth_rx_clk,
    input wire [3:0] eth_rxd,
    input wire eth_rx_dv,
    input wire eth_rx_er,
    output wire eth_tx_clk,
    output wire [3:0] eth_txd,
    output wire eth_tx_en,
    output wire eth_mdc,
    inout wire eth_mdio,
    output wire eth_reset_n,
    
    // KC705 UART Interface
    input wire uart_rx,
    output wire uart_tx,
    
    // KC705 User LEDs and Switches
    output wire [7:0] gpio_led,
    input wire [7:0] gpio_sw,
    input wire [4:0] gpio_buttons,
    
    // KC705 User SMA connectors (for external trigger/sync)
    input wire user_sma_clock_p,
    input wire user_sma_clock_n,
    output wire user_sma_gpio_p,
    output wire user_sma_gpio_n,
    
    // Status and Debug outputs
    output wire processing_done,
    output wire [15:0] debug_status,
    output wire inference_valid,
    output wire [31:0] classification_result
);

//=============================================================================
// Clock and Reset Management
//=============================================================================

wire clk_200mhz;       // Main system clock
wire clk_100mhz;       // PCIe and Ethernet clock
wire clk_50mhz;        // UART and control clock
wire mmcm_locked;
wire rst_n;

// Clock generation using MMCM
clk_wiz_0 clk_gen (
    .clk_in1_p(sysclk_p),
    .clk_in1_n(sysclk_n),
    .clk_out1(clk_200mhz),     // 200MHz for MobileNetV3 core
    .clk_out2(clk_100mhz),     // 100MHz for interfaces
    .clk_out3(clk_50mhz),      // 50MHz for UART
    .reset(cpu_reset),
    .locked(mmcm_locked)
);

// Reset synchronizer
reset_sync reset_gen (
    .clk(clk_200mhz),
    .ext_reset_n(mmcm_locked & ~cpu_reset),
    .rst_n(rst_n)
);

//=============================================================================
// DDR3 Memory Controller
//=============================================================================

wire ddr3_ui_clk;
wire ddr3_ui_rst;
wire ddr3_init_calib_complete;

// AXI interface to DDR3
wire [31:0] s_axi_awaddr;
wire [7:0] s_axi_awlen;
wire [2:0] s_axi_awsize;
wire [1:0] s_axi_awburst;
wire s_axi_awvalid;
wire s_axi_awready;
wire [127:0] s_axi_wdata;
wire [15:0] s_axi_wstrb;
wire s_axi_wlast;
wire s_axi_wvalid;
wire s_axi_wready;
wire [31:0] s_axi_araddr;
wire [7:0] s_axi_arlen;
wire [2:0] s_axi_arsize;
wire [1:0] s_axi_arburst;
wire s_axi_arvalid;
wire s_axi_arready;
wire [127:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire s_axi_rlast;
wire s_axi_rvalid;
wire s_axi_rready;

ddr3_interface ddr3_ctrl (
    // DDR3 Physical Interface
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_cke(ddr3_cke),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_odt(ddr3_odt),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_dm(ddr3_dm),
    
    // System Interface
    .sys_clk_i(clk_200mhz),
    .sys_rst(~rst_n),
    .ui_clk(ddr3_ui_clk),
    .ui_clk_sync_rst(ddr3_ui_rst),
    .init_calib_complete(ddr3_init_calib_complete),
    
    // AXI Interface
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready)
);

//=============================================================================
// PCIe Interface for Direct Computer Connection
//=============================================================================

wire [63:0] pcie_data_in;
wire pcie_data_valid_in;
wire pcie_data_ready_in;
wire [63:0] pcie_data_out;
wire pcie_data_valid_out;
wire pcie_data_ready_out;

pcie_interface pcie_ctrl (
    // PCIe Physical Interface
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_rxp(pcie_rx_p),
    .pci_exp_rxn(pcie_rx_n),
    .sys_clk_p(pcie_clk_p),
    .sys_clk_n(pcie_clk_n),
    .sys_rst_n(pcie_rst_n),
    
    // User Interface
    .user_clk(clk_100mhz),
    .user_reset(~rst_n),
    .user_lnk_up(),
    
    // AXI Stream Interface
    .m_axis_rx_tdata(pcie_data_in),
    .m_axis_rx_tvalid(pcie_data_valid_in),
    .m_axis_rx_tready(pcie_data_ready_in),
    .s_axis_tx_tdata(pcie_data_out),
    .s_axis_tx_tvalid(pcie_data_valid_out),
    .s_axis_tx_tready(pcie_data_ready_out)
);

//=============================================================================
// Ethernet Interface for Network Data Transfer
//=============================================================================

wire [7:0] eth_data_in;
wire eth_data_valid_in;
wire eth_data_ready_in;
wire [7:0] eth_data_out;
wire eth_data_valid_out;
wire eth_data_ready_out;

ethernet_interface eth_ctrl (
    // Ethernet Physical Interface
    .rgmii_rxc(eth_rx_clk),
    .rgmii_rxd(eth_rxd),
    .rgmii_rx_ctl(eth_rx_dv),
    .rgmii_txc(eth_tx_clk),
    .rgmii_txd(eth_txd),
    .rgmii_tx_ctl(eth_tx_en),
    .mdio(eth_mdio),
    .mdc(eth_mdc),
    .phy_reset_n(eth_reset_n),
    
    // System Interface
    .gtx_clk(clk_125mhz),
    .ref_clk(clk_200mhz),
    .glbl_rst(~rst_n),
    
    // AXI Stream Interface
    .rx_axis_tdata(eth_data_in),
    .rx_axis_tvalid(eth_data_valid_in),
    .rx_axis_tready(eth_data_ready_in),
    .tx_axis_tdata(eth_data_out),
    .tx_axis_tvalid(eth_data_valid_out),
    .tx_axis_tready(eth_data_ready_out)
);

//=============================================================================
// UART Interface for Control and Debug
//=============================================================================

wire [7:0] uart_data_in;
wire uart_data_valid_in;
wire uart_data_ready_in;
wire [7:0] uart_data_out;
wire uart_data_valid_out;
wire uart_data_ready_out;

uart_interface uart_ctrl (
    .clk(clk_50mhz),
    .rst_n(rst_n),
    
    // UART Physical Interface
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    
    // AXI Stream Interface
    .rx_axis_tdata(uart_data_in),
    .rx_axis_tvalid(uart_data_valid_in),
    .rx_axis_tready(uart_data_ready_in),
    .tx_axis_tdata(uart_data_out),
    .tx_axis_tvalid(uart_data_valid_out),
    .tx_axis_tready(uart_data_ready_out)
);

//=============================================================================
// Data Input Multiplexer and Protocol Handler
//=============================================================================

wire [63:0] unified_data_in;
wire unified_data_valid_in;
wire unified_data_ready_in;
wire [1:0] data_source_select;

// Protocol handler to manage different input sources
data_input_mux input_mux (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // Input sources
    .pcie_data(pcie_data_in),
    .pcie_valid(pcie_data_valid_in),
    .pcie_ready(pcie_data_ready_in),
    
    .eth_data({56'b0, eth_data_in}),
    .eth_valid(eth_data_valid_in),
    .eth_ready(eth_data_ready_in),
    
    .uart_data({56'b0, uart_data_in}),
    .uart_valid(uart_data_valid_in),
    .uart_ready(uart_data_ready_in),
    
    // Unified output
    .data_out(unified_data_in),
    .data_valid(unified_data_valid_in),
    .data_ready(unified_data_ready_in),
    
    // Control
    .source_select(data_source_select),
    .gpio_sw(gpio_sw[1:0])
);

//=============================================================================
// Image Pre-processing and Format Conversion
//=============================================================================

wire [DATA_WIDTH-1:0] image_data;
wire image_data_valid;
wire image_data_ready;
wire image_frame_start;
wire image_frame_end;

image_preprocessor img_preproc (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // Raw input data
    .raw_data(unified_data_in),
    .raw_valid(unified_data_valid_in),
    .raw_ready(unified_data_ready_in),
    
    // Processed image output
    .image_data(image_data),
    .image_valid(image_data_valid),
    .image_ready(image_data_ready),
    .frame_start(image_frame_start),
    .frame_end(image_frame_end),
    
    // Configuration
    .input_format(gpio_sw[4:2]),  // 0=RGB, 1=YUV, 2=RAW, etc.
    .enable_normalization(gpio_sw[5])
);

//=============================================================================
// MobileNetV3 Core Instance
//=============================================================================

wire [63:0] mobilenet_output;
wire mobilenet_output_valid;
wire mobilenet_output_ready;

mobilenetv3_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .IMAGE_WIDTH(IMAGE_WIDTH),
    .IMAGE_HEIGHT(IMAGE_HEIGHT),
    .INPUT_CHANNELS(INPUT_CHANNELS),
    .NUM_CLASSES(NUM_CLASSES),
    .ARCHITECTURE("LARGE"),
    .AXI_WIDTH(64),
    .BUFFER_DEPTH(4096),
    .PARALLEL_CHANNELS(16),     // Increased for Kintex-7
    .PIPELINE_STAGES(8)
) mobilenet_core (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // Input stream
    .s_axis_input_tdata({48'b0, image_data}),
    .s_axis_input_tvalid(image_data_valid),
    .s_axis_input_tready(image_data_ready),
    .s_axis_input_tlast(image_frame_end),
    
    // Output stream
    .m_axis_output_tdata(mobilenet_output),
    .m_axis_output_tvalid(mobilenet_output_valid),
    .m_axis_output_tready(mobilenet_output_ready),
    .m_axis_output_tlast(),
    
    // Control interface (connected to DDR3 for weight loading)
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata[31:0]),
    .s_axi_wstrb(s_axi_wstrb[3:0]),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(),
    .s_axi_bvalid(),
    .s_axi_bready(1'b1),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(),
    .s_axi_rresp(),
    .s_axi_rvalid(),
    .s_axi_rready(1'b1),
    
    // Status
    .processing_done(processing_done),
    .status_reg(debug_status),
    .start_processing(image_frame_start | gpio_buttons[0])
);

//=============================================================================
// Post-processing and Classification Results
//=============================================================================

wire [31:0] class_probability;
wire [9:0] predicted_class;
wire classification_valid;

classification_postprocessor postproc (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // MobileNetV3 output
    .logits_data(mobilenet_output),
    .logits_valid(mobilenet_output_valid),
    .logits_ready(mobilenet_output_ready),
    
    // Classification results
    .predicted_class(predicted_class),
    .class_probability(class_probability),
    .valid(classification_valid),
    
    // Configuration
    .softmax_enable(gpio_sw[6]),
    .top_k_mode(gpio_sw[7])
);

//=============================================================================
// Output Data Path Manager
//=============================================================================

output_manager out_mgr (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // Classification results
    .class_id(predicted_class),
    .confidence(class_probability),
    .result_valid(classification_valid),
    
    // Output interfaces
    .pcie_data(pcie_data_out),
    .pcie_valid(pcie_data_valid_out),
    .pcie_ready(pcie_data_ready_out),
    
    .eth_data(eth_data_out),
    .eth_valid(eth_data_valid_out),
    .eth_ready(eth_data_ready_out),
    
    .uart_data(uart_data_out),
    .uart_valid(uart_data_valid_out),
    .uart_ready(uart_data_ready_out),
    
    // Control
    .output_format(gpio_sw[1:0])  // 0=JSON, 1=Binary, 2=Text
);

//=============================================================================
// Status and Debug Interface
//=============================================================================

// LED indicators
assign gpio_led[0] = rst_n;                           // Power/Reset indicator
assign gpio_led[1] = ddr3_init_calib_complete;        // DDR3 ready
assign gpio_led[2] = mmcm_locked;                     // Clock locked
assign gpio_led[3] = processing_done;                 // Processing complete
assign gpio_led[4] = classification_valid;            // Valid result
assign gpio_led[5] = pcie_data_valid_in;             // PCIe data activity
assign gpio_led[6] = eth_data_valid_in;              // Ethernet activity
assign gpio_led[7] = uart_data_valid_in;             // UART activity

// SMA output for synchronization/trigger
assign user_sma_gpio_p = image_frame_start;
assign user_sma_gpio_n = ~image_frame_start;

// Combined outputs
assign inference_valid = classification_valid;
assign classification_result = {22'b0, predicted_class};

//=============================================================================
// Performance Monitoring and Resource Utilization
//=============================================================================

performance_monitor perf_mon (
    .clk(clk_200mhz),
    .rst_n(rst_n),
    
    // Input metrics
    .frames_processed(),
    .processing_latency(),
    .throughput_fps(),
    .resource_utilization(),
    
    // Control
    .reset_counters(gpio_buttons[1]),
    .enable_monitoring(gpio_sw[7])
);

endmodule

//=============================================================================
// Supporting Modules
//=============================================================================

module reset_sync (
    input wire clk,
    input wire ext_reset_n,
    output reg rst_n
);

reg [3:0] reset_sync_reg;

always @(posedge clk or negedge ext_reset_n) begin
    if (!ext_reset_n) begin
        reset_sync_reg <= 4'b0000;
        rst_n <= 1'b0;
    end else begin
        reset_sync_reg <= {reset_sync_reg[2:0], 1'b1};
        rst_n <= reset_sync_reg[3];
    end
end

endmodule

module data_input_mux (
    input wire clk,
    input wire rst_n,
    
    // PCIe input
    input wire [63:0] pcie_data,
    input wire pcie_valid,
    output reg pcie_ready,
    
    // Ethernet input
    input wire [63:0] eth_data,
    input wire eth_valid,
    output reg eth_ready,
    
    // UART input
    input wire [63:0] uart_data,
    input wire uart_valid,
    output reg uart_ready,
    
    // Unified output
    output reg [63:0] data_out,
    output reg data_valid,
    input wire data_ready,
    
    // Control
    input wire [1:0] source_select,
    input wire [1:0] gpio_sw
);

// Input source selection based on priority and availability
always @(*) begin
    case (source_select)
        2'b00: begin  // PCIe priority
            data_out = pcie_data;
            data_valid = pcie_valid;
            pcie_ready = data_ready;
            eth_ready = 1'b0;
            uart_ready = 1'b0;
        end
        2'b01: begin  // Ethernet priority
            data_out = eth_data;
            data_valid = eth_valid;
            eth_ready = data_ready;
            pcie_ready = 1'b0;
            uart_ready = 1'b0;
        end
        2'b10: begin  // UART priority
            data_out = uart_data;
            data_valid = uart_valid;
            uart_ready = data_ready;
            pcie_ready = 1'b0;
            eth_ready = 1'b0;
        end
        default: begin  // Auto-detect based on activity
            if (pcie_valid) begin
                data_out = pcie_data;
                data_valid = pcie_valid;
                pcie_ready = data_ready;
                eth_ready = 1'b0;
                uart_ready = 1'b0;
            end else if (eth_valid) begin
                data_out = eth_data;
                data_valid = eth_valid;
                eth_ready = data_ready;
                pcie_ready = 1'b0;
                uart_ready = 1'b0;
            end else begin
                data_out = uart_data;
                data_valid = uart_valid;
                uart_ready = data_ready;
                pcie_ready = 1'b0;
                eth_ready = 1'b0;
            end
        end
    endcase
end

endmodule