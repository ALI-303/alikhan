/**
 * Squeeze-and-Excitation (SE) Block for MobileNetV3
 * 
 * The SE block implements channel attention mechanism that adaptively recalibrates
 * channel-wise feature responses. It consists of:
 * 1. Squeeze: Global average pooling to compress spatial dimensions
 * 2. Excitation: Two FC layers with ReLU and sigmoid to generate channel weights
 * 3. Scale: Multiply input features by learned channel weights
 * 
 * Features:
 * - Configurable reduction ratio for efficiency
 * - Pipeline implementation for high throughput
 * - Fixed-point arithmetic optimized for FPGA
 * - AXI4-Stream interface compatibility
 */

module squeeze_excitation #(
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter NUM_CHANNELS = 64,
    parameter REDUCTION_RATIO = 4,      // Channel reduction in bottleneck
    parameter FEATURE_MAP_SIZE = 14,    // Spatial size of feature map
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
    
    // Weight data interface
    input wire [WEIGHT_WIDTH-1:0] weight_data,
    input wire weight_valid,
    output wire weight_ready,
    
    // Configuration
    input wire [7:0] layer_config [0:7]
);

// Local parameters
localparam REDUCED_CHANNELS = NUM_CHANNELS / REDUCTION_RATIO;
localparam SPATIAL_SIZE = FEATURE_MAP_SIZE * FEATURE_MAP_SIZE;
localparam ACCUMULATOR_WIDTH = DATA_WIDTH + 8; // Extra bits for accumulation

// Internal signals
wire [DATA_WIDTH-1:0] squeeze_out;
wire squeeze_valid;
wire squeeze_ready;

wire [DATA_WIDTH-1:0] fc1_out;
wire fc1_valid;
wire fc1_ready;

wire [DATA_WIDTH-1:0] relu_out;
wire relu_valid;
wire relu_ready;

wire [DATA_WIDTH-1:0] fc2_out;
wire fc2_valid;
wire fc2_ready;

wire [DATA_WIDTH-1:0] sigmoid_out;
wire sigmoid_valid;
wire sigmoid_ready;

wire [DATA_WIDTH-1:0] scale_out;
wire scale_valid;
wire scale_ready;

// Feature map buffering for bypass path
reg [DATA_WIDTH-1:0] feature_buffer [0:SPATIAL_SIZE*NUM_CHANNELS-1];
reg [15:0] buffer_wr_ptr;
reg [15:0] buffer_rd_ptr;
reg buffer_full;
reg buffer_empty;

//=============================================================================
// Stage 1: Squeeze - Global Average Pooling
//=============================================================================

global_average_pooling #(
    .DATA_WIDTH(DATA_WIDTH),
    .INPUT_CHANNELS(NUM_CHANNELS),
    .FEATURE_MAP_SIZE(FEATURE_MAP_SIZE)
) squeeze_gap (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(squeeze_out),
    .m_axis_tvalid(squeeze_valid),
    .m_axis_tready(squeeze_ready)
);

//=============================================================================
// Stage 2: Excitation - First FC Layer (Channel Reduction)
//=============================================================================

fully_connected_layer #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_FEATURES(NUM_CHANNELS),
    .OUTPUT_FEATURES(REDUCED_CHANNELS)
) fc1_layer (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(squeeze_out),
    .s_axis_tvalid(squeeze_valid),
    .s_axis_tready(squeeze_ready),
    .m_axis_tdata(fc1_out),
    .m_axis_tvalid(fc1_valid),
    .m_axis_tready(fc1_ready),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config)
);

// ReLU activation after first FC layer
relu_activation #(
    .DATA_WIDTH(DATA_WIDTH)
) fc1_relu (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(fc1_out),
    .s_axis_tvalid(fc1_valid),
    .s_axis_tready(fc1_ready),
    .m_axis_tdata(relu_out),
    .m_axis_tvalid(relu_valid),
    .m_axis_tready(relu_ready)
);

//=============================================================================
// Stage 3: Excitation - Second FC Layer (Channel Expansion)
//=============================================================================

fully_connected_layer #(
    .DATA_WIDTH(DATA_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .INPUT_FEATURES(REDUCED_CHANNELS),
    .OUTPUT_FEATURES(NUM_CHANNELS)
) fc2_layer (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(relu_out),
    .s_axis_tvalid(relu_valid),
    .s_axis_tready(relu_ready),
    .m_axis_tdata(fc2_out),
    .m_axis_tvalid(fc2_valid),
    .m_axis_tready(fc2_ready),
    .weight_data(weight_data),
    .weight_valid(weight_valid),
    .weight_ready(weight_ready),
    .layer_config(layer_config)
);

