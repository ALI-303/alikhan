//================================================================================
// KC705 OV7670 Camera with HDMI Output - Top Level Module
// 
// This design captures video from OV7670 camera and outputs to HDMI display
// Supports 720p and 1080p HDMI output with image processing
// Compatible with external HDMI transmitter or direct HDMI implementation
//================================================================================

module kc705_ov7670_hdmi_top (
    // System Clock and Reset
    input  wire        clk_200mhz,     // 200MHz differential input clock
    input  wire        clk_200mhz_n,
    input  wire        cpu_reset_n,    // CPU reset button (active low)
    
    // OV7670 Camera Interface
    output wire        ov7670_xclk,    // Camera clock (24MHz)
    input  wire        ov7670_pclk,    // Pixel clock from camera
    input  wire        ov7670_href,    // Horizontal reference
    input  wire        ov7670_vsync,   // Vertical sync
    input  wire [7:0]  ov7670_data,    // Pixel data
    
    // OV7670 Control (SCCB - I2C compatible)
    inout  wire        ov7670_sda,     // I2C data
    inout  wire        ov7670_scl,     // I2C clock
    output wire        ov7670_pwdn,    // Power down (active high)
    output wire        ov7670_reset,   // Reset (active low)
    
    // HDMI Output Interface
    output wire [2:0]  hdmi_tx_p,      // TMDS data positive
    output wire [2:0]  hdmi_tx_n,      // TMDS data negative
    output wire        hdmi_clk_p,     // TMDS clock positive  
    output wire        hdmi_clk_n,     // TMDS clock negative
    
    // HDMI Control (I2C for external transmitter)
    inout  wire        hdmi_scl,       // HDMI I2C clock
    inout  wire        hdmi_sda,       // HDMI I2C data
    input  wire        hdmi_hpd,       // Hot plug detect
    
    // User Controls
    input  wire [3:0]  dip_switches,   // DIP switches for control
    input  wire [4:0]  push_buttons,   // Push buttons
    
    // Status LEDs
    output wire [7:0]  gpio_leds,      // GPIO LEDs
    
    // UART Debug Interface
    output wire        uart_tx,        // UART transmit
    input  wire        uart_rx,        // UART receive
    
    // DDR3 Memory Interface (for frame buffering)
    inout  wire [63:0] ddr3_dq,
    inout  wire [7:0]  ddr3_dqs_p,
    inout  wire [7:0]  ddr3_dqs_n,
    output wire [13:0] ddr3_addr,
    output wire [2:0]  ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0:0]  ddr3_ck_p,
    output wire [0:0]  ddr3_ck_n,
    output wire [0:0]  ddr3_cke,
    output wire [0:0]  ddr3_cs_n,
    output wire [7:0]  ddr3_dm,
    output wire [0:0]  ddr3_odt
);

//================================================================================
// Parameters
//================================================================================
parameter HDMI_MODE = "720p";          // "720p", "1080p60", "1080p30"
parameter USE_EXTERNAL_HDMI_IC = 1;    // 1 for ADV7511, 0 for direct HDMI
parameter ENABLE_ILA = 0;               // 1 to enable Integrated Logic Analyzer

//================================================================================
// Clock Generation
//================================================================================
wire clk_100mhz;        // System clock
wire clk_24mhz;         // Camera clock
wire clk_pixel;         // HDMI pixel clock
wire clk_tmds;          // HDMI TMDS clock (5x pixel)
wire clk_memory;        // Memory interface clock
wire pll_locked;

// Input clock buffer
IBUFGDS #(
    .DIFF_TERM("FALSE"),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("LVDS")
) clk_200mhz_buf (
    .O(clk_200mhz_single),
    .I(clk_200mhz),
    .IB(clk_200mhz_n)
);

