`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2026 07:22:29 AM
// Design Name: 
// Module Name: Scoring
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

module Scoring(
        // Upstream
        input quote_t in_quote_c,
        input logic [2:0] in_lane_id,
        // Downstream
        output score_t out_score 
    );
    
    always_comb begin
        out_score.valid = in_quote_c.valid;
        out_score.price = in_quote_c.price;
        out_score.timestamp = in_quote_c.timestamp;
        out_score.lane_id = in_lane_id;   
        out_score.size = in_quote_c.size;         
    end
    
endmodule