// Sigmoid activation after second FC layer
sigmoid_activation #(
    .DATA_WIDTH(DATA_WIDTH)
) fc2_sigmoid (
    .clk(clk),
    .rst_n(rst_n),
    .s_axis_tdata(fc2_out),
    .s_axis_tvalid(fc2_valid),
    .s_axis_tready(fc2_ready),
    .m_axis_tdata(sigmoid_out),
    .m_axis_tvalid(sigmoid_valid),
    .m_axis_tready(sigmoid_ready)
);

//=============================================================================
// Stage 4: Scale - Element-wise Multiplication
//=============================================================================

// Buffer original feature maps for scaling
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buffer_wr_ptr <= 16'd0;
        buffer_rd_ptr <= 16'd0;
        buffer_full <= 1'b0;
        buffer_empty <= 1'b1;
    end else begin
        // Write input features to buffer
        if (s_axis_tvalid && s_axis_tready && !buffer_full) begin
            feature_buffer[buffer_wr_ptr] <= s_axis_tdata;
            buffer_wr_ptr <= buffer_wr_ptr + 1;
            buffer_empty <= 1'b0;
            
            if (buffer_wr_ptr == SPATIAL_SIZE * NUM_CHANNELS - 1) begin
                buffer_full <= 1'b1;
            end
        end
        
        // Read features for scaling
        if (sigmoid_valid && m_axis_tready && !buffer_empty) begin
            buffer_rd_ptr <= buffer_rd_ptr + 1;
            
            if (buffer_rd_ptr == SPATIAL_SIZE * NUM_CHANNELS - 1) begin
                buffer_empty <= 1'b1;
                buffer_full <= 1'b0;
                buffer_wr_ptr <= 16'd0;
                buffer_rd_ptr <= 16'd0;
            end
        end
    end
end

// Channel-wise scaling module
channel_wise_scale #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNELS(NUM_CHANNELS),
    .FEATURE_MAP_SIZE(FEATURE_MAP_SIZE)
) scaler (
    .clk(clk),
    .rst_n(rst_n),
    .feature_data(feature_buffer[buffer_rd_ptr]),
    .feature_valid(!buffer_empty),
    .scale_data(sigmoid_out),
    .scale_valid(sigmoid_valid),
    .scale_ready(sigmoid_ready),
    .result_data(m_axis_tdata),
    .result_valid(m_axis_tvalid),
    .result_ready(m_axis_tready),
    .result_last(m_axis_tlast)
);

endmodule

//=============================================================================
// Channel-wise Scaling Module
//=============================================================================

module channel_wise_scale #(
    parameter DATA_WIDTH = 16,
    parameter NUM_CHANNELS = 64,
    parameter FEATURE_MAP_SIZE = 14
) (
    input wire clk,
    input wire rst_n,
    
    input wire [DATA_WIDTH-1:0] feature_data,
    input wire feature_valid,
    
    input wire [DATA_WIDTH-1:0] scale_data,
    input wire scale_valid,
    output wire scale_ready,
    
    output wire [DATA_WIDTH-1:0] result_data,
    output wire result_valid,
    input wire result_ready,
    output wire result_last
);

// Scale factor buffer - one scale per channel
reg [DATA_WIDTH-1:0] scale_factors [0:NUM_CHANNELS-1];
reg scale_factors_loaded;
reg [7:0] scale_load_counter;

// Spatial position tracking
reg [7:0] current_channel;
reg [15:0] spatial_counter;
reg processing_active;

// Pipeline registers
reg [DATA_WIDTH-1:0] result_reg;
reg valid_reg;
reg last_reg;

// Load scale factors
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scale_load_counter <= 8'd0;
        scale_factors_loaded <= 1'b0;
        current_channel <= 8'd0;
        spatial_counter <= 16'd0;
        processing_active <= 1'b0;
    end else begin
        // Load scale factors first
        if (!scale_factors_loaded && scale_valid) begin
            scale_factors[scale_load_counter] <= scale_data;
            scale_load_counter <= scale_load_counter + 1;
            
            if (scale_load_counter == NUM_CHANNELS - 1) begin
                scale_factors_loaded <= 1'b1;
                processing_active <= 1'b1;
            end
        end
        
        // Process features
        if (scale_factors_loaded && feature_valid && result_ready) begin
            spatial_counter <= spatial_counter + 1;
            
            // Move to next channel after processing all spatial locations
            if (spatial_counter == FEATURE_MAP_SIZE * FEATURE_MAP_SIZE - 1) begin
                spatial_counter <= 16'd0;
                current_channel <= current_channel + 1;
                
                // Reset after processing all channels
                if (current_channel == NUM_CHANNELS - 1) begin
                    current_channel <= 8'd0;
                    processing_active <= 1'b0;
                    scale_factors_loaded <= 1'b0;
                    scale_load_counter <= 8'd0;
                end
            end
        end
    end
