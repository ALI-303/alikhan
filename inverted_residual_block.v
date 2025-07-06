/**
 * Inverted Residual Block for MobileNetV3
 * 
 * This module implements the inverted residual block used in MobileNetV3, which consists of:
 * 1. Expansion: 1x1 convolution to increase channels
 * 2. Depthwise: 3x3 or 5x5 depthwise convolution
 * 3. Squeeze-and-Excitation: Optional attention mechanism
 * 4. Compression: 1x1 convolution to reduce channels
 * 5. Residual connection: Add input to output when dimensions match
 * 
 * Features:
 * - Configurable expansion ratio, kernel size, and stride
 * - Optional Squeeze-and-Excitation block
 * - Support for h-swish and ReLU activation functions
 * - Batch normalization between layers
 * - Efficient pipeline implementation
 */

module inverted_residual_block #(
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter INPUT_CHANNELS = 24,
    parameter OUTPUT_CHANNELS = 24,
    parameter EXPANSION_CHANNELS = 144,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1,
    parameter USE_SE = 1,              // Use Squeeze-and-Excitation
    parameter USE_HSWISH = 1,          // Use h-swish activation
    parameter SE_REDUCTION = 4,        // SE reduction ratio
    parameter PARALLEL_MACS = 8
) (
    input wire clk,
    input wire rst_n,
    
    // Input feature map stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output feature map stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast,
    
    // Weight and bias data
    input wire [WEIGHT_WIDTH-1:0] weight_data,
    input wire weight_valid,
    output wire weight_ready,
    
    // Configuration and control
    input wire [7:0] layer_config [0:7],
    input wire enable,
    output wire processing_done
);

// Internal wire declarations for pipeline stages
wire [DATA_WIDTH-1:0] expansion_out;
wire expansion_valid;
wire expansion_ready;
wire expansion_last;

wire [DATA_WIDTH-1:0] expansion_bn_out;
wire expansion_bn_valid;
wire expansion_bn_ready;
wire expansion_bn_last;

wire [DATA_WIDTH-1:0] expansion_act_out;
wire expansion_act_valid;
wire expansion_act_ready;
wire expansion_act_last;

wire [DATA_WIDTH-1:0] depthwise_out;
wire depthwise_valid;
wire depthwise_ready;
wire depthwise_last;

wire [DATA_WIDTH-1:0] depthwise_bn_out;
wire depthwise_bn_valid;
wire depthwise_bn_ready;
wire depthwise_bn_last;

wire [DATA_WIDTH-1:0] depthwise_act_out;
wire depthwise_act_valid;
wire depthwise_act_ready;
wire depthwise_act_last;

wire [DATA_WIDTH-1:0] se_out;
wire se_valid;
wire se_ready;
wire se_last;

wire [DATA_WIDTH-1:0] compression_out;
wire compression_valid;
wire compression_ready;
wire compression_last;

wire [DATA_WIDTH-1:0] compression_bn_out;
wire compression_bn_valid;
wire compression_bn_ready;
wire compression_bn_last;

wire [DATA_WIDTH-1:0] residual_out;
wire residual_valid;
wire residual_ready;
wire residual_last;

// Input buffering for residual connection
reg [DATA_WIDTH-1:0] input_buffer [0:2047];
reg [10:0] input_buffer_wr_ptr;
reg [10:0] input_buffer_rd_ptr;
reg input_buffer_full;
reg input_buffer_empty;

// Residual connection enable
wire use_residual = (INPUT_CHANNELS == OUTPUT_CHANNELS) && (STRIDE == 1);

//=============================================================================
// Stage 1: Expansion (1x1 Convolution)
//=============================================================================

depthwise_separable_conv #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_CHANNELS(INPUT_CHANNELS),
    .OUTPUT_CHANNELS(EXPANSION_CHANNELS),
    .KERNEL_SIZE(1),
    .STRIDE(1),
    .PADDING(0),
    .USE_DEPTHWISE(0), // Standard 1x1 convolution
    .PARALLEL_MACS(PARALLEL_MACS)
) expansion_conv (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(expansion_out),
    .m_axis_tvalid(expansion_valid),
    .m_axis_tready(expansion_ready),
    .m_axis_tlast(expansion_last),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config),
    .enable(enable)
);

// Batch Normalization after expansion
batch_normalization #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNELS(EXPANSION_CHANNELS)
) expansion_bn (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(expansion_out),
    .s_axis_tvalid(expansion_valid),
    .s_axis_tready(expansion_ready),
    .s_axis_tlast(expansion_last),
    .m_axis_tdata(expansion_bn_out),
    .m_axis_tvalid(expansion_bn_valid),
    .m_axis_tready(expansion_bn_ready),
    .m_axis_tlast(expansion_bn_last),
    .layer_config(layer_config)
);

