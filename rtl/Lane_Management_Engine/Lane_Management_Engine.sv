`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 11:45:00 AM
// Design Name: 
// Module Name: Lane_Management_Engine_Paulo_V2
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

module Lane_Management_Engine #(
    parameter int N = 8,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int AGE_TIMEOUT = 300
)(
    input  logic clk, rst_n,
 
    // Upstream
    input quote_t in_quote,
    input logic [ORDER_ID_W-1:0] in_order_id,
    input logic [ORDER_TYPE_W-1:0] in_order_type,
 
    // Downstream
    output quote_t out_quote [N-1:0],
    output logic [$clog2(N)-1:0] out_lane_idx [N-1:0]
);
    // Order type definitions:
    typedef enum logic [ORDER_TYPE_W-1:0] {
        QUOTE  = 2'b00,
        FILL = 2'b01,
        CANCEL = 2'b10
    } order_type_e;
    
    // Lane registers
    quote_t quote_in_lane [N-1:0];
    logic [ORDER_ID_W-1:0] order_id_in_lane [N-1:0];
    
    // Masks
    logic [N-1:0] msg_invalid;
    logic [N-1:0] age_invalid;  
    logic [N-1:0] lane_invalid;
    
    // Invalidate mask
    assign lane_invalid = msg_invalid | age_invalid;
    
    // One hot coding for finding and invalidating the corresponding lane 
    always_comb begin
        msg_invalid = '0;  
        
        if (in_quote.valid && (in_order_type == FILL || in_order_type == CANCEL)) begin
            foreach (order_id_in_lane[i]) begin
                msg_invalid[i] = (in_order_id == order_id_in_lane[i]);
            end
        end
    end
        
    // Process incoming quote
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            foreach (quote_in_lane[i]) begin
                quote_in_lane[i] <= '0;
                order_id_in_lane[i] <= '0;
            end
        end else begin
    
            // allocation
            if (in_quote.valid && in_order_type == QUOTE) begin
                for (int i = 0; i < N; i++) begin
                    if (!quote_in_lane[i].valid && !lane_invalid[i]) begin
                        quote_in_lane[i] <= in_quote;
                        order_id_in_lane[i] <= in_order_id;
                        break;
                    end
                end
            end
    
            // invalidation
            foreach (quote_in_lane[i]) begin
                if (lane_invalid[i]) begin
                    quote_in_lane[i] <= '0;
                    order_id_in_lane[i] <= '0;
                end
            end
        end
    end
            
    // Age reset
    logic [31:0] curr_time;
    logic time_seeded;
    
    // Get the timestamp of the first incoming quote and start timer
    always_ff @(posedge clk or negedge rst_n) begin
         if (!rst_n)
            time_seeded <= 1'b0;
         else if (!time_seeded && in_quote.valid && in_order_type == QUOTE) begin
            time_seeded <= 1'b1;
            curr_time <= in_quote.timestamp;
         end else 
            curr_time <= curr_time + 1;
    end
       
    // Pipeline age
    logic [31:0] age_delta [0:N-1];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            foreach (age_delta[i]) age_delta[i] <= '0;
        else 
            foreach (quote_in_lane[i]) age_delta[i] <= curr_time - quote_in_lane[i].timestamp;
    end 
    
    // Invalidate lane based on difference between current time and registered timestamp 
    always_comb begin
        age_invalid = '0;
        foreach (quote_in_lane[i]) begin
            if (quote_in_lane[i].valid && (age_delta[i] > AGE_TIMEOUT))
                age_invalid[i] = 1'b1;
        end
    end
    
    // Outputs
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : GEN_OUTPUT
            assign out_quote[i] = quote_in_lane[i];
            assign out_lane_idx[i] = i;
        end
    endgenerate
    
endmodule
