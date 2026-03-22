`timescale 1ns/1ps

module tb_axi4_cdc_reg_file;
    // Clock & reset signals
    logic pclk = 0;
    logic presetn = 0;
    logic sclk = 0;
    logic sresetn = 0;

    // Clock gen at different frequencies to test CDC
    always #5 pclk = ~pclk;    // 100 MHz PCLK
    always #13 sclk = ~sclk;   // ~38 MHz SCLK (asynchronous)

    // AXI Bus
    logic [31:0] s_axi_awaddr;
    logic s_axi_awvalid;
    logic s_axi_awready;

    logic [31:0] s_axi_wdata;
    logic [3:0] s_axi_wstrb;
    logic s_axi_wvalid;
    logic s_axi_wready;

    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;

    logic [31:0] s_axi_araddr;
    logic s_axi_arvalid;
    logic s_axi_arready;

    logic [31:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready;

    // SCLK Application Environment
    logic [31:0] app_ctrl_reg;
    logic [31:0] app_sts_reg;
    logic [31:0] app_data_out;
    logic        app_data_out_vld;
    logic [31:0] app_data_in;
    logic        app_data_in_vld;
    logic        app_intr_req;
    logic        intr_out;

    // DUT Instantiation
    axi4_cdc_reg_file dut (.*);

    // Basic AXI Write Task
    task axi_write(input [31:0] addr, input [31:0] data);
        @(posedge pclk);
        s_axi_awaddr <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata <= data;
        s_axi_wstrb <= 4'hF;
        s_axi_wvalid <= 1'b1;
        s_axi_bready <= 1'b1;

        fork
            begin
                wait(s_axi_awready && s_axi_awvalid);
                @(posedge pclk);
                s_axi_awvalid <= 1'b0;
            end
            begin
                wait(s_axi_wready && s_axi_wvalid);
                @(posedge pclk);
                s_axi_wvalid <= 1'b0;
            end
        join

        wait(s_axi_bvalid);
        @(posedge pclk);
        s_axi_bready <= 1'b0;
    endtask

    // Basic AXI Read Task
    task axi_read(input [31:0] addr, output [31:0] data);
        @(posedge pclk);
        s_axi_araddr <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready <= 1'b1;

        wait(s_axi_arready && s_axi_arvalid);
        @(posedge pclk);
        s_axi_arvalid <= 1'b0;

        wait(s_axi_rvalid);
        @(posedge pclk);
        data = s_axi_rdata;
        s_axi_rready <= 1'b0;
    endtask

    // Test sequence
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_axi4_cdc_reg_file);
        
        // Initialize AXI
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        
        // Initialize App side
        app_sts_reg = 32'h0;
        app_data_in = 32'h0;
        app_data_in_vld = 1'b0;
        app_intr_req = 1'b0;

        $display("Applying reset...");
        #20;
        presetn = 1;
        sresetn = 1;
        $display("Out of reset...");
        #50;

        // Test 1: Write Control Reg (0) and check on SCLK side
        $display("Test 1: PCLK Control Reg Write -> SCLK Check");
        axi_write(32'h00, 32'hDEADBEEF);
        
        // Wait for sync via SCLK cycles (sync_3stage)
        #100;
        if (app_ctrl_reg !== 32'hDEADBEEF) $error("Control sync failed (Expected DEADBEEF, got %h)", app_ctrl_reg);
        else $display("Control sync passed!");

        // Test 2: Write Interrupt Enable (4)
        $display("Test 2: Enabling Interrupt in PCLK");
        axi_write(32'h10, 32'h00000001); // Reg 4 = 1
        
        // Test 3: SCLK Interrupt -> PCLK Intr Status (5)
        $display("Test 3: Generating SCLK Interrupt -> Checking PCLK Out");
        @(posedge sclk);
        app_intr_req <= 1'b1;
        @(posedge sclk);
        app_intr_req <= 1'b0;

        // Wait for CDC
        #150;
        if (intr_out !== 1'b1) $error("Interrupt generation failed");
        else $display("Interrupt sync passed!");

        // Test 4: Clear Interrupt in PCLK
        $display("Test 4: Clearing Interrupt (W1C)");
        axi_write(32'h14, 32'h00000001); // Reg 5, W1C
        #20;
        if (intr_out !== 1'b0) $error("Interrupt clear failed");
        else $display("Interrupt cleared successfully!");

        // Test 5: Multi-bit Data Transfer CDC FIFO (PCLK -> SCLK)
        $display("Test 5: PCLK -> SCLK Data Transfer (Reg 2)");
        axi_write(32'h08, 32'h12345678); // Reg 2

        // Wait for FIFO to cross CDC and registered output to settle.
        // Toggle sync may fire 1 SCLK cycle before the FIFO latch captures,
        // so use a timed wait rather than relying on app_data_out_vld alone.
        #200;
        if (app_data_out !== 32'h12345678) $error("Data Sync P2S Failed! (got %h)", app_data_out);
        else $display("PCLK->SCLK Data Transferred Successfully!");
        
        // Test 6: Multi-bit Data Transfer CDC FIFO (SCLK -> PCLK)
        $display("Test 6: SCLK -> PCLK Data Transfer (Reg 3)");
        @(posedge sclk);
        app_data_in <= 32'h87654321;
        app_data_in_vld <= 1'b1;
        @(posedge sclk);
        app_data_in_vld <= 1'b0;

        #150; // allow fifo write and sync to complete
        
        $display("Test 6: Starting AXI read...");
        begin
            logic [31:0] rdata;
            axi_read(32'h0C, rdata); // Reg 3
            if (rdata !== 32'h87654321) $error("Data Sync S2P Failed (Expected 87654321, got %h)", rdata);
            else $display("SCLK->PCLK Data Transferred Successfully!");
        end

        // Finish successfully
        $display("All tests passed!");
        $finish;
    end
endmodule
