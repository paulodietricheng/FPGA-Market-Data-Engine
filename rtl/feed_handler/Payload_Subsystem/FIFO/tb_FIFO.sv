`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench : tb_FIFO
// DUT : FIFO
//////////////////////////////////////////////////////////////////////////////////

module tb_FIFO;

    // Parameters
    localparam int MSG_W = 128;
    localparam int MAX_MSG = 4;
    localparam int DEPTH = 32;
    localparam int CLK_HALF = 5;

    // DUT signals
    logic clk, rst_n;

    logic [MSG_W-1:0] in_messages [0:MAX_MSG-1];
    logic [2:0] in_msg_count;
    logic in_tvalid;
    logic up_tready;

    logic [MSG_W-1:0] out_message;
    logic out_tvalid;
    logic down_tready;

    // DUT
    FIFO #(
        .MSG_W(MSG_W),
        .MAX_MSG(MAX_MSG),
        .DEPTH(DEPTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_messages(in_messages),
        .in_msg_count(in_msg_count),
        .in_tvalid(in_tvalid),
        .up_tready(up_tready),
        .out_message(out_message),
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
        logic [MSG_W-1:0] got,
        logic [MSG_W-1:0] exp
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

    // Push helpers
    task automatic push1(input logic [MSG_W-1:0] m0);
        in_messages[0] = m0;
        in_msg_count = 3'd1;
        in_tvalid = 1'b1;
        @(posedge clk);
        while (!up_tready) @(posedge clk);
        in_tvalid = 1'b0;
    endtask

    task automatic push4(
        input logic [MSG_W-1:0] m0,
        input logic [MSG_W-1:0] m1,
        input logic [MSG_W-1:0] m2,
        input logic [MSG_W-1:0] m3
    );
        in_messages[0] = m0;
        in_messages[1] = m1;
        in_messages[2] = m2;
        in_messages[3] = m3;
        in_msg_count = 3'd4;
        in_tvalid = 1'b1;
        @(posedge clk);
        while (!up_tready) @(posedge clk);
        in_tvalid = 1'b0;
    endtask

    task automatic pop_and_check(
        input string name,
        input logic [MSG_W-1:0] exp
    );
        while (!out_tvalid) @(posedge clk);
        down_tready = 1'b1;
        @(posedge clk);
        check(name, out_message, exp);
        down_tready = 1'b0;
    endtask
    
    task automatic reset_dut();
        in_tvalid = 1'b0;
        down_tready = 1'b0;
        in_msg_count = '0;
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    // Main test
    initial begin
        reset_dut();

        // Test 1: Push 1, Pop 1
        $display("\n=== Test 1: Push 1 / Pop 1 ===");

        begin
            logic [127:0] A = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111;

            push1(A);
            pop_and_check("pop A", A);
        end

        reset_dut();

        // Test 2: Push 4, Pop 4 
        $display("\n=== Test 2: Push 4 / Pop 4 ===");

        begin
            logic [127:0] M0 = 128'h0;
            logic [127:0] M1 = 128'h1;
            logic [127:0] M2 = 128'h2;
            logic [127:0] M3 = 128'h3;

            push4(M0, M1, M2, M3);

            pop_and_check("pop M0", M0);
            pop_and_check("pop M1", M1);
            pop_and_check("pop M2", M2);
            pop_and_check("pop M3", M3);
        end

        reset_dut();
    
        // Test 3: Mixed push (1 + 4)
        $display("\n=== Test 3: Mixed Push ===");

        begin
            logic [127:0] A = 128'hAA;
            logic [127:0] B = 128'hBB;
            logic [127:0] C = 128'hCC;
            logic [127:0] D = 128'hDD;
            logic [127:0] E = 128'hEE;

            push1(A);
            push4(B, C, D, E);
            
            pop_and_check("pop A", A);          
            pop_and_check("pop B", B);
            pop_and_check("pop C", C);
            pop_and_check("pop D", D);
            pop_and_check("pop E", E);
        end

        // Test 4: Backpressure 
        $display("\n=== Test 4: Backpressure ===");

        begin
            logic [127:0] X = 128'h1234;
            logic [127:0] Y = 128'h5678;

            push4(X, Y, 128'h9, 128'hA);

            // Stall output
            down_tready = 0;
            repeat (3) @(posedge clk);

            // Resume
            pop_and_check("pop X", X);
            pop_and_check("pop Y", Y);
        end
        
        reset_dut();

        // Test 5: Wraparound
        $display("\n=== Test 5: Wraparound ===");
        begin
            // Push 28 entries
            for (int i = 0; i < 7; i++)
                push4(4*i, 4*i+1, 4*i+2, 4*i+3);
        
            // Pop 16 entries
            for (int i = 0; i < 16; i++)
                pop_and_check($sformatf("wrap pop %0d", i), i);
        
            // Push 16 more entries: wr_ptr wraps
            for (int i = 7; i < 11; i++)
                push4(4*i, 4*i+1, 4*i+2, 4*i+3);
        
            // Drain
            for (int i = 16; i < 44; i++)
                pop_and_check($sformatf("wrap pop %0d", i), i);
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