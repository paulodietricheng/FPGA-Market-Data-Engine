`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 03:58:41 PM
// Design Name: 
// Module Name: tb_Lane_Management_Engine
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


`timescale 1ns / 1ps

import Data_Structures::*;

module tb_Lane_Management_Engine_Paulo_V2;

    // Parameters
    localparam int N = 8;
    localparam int ORDER_ID_W = 29;
    localparam int ORDER_TYPE_W = 2;
    localparam int AGE_TIMEOUT = 10;
    localparam int CLK_HALF = 5;

    // DUT IO
    logic clk, rst_n;

    quote_t in_quote;
    logic [ORDER_ID_W-1:0] in_order_id;
    logic [ORDER_TYPE_W-1:0] in_order_type;

    quote_t out_quote [N-1:0];
    logic [$clog2(N)-1:0] out_lane_idx [N-1:0];

    // DUT
    Lane_Management_Engine #(
        .N(N),
        .ORDER_ID_W(ORDER_ID_W),
        .ORDER_TYPE_W(ORDER_TYPE_W),
        .AGE_TIMEOUT(AGE_TIMEOUT)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_quote(in_quote),
        .in_order_id(in_order_id),
        .in_order_type(in_order_type),
        .out_quote(out_quote),
        .out_lane_idx(out_lane_idx)
    );

    // Clock
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // Checker
    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check(
        string name,
        logic got,
        logic exp
    );
        if (got === exp) begin
            $display("  [PASS] %-30s", name);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-30s got=%0d exp=%0d", name, got, exp);
            fail_cnt++;
        end
    endtask

    // Helpers
    task automatic send_msg(
        input logic [ORDER_ID_W-1:0] id,
        input logic [ORDER_TYPE_W-1:0] typ,
        input int ts
    );
        @(negedge clk);
        in_quote.valid = 1'b1;
        in_quote.timestamp = ts;
        in_order_id = id;
        in_order_type = typ;

        @(negedge clk);
        in_quote.valid = 1'b0;
    endtask

    task automatic idle(input int cycles);
        repeat (cycles) @(posedge clk);
    endtask

    task automatic reset_dut();
        in_quote = '0;
        in_order_id = '0;
        in_order_type = '0;

        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    // Helper
    function automatic logic any_lane_valid();
        for (int i = 0; i < N; i++) begin
            if (out_quote[i].valid)
                return 1'b1;
        end
        return 1'b0;
    endfunction

    // Main tests
    initial begin

        reset_dut();

        // Test 1: Allocation
        $display("\n=== Test 1: Allocation ===");

        for (int i = 0; i < N; i++) begin
            send_msg(i, 2'b00, i);
            @(posedge clk);
        end

        idle(2);

        check("lanes allocated", any_lane_valid(), 1'b1);

        reset_dut();

        // Test 2: FILL invalidation
        $display("\n=== Test 2: FILL invalidation ===");

        send_msg(42, 2'b00, 1);
        idle(2);

        send_msg(42, 2'b01, 2);
        idle(2);

        check("lane cleared after FILL", any_lane_valid(), 1'b0);

        reset_dut();

        // Test 3: CANCEL invalidation
        $display("\n=== Test 3: CANCEL invalidation ===");

        send_msg(55, 2'b00, 1);
        idle(2);

        send_msg(55, 2'b10, 2);
        idle(2);

        check("lane cleared after CANCEL", any_lane_valid(), 1'b0);

        reset_dut();

        // Test 4: Age eviction
        $display("\n=== Test 4: Age eviction ===");

        send_msg(1, 2'b00, 0);
        idle(AGE_TIMEOUT + 6);

        check("lane aged out", any_lane_valid(), 1'b0);

        reset_dut();

        // Test 5: Reuse
        $display("\n=== Test 5: Reuse ===");

        send_msg(10, 2'b00, 0);
        idle(2);

        send_msg(10, 2'b01, 1);
        idle(2);

        send_msg(99, 2'b00, 2);
        idle(2);

        check("reuse works", any_lane_valid(), 1'b1);

        // Summary
        $display("\n=== Results: %0d PASSED, %0d FAILED ===",
                 pass_cnt, fail_cnt);

        if (fail_cnt == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

endmodule
