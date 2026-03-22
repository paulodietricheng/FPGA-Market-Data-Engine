`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/18/2026 09:43:38 AM
// Design Name: 
// Module Name: Canonicalization
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

module Canonicalization #(
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W = 32,
    parameter int SIZE_W = 32,
    parameter int LANE_W = 3,
    parameter int BID = 1,
    parameter int ASK = 0
    )(
        input logic clk,
        input logic rst_n,
        input quote_t in_quote, // Upstream
       
        // Downstream        
        output quote_t ask_out_quote_c,
        output quote_t bid_out_quote_c
    );

    // Register    
    quote_t ask_reg_quote_c;
    quote_t bid_reg_quote_c;
    
    // Normalization
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bid_reg_quote_c <= '0;
            ask_reg_quote_c <= '0;
        end else if(in_quote.valid) begin
                
            // Bid canonical
            bid_reg_quote_c.valid <= in_quote.valid && (in_quote.side == BID);
            bid_reg_quote_c.side <= BID;
            bid_reg_quote_c.price <= in_quote.price;
            bid_reg_quote_c.timestamp <= ~in_quote.timestamp;
            bid_reg_quote_c.size <= in_quote.size;
            bid_reg_quote_c.lane_id <= in_quote.lane_id;
    
            // Ask canonical
            ask_reg_quote_c.valid <= in_quote.valid && (in_quote.side == ASK);
            ask_reg_quote_c.side <= ASK;
            ask_reg_quote_c.price <= ~in_quote.price;
            ask_reg_quote_c.timestamp <= ~in_quote.timestamp;
            ask_reg_quote_c.size <= in_quote.size;
            ask_reg_quote_c.lane_id <= in_quote.lane_id;
        end
    end


    // Output   
    assign bid_out_quote_c = bid_reg_quote_c;
    assign ask_out_quote_c = ask_reg_quote_c;

endmodule

