`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:50:47 PM
// Design Name: 
// Module Name: UDP_Pars
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

module UDP_Pars #(
    parameter int BUS_W = 512,
    parameter int ETHERNET_W = 112,
    parameter int IPv4_W = 160
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
        output udp_t out_udp,
        input logic down_tready
    );

    // UDP field positions
    localparam int UDP_BASE = ETHERNET_W + IPv4_W;

    localparam int UDP_SRC_PORT_LSB = UDP_BASE + 0;
    localparam int UDP_SRC_PORT_MSB = UDP_BASE + 15;
    localparam int UDP_DST_PORT_LSB = UDP_BASE + 16;
    localparam int UDP_DST_PORT_MSB = UDP_BASE + 31;
    localparam int UDP_LEN_LSB = UDP_BASE + 32;
    localparam int UDP_LEN_MSB = UDP_BASE + 47;
    localparam int UDP_CSUM_LSB = UDP_BASE + 48;
    localparam int UDP_CSUM_MSB = UDP_BASE + 63;

    // AXI regs
    logic [BUS_W-1:0] reg_tdata;
    logic reg_tvalid, reg_tlast;

    assign up_tready = !reg_tvalid || down_tready;

    // Parser state
    logic beat_1;
    udp_t reg_udp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_tvalid <= 1'b0;
            beat_1 <= 1'b1;
            reg_udp <= '0;
        end else if (up_tready) begin
            reg_tvalid <= in_tvalid;

            if (in_tvalid) begin
                reg_tdata <= in_tdata;
                reg_tlast <= in_tlast;

                if (beat_1) begin
                    reg_udp.src_port <= in_tdata[UDP_SRC_PORT_MSB:UDP_SRC_PORT_LSB];
                    reg_udp.dst_port <= in_tdata[UDP_DST_PORT_MSB:UDP_DST_PORT_LSB];
                    reg_udp.length <= in_tdata[UDP_LEN_MSB:UDP_LEN_LSB];
                    reg_udp.checksum <= in_tdata[UDP_CSUM_MSB:UDP_CSUM_LSB];
                end

                // First-beat tracking
                beat_1 <= in_tlast;
            end
        end
    end

    // Outputs
    assign out_tdata  = reg_tdata;
    assign out_tvalid = reg_tvalid;
    assign out_tlast = reg_tlast;
    assign out_udp = reg_udp;

endmodule
