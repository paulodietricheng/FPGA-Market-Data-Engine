`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:55:07 PM
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
    
    typedef struct packed {
        logic [47:0] dst_mac;
        logic [47:0] src_mac;
        logic [15:0] eth_type;
    } ethernet_t;

    typedef struct packed{
        logic [3:0] version;
        logic [3:0] ihl;
        logic [15:0] length;
        logic [7:0] protocol;
        logic [31:0] src_ip;
        logic [31:0] dst_ip;
    } ipv4_t ;

    typedef struct packed {
        logic [15:0] src_port;
        logic [15:0] dst_port;
        logic [15:0] length;
        logic [15:0] checksum;
    } udp_t;

endpackage
