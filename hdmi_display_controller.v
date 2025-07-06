//================================================================================
// KC705 OV7670 HDMI Display Controller
// Supports multiple HDMI resolutions with TMDS encoding
// Compatible with external HDMI transmitter ICs or direct HDMI output
//================================================================================

module hdmi_display_controller #(
    parameter HDMI_MODE = "720p",  // "720p", "1080p60", "1080p30"
    parameter USE_EXTERNAL_IC = 1   // 1 for ADV7511, 0 for direct HDMI
)(
    // Clock and Reset
    input  wire        clk_pixel,      // Pixel clock (74.25/148.5 MHz)
    input  wire        clk_tmds,       // TMDS clock (5x pixel clock)
    input  wire        rst_n,
    
    // Frame Buffer Interface
    input  wire        fb_clk,
    input  wire [18:0] fb_addr,
    output wire [23:0] fb_data,
    
    // Control Interface
    input  wire [1:0]  display_mode,   // 00=normal, 01=mono, 10=edge, 11=false_color
    input  wire        display_enable,
    
    // HDMI Output Pins
    output wire [2:0]  hdmi_tx_p,      // TMDS data positive
    output wire [2:0]  hdmi_tx_n,      // TMDS data negative  
    output wire        hdmi_clk_p,     // TMDS clock positive
    output wire        hdmi_clk_n,     // TMDS clock negative
    
    // I2C for EDID/Control (for external ICs)
    inout  wire        hdmi_scl,
    inout  wire        hdmi_sda,
    input  wire        hdmi_hpd,       // Hot plug detect
    
    // Debug
    output wire [7:0]  debug_leds
);

//================================================================================
// HDMI Timing Parameters
//================================================================================
localparam [10:0] H_ACTIVE_720P  = 1280;
localparam [10:0] H_FRONT_720P   = 110;
localparam [10:0] H_SYNC_720P    = 40;
localparam [10:0] H_BACK_720P    = 220;
localparam [10:0] H_TOTAL_720P   = 1650;

localparam [9:0]  V_ACTIVE_720P  = 720;
localparam [9:0]  V_FRONT_720P   = 5;
localparam [9:0]  V_SYNC_720P    = 5;
localparam [9:0]  V_BACK_720P    = 20;
localparam [9:0]  V_TOTAL_720P   = 750;

localparam [10:0] H_ACTIVE_1080P = 1920;
localparam [10:0] H_FRONT_1080P  = 88;
localparam [10:0] H_SYNC_1080P   = 44;
localparam [10:0] H_BACK_1080P   = 148;
localparam [10:0] H_TOTAL_1080P  = 2200;

localparam [10:0] V_ACTIVE_1080P = 1080;
localparam [10:0] V_FRONT_1080P  = 4;
localparam [10:0] V_SYNC_1080P   = 5;
localparam [10:0] V_BACK_1080P   = 36;
localparam [10:0] V_TOTAL_1080P  = 1125;

//================================================================================
// Resolution Selection
//================================================================================
wire [10:0] h_active, h_front, h_sync, h_back, h_total;
wire [10:0] v_active, v_front, v_sync, v_back, v_total;

generate
    if (HDMI_MODE == "720p") begin
        assign h_active = H_ACTIVE_720P;
        assign h_front  = H_FRONT_720P;
        assign h_sync   = H_SYNC_720P;
        assign h_back   = H_BACK_720P;
        assign h_total  = H_TOTAL_720P;
        assign v_active = V_ACTIVE_720P;
        assign v_front  = V_FRONT_720P;
        assign v_sync   = V_SYNC_720P;
        assign v_back   = V_BACK_720P;
        assign v_total  = V_TOTAL_720P;
    end else begin  // 1080p
        assign h_active = H_ACTIVE_1080P;
        assign h_front  = H_FRONT_1080P;
        assign h_sync   = H_SYNC_1080P;
        assign h_back   = H_BACK_1080P;
        assign h_total  = H_TOTAL_1080P;
        assign v_active = V_ACTIVE_1080P;
        assign v_front  = V_FRONT_1080P;
        assign v_sync   = V_SYNC_1080P;
        assign v_back   = V_BACK_1080P;
        assign v_total  = V_TOTAL_1080P;
    end
