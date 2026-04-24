`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 05:37:04 PM
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

module Canonicalization (
        // Upstream
        input quote_t in_quote,
        
        // Downstream        
        output quote_t ask_out_quote_c,
        output quote_t bid_out_quote_c
    );
    
    typedef enum logic{
        ASK = 0,
        BID = 1
    } order_side_e ;
    
    // Normalization
    always_comb begin        
        // Bid canonical
        bid_out_quote_c.valid = in_quote.valid && (in_quote.side == BID);
        bid_out_quote_c.side = BID;
        bid_out_quote_c.price = in_quote.price;
        bid_out_quote_c.timestamp = ~in_quote.timestamp;
        bid_out_quote_c.size = in_quote.size;
    
        // Ask canonical
        ask_out_quote_c.valid = in_quote.valid && (in_quote.side == ASK);
        ask_out_quote_c.side = ASK;
        ask_out_quote_c.price = ~in_quote.price;
        ask_out_quote_c.timestamp = ~in_quote.timestamp;
        ask_out_quote_c.size = in_quote.size;
    end

    assign out_lane_tvalid = in_quote.valid;
endmodule
