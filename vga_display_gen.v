`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: vga_display_gen
// Description: VGA Display Generator for KC705 OV7670 camera project
//              Converts RGB565 to 8-bit RGB for VGA output
//              Supports test patterns and different display modes
//////////////////////////////////////////////////////////////////////////////////

module vga_display_gen (
    input wire clk,                    // 25 MHz VGA pixel clock
    input wire reset,
    input wire [9:0] x,                // Current pixel X coordinate
    input wire [9:0] y,                // Current pixel Y coordinate
    input wire active,                 // VGA active area
    input wire [1:0] display_mode,     // Display mode selection
    input wire test_pattern_enable,    // Test pattern override
    
    // Frame buffer interface
    output reg [18:0] fb_addr,         // Frame buffer address
    input wire [15:0] fb_data,         // RGB565 data from frame buffer
    output reg fb_enable,              // Frame buffer read enable
    
    // VGA RGB output (8-bit per channel)
    output reg [7:0] vga_red,
    output reg [7:0] vga_green,
    output reg [7:0] vga_blue
);

    // RGB565 to RGB888 conversion
    wire [7:0] rgb565_red   = {fb_data[15:11], fb_data[15:13]};  // 5->8 bit
    wire [7:0] rgb565_green = {fb_data[10:5], fb_data[10:9]};    // 6->8 bit
    wire [7:0] rgb565_blue  = {fb_data[4:0], fb_data[4:2]};     // 5->8 bit
    
    // Test pattern generation
    wire [7:0] test_red, test_green, test_blue;
    
    // Pipeline registers for timing
    reg [9:0] x_reg, y_reg;
    reg active_reg;
    reg [1:0] display_mode_reg;
    reg test_pattern_reg;
    
    //==========================================================================
    // Address Generation Pipeline
    //==========================================================================
    
    always @(posedge clk) begin
        if (reset) begin
            fb_addr <= 0;
            fb_enable <= 0;
            x_reg <= 0;
            y_reg <= 0;
            active_reg <= 0;
            display_mode_reg <= 0;
            test_pattern_reg <= 0;
        end else begin
            // Pipeline stage 1: Address calculation
            if (active && x < 640 && y < 480) begin
                fb_addr <= y * 640 + x;
                fb_enable <= 1;
            end else begin
                fb_enable <= 0;
            end
            
            // Pipeline stage 2: Register inputs for timing
            x_reg <= x;
            y_reg <= y;
            active_reg <= active;
            display_mode_reg <= display_mode;
            test_pattern_reg <= test_pattern_enable;
        end
    end
    
    //==========================================================================
    // Test Pattern Generator
    //==========================================================================
    
    test_pattern_gen pattern_gen (
        .clk(clk),
        .reset(reset),
        .x(x_reg),
        .y(y_reg),
        .red(test_red),
        .green(test_green),
        .blue(test_blue)
    );
    
    //==========================================================================
    // Output Multiplexer and Color Processing
    //==========================================================================
    
    always @(posedge clk) begin
        if (reset) begin
            vga_red <= 0;
            vga_green <= 0;
            vga_blue <= 0;
        end else begin
            if (active_reg && x_reg < 640 && y_reg < 480) begin
                if (test_pattern_reg) begin
                    // Test pattern mode
                    vga_red <= test_red;
                    vga_green <= test_green;
                    vga_blue <= test_blue;
                end else begin
                    case (display_mode_reg)
                        2'b00: begin  // Normal color display
                            vga_red <= rgb565_red;
                            vga_green <= rgb565_green;
                            vga_blue <= rgb565_blue;
                        end
                        2'b01: begin  // Monochrome mode (luminance)
                            // Y = 0.299*R + 0.587*G + 0.114*B
                            vga_red <= (rgb565_red >> 2) + (rgb565_green >> 1) + (rgb565_blue >> 3);
                            vga_green <= (rgb565_red >> 2) + (rgb565_green >> 1) + (rgb565_blue >> 3);
                            vga_blue <= (rgb565_red >> 2) + (rgb565_green >> 1) + (rgb565_blue >> 3);
                        end
                        2'b10: begin  // Edge detection mode
                            vga_red <= edge_detect_output(rgb565_red, rgb565_green, rgb565_blue);
                            vga_green <= edge_detect_output(rgb565_red, rgb565_green, rgb565_blue);
                            vga_blue <= edge_detect_output(rgb565_red, rgb565_green, rgb565_blue);
                        end
                        2'b11: begin  // False color mode
                            vga_red <= rgb565_blue;   // Swap channels
                            vga_green <= rgb565_red;
                            vga_blue <= rgb565_green;
                        end
                    endcase
                end
            end else begin
                // Outside active area - output black
                vga_red <= 0;
                vga_green <= 0;
                vga_blue <= 0;
            end
        end
    end
    
    //==========================================================================
    // Simple Edge Detection Function
    //==========================================================================
    
    function [7:0] edge_detect_output;
        input [7:0] red, green, blue;
        reg [7:0] luminance;
        begin
            luminance = (red >> 2) + (green >> 1) + (blue >> 3);
            // Simple threshold for edge detection
            edge_detect_output = (luminance > 8'h80) ? 8'hFF : 8'h00;
        end
    endfunction

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Test Pattern Generator Module
//////////////////////////////////////////////////////////////////////////////////

module test_pattern_gen (
    input wire clk,
    input wire reset,
    input wire [9:0] x,
    input wire [9:0] y,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

    always @(posedge clk) begin
        if (reset) begin
            red <= 0;
            green <= 0;
            blue <= 0;
        end else begin
            // Color bars test pattern
            if (y < 160) begin
                // Top third - Red gradient
                red <= x[7:0];
                green <= 0;
                blue <= 0;
            end else if (y < 320) begin
                // Middle third - Green gradient
                red <= 0;
                green <= x[7:0];
                blue <= 0;
            end else begin
                // Bottom third - Blue gradient
                red <= 0;
                green <= 0;
                blue <= x[7:0];
            end
            
            // Add some pattern elements
            if ((x % 80) < 4 || (y % 60) < 4) begin
                red <= 8'hFF;
                green <= 8'hFF;
                blue <= 8'hFF;
            end
            
            // Add crosshair in center
            if ((x >= 318 && x <= 322) || (y >= 238 && y <= 242)) begin
                red <= 8'hFF;
                green <= 8'h00;
                blue <= 8'h00;
            end
        end
    end

endmodule