endgenerate

//================================================================================
// Timing Generator
//================================================================================
reg [10:0] h_count = 0;
reg [10:0] v_count = 0;

always @(posedge clk_pixel) begin
    if (!rst_n) begin
        h_count <= 0;
        v_count <= 0;
    end else begin
        if (h_count == h_total - 1) begin
            h_count <= 0;
            if (v_count == v_total - 1) begin
                v_count <= 0;
            end else begin
                v_count <= v_count + 1;
            end
        end else begin
            h_count <= h_count + 1;
        end
    end
end

// Timing signals
wire h_active_area = (h_count < h_active);
wire v_active_area = (v_count < v_active);
wire video_active = h_active_area && v_active_area && display_enable;

wire h_sync = (h_count >= (h_active + h_front)) && 
              (h_count < (h_active + h_front + h_sync));
wire v_sync = (v_count >= (v_active + v_front)) && 
              (v_count < (v_active + v_front + v_sync));

//================================================================================
// Frame Buffer Interface
//================================================================================
// Calculate frame buffer address based on current pixel position
wire [10:0] fb_x = h_count;
wire [10:0] fb_y = v_count;

// Scale to OV7670 resolution (640x480) if needed
wire [9:0] scaled_x = (fb_x * 640) / h_active;
wire [9:0] scaled_y = (fb_y * 480) / v_active;

// Frame buffer address calculation
assign fb_addr = (scaled_y * 640) + scaled_x;

// RGB data from frame buffer
wire [23:0] raw_rgb = fb_data;
wire [7:0] fb_r = raw_rgb[23:16];
wire [7:0] fb_g = raw_rgb[15:8];
wire [7:0] fb_b = raw_rgb[7:0];

//================================================================================
// Image Processing Pipeline
//================================================================================
reg [7:0] proc_r, proc_g, proc_b;
reg [7:0] proc_r_d, proc_g_d, proc_b_d;  // Delayed for pipeline

// Grayscale conversion
wire [7:0] gray = (fb_r >> 2) + (fb_g >> 1) + (fb_b >> 2);

// Edge detection (Sobel operator)
reg [7:0] pixel_buffer [0:2][0:2];
wire [7:0] sobel_x = pixel_buffer[0][2] + (pixel_buffer[1][2] << 1) + pixel_buffer[2][2] -
                     pixel_buffer[0][0] - (pixel_buffer[1][0] << 1) - pixel_buffer[2][0];
wire [7:0] sobel_y = pixel_buffer[2][0] + (pixel_buffer[2][1] << 1) + pixel_buffer[2][2] -
                     pixel_buffer[0][0] - (pixel_buffer[0][1] << 1) - pixel_buffer[0][2];
wire [8:0] edge_mag = sobel_x + sobel_y;
wire [7:0] edge_result = (edge_mag > 128) ? 8'hFF : 8'h00;

always @(posedge clk_pixel) begin
    if (video_active) begin
        case (display_mode)
            2'b00: begin  // Normal
                proc_r <= fb_r;
                proc_g <= fb_g;
                proc_b <= fb_b;
            end
            2'b01: begin  // Monochrome
                proc_r <= gray;
                proc_g <= gray;
                proc_b <= gray;
            end
            2'b10: begin  // Edge detection
                proc_r <= edge_result;
                proc_g <= edge_result;
                proc_b <= edge_result;
            end
            2'b11: begin  // False color
                proc_r <= fb_b;  // Swap channels
                proc_g <= fb_r;
                proc_b <= fb_g;
            end
        endcase
    end else begin
        proc_r <= 8'h00;
        proc_g <= 8'h00;
        proc_b <= 8'h00;
    end
    
    // Pipeline delay
    proc_r_d <= proc_r;
    proc_g_d <= proc_g;
    proc_b_d <= proc_b;
