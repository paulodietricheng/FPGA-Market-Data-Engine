`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 02:20:33 PM
// Design Name: 
// Module Name: BRAM
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


module bram_sdp #(
    parameter int MSG_W = 128,  
    parameter int DEPTH = 32,
    localparam ADDR_W = $clog2(DEPTH)
)(
    input logic clk, // Signals
 
    // Upstream 
    input logic wr_en,
    input logic [ADDR_W-1:0] wr_addr,
    input logic [MSG_W-1:0] wr_data,
 
    // Downstream
    input logic rd_en,
    input logic [ADDR_W-1:0] rd_addr,
    output logic [MSG_W-1:0] rd_data
);
    (* ram_style = "block" *)
    logic [MSG_W-1:0] mem [0:DEPTH-1];
 
    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
        if (rd_en)
            rd_data <= mem[rd_addr];
    end
 
endmodule
 
