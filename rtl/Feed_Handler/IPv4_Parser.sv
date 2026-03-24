`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 09:08:13 AM
// Design Name: 
// Module Name: IPv4_Parser
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

typedef struct packed{
    logic [3:0] version;
    logic [3:0] ihl;
    logic [15:0] length;
    logic [7:0] protocol;
    logic [31:0] src_ip;
    logic [31:0] dst_ip;
} ipv4_t ;

module IPv4_Parser#(
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
        output ipv4_t out_ipv4,
        input logic down_tready
    );

    // IPv4 header positions
    localparam int IPV4_VERSION_LSB = 112;
    localparam int IPV4_VERSION_MSB = 115;   
    localparam int IPV4_IHL_LSB = 116;
    localparam int IPV4_IHL_MSB = 119;  
    localparam int IPV4_TOTAL_LEN_LSB = 128;
    localparam int IPV4_TOTAL_LEN_MSB = 143;  
    localparam int IPV4_PROTOCOL_LSB = 184;
    localparam int IPV4_PROTOCOL_MSB = 191;  
    localparam int IPV4_SRC_IP_LSB = 208;
    localparam int IPV4_SRC_IP_MSB = 239; 
    localparam int IPV4_DST_IP_LSB = 240;
    localparam int IPV4_DST_IP_MSB = 271; 

    // AXI regs
    logic [BUS_W-1:0] reg_tdata;
    logic reg_tvalid, reg_tlast;

    assign up_tready = !reg_tvalid || down_tready;

    // Parser state
    logic beat_1;
    ipv4_t reg_ipv4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_tvalid <= 1'b0;
            beat_1 <= 1'b1;
            reg_ipv4 <= '0;
        end else if (up_tready) begin
            reg_tvalid <= in_tvalid;

            if (in_tvalid) begin
                reg_tdata <= in_tdata;
                reg_tlast <= in_tlast;

            if (beat_1) begin
                reg_ipv4.version <= in_tdata[IPV4_VERSION_MSB:IPV4_VERSION_LSB];
                reg_ipv4.ihl <= in_tdata[IPV4_IHL_MSB:IPV4_IHL_LSB];
                reg_ipv4.length <= in_tdata[IPV4_TOTAL_LEN_MSB:IPV4_TOTAL_LEN_LSB];
                reg_ipv4.protocol <= in_tdata[IPV4_PROTOCOL_MSB:IPV4_PROTOCOL_LSB];
                reg_ipv4.src_ip <= in_tdata[IPV4_SRC_IP_MSB:IPV4_SRC_IP_LSB];
                reg_ipv4.dst_ip <= in_tdata[IPV4_DST_IP_MSB:IPV4_DST_IP_LSB];
            end
                beat_1 <= in_tlast;
            end
        end
    end

    // Outputs
    assign out_tdata = reg_tdata;
    assign out_tvalid = reg_tvalid;
    assign out_tlast = reg_tlast;
    assign out_ipv4 = reg_ipv4;

endmodule