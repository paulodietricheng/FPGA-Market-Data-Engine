`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:58:10 PM
// Design Name: 
// Module Name: Filter
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
module Filter #(
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2
)(
    input  logic clk, rst_n,
 
    // Upstream
    input logic [ORDER_ID_W-1:0] in_order_id,
    input logic [ORDER_TYPE_W-1:0] in_order_type,
    input quote_t in_quote,
 
    // Downstream
    output logic [ORDER_ID_W-1:0] out_order_id,
    output logic [ORDER_TYPE_W-1:0] out_order_type,
    output quote_t out_quote
);
    localparam logic [ORDER_TYPE_W-1:0] QUOTE = 2'b00;
 
    logic [31:0] last_timestamp;

    logic accept;
    assign accept = in_quote.valid && (in_quote.timestamp > last_timestamp);
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_quote <= '0;
            last_timestamp <= '0;
            out_order_id <= '0;
            out_order_type <= '0;
        end else if (accept) begin
            out_quote <= in_quote;
            out_order_id <= in_order_id;
            out_order_type <= in_order_type;
            if (in_order_type == QUOTE)
                last_timestamp <= in_quote.timestamp;
        end else
            out_quote.valid <= 1'b0;
    end
 
endmodule
 