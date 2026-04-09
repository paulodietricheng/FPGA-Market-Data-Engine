`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 09:13:23 PM
// Design Name: 
// Module Name: FIFO_Burst
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


module FIFO_Burst#(
    parameter int MSG_W = 128,
    parameter int MAX_MSG = 4,
    parameter int DEPTH = 32
    )(
        input logic clk, rst_n,// Signals
        
        // Upstream
        input logic [MSG_W-1:0] in_messages [0:MAX_MSG-1],
        input logic [2:0] msg_c,
        input logic in_tvalid,
        output logic up_tready,
        
        // Downstream
        output logic [MSG_W-1:0] out_message,
        output logic out_tvalid,
        input logic down_tready
    );
    
    localparam ADDR_W = $clog2(DEPTH);
    localparam PTR_W = ADDR_W + 1;

    // Pointers:
    logic [PTR_W-1:0] wr_ptr, rd_ptr;
    
    // Occupancy
    logic unsigned [PTR_W-1:0] occupancy;
    assign occupancy = wr_ptr - rd_ptr;
    
    assign up_tready = (occupancy <= (DEPTH - MAX_MSG));
    
    // Control   
    logic write;
    assign write = in_tvalid & up_tready;
    
    logic read;
    assign read = down_tready & (occupancy > 0);
    
    logic [1:0] reg_lane_idx;
    
    // BRAM signals
    logic [ADDR_W-1:0] bram_wr_addr, bram_rd_addr; 
    assign bram_wr_addr = wr_ptr[PTR_W-1:2];
    assign bram_rd_addr = rd_ptr[PTR_W-1:2];
    logic [MSG_W-1:0] bram_rd_data [0:MAX_MSG-1];
    
    logic reg_valid;
    
    // Generate BRAM
    genvar i;
    generate 
        for (i = 0; i < MAX_MSG; i++) begin : GEN_BRAM
            BRAM #(
                .MSG_W(MSG_W),
                .DEPTH(DEPTH)
            ) BRAM (
                .clk(clk),
                .wr_en(write),
                .wr_addr(bram_wr_addr),
                .wr_data(in_messages[i]),
                .rd_en(read),
                .rd_addr(bram_rd_addr),
                .rd_data(bram_rd_data[i])
            );
        end
    endgenerate
    
    logic [1:0] rd_lane_now;
    assign rd_lane_now = rd_ptr[1:0];
    
    // Update pointers
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            reg_valid <= 0;
            reg_lane_idx <= 0;
        end else begin   
            if (write)
                wr_ptr <= wr_ptr + msg_c;
    
            if (read) begin
                rd_ptr <= rd_ptr + 1;
                reg_lane_idx <= rd_lane_now;
            end
        end
    end
    
    always_comb begin
        case (reg_lane_idx)
            0: out_message = bram_rd_data[0];
            1: out_message = bram_rd_data[1];
            2: out_message = bram_rd_data[2];
            3: out_message = bram_rd_data[3];
            default: out_message = '0;
        endcase
    end
    
    assign out_tvalid = read;
    
endmodule
