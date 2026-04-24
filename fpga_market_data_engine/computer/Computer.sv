`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 05:48:23 PM
// Design Name: 
// Module Name: Computer
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
module Computer #(
    parameter int N = 8,
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W = 32,
    parameter int SIZE_W = 32
    )(
        input logic clk, rst_n,
        // Upstream
        input quote_t in_data [N-1:0],
        input logic [$clog2(N)-1:0] lane_idx [N-1:0],
        
        // Outputs
        output quote_t best_bid,
        output quote_t best_ask,
        output logic signed [PRICE_W:0] out_spread,
        output logic [PRICE_W-1:0] out_mid,
        output logic out_cross,
        output logic out_lock
    );
    
    typedef enum logic {
        ASK = 0,
        BID = 1
    } order_side_e;

    // Canonicalized quotes
    quote_t ask_quote_c [N-1:0];
    quote_t bid_quote_c [N-1:0];
    // Scoring
    score_t ask_score [N-1:0];
    score_t bid_score [N-1:0];
    // Arbiter outputs
    quote_t bid_winner_quote;
    quote_t ask_winner_quote;
    // Signal generator outputs
    quote_t TOB_ASK, TOB_BID;
    logic signed [PRICE_W:0] _spread;
    logic [PRICE_W-1:0] _mid;
    logic _cross;
    logic _lock;

    // Generate Lanes
    generate
        for (genvar i = 0; i < N; i++) begin : GEN_LANES
            Canonicalization U_CANON (
                .in_quote(in_data[i]),
                .ask_out_quote_c(ask_quote_c[i]),
                .bid_out_quote_c(bid_quote_c[i])
            );
            Scoring #(.N(N)) U_SCORE_BID (
                .in_quote_c(bid_quote_c[i]),
                .in_lane_id(lane_idx[i]),
                .out_score(bid_score[i])
            );
            Scoring #(.N(N)) U_SCORE_ASK (
                .in_quote_c(ask_quote_c[i]),
                .in_lane_id(lane_idx[i]),
                .out_score(ask_score[i])
            );
        end
    endgenerate

    // Arbiters
    Arbiter #(.N(N), .SIDE(1)) U_ARB_BID (
        .clk(clk),
        .rst_n(rst_n),
        .in_score(bid_score),
        .winner_quote(bid_winner_quote)
    );
    Arbiter #(.N(N), .SIDE(0)) U_ARB_ASK (
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