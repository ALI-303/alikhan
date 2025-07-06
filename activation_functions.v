/**
 * Activation Functions for MobileNetV3
 * 
 * This file contains implementations of various activation functions used in MobileNetV3:
 * 1. ReLU: Standard rectified linear unit
 * 2. h-swish: Hardware-efficient swish activation function
 * 3. Sigmoid: Standard sigmoid activation with LUT implementation
 * 4. Hard Sigmoid: Hardware-efficient approximation of sigmoid
 * 
 * Features:
 * - Fixed-point arithmetic optimized for FPGA
 * - Pipeline-friendly implementations
 * - Configurable data width
 * - AXI4-Stream interface compatibility
 */

//=============================================================================
// ReLU Activation Function
//=============================================================================

module relu_activation #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire rst_n,
    
    // Input stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// ReLU is simply max(0, x)
// In fixed-point, negative numbers have MSB = 1
wire is_negative = s_axis_tdata[DATA_WIDTH-1];

assign m_axis_tdata = is_negative ? {DATA_WIDTH{1'b0}} : s_axis_tdata;
assign m_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = m_axis_tready;
assign m_axis_tlast = s_axis_tlast;

endmodule

//=============================================================================
// h-swish Activation Function (Hardware-efficient Swish)
//=============================================================================

module hswish_activation #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8  // Number of fractional bits
) (
    input wire clk,
    input wire rst_n,
    
    // Input stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// h-swish(x) = x * ReLU6(x + 3) / 6
// This is a hardware-efficient approximation of swish(x) = x * sigmoid(x)

// Pipeline registers
reg [DATA_WIDTH-1:0] x_reg;
reg [DATA_WIDTH-1:0] x_plus_3_reg;
reg [DATA_WIDTH-1:0] relu6_reg;
reg [DATA_WIDTH-1:0] mult_reg;
reg [DATA_WIDTH-1:0] result_reg;

reg valid_stage1, valid_stage2, valid_stage3, valid_stage4;
reg last_stage1, last_stage2, last_stage3, last_stage4;

// Constants in fixed-point
localparam [DATA_WIDTH-1:0] CONST_3 = 3 << FRAC_BITS;
localparam [DATA_WIDTH-1:0] CONST_6 = 6 << FRAC_BITS;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_reg <= {DATA_WIDTH{1'b0}};
        x_plus_3_reg <= {DATA_WIDTH{1'b0}};
        relu6_reg <= {DATA_WIDTH{1'b0}};
        mult_reg <= {DATA_WIDTH{1'b0}};
        result_reg <= {DATA_WIDTH{1'b0}};
        
        valid_stage1 <= 1'b0;
        valid_stage2 <= 1'b0;
        valid_stage3 <= 1'b0;
        valid_stage4 <= 1'b0;
        
        last_stage1 <= 1'b0;
        last_stage2 <= 1'b0;
        last_stage3 <= 1'b0;
        last_stage4 <= 1'b0;
    end else if (m_axis_tready) begin
        // Stage 1: Store x and compute x + 3
        if (s_axis_tvalid) begin
            x_reg <= s_axis_tdata;
            x_plus_3_reg <= s_axis_tdata + CONST_3;
            valid_stage1 <= 1'b1;
            last_stage1 <= s_axis_tlast;
        end else begin
            valid_stage1 <= 1'b0;
            last_stage1 <= 1'b0;
        end
        
        // Stage 2: Apply ReLU6 to (x + 3)
        if (valid_stage1) begin
            // ReLU6(x) = min(max(0, x), 6)
            reg [DATA_WIDTH-1:0] temp_relu6;
            
            if (x_plus_3_reg[DATA_WIDTH-1]) begin
                // Negative, so ReLU gives 0
                temp_relu6 = {DATA_WIDTH{1'b0}};
            end else if (x_plus_3_reg > CONST_6) begin
                // Greater than 6, so clip to 6
                temp_relu6 = CONST_6;
            end else begin
                // Between 0 and 6, so keep original value
                temp_relu6 = x_plus_3_reg;
            end
            
            relu6_reg <= temp_relu6;
            valid_stage2 <= 1'b1;
            last_stage2 <= last_stage1;
        end else begin
            valid_stage2 <= 1'b0;
            last_stage2 <= 1'b0;
        end
        
        // Stage 3: Multiply x * ReLU6(x + 3)
        if (valid_stage2) begin
            reg [2*DATA_WIDTH-1:0] mult_result;
            mult_result = x_reg * relu6_reg;
            mult_reg <= mult_result[DATA_WIDTH+FRAC_BITS-1:FRAC_BITS];
            valid_stage3 <= 1'b1;
            last_stage3 <= last_stage2;
        end else begin
            valid_stage3 <= 1'b0;
            last_stage3 <= 1'b0;
        end
        
        // Stage 4: Divide by 6
        if (valid_stage3) begin
            // Division by 6 using multiplication by reciprocal
            // 1/6 ≈ 0.166667 in fixed-point
            localparam [DATA_WIDTH-1:0] INV_6 = (1 << (FRAC_BITS + 8)) / 6;
            reg [2*DATA_WIDTH-1:0] div_result;
            
            div_result = mult_reg * INV_6;
            result_reg <= div_result[DATA_WIDTH+FRAC_BITS+7:FRAC_BITS+8];
            valid_stage4 <= 1'b1;
            last_stage4 <= last_stage3;
        end else begin
            valid_stage4 <= 1'b0;
            last_stage4 <= 1'b0;
        end
    end
end

assign m_axis_tdata = result_reg;
assign m_axis_tvalid = valid_stage4;
assign m_axis_tlast = last_stage4;
assign s_axis_tready = m_axis_tready;

endmodule

//=============================================================================
// Sigmoid Activation Function (LUT-based)
//=============================================================================

module sigmoid_activation #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8,
    parameter LUT_SIZE = 256
) (
    input wire clk,
    input wire rst_n,
    
    // Input stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// Sigmoid lookup table (precomputed values)
// sigmoid(x) = 1 / (1 + exp(-x))
reg [DATA_WIDTH-1:0] sigmoid_lut [0:LUT_SIZE-1];

// Initialize LUT with sigmoid values
initial begin
    // This would be populated with precomputed sigmoid values
    // For simulation, using a simplified approximation
    for (int i = 0; i < LUT_SIZE; i++) begin
        // Approximate sigmoid using piece-wise linear
        if (i < 64) begin
            sigmoid_lut[i] = (i * (1 << FRAC_BITS)) / 128;  // Rising part
        end else if (i < 192) begin
            sigmoid_lut[i] = (1 << FRAC_BITS) / 2;  // Middle plateau
        end else begin
            sigmoid_lut[i] = ((255 - i) * (1 << FRAC_BITS)) / 128 + (1 << FRAC_BITS) / 2;
        end
    end
end

// Pipeline registers
reg [DATA_WIDTH-1:0] input_reg;
reg [7:0] lut_index_reg;
reg [DATA_WIDTH-1:0] output_reg;
reg valid_reg1, valid_reg2;
reg last_reg1, last_reg2;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_reg <= {DATA_WIDTH{1'b0}};
        lut_index_reg <= 8'd0;
        output_reg <= {DATA_WIDTH{1'b0}};
        valid_reg1 <= 1'b0;
        valid_reg2 <= 1'b0;
        last_reg1 <= 1'b0;
        last_reg2 <= 1'b0;
    end else if (m_axis_tready) begin
        // Stage 1: Convert input to LUT index
        if (s_axis_tvalid) begin
            input_reg <= s_axis_tdata;
            
            // Map input range to LUT index [0, LUT_SIZE-1]
            if (s_axis_tdata[DATA_WIDTH-1]) begin
                // Negative input
                lut_index_reg <= 8'd0;
            end else if (s_axis_tdata[DATA_WIDTH-2:FRAC_BITS] >= LUT_SIZE) begin
                // Large positive input
                lut_index_reg <= LUT_SIZE - 1;
            end else begin
                // Normal range
                lut_index_reg <= s_axis_tdata[FRAC_BITS+7:FRAC_BITS];
            end
            
            valid_reg1 <= 1'b1;
            last_reg1 <= s_axis_tlast;
        end else begin
            valid_reg1 <= 1'b0;
            last_reg1 <= 1'b0;
        end
        
        // Stage 2: LUT lookup
        if (valid_reg1) begin
            output_reg <= sigmoid_lut[lut_index_reg];
            valid_reg2 <= 1'b1;
            last_reg2 <= last_reg1;
        end else begin
            valid_reg2 <= 1'b0;
            last_reg2 <= 1'b0;
        end
    end
end

assign m_axis_tdata = output_reg;
assign m_axis_tvalid = valid_reg2;
assign m_axis_tlast = last_reg2;
assign s_axis_tready = m_axis_tready;

endmodule

//=============================================================================
// Hard Sigmoid Activation Function
//=============================================================================

module hard_sigmoid_activation #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8
) (
    input wire clk,
    input wire rst_n,
    
    // Input stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// Hard sigmoid: max(0, min(1, (x + 1) / 2))
// This is a piece-wise linear approximation of sigmoid

// Constants in fixed-point
localparam [DATA_WIDTH-1:0] CONST_1 = 1 << FRAC_BITS;
localparam [DATA_WIDTH-1:0] CONST_NEG_1 = -(1 << FRAC_BITS);

// Pipeline registers
reg [DATA_WIDTH-1:0] x_plus_1_reg;
reg [DATA_WIDTH-1:0] div_2_reg;
reg [DATA_WIDTH-1:0] result_reg;
reg valid_reg1, valid_reg2, valid_reg3;
reg last_reg1, last_reg2, last_reg3;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_plus_1_reg <= {DATA_WIDTH{1'b0}};
        div_2_reg <= {DATA_WIDTH{1'b0}};
        result_reg <= {DATA_WIDTH{1'b0}};
        valid_reg1 <= 1'b0;
        valid_reg2 <= 1'b0;
        valid_reg3 <= 1'b0;
        last_reg1 <= 1'b0;
        last_reg2 <= 1'b0;
        last_reg3 <= 1'b0;
    end else if (m_axis_tready) begin
        // Stage 1: Compute x + 1
        if (s_axis_tvalid) begin
            x_plus_1_reg <= s_axis_tdata + CONST_1;
            valid_reg1 <= 1'b1;
            last_reg1 <= s_axis_tlast;
        end else begin
            valid_reg1 <= 1'b0;
            last_reg1 <= 1'b0;
        end
        
        // Stage 2: Divide by 2
        if (valid_reg1) begin
            div_2_reg <= x_plus_1_reg >>> 1;  // Arithmetic right shift
            valid_reg2 <= 1'b1;
            last_reg2 <= last_reg1;
        end else begin
            valid_reg2 <= 1'b0;
            last_reg2 <= 1'b0;
        end
        
        // Stage 3: Apply clipping [0, 1]
        if (valid_reg2) begin
            if (div_2_reg[DATA_WIDTH-1]) begin
                // Negative, clip to 0
                result_reg <= {DATA_WIDTH{1'b0}};
            end else if (div_2_reg > CONST_1) begin
                // Greater than 1, clip to 1
                result_reg <= CONST_1;
            end else begin
                // In range [0, 1]
                result_reg <= div_2_reg;
            end
            valid_reg3 <= 1'b1;
            last_reg3 <= last_reg2;
        end else begin
            valid_reg3 <= 1'b0;
            last_reg3 <= 1'b0;
        end
    end
end

assign m_axis_tdata = result_reg;
assign m_axis_tvalid = valid_reg3;
assign m_axis_tlast = last_reg3;
assign s_axis_tready = m_axis_tready;

endmodule

//=============================================================================
// ReLU6 Activation Function
//=============================================================================

module relu6_activation #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8
) (
    input wire clk,
    input wire rst_n,
    
    // Input stream
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Output stream
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

// ReLU6: min(max(0, x), 6)
localparam [DATA_WIDTH-1:0] CONST_6 = 6 << FRAC_BITS;

reg [DATA_WIDTH-1:0] result_reg;
reg valid_reg;
reg last_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_reg <= {DATA_WIDTH{1'b0}};
        valid_reg <= 1'b0;
        last_reg <= 1'b0;
    end else if (m_axis_tready) begin
        if (s_axis_tvalid) begin
            // Apply ReLU6 function
            if (s_axis_tdata[DATA_WIDTH-1]) begin
                // Negative, so output 0
                result_reg <= {DATA_WIDTH{1'b0}};
            end else if (s_axis_tdata > CONST_6) begin
                // Greater than 6, so clip to 6
                result_reg <= CONST_6;
            end else begin
                // Between 0 and 6, so keep original
                result_reg <= s_axis_tdata;
            end
            
            valid_reg <= 1'b1;
            last_reg <= s_axis_tlast;
        end else begin
            valid_reg <= 1'b0;
            last_reg <= 1'b0;
        end
    end
end

assign m_axis_tdata = result_reg;
assign m_axis_tvalid = valid_reg;
assign m_axis_tlast = last_reg;
assign s_axis_tready = m_axis_tready;

endmodule