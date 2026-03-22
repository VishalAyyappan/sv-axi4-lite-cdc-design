`timescale 1ns/1ps

module cdc_fifo #(
    parameter DWIDTH = 32,
    parameter AWIDTH = 3 // 8 entries
) (
    input  logic              wr_clk,
    input  logic              wr_rst_n,
    input  logic              wr_en,
    input  logic [DWIDTH-1:0] wr_data,
    output logic              wr_full,

    input  logic              rd_clk,
    input  logic              rd_rst_n,
    input  logic              rd_en,
    output logic [DWIDTH-1:0] rd_data,
    output logic              rd_empty
);
    localparam DEPTH = 1 << AWIDTH;
    logic [DWIDTH-1:0] mem [DEPTH];

    logic [AWIDTH:0] wr_ptr, wr_ptr_next;
    logic [AWIDTH:0] rd_ptr, rd_ptr_next;

    logic [AWIDTH:0] wr_ptr_gray_sync;
    logic [AWIDTH:0] rd_ptr_gray_sync;

    // Write clock domain pointer
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) wr_ptr <= '0;
        else if (wr_en && !wr_full) wr_ptr <= wr_ptr + 1'b1;
    end
    
    // Memory write
    always_ff @(posedge wr_clk) begin
        if (wr_en && !wr_full) mem[wr_ptr[AWIDTH-1:0]] <= wr_data;
    end

    // Read clock domain pointer
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) rd_ptr <= '0;
        else if (rd_en && !rd_empty) rd_ptr <= rd_ptr + 1'b1;
    end
    
    assign rd_data = mem[rd_ptr[AWIDTH-1:0]];

    // Sync RD ptr to WR domain (for full check)
    gray_sync #(.WIDTH(AWIDTH+1)) rd_to_wr_sync (
        .clk_dst(wr_clk),
        .rst_dst_n(wr_rst_n),
        .bin_src(rd_ptr),
        .bin_dst(rd_ptr_gray_sync)
    );

    // Sync WR ptr to RD domain (for empty check)
    gray_sync #(.WIDTH(AWIDTH+1)) wr_to_rd_sync (
        .clk_dst(rd_clk),
        .rst_dst_n(rd_rst_n),
        .bin_src(wr_ptr),
        .bin_dst(wr_ptr_gray_sync)
    );

    assign wr_full  = (wr_ptr == {~rd_ptr_gray_sync[AWIDTH], rd_ptr_gray_sync[AWIDTH-1:0]});
    assign rd_empty = (rd_ptr == wr_ptr_gray_sync);

endmodule
