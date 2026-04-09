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


module Feed_Normalizer #(
    parameter int N = 8,
    parameter int MSG_W = 128,
    parameter int RAW_DATA_W = 98,
    parameter int ORDER_ID_W = 29,
    parameter int ORDER_TYPE_W = 2,
    parameter int HEADER_W = 31
    )(    
        // Upstream
        input logic [MSG_W-1:0] in_msg,
        input logic in_tvalid,
        output logic up_tready,
    
        // Downstream
        output logic [RAW_DATA_W-1:0] out_data,
        output logic [ORDER_ID_W-1:0] order_id,
        output logic [ORDER_TYPE_W-1:0] order_type,
        input logic down_tready
    );

    // type encoding
    localparam logic [ORDER_TYPE_W-1:0] QUOTE = 2'b00;
    localparam logic [ORDER_TYPE_W-1:0] FILL = 2'b01;
    localparam logic [ORDER_TYPE_W-1:0] CANCEL = 2'b10;

    // Bit boundaries
    localparam int TYPE_MSB = MSG_W - 1; // 127
    localparam int TYPE_LSB = MSG_W - ORDER_TYPE_W; // 126
    localparam int ID_MSB = TYPE_LSB - 1; // 125
    localparam int ID_LSB = TYPE_LSB - ORDER_ID_W; // 97
    localparam int PAYLOAD_MSB = ID_LSB - 1; // 96

    // Parse fields
    assign order_type = in_msg[TYPE_MSB : TYPE_LSB];
    assign order_id = in_msg[ID_MSB : ID_LSB];
    assign out_data = {in_tvalid, in_msg[PAYLOAD_MSB:0]};

    // Assign never stalling pipeline
    assign up_tready  = 1'b1;

endmodule