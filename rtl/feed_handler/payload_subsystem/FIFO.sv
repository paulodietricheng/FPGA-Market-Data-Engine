`timescale 1ns / 1ps

module FIFO #(
    parameter int MSG_W   = 128,
    parameter int MAX_MSG = 4,
    parameter int DEPTH   = 32
)(
    input  logic clk, rst_n,

    // Upstream
    input  logic [MSG_W-1:0] in_messages [0:MAX_MSG-1],
    input  logic [2:0]       in_msg_count,
    input  logic             in_tvalid,
    output logic             up_tready,

    // Downstream
    output logic [MSG_W-1:0] out_message,
    output logic             out_tvalid,
    input  logic             down_tready
);

    // Parameters
    localparam int PTR_W      = $clog2(DEPTH);
    localparam int COUNT_W    = PTR_W + 1;
    localparam logic [PTR_W-1:0] WRAP_MASK = PTR_W'(DEPTH - 1);

    localparam int ROWS       = DEPTH / MAX_MSG;
    localparam int ROW_W      = $clog2(ROWS);
    localparam int BRAM_IDX_W = $clog2(MAX_MSG);

    // BRAM port signals
    logic [MSG_W-1:0]  bram_din     [0:MAX_MSG-1];
    logic [ROW_W-1:0]  bram_wr_addr [0:MAX_MSG-1];
    logic [ROW_W-1:0]  bram_rd_addr [0:MAX_MSG-1];
    logic              bram_wr_en   [0:MAX_MSG-1];
    logic [MSG_W-1:0]  bram_dout    [0:MAX_MSG-1];

    // Generate BRAMs
    genvar g;
    generate
        for (g = 0; g < MAX_MSG; g++) begin : bram_banks
            bram #(
                .MSG_W (MSG_W),
                .DEPTH (ROWS)
            ) u_bram (
                .clk    (clk),
                .din    (bram_din[g]),
                .wr_addr(bram_wr_addr[g]),
                .rd_addr(bram_rd_addr[g]),
                .wr_en  (bram_wr_en[g]),
                .dout   (bram_dout[g])
            );
        end
    endgenerate

    // Control
    logic [PTR_W-1:0]   wr_ptr, rd_ptr;
    logic [COUNT_W-1:0] count;

    // Write staging
    logic             write_q;
    logic [2:0]       msg_count_q;
    logic [MSG_W-1:0] in_messages_q [0:MAX_MSG-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_q     <= 1'b0;
            msg_count_q <= '0;
        end else begin
            write_q <= (in_tvalid && up_tready);
            if (in_tvalid && up_tready) begin
                msg_count_q <= in_msg_count;
                for (int i = 0; i < MAX_MSG; i++)
                    in_messages_q[i] <= in_messages[i];
            end
        end
    end

    // Handshake
    logic read;
    assign read = out_tvalid && down_tready;

    assign up_tready =
        (count
        + (write_q ? COUNT_W'(msg_count_q) : '0)
        - (read    ? COUNT_W'(1)            : '0)) <= DEPTH;

    // Update write pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (write_q)
            wr_ptr <= (wr_ptr + PTR_W'(msg_count_q)) & WRAP_MASK;
    end

    // BRAM write port drive
    always_comb begin
        for (int b = 0; b < MAX_MSG; b++) begin
            bram_wr_en[b]   = 1'b0;
            bram_wr_addr[b] = '0;
            bram_din[b]     = '0;
        end

        if (write_q) begin
            for (int i = 0; i < MAX_MSG; i++) begin
                if (i < int'(msg_count_q)) begin
                    // Compute which bank and row this slot maps to
                    logic [PTR_W-1:0]      addr;
                    logic [BRAM_IDX_W-1:0] bank;
                    logic [ROW_W-1:0]      row;

                    addr = (wr_ptr + PTR_W'(i)) & WRAP_MASK;
                    bank = BRAM_IDX_W'(addr[BRAM_IDX_W-1:0]);
                    row  = ROW_W'(addr >> BRAM_IDX_W);

                    bram_wr_en[bank]   = 1'b1;
                    bram_wr_addr[bank] = row;
                    bram_din[bank]     = in_messages_q[i];
                end
            end
        end
    end

    // Update read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (read)
            rd_ptr <= (rd_ptr + PTR_W'(1)) & WRAP_MASK;
    end

    // BRAM read addressing
    logic [PTR_W-1:0]      rd_ptr_next;
    logic [BRAM_IDX_W-1:0] bram_idx_next;
    logic [ROW_W-1:0]      row_next;

    assign rd_ptr_next  = read ? (rd_ptr + PTR_W'(1)) & WRAP_MASK : rd_ptr;
    assign bram_idx_next = BRAM_IDX_W'(rd_ptr_next[BRAM_IDX_W-1:0]);
    assign row_next      = ROW_W'(rd_ptr_next >> BRAM_IDX_W);

    always_comb begin
        for (int b = 0; b < MAX_MSG; b++)
            bram_rd_addr[b] = row_next;
    end

    // Register the bank select to align with the BRAM's registered dout
    logic [BRAM_IDX_W-1:0] bram_idx_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) bram_idx_q <= '0;
        else        bram_idx_q <= bram_idx_next;
    end

    assign out_message = bram_dout[bram_idx_q];

    // Update count
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else begin
            unique case ({write_q, read})
                2'b01:   count <= count - COUNT_W'(1);
                2'b10:   count <= count + COUNT_W'(msg_count_q);
                2'b11:   count <= count - COUNT_W'(1) + COUNT_W'(msg_count_q);
                default: /* no change */;
            endcase
        end
    end

    // out_tvalid
    logic count_nonzero_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count_nonzero_q <= 1'b0;
        else        count_nonzero_q <= (count > 0);
    end

    assign out_tvalid = count_nonzero_q;

endmodule