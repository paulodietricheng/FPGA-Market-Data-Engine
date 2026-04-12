`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2026 12:30:17 PM
// Design Name: 
// Module Name: Pure_TOB_Engine
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

import Data_Structures_V2::*;

module Pure_TOB_Engine #(
    parameter int N = 8,
    parameter int RAW_DATA_W = 98,
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W = 32,
    parameter int SIZE_W = 32,
    parameter int LANE_W = 3,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int BID = 1,
    parameter int ASK = 0
    )(
        input logic clk, rst_n, // Signals
        
        // Upstream
        input logic [RAW_DATA_W-1:0] in_data [N-1:0],
        input logic [LANE_W-1:0] in_lane_id [N-1:0],
        input logic [N-1:0] lane_reset,
        
        // Outputs
        output quote_t best_bid,
        output quote_t best_ask,
        output [PRICE_W:0] out_spread,
        output [PRICE_W-1:0] out_mid,
        output logic out_cross,     
        output logic out_lock,
        output logic [N-1:0] out_lane_tvalid
    );
    
    // Canonicalization
    logic [LANE_W-1:0] out_lane_id [N-1:0];
    quote_t ask_quote_c [N-1:0];
    quote_t bid_quote_c [N-1:0];  
    
    // Scoring  
    score_t ask_score [N-1:0];
    score_t bid_score [N-1:0];
    
    // Bid Arbiter
    quote_t bid_winner_quote;

    // Ask Arbiter
    quote_t ask_winner_quote;
    
    // Signal generator
    quote_t TOB_ASK, TOB_BID;
    logic [PRICE_W:0] _spread;
    logic [PRICE_W-1:0] _mid;
    logic _cross;    
    logic _lock;
    
    // Generate Lanes
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : GEN_LANES
            Canonicalization_V2 #(
                .PRICE_W (PRICE_W),
                .TIMESTAMP_W (TIMESTAMP_W),
                .SIZE_W (SIZE_W),
                .LANE_W (LANE_W),
                .BID (BID),
                .ASK (ASK)
            ) U_CANON (
                .in_quote (in_data[i]),
                .lane_reset (lane_reset[i]),
                .out_lane_tvalid (out_lane_tvalid[i]),
                .ask_out_quote_c (ask_quote_c[i]),
                .bid_out_quote_c (bid_quote_c[i])
            );
 
            Score_V2 U_SCORE_BID (
                .in_quote_c (bid_quote_c[i]),
                .in_lane_id (in_lane_id[i]),    
                .out_score (bid_score[i])
            );
 
            Score_V2 U_SCORE_ASK (
                .in_quote_c (ask_quote_c[i]),
                .in_lane_id (in_lane_id[i]),     
                .out_score (ask_score[i])
            );
        end
    endgenerate

    // Arbiter
    Arbiter_PIP #(.N(N), .SIDE(BID)) U_ARB_BID (
        .clk(clk),
        .rst_n(rst_n),
        .in_score(bid_score),
        .winner_quote(bid_winner_quote)
    );

    Arbiter_PIP #(.N(N), .SIDE(ASK)) U_ARB_ASK (
        .clk(clk),
        .rst_n(rst_n),
        .in_score(ask_score),
        .winner_quote(ask_winner_quote)
    );    
    
    // Signal generator  
    Signal_Generation #(.PRICE_W(PRICE_W)) U_SG (
        .clk(clk),
        .rst_n(rst_n),
        .in_BID(bid_winner_quote),
        .in_ASK(ask_winner_quote),
        .cross_true(_cross),
        .lock_true(_lock),
        .midpoint(_mid),
        .spread(_spread),
        .out_ASK(TOB_ASK),
        .out_BID(TOB_BID)
    );
    
    // Output
    assign best_bid = TOB_BID;
    assign best_ask = TOB_ASK;
    assign out_spread = _spread;
    assign out_mid = _mid;
    assign out_cross = _cross;
    assign out_lock = _lock;
    
endmodule