end

//================================================================================
// HDMI Output Generation
//================================================================================
generate
if (USE_EXTERNAL_IC) begin : external_hdmi
    // For external HDMI transmitter (e.g., ADV7511)
    // Output RGB data directly
    wire [7:0] hdmi_r = video_active ? proc_r_d : 8'h00;
    wire [7:0] hdmi_g = video_active ? proc_g_d : 8'h00;
    wire [7:0] hdmi_b = video_active ? proc_b_d : 8'h00;
    
    // Connect to external IC via FMC connector
    // (Specific pin assignments in constraints file)
    
end else begin : direct_hdmi
    // Direct HDMI implementation with TMDS encoding
    
    // TMDS Encoder instances
    wire [9:0] tmds_r, tmds_g, tmds_b;
    
    tmds_encoder tmds_enc_r (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(video_active ? proc_r_d : 8'h00),
        .c({1'b0, 1'b0}),
        .de(video_active),
        .encoded(tmds_r)
    );
    
    tmds_encoder tmds_enc_g (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(video_active ? proc_g_d : 8'h00),
        .c({1'b0, 1'b0}),
        .de(video_active),
        .encoded(tmds_g)
    );
    
    tmds_encoder tmds_enc_b (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .data(video_active ? proc_b_d : 8'h00),
        .c({v_sync, h_sync}),
        .de(video_active),
        .encoded(tmds_b)
    );
    
    // TMDS Serializers
    tmds_serializer ser_r (
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_tmds),
        .rst_n(rst_n),
        .data_in(tmds_r),
        .data_out_p(hdmi_tx_p[2]),
        .data_out_n(hdmi_tx_n[2])
    );
    
    tmds_serializer ser_g (
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_tmds),
        .rst_n(rst_n),
        .data_in(tmds_g),
        .data_out_p(hdmi_tx_p[1]),
        .data_out_n(hdmi_tx_n[1])
    );
    
    tmds_serializer ser_b (
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_tmds),
        .rst_n(rst_n),
        .data_in(tmds_b),
        .data_out_p(hdmi_tx_p[0]),
        .data_out_n(hdmi_tx_n[0])
    );
    
    // Clock output
    OBUFDS #(
        .IOSTANDARD("TMDS_33")
    ) hdmi_clk_buf (
        .I(clk_pixel),
        .O(hdmi_clk_p),
        .OB(hdmi_clk_n)
    );
    
end
endgenerate

//================================================================================
// Debug LEDs
//================================================================================
assign debug_leds[0] = video_active;
assign debug_leds[1] = h_sync;
assign debug_leds[2] = v_sync;
assign debug_leds[3] = hdmi_hpd;
assign debug_leds[7:4] = 4'b0;

endmodule

//================================================================================
// TMDS Encoder (8b/10b encoding)
//================================================================================
module tmds_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire [1:0] c,
    input  wire       de,
    output reg  [9:0] encoded
);

// TMDS encoding logic
reg [3:0] n1_data;
reg [8:0] q_m;
reg [4:0] cnt = 0;

// Count number of 1s in data
always @(*) begin
    n1_data = data[0] + data[1] + data[2] + data[3] + 
              data[4] + data[5] + data[6] + data[7];
end

