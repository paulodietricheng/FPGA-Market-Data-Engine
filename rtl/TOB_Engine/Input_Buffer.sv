`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Paulo Dietrich
// 
// Create Date: 02/13/2026 01:19:51 PM
// Module Name: Valid_Ready_Handshake
// Project Name: Mini_Trading_Pipeline
// Description: This module is responsible for preventing data corruption or loss, while 
// ensuring proper backpressure handling. 
// 
// Review: 0
// 
//////////////////////////////////////////////////////////////////////////////////


module Input_Buffer #(parameter int RAW_DATA_W = 98)(
        input logic clk, rst_n, // Signals 
        
        // Upstream
        input logic [RAW_DATA_W-1:0] in_data,
        
        // Downstream
        output logic [RAW_DATA_W-1:0] out_data
    );
    
    // Internal Register
    logic [RAW_DATA_W-1:0] reg_data;
    
    // Register the raw data to align to the clock
     always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reg_data <= '0;
        else
            reg_data <= in_data;
    end
     
    //Output
    assign out_data = reg_data;
endmodule
