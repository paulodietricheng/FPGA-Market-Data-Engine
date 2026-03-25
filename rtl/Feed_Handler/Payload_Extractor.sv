`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 02:56:57 PM
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
`timescale 1ns / 1ps
module Payload_Extractor #(
    parameter int BUS_W = 512,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160,
    parameter int UDP_W = 64,
    parameter int MSG_W = 96,
    parameter int MAX_MSG = 6
)(
    input  logic clk, rst_n,
    input  logic [BUS_W-1:0] in_tdata,
    input  logic in_tvalid,
    input  logic in_tlast,
    output logic up_tready,
    output logic [MSG_W-1:0] out_messages [0:MAX_MSG-1],
    output logic [2:0] out_msg_count,
    output logic out_tvalid,
    output logic out_tlast,
    input  logic down_tready
);
    localparam int PAYLOAD_BEGIN = ETHERNET_W + IPv4_W + UDP_W;
    localparam int CARRY_W = MSG_W - 1;
    localparam int SLICE_W = CARRY_W + BUS_W;
    localparam int TOT_W = 10;

    logic accept;
    assign up_tready = !out_tvalid || down_tready;
    assign accept = up_tready && in_tvalid;

    logic beat_first;
    logic [CARRY_W-1:0] carry_data;
    logic [6:0] carry_bits;
    logic [SLICE_W-1:0] reg_slice_window;

    logic [SLICE_W-1:0] slice_window;
    logic [TOT_W-1:0] total_bits;

    always_comb begin
        if (beat_first) begin
            slice_window = SLICE_W'(in_tdata[BUS_W-1:PAYLOAD_BEGIN]);
            total_bits = TOT_W'(BUS_W - PAYLOAD_BEGIN);
        end else begin
            slice_window = (SLICE_W'(in_tdata) << carry_bits) | SLICE_W'(carry_data);
            total_bits = TOT_W'(carry_bits) + TOT_W'(BUS_W);
        end
    end

    logic [2:0] msg_count_comb;
    always_comb begin
        msg_count_comb = 3'd0;
        if (total_bits >= 10'd96)  msg_count_comb = 3'd1;
        if (total_bits >= 10'd192) msg_count_comb = 3'd2;
        if (total_bits >= 10'd288) msg_count_comb = 3'd3;
        if (total_bits >= 10'd384) msg_count_comb = 3'd4;
        if (total_bits >= 10'd480) msg_count_comb = 3'd5;
        if (total_bits >= 10'd576) msg_count_comb = 3'd6;
    end

    logic [TOT_W-1:0] new_carry_bits_comb;
    logic [CARRY_W-1:0] new_carry_data_comb;
    always_comb begin
        new_carry_bits_comb = total_bits - msg_count_comb * MSG_W;
        new_carry_data_comb = in_tlast ? '0 : CARRY_W'(slice_window >> (msg_count_comb * MSG_W));
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beat_first <= 1'b1;
            carry_data <= '0;
            carry_bits <= 7'd0;
            reg_slice_window <= '0;
            out_tvalid <= 1'b0;
            out_tlast <= 1'b0;
            out_msg_count <= 3'd0;
        end else begin
            if (accept) begin
                beat_first <= in_tlast;
                carry_data <= new_carry_data_comb;
                carry_bits <= in_tlast ? '0 : 7'(new_carry_bits_comb);
                reg_slice_window <= slice_window;
                out_tvalid <= (msg_count_comb > 0);
                out_tlast <= in_tlast;
                out_msg_count <= msg_count_comb;
            end else if (down_tready && out_tvalid) begin
                out_tvalid <= 1'b0;
                out_tlast <= 1'b0;
                out_msg_count <= 3'd0;
            end
        end
    end

    generate
        genvar i;
        for (i = 0; i < MAX_MSG; i++) begin : GEN_OUT_MSG
            assign out_messages[i] = reg_slice_window[(i+1)*MSG_W-1 -: MSG_W];
        end
    endgenerate
endmodule