`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: ov7670_capture
// Description: OV7670 camera data capture module for KC705
//              Supports multiple resolution modes and formats
//////////////////////////////////////////////////////////////////////////////////

module ov7670_capture (
    input wire pclk,                    // Camera pixel clock
    input wire reset,
    input wire vsync,                   // Vertical sync
    input wire href,                    // Horizontal reference
    input wire [7:0] din,               // Camera data input
    input wire capture_enable,          // Enable capture
    input wire [1:0] capture_mode,      // Capture mode (VGA, QVGA, etc.)
    
    output reg [18:0] addr,             // Output address
    output reg [15:0] dout,             // Output data (RGB565)
    output reg we,                      // Write enable
    output reg frame_done               // Frame complete signal
);

    // Capture parameters for different modes
    localparam MODE_VGA  = 2'b00;       // 640x480
    localparam MODE_QVGA = 2'b01;       // 320x240  
    localparam MODE_CIF  = 2'b10;       // 352x288
    localparam MODE_QCIF = 2'b11;       // 176x144

    // State machine
    localparam IDLE = 0, WAIT_FRAME = 1, CAPTURE = 2, FRAME_END = 3;
    reg [1:0] state;
    
    // Pixel data assembly
    reg [7:0] pixel_data_high;
    reg pixel_phase;                    // 0 = high byte, 1 = low byte
    
    // Frame and line counters
    reg [9:0] x_count;
    reg [9:0] y_count;
    reg [9:0] line_length;
    reg [9:0] frame_height;
    
    // Synchronization
    reg vsync_prev, href_prev;
    reg frame_active;
    
    // Skip patterns for different resolutions
    reg x_skip, y_skip;
    reg [1:0] skip_counter_x, skip_counter_y;
    
    //==========================================================================
    // Resolution Configuration
    //==========================================================================
    
    always @(*) begin
        case (capture_mode)
            MODE_VGA: begin
                line_length = 640;
                frame_height = 480;
            end
            MODE_QVGA: begin
                line_length = 320;
                frame_height = 240;
            end
            MODE_CIF: begin
                line_length = 352;
                frame_height = 288;
            end
            MODE_QCIF: begin
                line_length = 176;
                frame_height = 144;
            end
        endcase
    end
    
    //==========================================================================
    // Main Capture State Machine
    //==========================================================================
    
    always @(posedge pclk) begin
        if (reset) begin
            state <= IDLE;
            frame_done <= 0;
            we <= 0;
            addr <= 0;
            x_count <= 0;
            y_count <= 0;
            pixel_phase <= 0;
            frame_active <= 0;
            vsync_prev <= 0;
            href_prev <= 0;
            skip_counter_x <= 0;
            skip_counter_y <= 0;
        end else begin
            vsync_prev <= vsync;
            href_prev <= href;
            
            case (state)
                IDLE: begin
                    frame_done <= 0;
                    we <= 0;
                    if (capture_enable && vsync && !vsync_prev) begin
                        // Start of new frame
                        state <= WAIT_FRAME;
                        addr <= 0;
                        x_count <= 0;
                        y_count <= 0;
                        pixel_phase <= 0;
                        skip_counter_x <= 0;
                        skip_counter_y <= 0;
                        frame_active <= 1;
                    end
                end
                
                WAIT_FRAME: begin
                    if (href && !href_prev && frame_active) begin
                        // Start of line
                        state <= CAPTURE;
                        x_count <= 0;
                        pixel_phase <= 0;
                        skip_counter_x <= 0;
                    end else if (!vsync && vsync_prev) begin
                        // End of frame
                        state <= FRAME_END;
                        frame_active <= 0;
                    end
                end
                
                CAPTURE: begin
                    if (href) begin
                        // Pixel data capture
                        if (should_capture_pixel()) begin
                            if (pixel_phase == 0) begin
                                // First byte (high)
                                pixel_data_high <= din;
                                pixel_phase <= 1;
                                we <= 0;
                            end else begin
                                // Second byte (low) - complete RGB565 pixel
                                dout <= {pixel_data_high, din};
                                we <= 1;
                                addr <= addr + 1;
                                pixel_phase <= 0;
                                x_count <= x_count + 1;
                            end
                        end else begin
                            // Skip this pixel
                            pixel_phase <= ~pixel_phase;
                            we <= 0;
                        end
                        
                        update_skip_counters();
                        
                    end else if (href_prev && !href) begin
                        // End of line
                        y_count <= y_count + 1;
                        skip_counter_y <= skip_counter_y + 1;
                        
                        if (y_count >= frame_height - 1) begin
                            state <= FRAME_END;
                            frame_active <= 0;
                        end else begin
                            state <= WAIT_FRAME;
                        end
                        we <= 0;
                    end else begin
                        we <= 0;
                    end
                end
                
                FRAME_END: begin
                    frame_done <= 1;
                    we <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
    
    //==========================================================================
    // Pixel Capture Decision Logic
    //==========================================================================
    
    function should_capture_pixel;
        begin
            case (capture_mode)
                MODE_VGA: begin
                    // Capture all pixels
                    should_capture_pixel = 1;
                end
                MODE_QVGA: begin
                    // Skip every other pixel and line
                    should_capture_pixel = (skip_counter_x[0] == 0) && (skip_counter_y[0] == 0);
                end
                MODE_CIF: begin
                    // Capture 352 out of 640 pixels per line
                    should_capture_pixel = (x_count < 352) && (y_count < 288);
                end
                MODE_QCIF: begin
                    // Skip patterns for QCIF
                    should_capture_pixel = (skip_counter_x[1:0] == 0) && (skip_counter_y[1:0] == 0);
                end
            endcase
        end
    endfunction
    
    //==========================================================================
    // Skip Counter Management
    //==========================================================================
    
    task update_skip_counters;
        begin
            skip_counter_x <= skip_counter_x + 1;
            
            // Reset x counter at end of capture line
            if (x_count >= line_length - 1) begin
                skip_counter_x <= 0;
            end
        end
    endtask

endmodule