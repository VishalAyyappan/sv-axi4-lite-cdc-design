`timescale 1ns/1ps

module axi4_cdc_reg_file (
    // PCLK Domain (AXI4-Lite)
    input  logic        pclk,
    input  logic        presetn,

    // AXI4-Lite Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // AXI4-Lite Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // SCLK Domain (System Peripheral)
    input  logic        sclk,
    input  logic        sresetn,

    // Application interface (to actual peripheral)
    output logic [31:0] app_ctrl_reg,      // Reg 0: Driven by PCLK, sync'd to SCLK
    input  logic [31:0] app_sts_reg,       // Reg 1: Driven by SCLK, sync'd to PCLK
    output logic [31:0] app_data_out,      // Reg 2: PCLK -> SCLK Data
    output logic        app_data_out_vld,
    input  logic [31:0] app_data_in,       // Reg 3: SCLK -> PCLK Data
    input  logic        app_data_in_vld,
    
    // Interrupt
    input  logic        app_intr_req,
    output logic        intr_out
);

    // Internal Registers in PCLK domain
    logic [31:0] reg_file_pclk [8];
    // 0: Control (RW)
    // 1: Status (RO)
    // 2: Data Out (RW)
    // 3: Data In (RO)
    // 4: Intr Enable (RW)
    // 5: Intr Status (W1C)
    // 6: Scratchpad (RW)
    // 7: Scratchpad2 (RW)

    // AXI FSM PCLK Domain
    typedef enum logic [1:0] {IDLE, WADDR_WDATA, WRESP} axi_wr_state_t;
    axi_wr_state_t wr_st;

    logic [31:0] awaddr_reg;
    logic awvalid_reg, wvalid_reg;

    // Write transaction logic
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            wr_st <= IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
        end else begin
            case (wr_st)
                IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready <= 1'b1;
                        wr_st <= WADDR_WDATA;
                        awaddr_reg <= s_axi_awaddr;
                    end
                end
                WADDR_WDATA: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b1;
                    wr_st <= WRESP;
                end
                WRESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b0;
                        wr_st <= IDLE;
                    end
                end
            endcase
        end
    end

    // Read transaction logic
    typedef enum logic [1:0] {R_IDLE, R_DATA} axi_rd_state_t;
    axi_rd_state_t rd_st;

    logic [31:0] araddr_reg;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            rd_st <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rdata <= 32'h0;
        end else begin
            case (rd_st)
                R_IDLE: begin
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        araddr_reg <= s_axi_araddr;
                        rd_st <= R_DATA;
                    end
                end
                R_DATA: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid <= 1'b1;
                    // Register read multiplexing
                    case (araddr_reg[4:2])
                        3'd0: s_axi_rdata <= reg_file_pclk[0];
                        3'd1: s_axi_rdata <= reg_file_pclk[1];
                        3'd2: s_axi_rdata <= reg_file_pclk[2];
                        3'd3: s_axi_rdata <= reg_file_pclk[3];
                        3'd4: s_axi_rdata <= reg_file_pclk[4];
                        3'd5: s_axi_rdata <= reg_file_pclk[5];
                        3'd6: s_axi_rdata <= reg_file_pclk[6];
                        3'd7: s_axi_rdata <= reg_file_pclk[7];
                        default: s_axi_rdata <= 32'h0;
                    endcase
                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        rd_st <= R_IDLE;
                    end
                end
            endcase
        end
    end

    // Signal toggles for CDC
    logic ctrl_update_pclk;
    logic data_out_vld_pclk;
    logic intr_status_clr_pclk;
    
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_file_pclk[0] <= 32'h0;
            reg_file_pclk[2] <= 32'h0;
            reg_file_pclk[4] <= 32'h0;
            reg_file_pclk[6] <= 32'h0;
            reg_file_pclk[7] <= 32'h0;
            ctrl_update_pclk <= 1'b0;
            data_out_vld_pclk <= 1'b0;
            intr_status_clr_pclk <= 1'b0;
        end else begin
            ctrl_update_pclk <= 1'b0;
            data_out_vld_pclk <= 1'b0;
            intr_status_clr_pclk <= 1'b0;

            if (wr_st == WADDR_WDATA) begin
                case (awaddr_reg[4:2])
                    3'd0: begin
                        if (s_axi_wstrb[0]) reg_file_pclk[0][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file_pclk[0][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file_pclk[0][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file_pclk[0][31:24] <= s_axi_wdata[31:24];
                        ctrl_update_pclk <= 1'b1;
                    end
                    3'd2: begin
                        if (s_axi_wstrb[0]) reg_file_pclk[2][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file_pclk[2][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file_pclk[2][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file_pclk[2][31:24] <= s_axi_wdata[31:24];
                        data_out_vld_pclk <= 1'b1;
                    end
                    3'd4: begin
                        if (s_axi_wstrb[0]) reg_file_pclk[4][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file_pclk[4][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file_pclk[4][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file_pclk[4][31:24] <= s_axi_wdata[31:24];
                    end
                    3'd5: begin // W1C
                        if (s_axi_wstrb[0] && s_axi_wdata[0]) intr_status_clr_pclk <= 1'b1;
                    end
                    3'd6: begin
                        if (s_axi_wstrb[0]) reg_file_pclk[6][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file_pclk[6][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file_pclk[6][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file_pclk[6][31:24] <= s_axi_wdata[31:24];
                    end
                    3'd7: begin
                        if (s_axi_wstrb[0]) reg_file_pclk[7][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_file_pclk[7][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_file_pclk[7][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_file_pclk[7][31:24] <= s_axi_wdata[31:24];
                    end
                endcase
            end
        end
    end

    // Pulse Synchronizer for Data Valid: PCLK -> SCLK
    toggle_pulse_sync p_data_out_ctrl (
        .clk_src(pclk), .rst_src_n(presetn), .pulse_src(data_out_vld_pclk),
        .clk_dst(sclk), .rst_dst_n(sresetn), .pulse_dst(app_data_out_vld)
    );

    // Multi-bit CDC using Async FIFO for PCLK->SCLK Data
    logic [31:0] fifo_p2s_rdata;
    logic cdc_fifo_p2s_full, cdc_fifo_p2s_empty;
    cdc_fifo #(.DWIDTH(32), .AWIDTH(2)) fifo_p2s_data (
        .wr_clk(pclk), .wr_rst_n(presetn), .wr_en(data_out_vld_pclk), .wr_data(reg_file_pclk[2]), .wr_full(cdc_fifo_p2s_full),
        .rd_clk(sclk), .rd_rst_n(sresetn), .rd_en(~cdc_fifo_p2s_empty), .rd_data(fifo_p2s_rdata), .rd_empty(cdc_fifo_p2s_empty)
    );

    // Register FIFO output so app_data_out is stable after FIFO drains
    always_ff @(posedge sclk or negedge sresetn) begin
        if (!sresetn) app_data_out <= 32'h0;
        else if (!cdc_fifo_p2s_empty) app_data_out <= fifo_p2s_rdata;
    end

    // Interrupt Synchronizer: SCLK -> PCLK
    logic intr_pclk;
    toggle_pulse_sync p_intr_s2p (
        .clk_src(sclk), .rst_src_n(sresetn), .pulse_src(app_intr_req),
        .clk_dst(pclk), .rst_dst_n(presetn), .pulse_dst(intr_pclk)
    );

    // Update Interrupt status register
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_file_pclk[5] <= 32'h0;
        end else begin
            if (intr_status_clr_pclk) reg_file_pclk[5][0] <= 1'b0;
            else if (intr_pclk) reg_file_pclk[5][0] <= 1'b1;
            
            intr_out <= reg_file_pclk[5][0] & reg_file_pclk[4][0]; // status & enable
        end
    end

    // Slow-changing Control register sync (using generic 2/3 stage sync on data is only safe if it changes slower than clocks)
    // To be perfectly safe across CDC, we can sync the individual bits using 3-stage synchronizer since it's just controls
    sync_3stage #(.WIDTH(32)) sync_ctrl (
        .clk(sclk), .rst_n(sresetn), .d(reg_file_pclk[0]), .q(app_ctrl_reg)
    );

    // Status / Data In from App: SCLK -> PCLK
    // For Status, assume it changes slowly.
    sync_3stage #(.WIDTH(32)) sync_sts (
        .clk(pclk), .rst_n(presetn), .d(app_sts_reg), .q(reg_file_pclk[1])
    );

    // Multi-bit CDC for Data IN (SCLK -> PCLK)
    logic [31:0] fifo_s2p_rdata;
    logic cdc_fifo_s2p_full, cdc_fifo_s2p_empty;
    cdc_fifo #(.DWIDTH(32), .AWIDTH(2)) fifo_s2p_data (
        .wr_clk(sclk), .wr_rst_n(sresetn), .wr_en(app_data_in_vld), .wr_data(app_data_in), .wr_full(cdc_fifo_s2p_full),
        .rd_clk(pclk), .rd_rst_n(presetn), .rd_en(~cdc_fifo_s2p_empty), .rd_data(fifo_s2p_rdata), .rd_empty(cdc_fifo_s2p_empty)
    );

    // Register FIFO output so reg_file_pclk[3] holds stable value after FIFO drains
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) reg_file_pclk[3] <= 32'h0;
        else if (!cdc_fifo_s2p_empty) reg_file_pclk[3] <= fifo_s2p_rdata;
    end

endmodule
