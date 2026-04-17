`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026
// Design Name: 
// Module Name: Top
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
module FPGA_Market_Data_Engine #(
    parameter int N = 8,
    parameter int BUS_W = 512,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W  = 32,
    parameter int SIZE_W = 32,
    parameter int AGE_TIMEOUT = 300
)(
    input  logic clk, rst_n,

    // AXI-S input stream (from network)
    input logic [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,

    // Top-of-Book outputs
    output quote_t best_bid,
    output quote_t best_ask,
    output logic signed [PRICE_W:0] out_spread,
    output logic [PRICE_W-1:0] out_mid,
    output logic out_cross,
    output logic out_lock
);

    // Feed Handler to Lane Management wires
    quote_t fh_quote;
    logic [ORDER_ID_W-1:0] fh_order_id;
    logic [ORDER_TYPE_W-1:0] fh_order_type;

    // Lane Management to Computer wires
    quote_t lme_quote [N-1:0];
    logic [$clog2(N)-1:0] lme_lane_idx [N-1:0];

    logic [$clog2(N)-1:0] comp_lane_idx [N-1:0];

    // Feed Handler
    Feed_Handler #(
        .BUS_W(BUS_W)
    ) U_FH (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_quote(fh_quote),
        .out_order_id(fh_order_id),
        .out_order_type(fh_order_type)
    );

    // Lane Management Engine
    Lane_Management_Engine_PIP #(
        .N(N),
        .ORDER_ID_W(ORDER_ID_W),
        .ORDER_TYPE_W(ORDER_TYPE_W),
        .AGE_TIMEOUT(AGE_TIMEOUT)
    ) U_LME (
        .clk(clk),
        .rst_n(rst_n),
        .in_quote(fh_quote),
        .in_order_id(fh_order_id),
        .in_order_type(fh_order_type),
        .out_quote(lme_quote),
        .out_lane_idx(lme_lane_idx)
    );

    // Computer
    Computer #(
        .N(N),
        .PRICE_W(PRICE_W),
        .TIMESTAMP_W(TIMESTAMP_W),
        .SIZE_W(SIZE_W)
    ) U_COMP (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(lme_quote),
        .lane_idx(comp_lane_idx),
        .best_bid(best_bid),
        .best_ask(best_ask),
        .out_spread(out_spread),
        .out_mid(out_mid),
        .out_cross(out_cross),
        .out_lock(out_lock)
    );

endmodule
