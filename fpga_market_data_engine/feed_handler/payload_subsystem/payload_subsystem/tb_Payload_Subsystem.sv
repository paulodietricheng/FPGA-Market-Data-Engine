`timescale 1ns / 1ps

module tb_Payload_Subsystem;

    import Data_Structures::*;

    // Parameters
    localparam int BUS_W = 512;
    localparam int MSG_W = 128;
    localparam int MAX_MSG = 4;
    localparam int CLK_HALF = 5;

    // DUT signals
    logic clk, rst_n;

    logic [BUS_W-1:0] in_tdata;
    logic in_tvalid;
    logic in_tlast;
    logic up_tready;

    quote_t out_quote;
    logic [28:0] out_order_id;
    logic [1:0]  out_order_type;

    // DUT
    Payload_Subsystem DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_quote(out_quote),
        .out_order_id(out_order_id),
        .out_order_type(out_order_type)
    );

    // Clock
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // Helpers
    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check_quote(
        string name,
        quote_t got,
        quote_t exp
    );
        if (got.valid !== exp.valid) begin
            $display("[FAIL] %s valid mismatch", name);
            fail_cnt++;
        end else if (got.valid) begin
            if (got.price == exp.price &&
                got.timestamp == exp.timestamp &&
                got.size == exp.size &&
                got.side == exp.side) begin
                $display("[PASS] %s", name);
                pass_cnt++;
            end else begin
                $display("[FAIL] %s data mismatch", name);
                fail_cnt++;
            end
        end else begin
            $display("[PASS] %s (invalid filtered)", name);
            pass_cnt++;
        end
    endtask

    // Build a 128-bit message
    function automatic logic [127:0] make_msg(
        logic [1:0] order_type,
        logic [28:0] id,
        logic side,
        logic [31:0] price,
        logic [31:0] ts,
        logic [31:0] size
    );
        return {order_type, id, side, price, ts, size};
    endfunction

    // Send one 512-bit beat
    task automatic send_beat(
        input logic [BUS_W-1:0] data,
        input logic last
    );
        in_tdata = data;
        in_tvalid = 1'b1;
        in_tlast = last;

        @(posedge clk);
        while (!up_tready) @(posedge clk);

        in_tvalid = 0;
        in_tlast = 0;
    endtask

    task automatic reset_dut();
        in_tvalid = 0;
        in_tlast = 0;
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    // Wait for next valid output
    task automatic wait_output(output quote_t q);
        while (!out_quote.valid) @(posedge clk);
        q = out_quote;
    endtask

    // Main test
    initial begin
        reset_dut();

        // Test 1: Single message packet
        $display("\n=== Test 1: Single Message ===");

        begin
            logic [127:0] msg;
            logic [511:0] beat;
            quote_t exp, got;

            msg = make_msg(2'b00, 29'h1, 1'b1, 32'd100, 32'd10, 32'd5);
            
            beat = '0;
            beat[336 +: 128] = msg;

            send_beat(beat, 1'b1);

            exp.valid = 1;
            exp.price = 100;
            exp.timestamp = 10;
            exp.size = 5;
            exp.side = 1;

            wait_output(got);
            check_quote("single msg", got, exp);
        end

        reset_dut();

        // Test 2: 4 messages across beats
        $display("\n=== Test 2: Multi-message ===");

        begin
            logic [127:0] m0, m1, m2, m3;
            logic [511:0] beat0 = '0;
            logic [511:0] beat1 = {m3, m2, m1, m0}; // aligned case

            quote_t got;

            m0 = make_msg(2'b00, 1, 0, 10, 1, 1);
            m1 = make_msg(2'b00, 2, 0, 20, 2, 2);
            m2 = make_msg(2'b00, 3, 0, 30, 3, 3);
            m3 = make_msg(2'b00, 4, 0, 40, 4, 4);

            beat0[336 +: 128] = m0;

            send_beat(beat0, 0);
            send_beat(beat1, 1);

            repeat (4) begin
                wait_output(got);
                $display("[INFO] Got message price=%0d ts=%0d",
                         got.price, got.timestamp);
            end
        end

        reset_dut();

        // Test 3: Filter (timestamp ordering)
        $display("\n=== Test 3: Filter ===");

        begin
            logic [127:0] m0, m1;
            logic [511:0] beat = '0;
            quote_t got;

            // m1 is older, should be dropped
            m0 = make_msg(2'b00, 1, 0, 10, 100, 1);
            m1 = make_msg(2'b00, 2, 0, 20, 50,  1);

            
            beat[336 +: 128] = m0;

            send_beat(beat, 0);

            beat = {m1, 384'b0};
            send_beat(beat, 1);

            // Expect only m0
            wait_output(got);
            if (got.timestamp == 100)
                $display("[PASS] filter keeps newest");
            else begin
                $display("[FAIL] filter wrong");
                fail_cnt++;
            end

            // ensure no second valid output
            repeat (5) @(posedge clk);
            if (!out_quote.valid)
                $display("[PASS] filter dropped old msg");
            else begin
                $display("[FAIL] old msg passed");
                fail_cnt++;
            end
        end

        // Summary
        $display("\n=== Results: %0d PASSED, %0d FAILED ===\n",
                 pass_cnt, fail_cnt);

        if (fail_cnt == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

    // Timeout
    initial begin
        #50_000;
        $display("[ERROR] Timeout");
        $finish;
    end

endmodule