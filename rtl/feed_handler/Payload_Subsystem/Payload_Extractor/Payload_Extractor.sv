`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:52:04 PM
// Design Name: 
// Module Name: Payload_Extractor
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

module Payload_Extractor #(
    parameter int BUS_W = 512,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160,
    parameter int UDP_W = 64,
    parameter int MSG_W = 128,
    parameter int MAX_MSG = 4
)(
    input logic clk, rst_n,
    input logic [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,
    output logic [MSG_W-1:0] out_messages [0:MAX_MSG-1],
    output logic [2:0] out_msg_count,
    output logic out_tvalid,
    input logic down_tready
);
    // Payload starts after headers
    localparam int PAYLOAD_BEGIN = ETHERNET_W + IPv4_W + UDP_W;
    localparam int CARRY_W = BUS_W - PAYLOAD_BEGIN - MSG_W;
 
    logic reg_valid;
 
    assign up_tready = !reg_valid || down_tready;
 
    logic accept;
    assign accept = up_tready & in_tvalid;
 
    // State
    logic beat_first;
    logic in_packet;
    logic in_packet_next;
    logic [CARRY_W-1:0] carry_data;
    
    assign in_packet_next = accept ? !in_tlast : in_packet;
    assign beat_first = accept && !in_packet;
 
    // Registered messages
    logic [MSG_W-1:0] reg_messages [0:MAX_MSG-1];
    logic [2:0] reg_msg_count;
 
    // Combinational window and carry
    logic [BUS_W-1:0] window_slice;
    logic [CARRY_W-1:0] new_carry;
 
    always_comb begin
        new_carry = in_tdata[BUS_W-1 : BUS_W-CARRY_W]; 
 
        if (beat_first) begin
            window_slice = {{(BUS_W-MSG_W){1'b0}}, in_tdata[PAYLOAD_BEGIN+MSG_W-1 : PAYLOAD_BEGIN]};
        end else begin
            window_slice = {in_tdata[BUS_W-CARRY_W-1:0], carry_data}; 
        end
    end
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            carry_data <= '0;
            reg_valid <= 1'b0;
            reg_msg_count <= 3'd0;
            in_packet <= 1'b0;
            for (int i = 0; i < MAX_MSG; i++) reg_messages[i] <= '0;
        end else if (accept) begin
            in_packet <= in_packet_next;
            carry_data <= in_tlast ? '0 : new_carry;
            reg_valid <= 1'b1;
            reg_msg_count <= beat_first ? 3'd1 : 3'd4;
            for (int i = 0; i < MAX_MSG; i++)
                reg_messages[i] <= window_slice[(i+1)*MSG_W-1 -: MSG_W];
        end else if (down_tready) begin
            reg_valid <= 1'b0;
        end
    end
 
    assign out_tvalid = reg_valid;
    assign out_msg_count = reg_msg_count;
    genvar i;
    generate
        for (i = 0; i < MAX_MSG; i++) begin : GEN_OUT_MSG
            assign out_messages[i] = reg_messages[i];
        end
    endgenerate
 
endmodule