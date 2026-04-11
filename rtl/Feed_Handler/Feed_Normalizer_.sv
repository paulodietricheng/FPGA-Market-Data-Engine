`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/08/2026 08:43:58 PM
// Design Name: 
// Module Name: Feed_Normalizer_
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

module Feed_Normalizer #(
    parameter int MSG_W = 128,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int LANE_W = 3,
    parameter int PRICE_W = 32,
    parameter int TIMESTAMP_W = 32,
    parameter int SIZE_W = 32
)(
    // Upstream
    input logic [MSG_W-1:0] in_data,
    input logic in_tvalid,
    input logic [LANE_W-1:0] lane_id,
    output logic up_tready,

    // Downstream
    output quote_t out_quote,
    output logic [ORDER_ID_W-1:0] order_id,
    output logic [ORDER_TYPE_W-1:0] order_type
);

    // Bit boundaries
    localparam int TYPE_MSB = MSG_W - 1; // 127
    localparam int TYPE_LSB = MSG_W - ORDER_TYPE_W; // 126
    localparam int ID_MSB = TYPE_LSB - 1; // 125
    localparam int ID_LSB = TYPE_LSB - ORDER_ID_W; // 97
    localparam int SIDE_BIT = ID_LSB - 1; // 96
    localparam int PRICE_MSB = SIDE_BIT - 1; // 95
    localparam int PRICE_LSB = PRICE_MSB - (PRICE_W - 1); // 64
    localparam int TIME_MSB = PRICE_LSB - 1; // 63
    localparam int TIME_LSB = TIME_MSB - (TIMESTAMP_W - 1); // 32
    localparam int SIZE_MSB = TIME_LSB - 1; // 31
    localparam int SIZE_LSB = SIZE_MSB - (SIZE_W - 1); // 0

    // Field extraction
    assign order_type = in_data[TYPE_MSB:TYPE_LSB];
    assign order_id = in_data[ID_MSB:ID_LSB];

    // Struct population
    always_comb begin
        out_quote.valid = in_tvalid;
        out_quote.side = in_data[SIDE_BIT];
        out_quote.price = in_data[PRICE_MSB:PRICE_LSB];
        out_quote.timestamp = in_data[TIME_MSB:TIME_LSB];
        out_quote.size = in_data[SIZE_MSB:SIZE_LSB];
    end

    assign up_tready = 1'b1;

endmodule