`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/07/2026 06:14:55 PM
// Design Name: 
// Module Name: Feed_Normalizer
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

import Data_Structures_V2::*;
 
module Lane_Management_Engine #(
    parameter int N =8,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int AGE_TIMEOUT = 300
)(
    input logic clk, rst_n,
 
    // Upstream interface
    input quote_t in_quote,    
    input logic [ORDER_ID_W-1:0] order_id,      
    input logic [ORDER_TYPE_W-1:0] order_type,   
 
    // Downstream interface 
    output quote_t out_quote [N-1:0],             
    output logic [N-1:0] lane_reset,                     
    output logic [$clog2(N)-1:0] out_lane_id [N-1:0],          
    input logic [N-1:0] lane_valid           
);
 
    // Opcodes
    localparam logic [ORDER_TYPE_W-1:0] QUOTE = 2'b00;
    localparam logic [ORDER_TYPE_W-1:0] FILL = 2'b01;
    localparam logic [ORDER_TYPE_W-1:0] CANCEL = 2'b10;
    
    // Lane Id output
    generate
        for (genvar i = 0; i < N; i++) begin : gen_lane_id
            assign out_lane_id[i] = ($clog2(N))'(i);
        end
    endgenerate
 
    // Store the ids from each lane
    logic [ORDER_ID_W-1:0] reg_order_id [N-1:0];  
 
    // Register for the quotes sent
    quote_t reg_quote [N-1:0];
 
    // Counter
    logic [31:0] curr_time;
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_time <= '0;
        else
            curr_time <= curr_time + 1'b1;
    end
 
    // Quote registers
    quote_t s1_quote;
    logic [ORDER_ID_W-1:0] s1_order_id;
    logic [ORDER_TYPE_W-1:0] s1_order_type;
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_quote <= '0;
            s1_order_id <= '0;
            s1_order_type <= '0;
        end else begin
            if (in_quote.valid) begin
                s1_quote <= in_quote;
                s1_order_id <= order_id;
                s1_order_type <= order_type;
            end
        end
    end
    
        // Invalidate stale orders
    logic [N-1:0] age_reset;
 
    always_comb begin
        for (int i = 0; i < N; i++) begin
            age_reset[i] = lane_valid[i] & ((curr_time - reg_quote[i].timestamp) > AGE_TIMEOUT);
        end
    end
 
    // Find the lowest free lane
    logic [N-1:0] free_mask;
    logic [$clog2(N)-1:0] free_lane_idx; 
    logic any_free;
 
    assign free_mask = ~lane_valid & ~age_reset;
 
    // Priority-encode to lowest set bit of free_mask.
    always_comb begin
        free_lane_idx = '0;
        any_free =| free_mask; 
        for (int i = N-1; i >= 0; i--) begin
            if (free_mask[i])
                free_lane_idx = ($clog2(N))'(i);
        end
    end
 
    // Fill/Cancel match
    logic [N-1:0] id_match; 
    always_comb begin
        for (int i = 0; i < N; i++) begin
            id_match[i] = lane_valid[i] & (reg_order_id[i] == s1_order_id);
        end
    end
 
    // Reset lanes
    logic [N-1:0] msg_reset; 
 
    always_comb begin
        msg_reset = '0;
        if (s1_quote.valid && (s1_order_type == FILL || s1_order_type == CANCEL)) begin
            msg_reset = id_match; 
        end
    end
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lane_reset <= '0;
        else
            lane_reset <= msg_reset | age_reset;
    end
 
    // Write lanes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N; i++) begin
                reg_order_id[i]  <= '0;
                reg_quote[i]  <= '0;
            end
        end else begin
            if (s1_quote.valid && s1_order_type == QUOTE && any_free) begin
                reg_order_id[free_lane_idx] <= s1_order_id;
                reg_quote[free_lane_idx] <= s1_quote;
            end
        end
    end
 
    // Output the lanes
    generate
        for (genvar i = 0; i < N; i++) begin : gen_out_quote
            assign out_quote[i] = reg_quote[i];
        end
    endgenerate
 
endmodule