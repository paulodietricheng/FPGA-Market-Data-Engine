`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 10:22:15 PM
// Design Name: 
// Module Name: bram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bram #(
    parameter MSG_W = 128,
    parameter DEPTH = 8
)(
    input  logic clk,
    
    input  logic [MSG_W-1:0]         din,
    input  logic [$clog2(DEPTH)-1:0] wr_addr, rd_addr,
    input  logic                     wr_en,
    
    output logic [MSG_W-1:0]         dout
);

    // Instantiate memory
    (* ram_style = "block" *) logic [MSG_W-1:0] mem [0:DEPTH-1];
    
    // Write
    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= din;
    end
    
    // Read
    always_ff @(posedge clk) begin
        dout <= mem[rd_addr];
    end
    
endmodule
