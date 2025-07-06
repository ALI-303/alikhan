`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: uart_debug_tx
// Description: Simple UART transmitter for debug information
//              Sends status information at 115200 baud
//////////////////////////////////////////////////////////////////////////////////

module uart_debug_tx (
    input wire clk,              // 100 MHz clock
    input wire reset,
    output reg tx,
    input wire config_finished,
    input wire [15:0] frame_count,
    input wire [7:0] error_flags
);

    // UART parameters for 115200 baud at 100 MHz
    localparam BAUD_RATE = 115200;
    localparam CLK_FREQ = 100000000;
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;  // 868

    // State machine
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3, DELAY = 4;
    reg [2:0] state;
    reg [15:0] baud_counter;
    reg [3:0] bit_counter;
    reg [7:0] tx_data;
    reg [7:0] send_buffer [0:15];  // Buffer for message
    reg [3:0] send_index;
    reg [3:0] send_length;
    reg [19:0] delay_counter;
    
    // Message formatting
    always @(posedge clk) begin
        if (reset) begin
            send_buffer[0] <= "S";  // Status
            send_buffer[1] <= "T";
            send_buffer[2] <= "A";
            send_buffer[3] <= "T";
            send_buffer[4] <= ":";
            send_buffer[5] <= " ";
            send_buffer[6] <= config_finished ? "R" : "N";  // Ready/Not ready
            send_buffer[7] <= " ";
            send_buffer[8] <= "F";  // Frame count (hex)
            send_buffer[9] <= ":";
            send_buffer[10] <= hex_to_ascii(frame_count[7:4]);
            send_buffer[11] <= hex_to_ascii(frame_count[3:0]);
            send_buffer[12] <= "\r";
            send_buffer[13] <= "\n";
            send_length <= 14;
        end
    end
    
    // UART transmitter state machine
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1'b1;
            baud_counter <= 0;
            bit_counter <= 0;
            send_index <= 0;
            delay_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (delay_counter == 0) begin
                        send_index <= 0;
                        state <= START;
                        delay_counter <= 20'd100000;  // 1ms delay between messages
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
                
                START: begin
                    if (baud_counter == 0) begin
                        tx <= 1'b0;  // Start bit
                        tx_data <= send_buffer[send_index];
                        baud_counter <= BAUD_DIV - 1;
                    end else if (baud_counter == 1) begin
                        state <= DATA;
                        bit_counter <= 0;
                        baud_counter <= BAUD_DIV - 1;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                DATA: begin
                    if (baud_counter == 0) begin
                        tx <= tx_data[bit_counter];
                        baud_counter <= BAUD_DIV - 1;
                        if (bit_counter == 7) begin
                            state <= STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                STOP: begin
                    if (baud_counter == 0) begin
                        tx <= 1'b1;  // Stop bit
                        baud_counter <= BAUD_DIV - 1;
                    end else if (baud_counter == 1) begin
                        if (send_index == send_length - 1) begin
                            state <= DELAY;
                            delay_counter <= 20'd50000000;  // 500ms between status updates
                        end else begin
                            send_index <= send_index + 1;
                            state <= START;
                        end
                        baud_counter <= 0;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                DELAY: begin
                    if (delay_counter == 0) begin
                        state <= IDLE;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end
            endcase
        end
    end
    
    // Hex to ASCII conversion function
    function [7:0] hex_to_ascii;
        input [3:0] hex_val;
        begin
            if (hex_val < 10)
                hex_to_ascii = "0" + hex_val;
            else
                hex_to_ascii = "A" + (hex_val - 10);
        end
    endfunction

endmodule