// Activation function after expansion BN
generate
if (USE_HSWISH) begin : gen_expansion_hswish
    hswish_activation #(
        .DATA_WIDTH(DATA_WIDTH)
    ) expansion_act (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(expansion_bn_out),
        .s_axis_tvalid(expansion_bn_valid),
        .s_axis_tready(expansion_bn_ready),
        .s_axis_tlast(expansion_bn_last),
        .m_axis_tdata(expansion_act_out),
        .m_axis_tvalid(expansion_act_valid),
        .m_axis_tready(expansion_act_ready),
        .m_axis_tlast(expansion_act_last)
    );
end else begin : gen_expansion_relu
    relu_activation #(
        .DATA_WIDTH(DATA_WIDTH)
    ) expansion_act (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(expansion_bn_out),
        .s_axis_tvalid(expansion_bn_valid),
        .s_axis_tready(expansion_bn_ready),
        .s_axis_tlast(expansion_bn_last),
        .m_axis_tdata(expansion_act_out),
        .m_axis_tvalid(expansion_act_valid),
        .m_axis_tready(expansion_act_ready),
        .m_axis_tlast(expansion_act_last)
    );
end
endgenerate

//=============================================================================
// Stage 2: Depthwise Convolution
//=============================================================================

depthwise_separable_conv #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_CHANNELS(EXPANSION_CHANNELS),
    .OUTPUT_CHANNELS(EXPANSION_CHANNELS),
    .KERNEL_SIZE(KERNEL_SIZE),
    .STRIDE(STRIDE),
    .PADDING(KERNEL_SIZE/2),
    .USE_DEPTHWISE(1), // Pure depthwise convolution
    .PARALLEL_MACS(PARALLEL_MACS)
) depthwise_conv (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(expansion_act_out),
    .s_axis_tvalid(expansion_act_valid),
    .s_axis_tready(expansion_act_ready),
    .s_axis_tlast(expansion_act_last),
    .m_axis_tdata(depthwise_out),
    .m_axis_tvalid(depthwise_valid),
    .m_axis_tready(depthwise_ready),
    .m_axis_tlast(depthwise_last),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config),
    .enable(enable)
);

// Batch Normalization after depthwise
batch_normalization #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNELS(EXPANSION_CHANNELS)
) depthwise_bn (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(depthwise_out),
    .s_axis_tvalid(depthwise_valid),
    .s_axis_tready(depthwise_ready),
    .s_axis_tlast(depthwise_last),
    .m_axis_tdata(depthwise_bn_out),
    .m_axis_tvalid(depthwise_bn_valid),
    .m_axis_tready(depthwise_bn_ready),
    .m_axis_tlast(depthwise_bn_last),
    .layer_config(layer_config)
);

// Activation function after depthwise BN
generate
if (USE_HSWISH) begin : gen_depthwise_hswish
    hswish_activation #(
        .DATA_WIDTH(DATA_WIDTH)
    ) depthwise_act (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(depthwise_bn_out),
        .s_axis_tvalid(depthwise_bn_valid),
        .s_axis_tready(depthwise_bn_ready),
        .s_axis_tlast(depthwise_bn_last),
        .m_axis_tdata(depthwise_act_out),
        .m_axis_tvalid(depthwise_act_valid),
        .m_axis_tready(depthwise_act_ready),
        .m_axis_tlast(depthwise_act_last)
    );
end else begin : gen_depthwise_relu
    relu_activation #(
        .DATA_WIDTH(DATA_WIDTH)
    ) depthwise_act (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(depthwise_bn_out),
        .s_axis_tvalid(depthwise_bn_valid),
        .s_axis_tready(depthwise_bn_ready),
        .s_axis_tlast(depthwise_bn_last),
        .m_axis_tdata(depthwise_act_out),
        .m_axis_tvalid(depthwise_act_valid),
        .m_axis_tready(depthwise_act_ready),
        .m_axis_tlast(depthwise_act_last)
    );
end
endgenerate

//=============================================================================
// Stage 3: Squeeze-and-Excitation (Optional)
//=============================================================================

generate
if (USE_SE) begin : gen_se_block
    squeeze_excitation #(
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .NUM_CHANNELS(EXPANSION_CHANNELS),
        .REDUCTION_RATIO(SE_REDUCTION)
    ) se_block (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(depthwise_act_out),
        .s_axis_tvalid(depthwise_act_valid),
        .s_axis_tready(depthwise_act_ready),
        .s_axis_tlast(depthwise_act_last),
        .m_axis_tdata(se_out),
        .m_axis_tvalid(se_valid),
        .m_axis_tready(se_ready),
        .m_axis_tlast(se_last),
        .weight_data(weight_data),
        .weight_valid(weight_valid),
        .weight_ready(weight_ready),
        .layer_config(layer_config)
    );
end else begin : gen_se_bypass
    // Bypass SE block
    assign se_out = depthwise_act_out;
    assign se_valid = depthwise_act_valid;
    assign depthwise_act_ready = se_ready;
    assign se_last = depthwise_act_last;
end
endgenerate

//=============================================================================
// Stage 4: Compression (1x1 Convolution)
//=============================================================================