// Minimize transitions
always @(*) begin
    if ((n1_data > 4) || ((n1_data == 4) && (data[0] == 0))) begin
        q_m[0] = data[0];
        q_m[1] = q_m[0] ~^ data[1];
        q_m[2] = q_m[1] ~^ data[2];
        q_m[3] = q_m[2] ~^ data[3];
        q_m[4] = q_m[3] ~^ data[4];
        q_m[5] = q_m[4] ~^ data[5];
        q_m[6] = q_m[5] ~^ data[6];
        q_m[7] = q_m[6] ~^ data[7];
        q_m[8] = 1'b0;
    end else begin
        q_m[0] = data[0];
        q_m[1] = q_m[0] ^ data[1];
        q_m[2] = q_m[1] ^ data[2];
        q_m[3] = q_m[2] ^ data[3];
        q_m[4] = q_m[3] ^ data[4];
        q_m[5] = q_m[4] ^ data[5];
        q_m[6] = q_m[5] ^ data[6];
        q_m[7] = q_m[6] ^ data[7];
        q_m[8] = 1'b1;
    end
end

// Count 1s and 0s in q_m[7:0]
wire [3:0] n1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] + 
                   q_m[4] + q_m[5] + q_m[6] + q_m[7];
wire [3:0] n0_qm = 8 - n1_qm;

always @(posedge clk) begin
    if (!rst_n) begin
        encoded <= 10'b0;
        cnt <= 5'b0;
    end else begin
        if (!de) begin
            // Control period
            case (c)
                2'b00: encoded <= 10'b1101010100;
                2'b01: encoded <= 10'b0010101011;
                2'b10: encoded <= 10'b0101010100;
                2'b11: encoded <= 10'b1010101011;
            endcase
            cnt <= 5'b0;
        end else begin
            // Data period
            if ((cnt == 0) || (n1_qm == n0_qm)) begin
                encoded[9] <= ~q_m[8];
                encoded[8] <= q_m[8];
                encoded[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
                
                if (q_m[8] == 0) begin
                    cnt <= cnt + n0_qm - n1_qm;
                end else begin
                    cnt <= cnt + n1_qm - n0_qm;
                end
            end else begin
                if (((cnt > 0) && (n1_qm > n0_qm)) || 
                    ((cnt < 0) && (n0_qm > n1_qm))) begin
                    encoded[9] <= 1'b1;
                    encoded[8] <= q_m[8];
                    encoded[7:0] <= ~q_m[7:0];
                    cnt <= cnt + {q_m[8], 1'b0} + n0_qm - n1_qm;
                end else begin
                    encoded[9] <= 1'b0;
                    encoded[8] <= q_m[8];
                    encoded[7:0] <= q_m[7:0];
                    cnt <= cnt - {~q_m[8], 1'b0} + n1_qm - n0_qm;
                end
            end
        end
    end
end

endmodule

//================================================================================
// TMDS Serializer using OSERDESE2
//================================================================================
module tmds_serializer (
    input  wire       clk_pixel,
    input  wire       clk_tmds,
    input  wire       rst_n,
    input  wire [9:0] data_in,
    output wire       data_out_p,
    output wire       data_out_n
);

wire serial_data;

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_RATE_TQ("SDR"),
    .DATA_WIDTH(10),
    .SERDES_MODE("MASTER"),
    .TBYTE_CTL("FALSE"),
    .TBYTE_SRC("FALSE"),
    .TRISTATE_WIDTH(1)
) oserdes_inst (
    .CLK(clk_tmds),
    .CLKDIV(clk_pixel),
    .D1(data_in[0]),
    .D2(data_in[1]),
    .D3(data_in[2]),
    .D4(data_in[3]),
    .D5(data_in[4]),
    .D6(data_in[5]),
    .D7(data_in[6]),
    .D8(data_in[7]),
    .OCE(1'b1),
    .RST(~rst_n),
    .OQ(serial_data),
    .T1(1'b0),
    .T2(1'b0),
    .T3(1'b0),
    .T4(1'b0),
    .TBYTEIN(1'b0),
    .TCE(1'b0)
);

OBUFDS #(
    .IOSTANDARD("TMDS_33")
) obuf_inst (
    .I(serial_data),
    .O(data_out_p),
    .OB(data_out_n)
);

endmodule