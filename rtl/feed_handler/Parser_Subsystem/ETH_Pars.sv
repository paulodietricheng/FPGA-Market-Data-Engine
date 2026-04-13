`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 04:49:01 PM
// Design Name: 
// Module Name: ETH_Pars
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

module ETH_Pars #(
    parameter int BUS_W = 512
    )(
        input logic clk, rst_n,
            
        // Upstream
        input logic [BUS_W-1:0] in_tdata,
        input logic in_tvalid,
        input logic in_tlast,
        output logic up_tready,
        
        // Downstream
        output logic [BUS_W-1:0] out_tdata,
        output logic out_tvalid,
        output logic out_tlast,
        output ethernet_t out_eth,
        input logic down_tready
    );

    // Header positions
    localparam int ETH_DST_MAC_LSB = 0;
    localparam int ETH_DST_MAC_MSB = 47;
    localparam int ETH_SRC_MAC_LSB = 48;
    localparam int ETH_SRC_MAC_MSB = 95;
    localparam int ETH_TYPE_LSB = 96;
    localparam int ETH_TYPE_MSB = 111;

    // AXI regs
    logic [BUS_W-1:0] reg_tdata;
    logic reg_tvalid, reg_tlast;

    assign up_tready = !reg_tvalid || down_tready;

    // Parser state
    logic beat_1;
    ethernet_t reg_eth;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_tvalid <= 1'b0;
            beat_1 <= 1'b1;
            reg_eth <= '0;
        end else if (up_tready) begin
            reg_tvalid <= in_tvalid;

            if (in_tvalid) begin
                reg_tdata <= in_tdata;
                reg_tlast <= in_tlast;

                if (beat_1) begin
                    reg_eth.dst_mac <= in_tdata[ETH_DST_MAC_MSB:ETH_DST_MAC_LSB];
                    reg_eth.src_mac <= in_tdata[ETH_SRC_MAC_MSB:ETH_SRC_MAC_LSB];
                    reg_eth.eth_type <= in_tdata[ETH_TYPE_MSB:ETH_TYPE_LSB];
                end

                // Correct beat tracking
                beat_1 <= in_tlast;
            end
        end
    end

    // Outputs
    assign out_tdata = reg_tdata;
    assign out_tvalid = reg_tvalid;
    assign out_tlast = reg_tlast;
    assign out_eth = reg_eth;

endmodule