depthwise_separable_conv #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_CHANNELS(EXPANSION_CHANNELS),
    .OUTPUT_CHANNELS(OUTPUT_CHANNELS),
    .KERNEL_SIZE(1),
    .STRIDE(1),
    .PADDING(0),
    .USE_DEPTHWISE(0), // Standard 1x1 convolution
    .PARALLEL_MACS(PARALLEL_MACS)
) compression_conv (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(se_out),
    .s_axis_tvalid(se_valid),
    .s_axis_tready(se_ready),
    .s_axis_tlast(se_last),
    .m_axis_tdata(compression_out),
    .m_axis_tvalid(compression_valid),
    .m_axis_tready(compression_ready),
    .m_axis_tlast(compression_last),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config),
    .enable(enable)
);

// Batch Normalization after compression
batch_normalization #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNELS(OUTPUT_CHANNELS)
) compression_bn (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(compression_out),
    .s_axis_tvalid(compression_valid),
    .s_axis_tready(compression_ready),
    .s_axis_tlast(compression_last),
    .m_axis_tdata(compression_bn_out),
    .m_axis_tvalid(compression_bn_valid),
    .m_axis_tready(compression_bn_ready),
    .m_axis_tlast(compression_bn_last),
    .layer_config(layer_config)
);

//=============================================================================
// Stage 5: Residual Connection (Optional)
//=============================================================================

// Input buffering for residual connection
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_buffer_wr_ptr <= 11'd0;
        input_buffer_rd_ptr <= 11'd0;
        input_buffer_full <= 1'b0;
        input_buffer_empty <= 1'b1;
    end else begin
        // Write input data to buffer when residual connection is needed
        if (use_residual && s_axis_tvalid && s_axis_tready) begin
            input_buffer[input_buffer_wr_ptr] <= s_axis_tdata;
            input_buffer_wr_ptr <= input_buffer_wr_ptr + 1;
            input_buffer_empty <= 1'b0;
            if (input_buffer_wr_ptr == input_buffer_rd_ptr - 1)
                input_buffer_full <= 1'b1;
        end
        
        // Read from buffer for residual addition
        if (use_residual && compression_bn_valid && compression_bn_ready) begin
            input_buffer_rd_ptr <= input_buffer_rd_ptr + 1;
            input_buffer_full <= 1'b0;
            if (input_buffer_rd_ptr == input_buffer_wr_ptr - 1)
                input_buffer_empty <= 1'b1;
        end
    end
end

// Residual addition
generate
if (use_residual) begin : gen_residual_add
    residual_add #(
        .DATA_WIDTH(DATA_WIDTH)
    ) res_add (
        .clk(clk),
        .rst_n(rst_n),
        .main_data(compression_bn_out),
        .main_valid(compression_bn_valid),
        .main_ready(compression_bn_ready),
        .main_last(compression_bn_last),
        .residual_data(input_buffer[input_buffer_rd_ptr]),
        .residual_valid(!input_buffer_empty),
        .result_data(m_axis_tdata),
        .result_valid(m_axis_tvalid),
        .result_ready(m_axis_tready),
        .result_last(m_axis_tlast)
    );
end else begin : gen_residual_bypass
    // No residual connection
    assign m_axis_tdata = compression_bn_out;
    assign m_axis_tvalid = compression_bn_valid;
    assign compression_bn_ready = m_axis_tready;
    assign m_axis_tlast = compression_bn_last;
end
endgenerate

assign processing_done = compression_bn_valid && compression_bn_ready && compression_bn_last;

endmodule

//=============================================================================
// Residual Addition Module
//=============================================================================

module residual_add #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire rst_n,
    
    input wire [DATA_WIDTH-1:0] main_data,
    input wire main_valid,
    output wire main_ready,
    input wire main_last,
    
    input wire [DATA_WIDTH-1:0] residual_data,
    input wire residual_valid,
    
    output wire [DATA_WIDTH-1:0] result_data,
    output wire result_valid,
    input wire result_ready,
    output wire result_last
);

// Simple element-wise addition with saturation
reg [DATA_WIDTH-1:0] result_reg;
reg valid_reg;
reg last_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_reg <= {DATA_WIDTH{1'b0}};
        valid_reg <= 1'b0;
        last_reg <= 1'b0;
    end else if (main_valid && residual_valid && result_ready) begin
        // Perform saturated addition
        reg [DATA_WIDTH:0] temp_sum;
        temp_sum = main_data + residual_data;
        
        // Saturation logic
        if (temp_sum[DATA_WIDTH]) begin
            // Overflow - saturate to maximum value
            result_reg <= {DATA_WIDTH{1'b1}};
        end else begin
            result_reg <= temp_sum[DATA_WIDTH-1:0];
        end
        
        valid_reg <= 1'b1;
        last_reg <= main_last;
    end else if (result_ready) begin
        valid_reg <= 1'b0;
        last_reg <= 1'b0;
    end
end

assign result_data = result_reg;
assign result_valid = valid_reg;
assign result_last = last_reg;
assign main_ready = result_ready && residual_valid;

endmodule