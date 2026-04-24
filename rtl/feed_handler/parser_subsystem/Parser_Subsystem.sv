`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 07:50:04 AM
// Design Name: 
// Module Name: Parser_Subsystem
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

module Parser_Subsystem #(parameter int BUS_W = 512 )(
    input logic clk, rst_n,     
    // Upstream
    input [BUS_W-1:0] in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic up_tready,
    
    // Downstream
    output logic [BUS_W-1:0] out_tdata,
    output logic out_tvalid,
    output logic out_tlast,
    output ethernet_t out_eth,
    output ipv4_t out_ipv4,
    output udp_t out_udp,
    input logic down_tready
    );

    // Etherner Parser
    logic [BUS_W-1:0] out_tdata_eth;
    logic out_tvalid_eth, out_tlast_eth;
    logic up_tready_ipv4;
    
    ETH_Pars #(.BUS_W(BUS_W)) U_ETH (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_tdata(out_tdata_eth),
        .out_tvalid(out_tvalid_eth),
        .out_tlast(out_tlast_eth),
        .out_eth(out_eth),
        .down_tready(up_tready_ipv4)
    );

    // IPv4 Parser
    logic [BUS_W-1:0] out_tdata_ipv4;
    logic out_tvalid_ipv4, out_tlast_ipv4;
    logic up_tready_udp;
    
    IPv4_Pars #(.BUS_W(BUS_W)) U_IPv4 (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(out_tdata_eth),
        .in_tvalid(out_tvalid_eth),
        .in_tlast(out_tlast_eth),
        .up_tready(up_tready_ipv4),
        .out_tdata(out_tdata_ipv4),
        .out_tvalid(out_tvalid_ipv4),
        .out_tlast(out_tlast_ipv4),
        .out_ipv4(out_ipv4),
        .down_tready(up_tready_udp)
    );

    // UDP Parser
    
    UDP_Pars #(.BUS_W(BUS_W)) U_UDP (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(out_tdata_ipv4),
        .in_tvalid(out_tvalid_ipv4),
        .in_tlast(out_tlast_ipv4),
        .up_tready(up_tready_udp),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_udp(out_udp),
        .down_tready(down_tready)
    );

endmodule

