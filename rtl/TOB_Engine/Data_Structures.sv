`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/18/2026 06:26:21 AM
// Design Name: 
// Module Name: Data_Structures
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


package Data_Structures;

    typedef struct packed {
        logic valid;
        logic side;
        logic [31:0] price;
        logic signed [31:0] timestamp;
        logic [31:0] size;
    } quote_t;  
    
    typedef struct packed {
        logic valid;
        logic [31:0] price;
        logic [31:0] timestamp;
        logic [2:0] lane_id;
        logic [31:0] size;
    } score_t;
    
endpackage
