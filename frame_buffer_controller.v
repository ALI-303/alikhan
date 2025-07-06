`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: frame_buffer_controller
// Description: Frame buffer controller for OV7670 camera with dual-port memory
//              Manages full VGA resolution (640x480) frame storage
//              Handles clock domain crossing between camera and VGA clocks
//////////////////////////////////////////////////////////////////////////////////

module frame_buffer_controller (
    // Write side (camera clock domain)
    input wire wr_clk,
    input wire wr_reset,
    input wire [18:0] wr_addr,        // 19 bits for 640x480 = 307,200 pixels
    input wire [15:0] wr_data,        // RGB565 format
    input wire wr_enable,
    input wire frame_done,
    
    // Read side (VGA clock domain)
    input wire rd_clk,
    input wire rd_reset,
    output reg [18:0] rd_addr,
    output wire [15:0] rd_data,
    input wire rd_enable,
    
    // Control
    input wire [1:0] capture_mode,    // 00=VGA, 01=QVGA, 10=CIF, 11=QCIF
    input wire [1:0] display_mode     // 00=Normal, 01=Zoom, 10=Test, 11=Freeze
);

    // Frame buffer parameters
    localparam FRAME_BUFFER_DEPTH = 19'h4B000;  // 307,200 pixels (640x480)
    
    // Dual frame buffers for ping-pong operation
    wire [15:0] buffer0_rd_data, buffer1_rd_data;
    wire buffer0_wr_en, buffer1_wr_en;
    
    // Frame buffer selection
    reg active_buffer;          // 0 = buffer0 active for write, 1 = buffer1 active
    reg display_buffer;         // Buffer being displayed
    reg frame_complete;
    
    // Address generation for different modes
    wire [18:0] scaled_addr;
    
    // Synchronizers for clock domain crossing
    reg frame_done_sync1, frame_done_sync2, frame_done_rd_clk;
    reg frame_complete_sync1, frame_complete_sync2, frame_complete_wr_clk;
    
    //==========================================================================
    // Clock Domain Crossing for Frame Control
    //==========================================================================
    
    // Sync frame_done from write clock to read clock
    always @(posedge rd_clk) begin
        if (rd_reset) begin
            frame_done_sync1 <= 0;
            frame_done_sync2 <= 0;
            frame_done_rd_clk <= 0;
        end else begin
            frame_done_sync1 <= frame_done;
            frame_done_sync2 <= frame_done_sync1;
            frame_done_rd_clk <= frame_done_sync2;
        end
    end
    
    // Sync frame_complete from read clock to write clock
    always @(posedge wr_clk) begin
        if (wr_reset) begin
            frame_complete_sync1 <= 0;
            frame_complete_sync2 <= 0;
            frame_complete_wr_clk <= 0;
        end else begin
            frame_complete_sync1 <= frame_complete;
            frame_complete_sync2 <= frame_complete_sync1;
            frame_complete_wr_clk <= frame_complete_sync2;
        end
    end
    
    //==========================================================================
    // Frame Buffer Management (Write Side)
    //==========================================================================
    
    // Buffer selection logic - ping pong between buffers
    always @(posedge wr_clk) begin
        if (wr_reset) begin
            active_buffer <= 0;
        end else if (frame_done && !frame_complete_wr_clk) begin
            active_buffer <= ~active_buffer;  // Switch active buffer
        end
    end
    
    // Write enable generation for each buffer
    assign buffer0_wr_en = wr_enable && !active_buffer;
    assign buffer1_wr_en = wr_enable && active_buffer;
    
    //==========================================================================
    // Display Buffer Management (Read Side)
    //==========================================================================
    
    // Switch display buffer when new frame is ready
    always @(posedge rd_clk) begin
        if (rd_reset) begin
            display_buffer <= 1;  // Start with buffer1 for display
            frame_complete <= 0;
        end else begin
            if (frame_done_rd_clk && !frame_complete) begin
                display_buffer <= active_buffer;  // Switch to newly written buffer
                frame_complete <= 1;
            end else if (!frame_done_rd_clk) begin
                frame_complete <= 0;
            end
        end
    end
    
    //==========================================================================
    // Address Scaling for Different Display Modes
    //==========================================================================
    
    address_scaler addr_scaler (
        .clk(rd_clk),
        .reset(rd_reset),
        .rd_addr_in(rd_addr),
        .capture_mode(capture_mode),
        .display_mode(display_mode),
        .scaled_addr(scaled_addr)
    );
    
    //==========================================================================
    // Dual Port Block RAM Instances
    //==========================================================================
    
    // Frame Buffer 0
    frame_buffer_bram buffer0 (
        // Write Port (Camera Clock Domain)
        .clka(wr_clk),
        .ena(1'b1),
        .wea(buffer0_wr_en),
        .addra(wr_addr),
        .dina(wr_data),
        
        // Read Port (VGA Clock Domain)
        .clkb(rd_clk),
        .enb(rd_enable),
        .web(1'b0),
        .addrb(scaled_addr),
        .dinb(16'h0),
        .doutb(buffer0_rd_data)
    );
    
    // Frame Buffer 1
    frame_buffer_bram buffer1 (
        // Write Port (Camera Clock Domain)
        .clka(wr_clk),
        .ena(1'b1),
        .wea(buffer1_wr_en),
        .addra(wr_addr),
        .dina(wr_data),
        
        // Read Port (VGA Clock Domain)
        .clkb(rd_clk),
        .enb(rd_enable),
        .web(1'b0),
        .addrb(scaled_addr),
        .dinb(16'h0),
        .doutb(buffer1_rd_data)
    );
    
    //==========================================================================
    // Output Multiplexing
    //==========================================================================
    
    assign rd_data = display_buffer ? buffer1_rd_data : buffer0_rd_data;

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Address Scaler Module
// Handles address translation for different capture and display modes
//////////////////////////////////////////////////////////////////////////////////

module address_scaler (
    input wire clk,
    input wire reset,
    input wire [18:0] rd_addr_in,
    input wire [1:0] capture_mode,
    input wire [1:0] display_mode,
    output reg [18:0] scaled_addr
);

    // Extract X and Y coordinates from linear address
    wire [9:0] x_coord = rd_addr_in % 640;
    wire [8:0] y_coord = rd_addr_in / 640;
    
    // Scaled coordinates
    reg [9:0] scaled_x;
    reg [8:0] scaled_y;
    
    always @(posedge clk) begin
        if (reset) begin
            scaled_addr <= 0;
        end else begin
            case (display_mode)
                2'b00: begin  // Normal display
                    case (capture_mode)
                        2'b00: begin  // VGA (640x480)
                            scaled_x <= x_coord;
                            scaled_y <= y_coord;
                        end
                        2'b01: begin  // QVGA (320x240) - upsample
                            scaled_x <= x_coord >> 1;
                            scaled_y <= y_coord >> 1;
                        end
                        2'b10: begin  // CIF (352x288)
                            scaled_x <= (x_coord * 352) / 640;
                            scaled_y <= (y_coord * 288) / 480;
                        end
                        2'b11: begin  // QCIF (176x144)
                            scaled_x <= (x_coord * 176) / 640;
                            scaled_y <= (y_coord * 144) / 480;
                        end
                    endcase
                end
                
                2'b01: begin  // Digital zoom (2x)
                    scaled_x <= (x_coord >> 1) + 160;  // Center crop
                    scaled_y <= (y_coord >> 1) + 120;
                end
                
                2'b10: begin  // Test pattern - use original address
                    scaled_x <= x_coord;
                    scaled_y <= y_coord;
                end
                
                2'b11: begin  // Freeze - maintain last address
                    // Keep previous values
                end
            endcase
            
            // Convert back to linear address
            if (display_mode != 2'b11) begin
                scaled_addr <= scaled_y * 640 + scaled_x;
            end
        end
    end

endmodule