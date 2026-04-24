`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench : tb_Payload_Extractor
// DUT : Payload_Extractor
//////////////////////////////////////////////////////////////////////////////////

module tb_Payload_Extractor;

    // Parameters
    localparam int BUS_W = 512;
    localparam int ETHERNET_W = 112;
    localparam int IPv4_W = 160;
    localparam int UDP_W = 64;
    localparam int MSG_W = 128;
    localparam int MAX_MSG = 4;
    localparam int CLK_HALF = 5;   // 10 ns period

    localparam int PAYLOAD_BEGIN = ETHERNET_W + IPv4_W + UDP_W;  // 336
    localparam int CARRY_W = BUS_W - PAYLOAD_BEGIN - MSG_W; // 48

    // U_PLE signals
    logic clk, rst_n;
    logic [BUS_W-1:0] in_tdata;
    logic in_tvalid, in_tlast;
    logic up_tready;
    logic [MSG_W-1:0] out_messages [0:MAX_MSG-1];
    logic [2:0] out_msg_count;
    logic out_tvalid;
    logic down_tready;

    // U_PLE instantiation
    Payload_Extractor #(
        .BUS_W(BUS_W),
        .ETHERNET_W(ETHERNET_W),
        .IPv4_W(IPv4_W),
        .UDP_W(UDP_W),
        .MSG_W(MSG_W),
        .MAX_MSG(MAX_MSG)
    ) U_PLE (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_messages(out_messages),
        .out_msg_count(out_msg_count),
        .out_tvalid(out_tvalid),
        .down_tready(down_tready)
    );

    // Clock
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // Checker
    int pass_cnt = 0;
    int fail_cnt = 0;

    task automatic check (
        string name,
        logic [127:0] got,
        logic [127:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-30s  got=0x%032h", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-30s  got=0x%032h", name, got);
            $display("  %30s   exp=0x%032h", "", exp);
            fail_cnt++;
        end
    endtask

    task automatic check8 (
        string name,
        logic [7:0] got,
        logic [7:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-30s  got=%0d", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-30s  got=%0d  exp=%0d", name, got, exp);
            fail_cnt++;
        end
    endtask

    // AXI-Stream helpers
    task automatic send_beat (
        input logic [BUS_W-1:0] data,
        input logic last
    );
        in_tdata = data;
        in_tvalid = 1'b1;
        in_tlast = last;
        @(posedge clk);
        while (!up_tready) @(posedge clk);
        in_tvalid = 1'b0;
        in_tlast = 1'b0;
    endtask

    task automatic wait_for_output ();
        while (!out_tvalid) @(posedge clk);
    endtask

    // Stimulus builders

    // Build a beat with one payload message starting at PAYLOAD_BEGIN,
    function automatic logic [BUS_W-1:0] build_beat1 (
        input logic [MSG_W-1:0]  payload_msg,   // goes to in_tdata[463:336]
        input logic [CARRY_W-1:0] carry_out      // goes to in_tdata[511:464]
    );
        logic [BUS_W-1:0] w = '0;
        w[PAYLOAD_BEGIN +: MSG_W]        = payload_msg;
        w[BUS_W-1 -: CARRY_W]           = carry_out;
        return w;
    endfunction

    // Build beat 2 with four 128-bit data regions placed at the positions
    function automatic logic [BUS_W-1:0] build_beat2 (
        input logic [MSG_W-1:0]   m0, m1, m2, m3,
        input logic [CARRY_W-1:0] carry_in  // carry saved from beat 1
    );
        // msg[0] = {in_tdata[79:0], carry_in[47:0]}
        logic [BUS_W-1:0] w = '0;
        w[79:0] = m0[MSG_W-1 -: 80]; // top 80 bits of m0
        // msg[1] = in_tdata[207:80]  -> m1[127:0]
        w[207:80] = m1;
        // msg[2] = in_tdata[335:208] -> m2[127:0]
        w[335:208] = m2;
        // msg[3] = in_tdata[463:336] -> m3[127:0]
        w[463:336] = m3;
        // new carry
        w[511:464] = '0;
        return w;
    endfunction

    // Main test
    initial begin
        in_tdata = '0;
        in_tvalid = 1'b0;
        in_tlast = 1'b0;
        down_tready = 1'b1;

        // Reset
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Test 1: Single-beat packet
        $display("\n=== Test 1: Single-beat packet ===");

        begin
            automatic logic [MSG_W-1:0]   PAYLOAD_MSG_A = 128'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;
            automatic logic [CARRY_W-1:0] CARRY_A       = 48'hA1B2C3D4E5F6;
            automatic logic [BUS_W-1:0]   beat;
            beat = build_beat1(PAYLOAD_MSG_A, CARRY_A);

            send_beat(beat, 1'b1); // Send single beat packet
            wait_for_output();
            @(posedge clk);

            check ("msg[0]", out_messages[0], PAYLOAD_MSG_A);
            check ("msg[1]", out_messages[1], '0);
            check ("msg[2]", out_messages[2], '0);
            check ("msg[3]", out_messages[3], '0);
            check8("msg_count", {5'b0, out_msg_count}, 8'd1);
        end

        // Test 2: Two-beat packet - carry stitching
        $display("\n=== Test 2: Two-beat packet - carry stitching ===");

        // Wait for pipeline to drain
        while (out_tvalid) @(posedge clk);

        begin
            automatic logic [MSG_W-1:0] PAYLOAD_MSG_B = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
            automatic logic [CARRY_W-1:0] CARRY_B = 48'hAABBCCDDEEFF;

            // Expected output
            automatic logic [MSG_W-1:0] EXP_M0 = 128'hAABBCCDDEEFF_0000_1111_2222_3333_4444_5555;
            automatic logic [MSG_W-1:0] EXP_M1 = 128'hABCD_EF01_2345_6789_ABCD_EF01_2345_6789;
            automatic logic [MSG_W-1:0] EXP_M2 = 128'hFEDC_BA98_7654_3210_FEDC_BA98_7654_3210;
            automatic logic [MSG_W-1:0] EXP_M3 = 128'h0F0E_0D0C_0B0A_0908_0706_0504_0302_0100;

            // Recompute EXP_M0 from carry
            automatic logic [79:0] M0_HI  = 80'h1111_2222_3333_4444_5555;
            automatic logic [BUS_W-1:0] beat1, beat2;
            EXP_M0 = {M0_HI, CARRY_B};

            beat1 = build_beat1(PAYLOAD_MSG_B, CARRY_B);
            beat2 = build_beat2(EXP_M0, EXP_M1, EXP_M2, EXP_M3, CARRY_B);

            // Beat 1 output
            $display("  -- Beat 1 output (msg_count=1) --");
            send_beat(beat1, 1'b0); // Sent first beat  
            wait_for_output();
            @(posedge clk);

            check ("msg[0]", out_messages[0], PAYLOAD_MSG_B);
            check ("msg[1]", out_messages[1], '0);
            check ("msg[2]", out_messages[2], '0);
            check ("msg[3]", out_messages[3], '0);
            check8("msg_count", {5'b0, out_msg_count}, 8'd1);

            // Beat 2 output
            $display("  -- Beat 2 output (msg_count=4, carry stitched) --");
            while (out_tvalid) @(posedge clk);

            send_beat(beat2, 1'b1); // Send second beat (last)
            wait_for_output();
            @(posedge clk);

            check ("msg[0]", out_messages[0], EXP_M0);
            check ("msg[1]", out_messages[1], EXP_M1);
            check ("msg[2]", out_messages[2], EXP_M2);
            check ("msg[3]", out_messages[3], EXP_M3);
            check8("msg_count", {5'b0, out_msg_count}, 8'd4);
        end

        // Test 3: beat_first reset - single-beat packet after two-beat packet
        $display("\n=== Test 3: beat_first reset after tlast ===");

        while (out_tvalid) @(posedge clk);

        begin
            automatic logic [MSG_W-1:0] PAYLOAD_MSG_C = 128'hC0FFEE00_DEADC0DE_BAADF00D_CAFEBABE;
            automatic logic [CARRY_W-1:0] CARRY_C = 48'h123456789ABC;
            automatic logic [BUS_W-1:0] beat;
            beat = build_beat1(PAYLOAD_MSG_C, CARRY_C);

            send_beat(beat, 1'b1);
            wait_for_output();
            @(posedge clk);

            check ("msg[0]", out_messages[0], PAYLOAD_MSG_C);
            check ("msg[1]", out_messages[1], '0);
            check ("msg[2]", out_messages[2], '0);
            check ("msg[3]", out_messages[3], '0);
            check8 ("msg_count", {5'b0, out_msg_count}, 8'd1);
        end

        // Summary
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
        #50_000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule