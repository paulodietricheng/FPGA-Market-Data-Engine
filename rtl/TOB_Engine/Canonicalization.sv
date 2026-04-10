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
    parameter BID = 1,
    parameter ASK = 0
    )(
        // Upstream
        input quote_t in_quote,
        input logic lane_reset,
        output logic out_lane_tvalid,
        
        // Downstream        
        output quote_t ask_out_quote_c,
        output quote_t bid_out_quote_c
    );
    
    // Normalization
    always_comb begin
         
        // Bid canonical
        bid_out_quote_c.valid = in_quote.valid && (in_quote.side == BID) && !lane_reset;
        bid_out_quote_c.side = BID;
        bid_out_quote_c.price = in_quote.price;
        bid_out_quote_c.timestamp = ~in_quote.timestamp;
        bid_out_quote_c.size = in_quote.size;
    
        // Ask canonical
        ask_out_quote_c.valid = in_quote.valid && (in_quote.side == ASK) && !lane_reset;
        ask_out_quote_c.side = ASK;
        ask_out_quote_c.price = ~in_quote.price;
        ask_out_quote_c.timestamp = ~in_quote.timestamp;
        ask_out_quote_c.size = in_quote.size;
    end

    assign lane_tvalid = !lane_reset;
endmodule