// Main PLL for system clocks
clk_wiz_hdmi clk_gen_inst (
    .clk_in1(clk_200mhz_single),
    .reset(~cpu_reset_n),
    .locked(pll_locked),
    .clk_out1(clk_100mhz),      // 100MHz system clock
    .clk_out2(clk_24mhz),       // 24MHz camera clock
    .clk_out3(clk_pixel),       // HDMI pixel clock
    .clk_out4(clk_tmds),        // HDMI TMDS clock
    .clk_out5(clk_memory)       // Memory interface clock
);

// Clock frequency selection based on HDMI mode
generate
    if (HDMI_MODE == "720p" || HDMI_MODE == "1080p30") begin
        // 720p@60Hz or 1080p@30Hz: 74.25 MHz pixel, 371.25 MHz TMDS
        localparam PIXEL_FREQ = 74.25;
        localparam TMDS_FREQ = 371.25;
    end else begin
        // 1080p@60Hz: 148.5 MHz pixel, 742.5 MHz TMDS
        localparam PIXEL_FREQ = 148.5;
        localparam TMDS_FREQ = 742.5;
    end
endgenerate

//================================================================================
// Reset Generation
//================================================================================
reset_generator reset_gen (
    .clk_100mhz(clk_100mhz),
    .clk_24mhz(clk_24mhz),
    .clk_pixel(clk_pixel),
    .pll_locked(pll_locked),
    .cpu_reset_n(cpu_reset_n),
    .rst_100mhz_n(rst_100mhz_n),
    .rst_24mhz_n(rst_24mhz_n),
    .rst_pixel_n(rst_pixel_n)
);

//================================================================================
// OV7670 Camera Interface
//================================================================================
wire [15:0] camera_rgb565;
wire        camera_data_valid;
wire        camera_frame_valid;
wire [9:0]  camera_x;
wire [9:0]  camera_y;

// Camera clock output
assign ov7670_xclk = clk_24mhz;
assign ov7670_pwdn = 1'b0;  // Not in power down
assign ov7670_reset = rst_24mhz_n;

// OV7670 capture module with multi-resolution support
ov7670_capture #(
    .CAPTURE_MODE("VGA")  // VGA, QVGA, CIF, QCIF
) camera_capture (
    .clk_24mhz(clk_24mhz),
    .rst_n(rst_24mhz_n),
    
    // Camera interface
    .ov7670_pclk(ov7670_pclk),
    .ov7670_href(ov7670_href),
    .ov7670_vsync(ov7670_vsync),
    .ov7670_data(ov7670_data),
    
    // Camera control
    .ov7670_sda(ov7670_sda),
    .ov7670_scl(ov7670_scl),
    
    // Output data
    .rgb565_data(camera_rgb565),
    .data_valid(camera_data_valid),
    .frame_valid(camera_frame_valid),
    .pixel_x(camera_x),
    .pixel_y(camera_y),
    
    // Configuration
    .resolution_mode(dip_switches[1:0]),
    .test_pattern_enable(push_buttons[0])
);

//================================================================================
// Frame Buffer Controller
//================================================================================
wire [23:0] fb_read_data;
wire [18:0] fb_read_addr;
wire        fb_read_enable;

