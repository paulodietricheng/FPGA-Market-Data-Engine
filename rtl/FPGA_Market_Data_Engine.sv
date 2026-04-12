`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////

import Data_Structures_V2::*;

module FPGA_Market_Data_Engine #(
    parameter int BUS_W = 512,
    parameter int MSG_W = 128,
    parameter int MAX_MSG = 4,
    parameter int FIFO_DEPTH = 32,
    parameter int N = 8,
    parameter int ORDER_ID_W   = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int LANE_W = 3,
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W = 32,
    parameter int SIZE_W = 32,
    parameter int RAW_DATA_W = 98,
    parameter int AGE_TIMEOUT = 300,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160,
    parameter int UDP_W = 64
)(
    input logic clk, rst_n,

    // Upstream from MAC
    input logic [BUS_W-1:0]  in_tdata,
    input logic in_tvalid,
    input logic in_tlast,
    output logic in_tready,

    // Top-of-book outputs
    output quote_t best_bid,
    output quote_t best_ask,
    output logic [PRICE_W:0] out_spread,
    output logic [PRICE_W-1:0] out_mid,
    output logic out_cross,
    output logic out_lock
);

    // Ethernet Parser
    logic [BUS_W-1:0] eth_tdata;
    logic eth_tvalid, eth_tlast;
    logic eth_up_tready;   
    ethernet_t eth_hdr;

    Ethernet_Parser #(
        .BUS_W(BUS_W)
    ) U_ETH (
        .clk (clk),
        .rst_n (rst_n),
        .in_tdata (in_tdata),
        .in_tvalid (in_tvalid),
        .in_tlast (in_tlast),
        .up_tready (in_tready),
        .out_tdata (eth_tdata),
        .out_tvalid (eth_tvalid),
        .out_tlast (eth_tlast),
        .out_eth (eth_hdr),
        .down_tready (eth_up_tready)    
    );

    // IPv4 parser
    logic [BUS_W-1:0] ipv4_tdata;
    logic ipv4_tvalid, ipv4_tlast;
    logic ipv4_up_tready;   

    IPv4_Parser #(
        .BUS_W(BUS_W)
    ) U_IPV4 (
        .clk (clk),
        .rst_n (rst_n),
        .in_tdata (eth_tdata),
        .in_tvalid (eth_tvalid),
        .in_tlast (eth_tlast),
        .up_tready (eth_up_tready),  
        .out_tdata (ipv4_tdata),
        .out_tvalid (ipv4_tvalid),
        .out_tlast (ipv4_tlast),
        .out_ipv4 (/* ipv4_hdr unused in top - protocol gating omitted */),
        .down_tready (ipv4_up_tready)  
    );

    // UDP Parser
    logic [BUS_W-1:0] udp_tdata;
    logic udp_tvalid, udp_tlast;
    logic udp_up_tready; 

    UDP_Parser #(
        .BUS_W (BUS_W),
        .ETHERNET_W (ETHERNET_W),
        .IPv4_W (IPv4_W)
    ) U_UDP (
        .clk (clk),
        .rst_n (rst_n),
        .in_tdata (ipv4_tdata),
        .in_tvalid (ipv4_tvalid),
        .in_tlast (ipv4_tlast),
        .up_tready (ipv4_up_tready), 
        .out_tdata (udp_tdata),
        .out_tvalid (udp_tvalid),
        .out_tlast (udp_tlast),
        .out_udp (/* udp_hdr unused in top - port filtering omitted */),
        .down_tready (udp_up_tready)
    );

    // Payload Extractor
    logic [MSG_W-1:0] payload_messages  [0:MAX_MSG-1];
    logic [2:0] payload_msg_count;
    logic payload_tvalid;
    logic payload_up_tready;

    Payload_Extractor_128 #(
        .BUS_W (BUS_W),
        .ETHERNET_W (ETHERNET_W),
        .IPv4_W (IPv4_W),
        .UDP_W (UDP_W),
        .MSG_W (MSG_W),
        .MAX_MSG (MAX_MSG)
    ) U_PAYLOAD (
        .clk (clk),
        .rst_n (rst_n),
        .in_tdata (udp_tdata),
        .in_tvalid (udp_tvalid),
        .in_tlast (udp_tlast),
        .up_tready (udp_up_tready),   
        .out_messages (payload_messages),
        .out_msg_count (payload_msg_count),
        .out_tvalid (payload_tvalid),
        .down_tready (payload_up_tready) 
    );

    // FIFO Burst Handler
    logic [MSG_W-1:0] fifo_out_message;
    logic fifo_out_tvalid;

    FIFO_Burst #(
        .MSG_W (MSG_W),
        .MAX_MSG (MAX_MSG),
        .DEPTH (FIFO_DEPTH)
    ) U_FIFO (
        .clk (clk),
        .rst_n (rst_n),
        .in_messages (payload_messages),
        .msg_c (payload_msg_count),
        .in_tvalid (payload_tvalid),
        .up_tready (payload_up_tready),
        .out_message (fifo_out_message),
        .out_tvalid (fifo_out_tvalid),
        .down_tready (1'b1)            
    );
    
    // Feed Normalizer
    quote_t norm_quote;
    logic [ORDER_ID_W-1:0] norm_order_id;
    logic [ORDER_TYPE_W-1:0] norm_order_type;

    Feed_Normalizer #(
        .MSG_W (MSG_W),
        .ORDER_ID_W (ORDER_ID_W),
        .ORDER_TYPE_W (ORDER_TYPE_W),
        .LANE_W (LANE_W),
        .PRICE_W (PRICE_W),
        .TIMESTAMP_W (TIMESTAMP_W),
        .SIZE_W (SIZE_W)
    ) U_NORM (
        .in_data (fifo_out_message),
        .in_tvalid (fifo_out_tvalid),
        .up_tready (1'b1),
        .out_quote (norm_quote),
        .order_id (norm_order_id),
        .order_type (norm_order_type)
    );

    // Filter
    quote_t filt_quote;
    logic [ORDER_ID_W-1:0] filt_order_id;
    logic [ORDER_TYPE_W-1:0] filt_order_type;

    Filter_V2 #(
        .ORDER_ID_W (ORDER_ID_W),
        .ORDER_TYPE_W (ORDER_TYPE_W)
    ) U_FILTER (
        .clk (clk),
        .rst_n (rst_n),
        .in_order_id (norm_order_id),
        .in_order_type (norm_order_type),
        .in_quote (norm_quote),
        .out_order_id (filt_order_id),
        .out_order_type (filt_order_type),
        .out_quote (filt_quote)
    );

    // Lane Management Engine
    quote_t lme_out_quote [N-1:0];
    logic [N-1:0] lme_lane_reset;
    logic [$clog2(N)-1:0] lme_out_lane_id [N-1:0];
    logic [N-1:0] tob_lane_tvalid; 

    Lane_Management_Engine #(
        .N (N),
        .ORDER_ID_W  (ORDER_ID_W),
        .ORDER_TYPE_W (ORDER_TYPE_W),
        .AGE_TIMEOUT (AGE_TIMEOUT)
    ) U_LME (
        .clk (clk),
        .rst_n (rst_n),
        .in_quote (filt_quote),
        .order_id (filt_order_id),
        .order_type (filt_order_type),
        .out_quote (lme_out_quote),
        .lane_reset (lme_lane_reset),
        .out_lane_id (lme_out_lane_id),
        .lane_valid (tob_lane_tvalid)
    );

    // Stage 9: TOB Engine
    logic [RAW_DATA_W-1:0] tob_in_data [N-1:0];

    genvar g;
    generate
        for (g = 0; g < N; g++) begin : GEN_TOB_CAST
            assign tob_in_data[g] = lme_out_quote[g][RAW_DATA_W-1:0];
        end
    endgenerate

    Pure_TOB_Engine #(
        .N (N),
        .RAW_DATA_W (RAW_DATA_W),
        .PRICE_W (PRICE_W),
        .TIMESTAMP_W (TIMESTAMP_W),
        .SIZE_W (SIZE_W),
        .LANE_W (LANE_W),
        .ORDER_ID_W (ORDER_ID_W),
        .ORDER_TYPE_W (ORDER_TYPE_W)
    ) U_TOB (
        .clk (clk),
        .rst_n (rst_n),
        .in_data (tob_in_data),
        .in_lane_id (lme_out_lane_id),
        .lane_reset (lme_lane_reset),
        .best_bid (best_bid),
        .best_ask (best_ask),
        .out_spread (out_spread),
        .out_mid (out_mid),
        .out_cross (out_cross),
        .out_lock (out_lock),
        .out_lane_tvalid (tob_lane_tvalid) // → U_LME.lane_valid feedback
    );

endmodule