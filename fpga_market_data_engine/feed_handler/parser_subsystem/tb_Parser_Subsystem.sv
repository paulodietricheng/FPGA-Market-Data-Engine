`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench : tb_Parser_Subsystem
// DUT : Parser_Subsystem
//////////////////////////////////////////////////////////////////////////////////
 
import Data_Structures::*;
 
module tb_Parser_Subsystem;
 
    // Parameters
    localparam int BUS_W = 512;
    localparam int CLK_HALF = 5; // 10 ns clock period
 
    // DUT signals
    logic clk, rst_n;
    logic [BUS_W-1:0] in_tdata;
    logic in_tvalid, in_tlast;
    logic up_tready;
    logic [BUS_W-1:0] out_tdata;
    logic out_tvalid, out_tlast;
    ethernet_t out_eth;
    ipv4_t out_ipv4;
    udp_t out_udp;
    logic down_tready;
 
    // DUT instantiation
    Parser_Subsystem #(.BUS_W(BUS_W)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .up_tready(up_tready),
        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_eth(out_eth),
        .out_ipv4(out_ipv4),
        .out_udp(out_udp),
        .down_tready(down_tready)
    );
 
    // Clock generation
    initial clk = 0;
    always #CLK_HALF clk = ~clk;
  
    // Expected values
    localparam logic [47:0] EXP_DST_MAC = 48'hAABBCCDDEEFF;
    localparam logic [47:0] EXP_SRC_MAC = 48'h001122334455;
    localparam logic [15:0] EXP_ETH_TYPE = 16'h0800; // IPv4
 
    localparam logic [3:0] EXP_VERSION = 4'h4;
    localparam logic [3:0] EXP_IHL = 4'h5;
    localparam logic [15:0] EXP_IP_LEN = 16'd40;
    localparam logic [7:0] EXP_PROTOCOL = 8'd17; // UDP
    localparam logic [31:0] EXP_SRC_IP = 32'hC0A80101;    
    localparam logic [31:0] EXP_DST_IP = 32'hC0A80102; 
 
    localparam logic [15:0] EXP_SRC_PORT = 16'd1234;
    localparam logic [15:0] EXP_DST_PORT = 16'd5678;
    localparam logic [15:0] EXP_UDP_LEN = 16'd20;
    localparam logic [15:0] EXP_CHECKSUM = 16'hBEEF;
 
    // Build the 512-bit stimulus word
    function automatic logic [BUS_W-1:0] build_packet();
        logic [BUS_W-1:0] pkt = '0;
 
        // Ethernet (bits 111:0)
        pkt[47:0] = EXP_DST_MAC;
        pkt[95:48] = EXP_SRC_MAC;
        pkt[111:96] = EXP_ETH_TYPE;
 
        // IPv4 (bits 271:112)
        pkt[115:112] = EXP_VERSION;
        pkt[119:116] = EXP_IHL;
        pkt[143:128] = EXP_IP_LEN;
        pkt[191:184] = EXP_PROTOCOL;
        pkt[239:208] = EXP_SRC_IP;
        pkt[271:240] = EXP_DST_IP;
 
        // UDP (bits 335:272)
        pkt[287:272] = EXP_SRC_PORT;
        pkt[303:288] = EXP_DST_PORT;
        pkt[319:304] = EXP_UDP_LEN;
        pkt[335:320] = EXP_CHECKSUM;
 
        return pkt;
    endfunction
    
    function automatic logic [BUS_W-1:0] build_payload();
        logic [BUS_W-1:0] pl;
        for (int i = 0; i < BUS_W/8; i++)
            pl[i*8 +: 8] = 8'(i);
        return pl;
    endfunction
 
    // Helper task: send one AXI-Stream beat
    task automatic send_beat(input logic [BUS_W-1:0] data, input logic last);
        // Wait until upstream is ready
        in_tdata  = data;
        in_tvalid = 1'b1;
        in_tlast  = last;
        @(posedge clk);
        while (!up_tready) @(posedge clk);
        // De-assert after handshake
        in_tvalid = 1'b0;
        in_tlast  = 1'b0;
    endtask
 
    // Helper task: wait for valid output beat
    task automatic wait_for_output();
        while (!out_tvalid) @(posedge clk);
    endtask
 
    // Checker
    int pass_cnt = 0;
    int fail_cnt = 0;
 
    task automatic check (
        string name,
        logic [63:0] got,
        logic [63:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-20s  got=0x%0h", name, got);
            pass_cnt++;
        end else begin
            $display("  [FAIL] %-20s  got=0x%0h  exp=0x%0h", name, got, exp);
            fail_cnt++;
        end
    endtask
    
    // Check all headers
    task automatic check_all_headers();
        $display("  -- Ethernet --");
        check("dst_mac", 64'(out_eth.dst_mac), 64'(EXP_DST_MAC));
        check("src_mac", 64'(out_eth.src_mac), 64'(EXP_SRC_MAC));
        check("eth_type", 64'(out_eth.eth_type), 64'(EXP_ETH_TYPE));
 
        $display("  -- IPv4 --");
        check("version", 64'(out_ipv4.version), 64'(EXP_VERSION));
        check("ihl", 64'(out_ipv4.ihl), 64'(EXP_IHL));
        check("length", 64'(out_ipv4.length), 64'(EXP_IP_LEN));
        check("protocol", 64'(out_ipv4.protocol), 64'(EXP_PROTOCOL));
        check("src_ip", 64'(out_ipv4.src_ip), 64'(EXP_SRC_IP));
        check("dst_ip", 64'(out_ipv4.dst_ip), 64'(EXP_DST_IP));
 
        $display("  -- UDP --");
        check("src_port", 64'(out_udp.src_port), 64'(EXP_SRC_PORT));
        check("dst_port", 64'(out_udp.dst_port), 64'(EXP_DST_PORT));
        check("length", 64'(out_udp.length), 64'(EXP_UDP_LEN));
        check("checksum", 64'(out_udp.checksum), 64'(EXP_CHECKSUM));
    endtask
 
    // Main test
    initial begin
        // Defaults
        in_tdata = '0;
        in_tvalid = 1'b0;
        in_tlast = 1'b0;
        down_tready = 1'b1;     // downstream always ready
 
        // Reset
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
 
        // Test 1: Single-beat packet
        $display("\n=== Test 1: Single-beat packet ===");
        send_beat(build_packet(), 1'b1);
 
        wait_for_output();
        @(posedge clk);
 
        check_all_headers();
        check("out_tlast", 64'(out_tlast), 64'(1'b1));
 
        // Test 2: 2 beat packet
        $display("\n=== Test 2: Two-beat packet - beat_1 locks headers, payload ignored ===");
 
        // Wait for pipeline to drain before sending the next packet
        while (out_tvalid) @(posedge clk);
 
        send_beat(build_packet(), 1'b0); // beat 1: headers, not last
        send_beat(build_payload(), 1'b1); // beat 2: UDP payload, last beat
 
        // Wait for the last output beat (tlast=1) to propagate through
        wait_for_output();
        while (!out_tlast) @(posedge clk);
        @(posedge clk);
 
        // Headers must still reflect beat 1 values
        check_all_headers();
        check("out_tlast", 64'(out_tlast), 64'(1'b1));
 
        // Summary 
        $display("\n=== Results: %0d PASSED, %0d FAILED ===\n",
                 pass_cnt, fail_cnt);
 
        if (fail_cnt == 0)
            $display("*** ALL TESTS PASSED ***\n");
        else
            $display("*** SOME TESTS FAILED ***\n");
 
        $finish;
    end
 
    // Watch for timeout
    initial begin
        #10_000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end
 
endmodule