`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 09:28:41 AM
// Design Name: 
// Module Name: Payload_Extractor_128
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

module Payload_Extractor_128 #(
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

    logic beat_first;
    logic [47:0] carry_data;  
    logic [47:0] new_carry;
    logic [MSG_W-1:0] out_messages_local [0:MAX_MSG-1];

    assign up_tready = !out_tvalid | down_tready;

    // Accept new input
    logic accept;
    assign accept = up_tready & in_tvalid;
    
    // Window registers
    logic [BUS_W-1:0] window_slice;
    logic [BUS_W-1:0] reg_slice;
    
    // Combinational window
    always_comb begin
        if (beat_first) begin
            window_slice = BUS_W'(in_tdata[PAYLOAD_BEGIN+127:PAYLOAD_BEGIN]); 
        end else begin
            window_slice = {in_tdata[463:0], carry_data}; // slide in previous carry
        end
        new_carry = in_tdata[511:464];
    end
    
    // Register updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beat_first <= 1'b1;
            carry_data <= 48'd0;
            out_tvalid <= 1'b0;
            out_msg_count <= 3'd0;
            reg_slice <= '0;
            for (int i = 0; i < MAX_MSG; i++) out_messages_local[i] <= '0;
        end else if (accept) begin
            beat_first <= in_tlast;
            carry_data <= new_carry;
            reg_slice <= window_slice;
    
            out_msg_count <= (beat_first) ? 3'd1 : 3'd4;
            out_tvalid <= 1'b1;
        end else begin
            out_tvalid <= 1'b0;
        end
    end

    // Output assignment
    genvar i;
    generate
        for (i = 0; i < MAX_MSG; i++) begin : GEN_OUT_MSG
            assign out_messages[i] = reg_slice[(i+1)*MSG_W-1:i*MSG_W];
        end
    endgenerate
endmodule
