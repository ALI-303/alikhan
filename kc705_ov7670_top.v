`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: KC705 OV7670 Camera Integration
// Module Name: kc705_ov7670_top
// Project Name: 
// Target Devices: KC705 (Kintex-7 XC7K325T)
// Tool Versions: 
// Description: Top-level module for OV7670 camera integration with KC705
// 
//////////////////////////////////////////////////////////////////////////////////

module kc705_ov7670_top (
    // System Clock (200 MHz differential)
    input wire sysclk_p,
    input wire sysclk_n,
    
    // System Reset
    input wire cpu_reset,
    
    // OV7670 Camera Interface
    input wire [7:0] ov7670_data,
    input wire ov7670_pclk,
    input wire ov7670_href,
    input wire ov7670_vsync,
    output wire ov7670_xclk,
    output wire ov7670_sioc,
    inout wire ov7670_siod,
    output wire ov7670_reset,
    output wire ov7670_pwdn,
    
    // VGA Interface (using FMC connector for VGA breakout)
    output wire [7:0] vga_red,
    output wire [7:0] vga_green,
    output wire [7:0] vga_blue,
    output wire vga_hsync,
    output wire vga_vsync,
    output wire vga_clk,
    
    // Debug Interface
    output wire [7:0] gpio_led,
    input wire [3:0] gpio_dip_sw,
    input wire gpio_sw_n,
    input wire gpio_sw_s,
    input wire gpio_sw_w,
    input wire gpio_sw_e,
    input wire gpio_sw_c,
    
    // UART for debug (optional)
    output wire uart_tx,
    input wire uart_rx
);

    // Internal clock signals
    wire clk_200mhz;          // System clock
    wire clk_100mhz;          // General purpose
    wire clk_25mhz;           // VGA pixel clock
    wire clk_24mhz;           // Camera input clock
    wire clk_locked;
    
    // Reset signals
    wire reset_sync;
    wire reset_n;
    
    // Camera configuration signals
    wire config_finished;
    wire config_error;
    
    // Camera data capture signals
    wire capture_enable;
    wire [18:0] capture_addr;  // 19 bits for 640x480 = 307,200 pixels
    wire [15:0] capture_data;  // RGB565 format
    wire capture_we;
    wire frame_done;
    
    // Frame buffer signals
    wire [18:0] fb_read_addr;
    wire [15:0] fb_read_data;
    wire fb_read_enable;
    
    // VGA controller signals
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire vga_active;
    wire vga_frame_start;
    
    // Debug and control signals
    wire [1:0] display_mode;
    wire [1:0] capture_mode;
    wire test_pattern_enable;
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    
    // Convert differential clock to single-ended
    IBUFGDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("TRUE")
    ) ibufgds_sysclk (
        .O(clk_200mhz),
        .I(sysclk_p),
        .IB(sysclk_n)
    );
    
    // Clock Wizard for multiple clock domains
    clk_wiz_0 clock_generator (
        .clk_in1(clk_200mhz),
        .clk_out1(clk_100mhz),    // 100 MHz - System clock
        .clk_out2(clk_25mhz),     // 25 MHz - VGA pixel clock  
        .clk_out3(clk_24mhz),     // 24 MHz - Camera input clock
        .reset(cpu_reset),
        .locked(clk_locked)
    );
    
    //==========================================================================
    // Reset Generation
    //==========================================================================
    
    reset_generator reset_gen (
        .clk(clk_100mhz),
        .ext_reset(cpu_reset),
        .pll_locked(clk_locked),
        .reset_out(reset_sync)
    );
    
    assign reset_n = ~reset_sync;
    
    //==========================================================================
    // User Interface and Control
    //==========================================================================
    
    // Map switches to control signals
    assign display_mode = gpio_dip_sw[1:0];
    assign capture_mode = gpio_dip_sw[3:2];
    assign test_pattern_enable = gpio_sw_n;
    assign capture_enable = ~gpio_sw_s;  // Active low switch
    
    //==========================================================================
    // OV7670 Camera Controller
    //==========================================================================
    
    ov7670_controller camera_config (
        .clk(clk_100mhz),
        .reset(reset_sync),
        .sioc(ov7670_sioc),
        .siod(ov7670_siod),
        .config_finished(config_finished),
        .config_error(config_error),
        .capture_mode(capture_mode)  // Different resolution modes
    );
    
    //==========================================================================
    // Camera Data Capture
    //==========================================================================
    
    ov7670_capture camera_capture (
        .pclk(ov7670_pclk),
        .reset(reset_sync),
        .vsync(ov7670_vsync),
        .href(ov7670_href),
        .din(ov7670_data),
        .capture_enable(capture_enable & config_finished),
        .capture_mode(capture_mode),
        .addr(capture_addr),
        .dout(capture_data),
        .we(capture_we),
        .frame_done(frame_done)
    );
    
    //==========================================================================
    // Frame Buffer Controller  
    //==========================================================================
    
    frame_buffer_controller fb_controller (
        // Write side (camera clock domain)
        .wr_clk(ov7670_pclk),
        .wr_reset(reset_sync),
        .wr_addr(capture_addr),
        .wr_data(capture_data),
        .wr_enable(capture_we),
        .frame_done(frame_done),
        
        // Read side (VGA clock domain)
        .rd_clk(clk_25mhz),
        .rd_reset(reset_sync),
        .rd_addr(fb_read_addr),
        .rd_data(fb_read_data),
        .rd_enable(fb_read_enable),
        
        // Control
        .capture_mode(capture_mode),
        .display_mode(display_mode)
    );
    
    //==========================================================================
    // VGA Controller
    //==========================================================================
    
    vga_controller vga_ctrl (
        .clk(clk_25mhz),
        .reset(reset_sync),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .active(vga_active),
        .x(vga_x),
        .y(vga_y),
        .frame_start(vga_frame_start)
    );
    
    //==========================================================================
    // VGA Display Generator
    //==========================================================================
    
    vga_display_gen vga_display (
        .clk(clk_25mhz),
        .reset(reset_sync),
        .x(vga_x),
        .y(vga_y),
        .active(vga_active),
        .display_mode(display_mode),
        .test_pattern_enable(test_pattern_enable),
        
        // Frame buffer interface
        .fb_addr(fb_read_addr),
        .fb_data(fb_read_data),
        .fb_enable(fb_read_enable),
        
        // VGA output
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );
    
    assign vga_clk = clk_25mhz;
    
    //==========================================================================
    // Camera Control Outputs
    //==========================================================================
    
    assign ov7670_xclk = clk_24mhz;
    assign ov7670_reset = reset_n;      // Active low reset
    assign ov7670_pwdn = 1'b0;          // Never power down
    
    //==========================================================================
    // Debug and Status LEDs
    //==========================================================================
    
    assign gpio_led[0] = config_finished;
    assign gpio_led[1] = config_error;
    assign gpio_led[2] = capture_enable;
    assign gpio_led[3] = frame_done;
    assign gpio_led[4] = ov7670_vsync;
    assign gpio_led[5] = ov7670_href;
    assign gpio_led[6] = capture_we;
    assign gpio_led[7] = clk_locked;
    
    //==========================================================================
    // Optional UART Debug Interface  
    //==========================================================================
    
    // Simple UART transmitter for debug information
    uart_debug_tx uart_debug (
        .clk(clk_100mhz),
        .reset(reset_sync),
        .tx(uart_tx),
        .config_finished(config_finished),
        .frame_count(frame_count),
        .error_flags({config_error, 7'b0})
    );
    
    // Frame counter for debug
    reg [15:0] frame_count;
    always @(posedge ov7670_pclk) begin
        if (reset_sync) begin
            frame_count <= 0;
        end else if (frame_done) begin
            frame_count <= frame_count + 1;
        end
    end

endmodule