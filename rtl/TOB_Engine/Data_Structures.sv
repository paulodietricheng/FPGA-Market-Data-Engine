`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/10/2026 05:12:43 PM
// Design Name: 
// Module Name: Data_Structures_V2
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


package Data_Structures_V2;
    typedef struct packed {
        logic valid;
        logic side;
        logic [31:0] price;
        logic [31:0] timestamp;
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
