`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 05:15:52 PM
// Design Name: 
// Module Name: Feed_Handler
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

module Feed_Handler #(parameter BUS_W = 512) (
    input logic clk, rst_n,

    // Input stream
    input logic [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,

    // Final outputs
    output quote_t out_quote,
    output logic [28:0] out_order_id,
    output logic [1:0]  out_order_type
);

    // Parser to Payload wires
    logic [BUS_W-1:0] parser_tdata;
    logic parser_tvalid, parser_tlast;
    logic parser_to_payload_ready;

    // Parser
    Parser_Subsystem #(.BUS_W(BUS_W)) U_Parser (
        .clk(clk),
        .rst_n(rst_n),

        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),

        .out_tdata(parser_tdata),
        .out_tvalid(parser_tvalid),
        .out_tlast(parser_tlast),

        .out_eth(),
        .out_ipv4(),
        .out_udp(),

        .down_tready(parser_to_payload_ready)
    );
    
    // Payload subsystem
    Payload_Subsystem U_Payload (
        .clk(clk),
        .rst_n(rst_n),

        .in_tdata(parser_tdata),
        .in_tvalid(parser_tvalid),
        .in_tlast(parser_tlast),
        .up_tready(parser_to_payload_ready),

        .out_quote(out_quote),
        .out_order_id(out_order_id),
        .out_order_type(out_order_type)
    );

endmodule
