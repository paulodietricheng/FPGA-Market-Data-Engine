`timescale 1ns / 1ps

import Data_Structures::*;

module tb_FPGA_Market_Data_Engine;

    // =========================================================
    // Parameters
    // =========================================================
    localparam int N            = 8;
    localparam int BUS_W        = 512;
    localparam int ORDER_ID_W   = 29;
    localparam int ORDER_TYPE_W = 2;
    localparam int PRICE_W      = 32;
    localparam int TIMESTAMP_W  = 32;
    localparam int SIZE_W       = 32;
    localparam int AGE_TIMEOUT  = 300;
    localparam int CLK_HALF     = 5;

    // Order type encoding
    localparam logic [1:0] QUOTE  = 2'b00;
    localparam logic [1:0] FILL   = 2'b01;
    localparam logic [1:0] CANCEL = 2'b10;

    // Packet field offsets (within 512-bit word)
    localparam int PAYLOAD_BASE = 112 + 160 + 64; // = 336

    // Message field offsets within 128-bit message word
    localparam int TYPE_MSB  = 127;
    localparam int TYPE_LSB  = 126;
    localparam int ID_MSB    = 125;
    localparam int ID_LSB    = 97;
    localparam int SIDE_BIT  = 96;
    localparam int PRICE_MSB = 95;
    localparam int PRICE_LSB = 64;
    localparam int TIME_MSB  = 63;
    localparam int TIME_LSB  = 32;
    localparam int SIZE_MSB  = 31;
    localparam int SIZE_LSB  = 0;

    // =========================================================
    // DUT signals
    // =========================================================
    logic                    clk, rst_n;
    logic [BUS_W-1:0]        in_tdata;
    logic                    in_tvalid, in_tlast;
    logic                    up_tready;
    quote_t                  best_bid, best_ask;
    logic signed [PRICE_W:0] out_spread;
    logic [PRICE_W-1:0]      out_mid;
    logic                    out_cross, out_lock;

    // =========================================================
    // DUT
    // =========================================================
    FPGA_Market_Data_Engine #(
        .N          (N),
        .BUS_W      (BUS_W),
        .ORDER_ID_W (ORDER_ID_W),
        .AGE_TIMEOUT(AGE_TIMEOUT)
    ) DUT (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_tdata   (in_tdata),
        .in_tvalid  (in_tvalid),
        .in_tlast   (in_tlast),
        .up_tready  (up_tready),
        .best_bid   (best_bid),
        .best_ask   (best_ask),
        .out_spread (out_spread),
        .out_mid    (out_mid),
        .out_cross  (out_cross),
        .out_lock   (out_lock)
    );

    // =========================================================
    // Clock
    // =========================================================
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // =========================================================
    // Score
    // =========================================================
    int pass_cnt = 0;
    int fail_cnt = 0;

    // =========================================================
    // Checker tasks
    // =========================================================
    task automatic check_logic(
        string       name,
        logic        got,
        logic        exp
    );
        if (got === exp) begin
            $display("  [PASS] %-40s  got=%0b", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-40s  got=%0b  exp=%0b", name, got, exp);
            fail_cnt++;
        end
    endtask

    task automatic check_price(
        string              name,
        logic [PRICE_W-1:0] got,
        logic [PRICE_W-1:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-40s  got=%0d", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-40s  got=%0d  exp=%0d", name, got, exp);
            fail_cnt++;
        end
    endtask

    task automatic check_spread(
        string                   name,
        logic signed [PRICE_W:0] got,
        logic signed [PRICE_W:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-40s  got=%0d", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-40s  got=%0d  exp=%0d", name, got, exp);
            fail_cnt++;
        end
    endtask

    // =========================================================
    // Packet builder
    // Packs one 128-bit message into a full 512-bit AXI-S word.
    // Headers are zeroed - the parsers pass through the bus
    // unchanged and only the payload fields are consumed.
    // =========================================================
    function automatic logic [BUS_W-1:0] build_packet(
        input logic [1:0]  order_type,
        input logic [28:0] order_id,
        input logic        side,
        input logic [31:0] price,
        input logic [31:0] timestamp,
        input logic [31:0] size
    );
        logic [127:0] msg;
        logic [BUS_W-1:0] pkt;

        msg = '0;
        msg[TYPE_MSB:TYPE_LSB] = order_type;
        msg[ID_MSB:ID_LSB]     = order_id;
        msg[SIDE_BIT]          = side;
        msg[PRICE_MSB:PRICE_LSB] = price;
        msg[TIME_MSB:TIME_LSB]   = timestamp;
        msg[SIZE_MSB:SIZE_LSB]   = size;

        pkt = '0;
        pkt[PAYLOAD_BASE +: 128] = msg;
        return pkt;
    endfunction

    // =========================================================
    // Send one single-flit packet and wait for acceptance
    // =========================================================
    task automatic send_packet(input logic [BUS_W-1:0] pkt);
        in_tdata  = pkt;
        in_tvalid = 1'b1;
        in_tlast  = 1'b1;
        @(posedge clk);
        while (!up_tready) @(posedge clk);
        in_tvalid = 1'b0;
        in_tlast  = 1'b0;
    endtask

    // =========================================================
    // Wait until best_bid or best_ask is valid (with timeout)
    // =========================================================
    task automatic wait_bid_valid(input int max_cycles = 100);
        int i;
        for (i = 0; i < max_cycles; i++) begin
            @(posedge clk);
            if (best_bid.valid) return;
        end
        $display("  [WARN] wait_bid_valid timed out after %0d cycles", max_cycles);
    endtask

    task automatic wait_ask_valid(input int max_cycles = 100);
        int i;
        for (i = 0; i < max_cycles; i++) begin
            @(posedge clk);
            if (best_ask.valid) return;
        end
        $display("  [WARN] wait_ask_valid timed out after %0d cycles", max_cycles);
    endtask

    task automatic wait_both_valid(input int max_cycles = 200);
        int i;
        for (i = 0; i < max_cycles; i++) begin
            @(posedge clk);
            if (best_bid.valid && best_ask.valid) return;
        end
        $display("  [WARN] wait_both_valid timed out after %0d cycles", max_cycles);
    endtask

    // =========================================================
    // Reset
    // =========================================================
    task automatic reset_dut();
        in_tvalid = 1'b0;
        in_tlast  = 1'b0;
        in_tdata  = '0;
        rst_n     = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    // =========================================================
    // Tests
    // =========================================================
    initial begin
        reset_dut();

        // =======================================================
        // Test 1: Single bid quote - best_bid should be populated
        // =======================================================
        $display("\n=== Test 1: Single Bid Quote ===");
        begin
            logic [BUS_W-1:0] pkt;
            pkt = build_packet(
                .order_type(QUOTE),
                .order_id  (29'd1),
                .side      (1'b0),       // 0 = bid
                .price     (32'd100),
                .timestamp (32'd1000),
                .size      (32'd50)
            );
            send_packet(pkt);
            wait_bid_valid();
            check_logic ("best_bid.valid", best_bid.valid, 1'b1);
            check_price ("best_bid.price", best_bid.price, 32'd100);
            check_logic ("best_ask.valid (should be 0)", best_ask.valid, 1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 2: Single ask quote - best_ask should be populated
        // =======================================================
        $display("\n=== Test 2: Single Ask Quote ===");
        begin
            logic [BUS_W-1:0] pkt;
            pkt = build_packet(
                .order_type(QUOTE),
                .order_id  (29'd2),
                .side      (1'b1),       // 1 = ask
                .price     (32'd105),
                .timestamp (32'd1001),
                .size      (32'd30)
            );
            send_packet(pkt);
            wait_ask_valid();
            check_logic ("best_ask.valid", best_ask.valid, 1'b1);
            check_price ("best_ask.price", best_ask.price, 32'd105);
            check_logic ("best_bid.valid (should be 0)", best_bid.valid, 1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 3: Spread and mid calculation
        //   bid=100, ask=110 → spread=10, mid=105, no cross/lock
        // =======================================================
        $display("\n=== Test 3: Spread and Mid ===");
        begin
            logic [BUS_W-1:0] pkt;

            pkt = build_packet(QUOTE, 29'd10, 1'b0, 32'd100, 32'd2000, 32'd10);
            send_packet(pkt);

            pkt = build_packet(QUOTE, 29'd11, 1'b1, 32'd110, 32'd2001, 32'd10);
            send_packet(pkt);

            wait_both_valid();
            check_price ("best_bid.price", best_bid.price, 32'd100);
            check_price ("best_ask.price", best_ask.price, 32'd110);
            check_spread("out_spread",     out_spread,     33'sd10);
            check_price ("out_mid",        out_mid,        32'd105);
            check_logic ("out_cross",      out_cross,      1'b0);
            check_logic ("out_lock",       out_lock,       1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 4: Crossed market - ask < bid
        //   bid=110, ask=100 → cross=1
        // =======================================================
        $display("\n=== Test 4: Crossed Market ===");
        begin
            logic [BUS_W-1:0] pkt;

            pkt = build_packet(QUOTE, 29'd20, 1'b0, 32'd110, 32'd3000, 32'd5);
            send_packet(pkt);

            pkt = build_packet(QUOTE, 29'd21, 1'b1, 32'd100, 32'd3001, 32'd5);
            send_packet(pkt);

            wait_both_valid();
            check_logic("out_cross", out_cross, 1'b1);
            check_logic("out_lock",  out_lock,  1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 5: Locked market - ask == bid
        //   bid=100, ask=100 → lock=1, cross=0
        // =======================================================
        $display("\n=== Test 5: Locked Market ===");
        begin
            logic [BUS_W-1:0] pkt;

            pkt = build_packet(QUOTE, 29'd30, 1'b0, 32'd100, 32'd4000, 32'd20);
            send_packet(pkt);

            pkt = build_packet(QUOTE, 29'd31, 1'b1, 32'd100, 32'd4001, 32'd20);
            send_packet(pkt);

            wait_both_valid();
            check_logic("out_lock",  out_lock,  1'b1);
            check_logic("out_cross", out_cross, 1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 6: Best bid update - second bid at higher price
        //   wins over first bid
        // =======================================================
        $display("\n=== Test 6: Best Bid Update (higher price wins) ===");
        begin
            logic [BUS_W-1:0] pkt;

            pkt = build_packet(QUOTE, 29'd40, 1'b0, 32'd100, 32'd5000, 32'd10);
            send_packet(pkt);

            pkt = build_packet(QUOTE, 29'd41, 1'b0, 32'd105, 32'd5001, 32'd10);
            send_packet(pkt);

            wait_bid_valid();
            repeat (20) @(posedge clk);
            check_price("best_bid.price (should be 105)", best_bid.price, 32'd105);
        end

        reset_dut();

        // =======================================================
        // Test 7: Best ask update - second ask at lower price wins
        // =======================================================
        $display("\n=== Test 7: Best Ask Update (lower price wins) ===");
        begin
            logic [BUS_W-1:0] pkt;

            pkt = build_packet(QUOTE, 29'd50, 1'b1, 32'd110, 32'd6000, 32'd10);
            send_packet(pkt);

            pkt = build_packet(QUOTE, 29'd51, 1'b1, 32'd105, 32'd6001, 32'd10);
            send_packet(pkt);

            wait_ask_valid();
            repeat (20) @(posedge clk);
            check_price("best_ask.price (should be 105)", best_ask.price, 32'd105);
        end

        reset_dut();

        // =======================================================
        // Test 8: Cancel removes quote
        // =======================================================
        $display("\n=== Test 8: Cancel ===");
        begin
            logic [BUS_W-1:0] pkt;

            // Add a bid
            pkt = build_packet(QUOTE, 29'd60, 1'b0, 32'd100, 32'd7000, 32'd10);
            send_packet(pkt);
            wait_bid_valid();

            // Cancel the same order_id
            pkt = build_packet(CANCEL, 29'd60, 1'b0, 32'd100, 32'd7001, 32'd0);
            send_packet(pkt);
            repeat (30) @(posedge clk);
            check_logic("best_bid.valid after cancel", best_bid.valid, 1'b0);
        end

        reset_dut();

        // =======================================================
        // Test 9: Back-to-back packets (no idle between)
        // =======================================================
        $display("\n=== Test 9: Back-to-back Packets ===");
        begin
            // Send 4 quotes without gaps and confirm the pipeline
            // doesn't drop any - check that both sides have valid quotes
            for (int i = 0; i < 4; i++) begin
                logic [BUS_W-1:0] pkt;
                pkt = build_packet(
                    QUOTE,
                    29'(i + 100),
                    logic'(i[0]),          // alternate bid/ask
                    32'(200 + i),
                    32'(8000 + i),
                    32'd15
                );
                // Drive without waiting for ready - stress backpressure
                in_tdata  = pkt;
                in_tvalid = 1'b1;
                in_tlast  = 1'b1;
                @(posedge clk);
            end
            in_tvalid = 1'b0;
            in_tlast  = 1'b0;

            wait_both_valid(200);
            check_logic("best_bid.valid after burst", best_bid.valid, 1'b1);
            check_logic("best_ask.valid after burst", best_ask.valid, 1'b1);
        end

        // =======================================================
        // Summary
        // =======================================================
        $display("\n=== Results: %0d PASSED, %0d FAILED ===\n",
                 pass_cnt, fail_cnt);

        if (fail_cnt == 0)
            $display("*** ALL TESTS PASSED ***\n");
        else
            $display("*** SOME TESTS FAILED ***\n");

        $finish;
    end

    // Timeout
    initial begin
        #200_000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule