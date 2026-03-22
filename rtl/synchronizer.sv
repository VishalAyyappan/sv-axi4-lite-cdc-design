`timescale 1ns/1ps

module sync_3stage #(
    parameter WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    logic [WIDTH-1:0] q1, q2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= '0;
            q2 <= '0;
            q  <= '0;
        end else begin
            q1 <= d;
            q2 <= q1;
            q  <= q2;
        end
    end
endmodule

module toggle_pulse_sync (
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_src,

    input  logic clk_dst,
    input  logic rst_dst_n,
    output logic pulse_dst
);
    logic toggle_src;
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) toggle_src <= 1'b0;
        else if (pulse_src) toggle_src <= ~toggle_src;
    end

    logic toggle_dst_sync, toggle_dst_sync_d;
    sync_3stage #(.WIDTH(1)) sync_inst (
        .clk(clk_dst),
        .rst_n(rst_dst_n),
        .d(toggle_src),
        .q(toggle_dst_sync)
    );

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) toggle_dst_sync_d <= 1'b0;
        else toggle_dst_sync_d <= toggle_dst_sync;
    end

    assign pulse_dst = toggle_dst_sync ^ toggle_dst_sync_d;
endmodule

// Gray code multi-bit synchronizer for pointers/counters
module gray_sync #(
    parameter WIDTH = 4
) (
    input  logic             clk_dst,
    input  logic             rst_dst_n,
    input  logic [WIDTH-1:0] bin_src,
    output logic [WIDTH-1:0] bin_dst
);
    logic [WIDTH-1:0] gray_src;
    
    // Binary to Gray
    assign gray_src = (bin_src >> 1) ^ bin_src;

    logic [WIDTH-1:0] gray_dst_sync;
    sync_3stage #(.WIDTH(WIDTH)) sync_inst (
        .clk(clk_dst),
        .rst_n(rst_dst_n),
        .d(gray_src),
        .q(gray_dst_sync)
    );

    // Gray to Binary
    logic [WIDTH-1:0] bin_dst_nxt;
    always_comb begin
        bin_dst_nxt[WIDTH-1] = gray_dst_sync[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) begin
            bin_dst_nxt[i] = bin_dst_nxt[i+1] ^ gray_dst_sync[i];
        end
    end

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) bin_dst <= '0;
        else bin_dst <= bin_dst_nxt;
    end
endmodule
