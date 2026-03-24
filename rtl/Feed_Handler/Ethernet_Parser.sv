`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 09:03:36 AM
// Design Name: 
// Module Name: Ethernet_Parser
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

module Ethernet_Parser #(
    parameter int BUS_W = 512,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160,
    parameter int UDP_LEN_W = 16
    )(
        input  logic clk, rst_n, // Signals
            
        // Upstream
        input logic [BUS_W-1:0] in_tdata,
        input logic in_tvalid,
        input logic in_tlast,
        output logic up_tready,
    
        // Downstream
        output logic [BUS_W-1:0] out_tdata,
        output logic out_tvalid,
        output logic out_tlast,
        output logic [UDP_LEN_W-1:0] udp_length,
        input logic down_tready
    );

    // Register Variables
    logic [BUS_W-1:0] reg_tdata;
    logic reg_tvalid;
    logic reg_tlast;
    logic [UDP_LEN_W-1:0] reg_udp;
    
    assign up_tready = !reg_tvalid || down_tready;

    // Beat 1 tracking
    logic beat_1;

    // UDP Bit positioning parameters
    localparam int UDP_LEN_LSB = ETHERNET_W + IPv4_W + 32;
    localparam int UDP_LEN_MSB = UDP_LEN_LSB + UDP_LEN_W - 1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_tvalid <= 1'b0;
            beat_1 <= 1'b1;
            reg_udp <= '0;
        end else if (up_tready) begin          
            // AXI Stream
            reg_tvalid <= in_tvalid;
            if (in_tvalid) begin
                reg_tdata <= in_tdata;
                reg_tlast <= in_tlast;
                // Extract UDP length
                if (beat_1) begin
                    reg_udp <= in_tdata[UDP_LEN_MSB:UDP_LEN_LSB];
                end
                // First-beat tracking
                beat_1 <= in_tlast;
            end
        end
    end
    
    // Outputs
    assign out_tdata = reg_tdata;
    assign out_tvalid = reg_tvalid;
    assign out_tlast = reg_tlast;
    assign udp_length = reg_udp;

endmodule
