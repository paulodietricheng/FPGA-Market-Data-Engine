`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 05:45:10 PM
// Design Name: 
// Module Name: Arbiter
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

module Arbiter #(
    parameter int N = 8,
    parameter SIDE = 1
    )(
        input logic clk, rst_n,
        input score_t in_score [N-1:0],
        output quote_t winner_quote
    );

    localparam STAGES = $clog2(N);

    // Stage 0 registers
    score_t s_reg [N-1:0];

    // Tree wires 
    score_t s [0:STAGES][0:N-1];

    // Stage 0 = registered inputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_reg <= '{default:'0};
        end else begin
            for (int i = 0; i < N; i++) begin
                s_reg[i] <= in_score[i];
            end
        end
    end

    // Connect stage 0 wires
    for (genvar i = 0; i < N; i++) begin
        assign s[0][i] = s_reg[i];
    end

    // Tournament tree (pure combinational)
    generate
        for (genvar k = 0; k < STAGES; k++) begin : GEN_TREE
            for (genvar i = 0; i < (N >> k); i += 2) begin : GEN_NODE
                
                score_t s_w;
            
                Module_Arbiter U_ARB (
                    .in_score_A(s[k][i]),
                    .in_score_B(s[k][i+1]),
                    .winner_score(s_w)
                );
                
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        s[k+1][i>>1] <= '0;
                    end else begin
                        s[k+1][i>>1] <= s_w;
                    end
                end               
            end
        end
    endgenerate
    
    // Quote reconstruction
    quote_t reg_w_quote;
    always_comb begin
            reg_w_quote.valid = s[STAGES][0].valid;
            reg_w_quote.side = SIDE;
            reg_w_quote.price = SIDE ? s[STAGES][0].price : ~s[STAGES][0].price;
            reg_w_quote.timestamp = ~s[STAGES][0].timestamp;
            reg_w_quote.size = s[STAGES][0].size;
    end
    
    assign winner_quote = reg_w_quote;
endmodule
