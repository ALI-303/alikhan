`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: reset_generator
// Description: Reset generator for KC705 OV7670 project
//              Provides synchronized reset signals
//////////////////////////////////////////////////////////////////////////////////

module reset_generator (
    input wire clk,
    input wire ext_reset,
    input wire pll_locked,
    output reg reset_out
);

    reg [3:0] reset_counter;
    
    always @(posedge clk or posedge ext_reset) begin
        if (ext_reset || !pll_locked) begin
            reset_counter <= 4'hF;
            reset_out <= 1'b1;
        end else begin
            if (reset_counter != 4'h0) begin
                reset_counter <= reset_counter - 1;
                reset_out <= 1'b1;
            end else begin
                reset_out <= 1'b0;
            end
        end
    end

endmodule