frame_buffer_controller #(
    .FRAME_WIDTH(640),
    .FRAME_HEIGHT(480),
    .MEMORY_DEPTH(307200)  // 640 * 480
) frame_buffer (
    // Write side (camera clock domain)
    .wr_clk(ov7670_pclk),
    .wr_rst_n(rst_24mhz_n),
    .wr_data({camera_rgb565[15:11], 3'b000,   // R
              camera_rgb565[10:5],  2'b00,    // G  
              camera_rgb565[4:0],   3'b000}), // B
    .wr_enable(camera_data_valid && camera_frame_valid),
    .wr_addr({camera_y[8:0], camera_x[9:0]}),
    
    // Read side (HDMI pixel clock domain)
    .rd_clk(clk_pixel),
    .rd_rst_n(rst_pixel_n),
    .rd_addr(fb_read_addr),
    .rd_data(fb_read_data),
    .rd_enable(fb_read_enable),
    
    // Memory interface (DDR3)
    .mem_clk(clk_memory),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    
    // Status
    .buffer_ready(fb_buffer_ready),
    .frame_complete(fb_frame_complete)
);

//================================================================================
// HDMI Display Controller
//================================================================================
wire [7:0] hdmi_debug_leds;

hdmi_display_controller #(
    .HDMI_MODE(HDMI_MODE),
    .USE_EXTERNAL_IC(USE_EXTERNAL_HDMI_IC)
) hdmi_display (
    // Clock and Reset
    .clk_pixel(clk_pixel),
    .clk_tmds(clk_tmds),
    .rst_n(rst_pixel_n),
    
    // Frame Buffer Interface
    .fb_clk(clk_pixel),
    .fb_addr(fb_read_addr),
    .fb_data(fb_read_data),
    
    // Control Interface
    .display_mode(dip_switches[3:2]),   // Display processing mode
    .display_enable(fb_buffer_ready),
    
    // HDMI Output
    .hdmi_tx_p(hdmi_tx_p),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_clk_p(hdmi_clk_p),
    .hdmi_clk_n(hdmi_clk_n),
    
    // I2C Control
    .hdmi_scl(hdmi_scl),
    .hdmi_sda(hdmi_sda),
    .hdmi_hpd(hdmi_hpd),
    
    // Debug
    .debug_leds(hdmi_debug_leds)
);

//================================================================================
// UART Debug Interface
//================================================================================
uart_debug_tx #(
    .CLK_FREQ(100000000),
    .BAUD_RATE(115200)
) uart_debug (
    .clk(clk_100mhz),
    .rst_n(rst_100mhz_n),
    .tx(uart_tx),
    
    // Status information
    .camera_active(camera_frame_valid),
    .buffer_ready(fb_buffer_ready),
    .hdmi_connected(hdmi_hpd),
    .frame_count(frame_counter[15:0]),
    .error_flags(8'h00)
);

//================================================================================
// Frame Counter and Status
//================================================================================
reg [23:0] frame_counter = 0;

always @(posedge clk_pixel) begin
    if (!rst_pixel_n) begin
        frame_counter <= 0;
    end else if (fb_frame_complete) begin
        frame_counter <= frame_counter + 1;
    end
end

//================================================================================
// Status LEDs
//================================================================================
assign gpio_leds[0] = pll_locked;
assign gpio_leds[1] = rst_100mhz_n;
assign gpio_leds[2] = camera_frame_valid;
assign gpio_leds[3] = fb_buffer_ready;
assign gpio_leds[4] = hdmi_hpd;
assign gpio_leds[5] = hdmi_debug_leds[0];  // video_active from HDMI controller
assign gpio_leds[6] = frame_counter[23];   // Slow blink for frame activity
assign gpio_leds[7] = |hdmi_debug_leds[3:1]; // HDMI sync status

//================================================================================
// Integrated Logic Analyzer (Optional)
//================================================================================
generate
if (ENABLE_ILA) begin : ila_debug
    ila_0 ila_inst (
        .clk(clk_pixel),
        .probe0(fb_read_data),      // [23:0]
        .probe1(fb_read_addr),      // [18:0]
        .probe2(hdmi_debug_leds),   // [7:0]
        .probe3({hdmi_hpd, fb_buffer_ready, camera_frame_valid, rst_pixel_n}), // [3:0]
        .probe4(frame_counter[15:0]) // [15:0]
    );
end
endgenerate

endmodule

//================================================================================
// Clock Wizard IP Configuration
// This would be generated by Vivado Clock Wizard IP
//================================================================================
// Configuration for different HDMI modes:
// 720p@60Hz:  clk_pixel = 74.25 MHz, clk_tmds = 371.25 MHz
// 1080p@30Hz: clk_pixel = 74.25 MHz, clk_tmds = 371.25 MHz  
// 1080p@60Hz: clk_pixel = 148.5 MHz, clk_tmds = 742.5 MHz