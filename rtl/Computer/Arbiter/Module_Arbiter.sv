`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 05:45:51 PM
// Design Name: 
// Module Name: Module_Arbiter
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

module Module_Arbiter(        
        // Upstream
        input score_t in_score_A, in_score_B,
        
        // Donwstream
        output score_t winner_score
    );
    
    assign winner_score = (in_score_A[99:32] > in_score_B[99:32]) ? in_score_A : in_score_B;
  
endmodule