end

// Perform channel-wise multiplication
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_reg <= {DATA_WIDTH{1'b0}};
        valid_reg <= 1'b0;
        last_reg <= 1'b0;
    end else if (scale_factors_loaded && feature_valid && result_ready) begin
        // Fixed-point multiplication with proper scaling
        reg [2*DATA_WIDTH-1:0] mult_result;
        mult_result = feature_data * scale_factors[current_channel];
        
        // Scale back to original range (assuming scale factors are in [0,1] range)
        result_reg <= mult_result[2*DATA_WIDTH-1:DATA_WIDTH];
        valid_reg <= 1'b1;
        
        // Generate last signal for final pixel of final channel
        last_reg <= (current_channel == NUM_CHANNELS - 1) && 
                    (spatial_counter == FEATURE_MAP_SIZE * FEATURE_MAP_SIZE - 1);
    end else if (result_ready) begin
        valid_reg <= 1'b0;
        last_reg <= 1'b0;
    end
end

assign result_data = result_reg;
assign result_valid = valid_reg;
assign result_last = last_reg;
assign scale_ready = !scale_factors_loaded || (scale_load_counter < NUM_CHANNELS);

endmodule

//=============================================================================
// Global Average Pooling Module
//=============================================================================

module global_average_pooling #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_CHANNELS = 64,
    parameter FEATURE_MAP_SIZE = 14
) (
    input wire clk,
    input wire rst_n,
    
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready
);

localparam SPATIAL_SIZE = FEATURE_MAP_SIZE * FEATURE_MAP_SIZE;
localparam ACCUMULATOR_WIDTH = DATA_WIDTH + 8; // Extra bits for accumulation

// Accumulator for each channel
reg [ACCUMULATOR_WIDTH-1:0] channel_accumulators [0:INPUT_CHANNELS-1];
reg [7:0] current_channel;
reg [15:0] spatial_counter;
reg [7:0] output_channel;

// Control signals
reg accumulating;
reg outputting;
reg output_valid_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_channel <= 8'd0;
        spatial_counter <= 16'd0;
        output_channel <= 8'd0;
        accumulating <= 1'b0;
        outputting <= 1'b0;
        output_valid_reg <= 1'b0;
        
        // Clear accumulators
        for (int i = 0; i < INPUT_CHANNELS; i++) begin
            channel_accumulators[i] <= {ACCUMULATOR_WIDTH{1'b0}};
        end
    end else begin
        // Accumulation phase
        if (s_axis_tvalid && s_axis_tready && !outputting) begin
            channel_accumulators[current_channel] <= channel_accumulators[current_channel] + s_axis_tdata;
            spatial_counter <= spatial_counter + 1;
            accumulating <= 1'b1;
            
            // Move to next channel after processing all spatial locations
            if (spatial_counter == SPATIAL_SIZE - 1) begin
                spatial_counter <= 16'd0;
                current_channel <= current_channel + 1;
                
                // Start outputting after processing all channels
                if (current_channel == INPUT_CHANNELS - 1) begin
                    current_channel <= 8'd0;
                    accumulating <= 1'b0;
                    outputting <= 1'b1;
                    output_valid_reg <= 1'b1;
                end
            end
        end
        
        // Output phase
        if (outputting && m_axis_tready) begin
            output_channel <= output_channel + 1;
            
            if (output_channel == INPUT_CHANNELS - 1) begin
                outputting <= 1'b0;
                output_valid_reg <= 1'b0;
                output_channel <= 8'd0;
                
                // Clear accumulators for next iteration
                for (int i = 0; i < INPUT_CHANNELS; i++) begin
                    channel_accumulators[i] <= {ACCUMULATOR_WIDTH{1'b0}};
                end
            end
        end
    end
end

// Compute average by dividing by spatial size
wire [DATA_WIDTH-1:0] averaged_output;
assign averaged_output = channel_accumulators[output_channel][ACCUMULATOR_WIDTH-1:8] / SPATIAL_SIZE;

assign m_axis_tdata = averaged_output;
assign m_axis_tvalid = output_valid_reg;
assign s_axis_tready = !outputting;

endmodule