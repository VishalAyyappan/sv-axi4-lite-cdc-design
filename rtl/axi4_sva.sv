// AXI4-Lite protocol and CDC stability assertions
`timescale 1ns/1ps

module axi4_cdc_sva_checker (
    input logic pclk,
    input logic presetn,
    input logic [31:0] s_axi_awaddr,
    input logic s_axi_awvalid,
    input logic s_axi_awready,
    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    input logic s_axi_wready,
    input logic [1:0] s_axi_bresp,
    input logic s_axi_bvalid,
    input logic s_axi_bready,
    input logic [31:0] s_axi_araddr,
    input logic s_axi_arvalid,
    input logic s_axi_arready,
    input logic [31:0] s_axi_rdata,
    input logic [1:0] s_axi_rresp,
    input logic s_axi_rvalid,
    input logic s_axi_rready
);

    // ----------------------------------------------------
    // AXI4-Lite Protocol Assertions (PCLK Domain)
    // ----------------------------------------------------

    // 1. AWVALID stability: Once asserted, must remain high until handshake
    property p_awvalid_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_awvalid && !s_axi_awready |=> s_axi_awvalid;
    endproperty
    assert_awvalid_stable: assert property (p_awvalid_stable)
    else $error("Assertion failed: AWVALID dropped before AWREADY handshake");

    // 2. AWADDR stability: Address must be stable when AWVALID is high
    property p_awaddr_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_awvalid && !s_axi_awready |=> $stable(s_axi_awaddr);
    endproperty
    assert_awaddr_stable: assert property (p_awaddr_stable)
    else $error("Assertion failed: AWADDR changed while AWVALID is asserted");

    // 3. WVALID stability
    property p_wvalid_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_wvalid && !s_axi_wready |=> s_axi_wvalid;
    endproperty
    assert_wvalid_stable: assert property (p_wvalid_stable);

    // 4. WDATA stability
    property p_wdata_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_wvalid && !s_axi_wready |=> $stable(s_axi_wdata);
    endproperty
    assert_wdata_stable: assert property (p_wdata_stable);

    // 5. WSTRB stability
    property p_wstrb_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_wvalid && !s_axi_wready |=> $stable(s_axi_wstrb);
    endproperty
    assert_wstrb_stable: assert property (p_wstrb_stable);

    // 6. BVALID stability
    property p_bvalid_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid;
    endproperty
    assert_bvalid_stable: assert property (p_bvalid_stable);

    // 7. BRESP stability
    property p_bresp_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_bvalid && !s_axi_bready |=> $stable(s_axi_bresp);
    endproperty
    assert_bresp_stable: assert property (p_bresp_stable);

    // 8. ARVALID stability
    property p_arvalid_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_arvalid && !s_axi_arready |=> s_axi_arvalid;
    endproperty
    assert_arvalid_stable: assert property (p_arvalid_stable);

    // 9. ARADDR stability
    property p_araddr_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_arvalid && !s_axi_arready |=> $stable(s_axi_araddr);
    endproperty
    assert_araddr_stable: assert property (p_araddr_stable);

    // 10. RVALID stability
    property p_rvalid_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_rvalid && !s_axi_rready |=> s_axi_rvalid;
    endproperty
    assert_rvalid_stable: assert property (p_rvalid_stable);

    // 11. RDATA stability
    property p_rdata_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_rvalid && !s_axi_rready |=> $stable(s_axi_rdata);
    endproperty
    assert_rdata_stable: assert property (p_rdata_stable);

    // 12. RRESP stability
    property p_rresp_stable;
        @(posedge pclk) disable iff (!presetn)
        s_axi_rvalid && !s_axi_rready |=> $stable(s_axi_rresp);
    endproperty
    assert_rresp_stable: assert property (p_rresp_stable);

    // ----------------------------------------------------
    // Additional protocol rules
    // ----------------------------------------------------
    // 13. Write address range check (Assuming 8 x 4-byte registers = 32 bytes = 0x00 to 0x1C)
    property p_awaddr_range;
        @(posedge pclk) disable iff (!presetn)
        s_axi_awvalid |-> s_axi_awaddr[31:5] == 27'h0;
    endproperty
    assert_awaddr_range: assert property (p_awaddr_range);

    // 14. Read address range check
    property p_araddr_range;
        @(posedge pclk) disable iff (!presetn)
        s_axi_arvalid |-> s_axi_araddr[31:5] == 27'h0;
    endproperty
    assert_araddr_range: assert property (p_araddr_range);

    // 15. AWADDR and WDATA must both handshake before BVALID can assert
    property p_bvalid_wait_handshakes;
        @(posedge pclk) disable iff (!presetn)
        (s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready) |=> s_axi_bvalid [->1];
    endproperty
    assert_bvalid_wait_handshakes: assert property (p_bvalid_wait_handshakes);

    // 16. Cannot send BVALID if AW or W is missing
    property p_bvalid_no_early;
        @(posedge pclk) disable iff(!presetn)
        $rose(s_axi_bvalid) |-> $past(s_axi_awready) && $past(s_axi_wready);
    endproperty
    assert_bvalid_no_early: assert property (p_bvalid_no_early);

    // 17. ARADDR handshake must occur before RVALID
    property p_rvalid_wait_ar_handshake;
        @(posedge pclk) disable iff (!presetn)
        (s_axi_arvalid && s_axi_arready) |=> s_axi_rvalid [->1];
    endproperty
    assert_rvalid_wait_ar_handshake: assert property (p_rvalid_wait_ar_handshake);

    // 18. RVALID must not rise without ARADDR past handshake
    property p_rvalid_no_early;
        @(posedge pclk) disable iff (!presetn)
        $rose(s_axi_rvalid) |-> $past(s_axi_arready);
    endproperty
    assert_rvalid_no_early: assert property (p_rvalid_no_early);

    // 19-30+ Reset checks: All VALID signals must be 0 when resetn is asserted
    property p_reset_awvalid;
        @(posedge pclk) !presetn |=> !s_axi_awvalid;
    endproperty
    assert_reset_awvalid: assert property (p_reset_awvalid);

    property p_reset_wvalid;
        @(posedge pclk) !presetn |=> !s_axi_wvalid;
    endproperty
    assert_reset_wvalid: assert property (p_reset_wvalid);

    property p_reset_bvalid;
        @(posedge pclk) !presetn |=> !s_axi_bvalid;
    endproperty
    assert_reset_bvalid: assert property (p_reset_bvalid);

    property p_reset_arvalid;
        @(posedge pclk) !presetn |=> !s_axi_arvalid;
    endproperty
    assert_reset_arvalid: assert property (p_reset_arvalid);

    property p_reset_rvalid;
        @(posedge pclk) !presetn |=> !s_axi_rvalid;
    endproperty
    assert_reset_rvalid: assert property (p_reset_rvalid);

    property p_reset_awready;
        @(posedge pclk) !presetn |=> !s_axi_awready;
    endproperty
    assert_reset_awready: assert property (p_reset_awready);

    property p_reset_wready;
        @(posedge pclk) !presetn |=> !s_axi_wready;
    endproperty
    assert_reset_wready: assert property (p_reset_wready);

    property p_reset_arready;
        @(posedge pclk) !presetn |=> !s_axi_arready;
    endproperty
    assert_reset_arready: assert property (p_reset_arready);

    // Note: Due to limitations of not seeing inside the CDC boundary entirely, 
    // structural CDC stability verification is done with Conformal CDC and Formal. 
    // The SVAs cover standard AXI4 compliance locally in PCLK. 

endmodule

// Bind the checker to the main module
bind axi4_cdc_reg_file axi4_cdc_sva_checker u_sva_checker (
    .pclk(pclk),
    .presetn(presetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready)
);

