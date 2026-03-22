`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Paulo Dietrich
// 
// Create Date: 02/17/2026 02:38:34 PM
// Module Name: Filter
// Project Name: Mini_Trading_Pipeline
// Description: This module implements the filtering strategy 
// 
//////////////////////////////////////////////////////////////////////////////////

import Data_Structures::*;

module Filter(
        input logic clk, rst_n, // Signals
        
        input quote_t in_quote, // Upstream
        output quote_t out_quote // Downstream
    );
    
    // Register variables
    quote_t reg_quote;
    logic [31:0] last_timestamp;
    logic take;
    assign take = (in_quote.valid && in_quote.timestamp >= last_timestamp);
       
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            reg_quote <= '0;
            last_timestamp <= '0;
        end else if (take) begin
            last_timestamp <= in_quote.timestamp;
            reg_quote <= in_quote;
        end else
            reg_quote.valid <= 1'b0;
    end
    
    assign out_quote = reg_quote;
    
endmodule
