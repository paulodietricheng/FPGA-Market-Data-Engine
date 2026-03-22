`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 07:03:59 AM
// Design Name: 
// Module Name: Signal_Generation
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

module Signal_Generation #(parameter PRICE_W = 32)(
    input logic clk, rst_n, // Signals
    // Upstream
    input quote_t in_BID, in_ASK,
    // Downstream
    output logic cross_true, lock_true,
    output logic signed [PRICE_W:0] spread,
    output logic [PRICE_W-1:0]midpoint,
    output quote_t out_BID, out_ASK
    );
    
    // Intermediate varialbles
    logic signed [PRICE_W:0] comb_spread, reg_spread;
    logic [PRICE_W:0] reg_mid;
    logic reg_cross;
    logic reg_lock;
    quote_t reg_BID, reg_ASK;
    
    assign comb_spread = $signed({1'b0, in_ASK.price}) - $signed({1'b0, in_BID.price});
    
    // Calculations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_spread <= '0;
            reg_mid <= '0;
            reg_cross <= 1'b0;
            reg_BID <= '0;
            reg_ASK <= '0;
            reg_lock <= 1'b0;
        end 
        else begin
            // Spread (unsigned, clamped to zero if crossed)
            reg_spread <= comb_spread;
  
            // Cross detection
            reg_cross <= (comb_spread[PRICE_W]);
            
            // Lock detection
            reg_lock <= (comb_spread == 0);
    
            // Midpoint
            reg_mid <= ({1'b0, in_BID.price} + {1'b0, in_ASK.price}) >> 1;
    
            reg_BID <= in_BID;
            reg_ASK <= in_ASK;
        end
    end
    
    // Output   
    assign spread = reg_spread;
    assign midpoint = reg_mid[PRICE_W-1:0];
    assign cross_true = reg_cross;
    assign lock_true = reg_lock;
    assign out_BID = reg_BID;
    assign out_ASK = reg_ASK;
    
endmodule
