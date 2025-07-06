/**
 * MobileNetV3 Top-Level Module
 * A complete hardware implementation of MobileNetV3 for FPGA deployment
 * 
 * Features:
 * - Configurable for MobileNetV3-Large and MobileNetV3-Small
 * - Depthwise separable convolutions
 * - Squeeze-and-Excitation blocks
 * - h-swish activation function
 * - Efficient memory hierarchy with ping-pong buffers
 * - Full pipeline design for maximum throughput
 */

module mobilenetv3_top #(
    // Architecture parameters
    parameter DATA_WIDTH = 16,          // Fixed-point data width
    parameter WEIGHT_WIDTH = 8,         // Weight quantization width
    parameter IMAGE_WIDTH = 224,        // Input image width
    parameter IMAGE_HEIGHT = 224,       // Input image height
    parameter INPUT_CHANNELS = 3,       // RGB input channels
    parameter NUM_CLASSES = 1000,       // Output classes (ImageNet)
    parameter ARCHITECTURE = "LARGE",   // "LARGE" or "SMALL"
    
    // Memory and performance parameters
    parameter AXI_WIDTH = 64,           // AXI bus width
    parameter BUFFER_DEPTH = 2048,      // On-chip buffer depth
    parameter PARALLEL_CHANNELS = 8,    // Parallel processing channels
    parameter PIPELINE_STAGES = 6       // Pipeline depth
) (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // AXI4-Stream input interface
    input wire [AXI_WIDTH-1:0] s_axis_input_tdata,
    input wire s_axis_input_tvalid,
    output wire s_axis_input_tready,
    input wire s_axis_input_tlast,
    
    // AXI4-Stream output interface
    output wire [AXI_WIDTH-1:0] m_axis_output_tdata,
    output wire m_axis_output_tvalid,
    input wire m_axis_output_tready,
    output wire m_axis_output_tlast,
    
    // AXI4-Lite control interface
    input wire [31:0] s_axi_awaddr,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    output wire [1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    input wire [31:0] s_axi_araddr,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp,
    output wire s_axi_rvalid,
    input wire s_axi_rready,
    
    // Status and control signals
    output wire processing_done,
    output wire [15:0] status_reg,
    input wire start_processing
);

// Internal signal declarations
wire [DATA_WIDTH-1:0] stem_conv_out;
wire stem_conv_valid;
wire stem_conv_ready;

wire [DATA_WIDTH-1:0] bneck_out [0:15]; // Up to 16 bottleneck layers
wire [15:0] bneck_valid;
wire [15:0] bneck_ready;

wire [DATA_WIDTH-1:0] final_conv_out;
wire final_conv_valid;
wire final_conv_ready;

wire [DATA_WIDTH-1:0] gap_out;
wire gap_valid;
wire gap_ready;

wire [DATA_WIDTH-1:0] classifier_out;
wire classifier_valid;
wire classifier_ready;

// Configuration registers
reg [31:0] config_reg [0:15];
reg [7:0] layer_config [0:31][0:7]; // Layer configuration memory

// Control and status registers
reg [3:0] current_layer;
reg processing_active;
reg [15:0] pixel_counter;
reg [15:0] channel_counter;

// Memory interface signals
wire [AXI_WIDTH-1:0] weight_data;
wire weight_valid;
wire weight_ready;
wire [AXI_WIDTH-1:0] feature_data;
wire feature_valid;
wire feature_ready;

//=============================================================================
// Control Logic and Register Interface
//=============================================================================

// AXI4-Lite slave for configuration
axi4_lite_slave #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
) config_interface (
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .config_regs(config_reg)
);

//=============================================================================
// Input Processing - Stem Convolution
//=============================================================================

// Initial 3x3 convolution with stride 2
depthwise_separable_conv #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_CHANNELS(INPUT_CHANNELS),
    .OUTPUT_CHANNELS(16),
    .KERNEL_SIZE(3),
    .STRIDE(2),
    .PADDING(1),
    .USE_DEPTHWISE(0) // Standard convolution for stem
) stem_conv (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(s_axis_input_tdata),
    .s_axis_tvalid(s_axis_input_tvalid),
    .s_axis_tready(s_axis_input_tready),
    .s_axis_tlast(s_axis_input_tlast),
    .m_axis_tdata(stem_conv_out),
    .m_axis_tvalid(stem_conv_valid),
    .m_axis_tready(stem_conv_ready),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config[0])
);

//=============================================================================
// MobileNetV3 Inverted Residual Blocks
//=============================================================================

genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin : gen_bneck_layers
        
        // Configure layer parameters based on MobileNetV3 specification
        localparam [7:0] LAYER_PARAMS [0:7] = {
            (i == 0) ? 8'd16  : (i < 3) ? 8'd24  : (i < 6) ? 8'd40  : 
            (i < 9) ? 8'd80  : (i < 13) ? 8'd112 : 8'd160,  // input_channels
            (i == 0) ? 8'd16  : (i < 2) ? 8'd24  : (i < 5) ? 8'd40  : 
            (i < 8) ? 8'd80  : (i < 12) ? 8'd112 : 8'd160,  // output_channels
            (i == 0) ? 8'd16  : (i < 2) ? 8'd72  : (i < 5) ? 8'd120 : 
            (i < 8) ? 8'd200 : (i < 12) ? 8'd672 : 8'd960,  // expansion_channels
            (i == 1 || i == 4 || i == 7) ? 8'd2 : 8'd1,     // stride
            (i >= 2) ? 8'd1 : 8'd0,                          // use_se
            (i >= 4) ? 8'd1 : 8'd0,                          // use_hswish
            8'd3,                                            // kernel_size
            8'd0                                             // reserved
        };
        
        inverted_residual_block #(
            .DATA_WIDTH(DATA_WIDTH),
            .WEIGHT_WIDTH(WEIGHT_WIDTH),
            .INPUT_CHANNELS(LAYER_PARAMS[0]),
            .OUTPUT_CHANNELS(LAYER_PARAMS[1]),
            .EXPANSION_CHANNELS(LAYER_PARAMS[2]),
            .STRIDE(LAYER_PARAMS[3]),
            .USE_SE(LAYER_PARAMS[4]),
            .USE_HSWISH(LAYER_PARAMS[5]),
            .KERNEL_SIZE(LAYER_PARAMS[6])
        ) bneck_layer (
            .clk(clk),
            .rst_n(rst_n),
            .s_axis_tdata(i == 0 ? stem_conv_out : bneck_out[i-1]),
            .s_axis_tvalid(i == 0 ? stem_conv_valid : bneck_valid[i-1]),
            .s_axis_tready(i == 0 ? stem_conv_ready : bneck_ready[i-1]),
            .m_axis_tdata(bneck_out[i]),
            .m_axis_tvalid(bneck_valid[i]),
            .m_axis_tready(bneck_ready[i]),
            .weight_data(weight_data),
            .weight_valid(weight_valid),
            .weight_ready(weight_ready),
            .layer_config(layer_config[i+1])
        );
    end
endgenerate

//=============================================================================
// Final Convolution and Pooling
//=============================================================================

// Final 1x1 convolution
depthwise_separable_conv #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_CHANNELS(160),
    .OUTPUT_CHANNELS(960),
    .KERNEL_SIZE(1),
    .STRIDE(1),
    .PADDING(0),
    .USE_DEPTHWISE(0)
) final_conv (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(bneck_out[15]),
    .s_axis_tvalid(bneck_valid[15]),
    .s_axis_tready(bneck_ready[15]),
    .m_axis_tdata(final_conv_out),
    .m_axis_tvalid(final_conv_valid),
    .m_axis_tready(final_conv_ready),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config[17])
);

// Global Average Pooling
global_average_pooling #(
    .DATA_WIDTH(DATA_WIDTH),
    .INPUT_CHANNELS(960),
    .FEATURE_MAP_SIZE(7) // 7x7 after all downsampling
) gap_layer (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(final_conv_out),
    .s_axis_tvalid(final_conv_valid),
    .s_axis_tready(final_conv_ready),
    .m_axis_tdata(gap_out),
    .m_axis_tvalid(gap_valid),
    .m_axis_tready(gap_ready)
);

//=============================================================================
// Classification Head
//=============================================================================

fully_connected_layer #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_FEATURES(960),
    .OUTPUT_FEATURES(NUM_CLASSES)
) classifier (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(gap_out),
    .s_axis_tvalid(gap_valid),
    .s_axis_tready(gap_ready),
    .m_axis_tdata(m_axis_output_tdata),
    .m_axis_tvalid(m_axis_output_tvalid),
    .m_axis_tready(m_axis_output_tready),
    .m_axis_tlast(m_axis_output_tlast),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config[18])
);

//=============================================================================
// Memory Controller
//=============================================================================

memory_controller #(
    .AXI_WIDTH(AXI_WIDTH),
    .BUFFER_DEPTH(BUFFER_DEPTH),
    .NUM_LAYERS(19)
) mem_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .current_layer(current_layer),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .feature_data(feature_data),
    .feature_valid(feature_valid),
    .feature_ready(feature_ready),
    .config_regs(config_reg)
);

//=============================================================================
// Control State Machine
//=============================================================================

typedef enum logic [2:0] {
    IDLE,
    LOADING_WEIGHTS,
    PROCESSING,
    DONE,
    ERROR
} state_t;

state_t current_state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        current_layer <= 4'd0;
        processing_active <= 1'b0;
        pixel_counter <= 16'd0;
        channel_counter <= 16'd0;
    end else begin
        current_state <= next_state;
        
        // Layer progression control
        if (processing_active) begin
            if (classifier_valid && classifier_ready) begin
                processing_active <= 1'b0;
            end
        end else if (start_processing) begin
            processing_active <= 1'b1;
            current_layer <= 4'd0;
        end
    end
end

always_comb begin
    next_state = current_state;
    
    case (current_state)
        IDLE: begin
            if (start_processing)
                next_state = LOADING_WEIGHTS;
        end
        
        LOADING_WEIGHTS: begin
            if (weight_valid && weight_ready)
                next_state = PROCESSING;
        end
        
        PROCESSING: begin
            if (!processing_active)
                next_state = DONE;
        end
        
        DONE: begin
            if (!start_processing)
                next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Status outputs
assign processing_done = (current_state == DONE);
assign status_reg = {12'd0, current_state, processing_active};

endmodule