`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026
// Design Name: 
// Module Name: Payload_Subsystem
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

import Data_Structures::*;

module Payload_Subsystem #(
    parameter int BUS_W = 512,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160,
    parameter int UDP_W = 64,
    parameter int MSG_W = 128,
    parameter int MAX_MSG = 4,
    parameter int DEPTH = 32,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2
)(
    input logic clk, rst_n,     

    // Upstream
    input [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,
    
    // Downstream
    output quote_t out_quote,
    output logic [ORDER_ID_W-1:0] out_order_id,
    output logic [ORDER_TYPE_W-1:0] out_order_type
    );

    // Payload Extractor
    logic [MSG_W-1:0] out_messages_pe [0:MAX_MSG-1];
    logic [2:0] out_msg_count_pe;
    logic out_tvalid_pe;
    logic up_tready_fifo;
    
    Payload_Extractor #(
        .BUS_W(BUS_W),
        .ETHERNET_W(ETHERNET_W),
        .IPv4_W(IPv4_W),
        .UDP_W(UDP_W),
        .MSG_W(MSG_W),
        .MAX_MSG(MAX_MSG)
    ) U_PLE (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_messages(out_messages_pe),
        .out_msg_count(out_msg_count_pe),
        .out_tvalid(out_tvalid_pe),
        .down_tready(up_tready_fifo)
    );

    // FIFO
    logic [MSG_W-1:0] out_message_fifo;
    logic out_tvalid_fifo;
    logic up_tready_decoder;
    
    FIFO #(
        .MSG_W(MSG_W),
        .MAX_MSG(MAX_MSG),
        .DEPTH(DEPTH)
    ) U_FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .in_messages(out_messages_pe),
        .in_msg_count(out_msg_count_pe),
        .in_tvalid(out_tvalid_pe),
        .up_tready(up_tready_fifo),
        .out_message(out_message_fifo),
        .out_tvalid(out_tvalid_fifo),
        .down_tready(up_tready_decoder)
    );

    // Decoder
    logic [ORDER_ID_W-1:0] order_id_dec;
    logic [ORDER_TYPE_W-1:0] order_type_dec;
    quote_t out_quote_dec;
    
    Decoder #(
        .MSG_W(MSG_W),
        .ORDER_ID_W(ORDER_ID_W),
        .ORDER_TYPE_W(ORDER_TYPE_W)
    ) U_Decoder (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(out_message_fifo),
        .in_tvalid(out_tvalid_fifo),
        .up_tready(up_tready_decoder),
        .out_quote(out_quote),
        .order_id(out_order_id),
        .order_type(out_order_type)
    );

endmodule