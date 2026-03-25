`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 08:33:12 AM
// Design Name: 
// Module Name: AXI4_Stream_RX
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


module AXI4_Stream_RX #(parameter int BUS_W = 512)(
    input logic clk, rst_n, // Signals

    // Upstream
    input logic [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,

    // Downstream
    output logic [BUS_W-1:0] out_tdata,
    output logic out_tvalid,
    output logic out_tlast,
    input logic down_tready
);

    // AXI regs
    logic [BUS_W-1:0] reg_tdata;
    logic reg_tvalid, reg_tlast;

    // Ready when buffer is empty OR downstream is consuming
    assign up_tready = !reg_tvalid || down_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_tvalid <= 0;
        end else if (up_tready) begin
            reg_tvalid <= in_tvalid;
            if (in_tvalid) begin
                reg_tdata <= in_tdata;
                reg_tlast <= in_tlast;
            end
        end
    end

    assign out_tdata  = reg_tdata;
    assign out_tvalid = reg_tvalid;
    assign out_tlast  = reg_tlast;

endmodule
