`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 03:16:44 PM
// Design Name: 
// Module Name: FIFO
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


module FIFO #(
    parameter int MSG_W = 128,
    parameter int MAX_MSG = 4,
    parameter int DEPTH = 32
)(
    input logic clk, rst_n,
 
    // Upstream
    input logic [MSG_W-1:0] in_messages [0:MAX_MSG-1],
    input logic [2:0] in_msg_count,
    input logic in_tvalid,
    output logic up_tready,
 
    // Downstream 
    output logic [MSG_W-1:0] out_message,
    output logic out_tvalid,
    input logic down_tready
);

    // Local parameters
    localparam int PTR_W = $clog2(DEPTH);
    localparam int COUNT_W = PTR_W + 1; 
    localparam logic [PTR_W-1:0] WRAP_MASK = PTR_W'(DEPTH - 1);
    
    // Memory
    logic [MSG_W-1:0] mem [0:DEPTH-1];
    
    // Pointers
    logic [PTR_W-1:0] wr_ptr, rd_ptr;
    logic [COUNT_W-1:0] count;
    
    // Registered variables
    logic [2:0] msg_count_q;
    logic write_q;
    logic [MSG_W-1:0] in_messages_q [0:MAX_MSG-1];
    
    // Read and write
    logic write, read;    
    assign write = write_q;
    assign read = out_tvalid && down_tready;
    
    // Handshake
    assign up_tready = ((count + (write_q ? msg_count_q : '0) - (read ? 1'b1 : '0)) <= DEPTH);
    assign out_tvalid = (count > 0);
    
    // Track sequential write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg_count_q <= '0;
            write_q <= 1'b0;
        end else begin
            write_q <= (in_tvalid && up_tready);
    
            if (in_tvalid && up_tready) begin
                msg_count_q <= in_msg_count;
                for (int i = 0; i < MAX_MSG; i++)
                    in_messages_q[i] <= in_messages[i];
            end
        end
    end
    
    // Write and advance write pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (write_q) begin
                for (int i = 0; i < MAX_MSG; i++) begin
                    if(i < msg_count_q)
                        mem[(wr_ptr + PTR_W'(i)) & WRAP_MASK] <= in_messages_q[i];
                end
                wr_ptr <= (wr_ptr + PTR_W'(msg_count_q)) & WRAP_MASK;
        end
    end
    
    // Advance read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (read) begin
            rd_ptr <= (rd_ptr + PTR_W'(1)) & WRAP_MASK;
        end
    end
    
    // Read
    assign out_message = mem[rd_ptr];
   
    // Update count
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else begin
            unique case ({write, read})
                2'b01:  count <= count - COUNT_W'(1);
                2'b11:  count <= count - COUNT_W'(1) + COUNT_W'(msg_count_q);
                2'b10:  count <= count + COUNT_W'(msg_count_q);
                default: count <= count;
            endcase
        end
    end
endmodule

