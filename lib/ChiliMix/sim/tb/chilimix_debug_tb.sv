// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_debug -- the debug unit end to end from its pins:
// JTAG scans (as OpenOCD: a dmi access is followed by a nop scan for its
// result; a busy result means dmireset and a retry with more Run-Test/Idle
// cycles), a "hart" on the DM's AHB subordinate (basechili_ahb_manager
// driven by the testbench), and a memory behind the SBA manager
// (basechili_ahb_sram with a testbench SRAM model). The units' behavior is
// checked by their own testbenches; this one checks every path through the
// top:
//   JTAG IDCODE, dtmcs; dmactive, dmstatus over the DMI;
//   SBA writes and reads of 8 / 16 / 32 bits (and 64 on a 64-bit bus, through
//   sbaddress1 / sbdata1 where they exist) reach the memory;
//   haltreq raises debug_req; the hart's HALTED store makes dmstatus halted;
//   the ROM read over AHB against GNU as; the resume flag seen by the hart
//   at FLAGS, its RESUMING store makes resumeack; ndmreset reaches the pin.
`include "tb_common.svh"
module chilimix_debug_tb #(
  parameter int TCK_H     = 13,         // tck half period (clk period 10)
  parameter int XLEN      = 32,
  parameter int SB_ADDR_W = 32,
  parameter int SB_DATA_W = 32
);
  localparam int SB_LANES = SB_DATA_W / 8;
  localparam int SB_LO    = $clog2(SB_LANES);
  import chilimix_debug_pkg::*;
  localparam logic [31:0] IDCODE = 32'h2C0D_E001;
  localparam logic [31:0] GOLDEN_ROM [ROM_WORDS] = '{
    32'h00c0006f, 32'h00000013, 32'h0440006f, 32'h0ff0000f, 32'h7b241073, 32'h10002023,
    32'h40004403, 32'h00147413, 32'h02041063, 32'h40004403, 32'h00247413, 32'h00041463,
    32'hfe5ff06f, 32'h10002423, 32'h7b202473, 32'h7b200073, 32'h7b202473, 32'h10002223,
    32'h33c00067, 32'h10002623, 32'h7b202473, 32'h00100073};

  `TB_CLOCK_RESET

  logic        tck = 0, trst_n = 1, tms = 1, tdi = 0, tdo, tdo_en;
  logic        debug_req, hart_unavail, ndmreset;
  logic        HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [31:0] HADDR, HWDATA, HRDATA;
  logic [1:0]  HTRANS;
  logic [2:0]  HSIZE, HBURST_cpu;
  logic [3:0]  HPROT_cpu;
  logic        HMASTLOCK_cpu;
  logic [SB_ADDR_W-1:0] sba_HADDR;
  logic [SB_DATA_W-1:0] sba_HWDATA, sba_HRDATA;
  logic [1:0]  sba_HTRANS;
  logic        sba_HWRITE, sba_HMASTLOCK, sba_HREADY, sba_HRESP;
  logic [2:0]  sba_HSIZE, sba_HBURST;
  logic [3:0]  sba_HPROT;

  chilimix_debug #(.IDCODE(IDCODE), .IDLE(1), .XLEN(XLEN), .SB_ADDR_W(SB_ADDR_W), .SB_DATA_W(SB_DATA_W)) dut (.*);

  // ---- the "hart": an AHB manager on the DM memory
  logic        c_req_valid, c_req_write, c_req_accept, c_ack_valid, c_ack_error, c_ack_accept;
  logic [31:0] c_req_addr, c_req_wdata, c_ack_rdata;
  logic [2:0]  c_req_size;

  basechili_ahb_manager #(.HADDR_W(32), .HDATA_W(32)) u_cpu (
    .clk, .rst_n,
    .req_valid (c_req_valid), .req_write (c_req_write), .req_addr (c_req_addr), .req_wdata (c_req_wdata),
    .req_size (c_req_size), .req_accept (c_req_accept),
    .ack_valid (c_ack_valid), .ack_error (c_ack_error), .ack_rdata (c_ack_rdata), .ack_accept (c_ack_accept),
    .HADDR (HADDR), .HTRANS (HTRANS), .HWRITE (HWRITE), .HSIZE (HSIZE), .HBURST (HBURST_cpu),
    .HPROT (HPROT_cpu), .HMASTLOCK (HMASTLOCK_cpu), .HWDATA (HWDATA), .HREADY (HREADY), .HRESP (HRESP),
    .HRDATA (HRDATA));

  assign HSEL   = 1'b1;
  assign HREADY = HREADYOUT;

  // one access; handshakes are checked before the rising edge they fire on
  task automatic cpu(input bit write, input logic [31:0] a, input logic [31:0] d, output logic [31:0] r);
    @(negedge clk);
    c_req_valid = 1; c_req_write = write; c_req_addr = a; c_req_wdata = d; c_req_size = 3'd2;
    forever begin #1; if (c_req_accept) break; @(negedge clk); end
    @(negedge clk);
    c_req_valid = 0; c_ack_accept = 1;
    forever begin #1; if (c_ack_valid) break; @(negedge clk); end
    r = c_ack_rdata;
    `CHECK(!c_ack_error, "DM memory access answered OKAY")
    @(negedge clk);
    c_ack_accept = 0;
  endtask

  // ---- the system bus memory: basechili_ahb_sram with an SRAM model
  logic                 s_req, s_we;
  logic [9:0]           s_addr;
  logic [SB_DATA_W-1:0] s_wdata, s_rdata;
  logic [SB_LANES-1:0]  s_be;
  logic [SB_DATA_W-1:0] sram [1024];

  // 32-bit word at byte address a (word k holds k after reset)
  function automatic logic [31:0] word32(int a);
    return 32'(sram[a >> SB_LO] >> (8 * (a % SB_LANES)));
  endfunction

  basechili_ahb_sram #(.ADDR_W(SB_ADDR_W), .DATA_W(SB_DATA_W), .MEM_AW(10)) u_sysmem (
    .clk, .rst_n,
    .HSEL (1'b1), .HADDR (sba_HADDR), .HTRANS (sba_HTRANS), .HWRITE (sba_HWRITE), .HSIZE (sba_HSIZE),
    .HWDATA (sba_HWDATA), .HREADY (sba_HREADY), .HREADYOUT (sba_HREADY), .HRESP (sba_HRESP), .HRDATA (sba_HRDATA),
    .mem_req (s_req), .mem_we (s_we), .mem_addr (s_addr), .mem_wdata (s_wdata), .mem_be (s_be), .mem_rdata (s_rdata));

  always @(posedge clk) if (s_req) begin
    if (s_we) for (int b = 0; b < SB_LANES; b++) begin if (s_be[b]) sram[s_addr][b*8 +: 8] <= s_wdata[b*8 +: 8]; end
    else s_rdata <= sram[s_addr];
  end

  // ---- JTAG
  logic [63:0] sh_out;

  task automatic step(input logic t, input logic d);
    tms = t; tdi = d;
    #(TCK_H);
    tck = 1;
    #(TCK_H);
    tck = 0;
  endtask

  task automatic ir_scan(input logic [4:0] v);
    step(1, 0); step(1, 0); step(0, 0); step(0, 0);
    for (int i = 0; i < 5; i++) step(i == 4, v[i]);
    step(1, 0); step(0, 0);
  endtask

  task automatic dr_scan(input int n, input logic [63:0] v, input int idle);
    step(1, 0); step(0, 0); step(0, 0);
    sh_out = '0;
    for (int i = 0; i < n; i++) begin
      #1 sh_out[i] = tdo;
      step(i == n - 1, v[i]);
    end
    step(1, 0);
    for (int i = 0; i <= idle; i++) step(0, 0);
  endtask

  int idle = 1, n_busy = 0;

  // one DMI access, OpenOCD style; returns the read data
  task automatic dmi(input logic [1:0] op, input logic [6:0] a, input logic [31:0] d, output logic [31:0] r);
    forever begin
      ir_scan(5'h11);
      dr_scan(41, {23'd0, a, d, op}, idle);
      dr_scan(41, '0, idle);                       // nop: result of the access
      if (sh_out[1:0] == 2'd0) begin r = sh_out[33:2]; return; end
      `CHECK(sh_out[1:0] == 2'd3, "DMI op result: only busy is expected")
      n_busy++;
      idle = idle + 2;
      ir_scan(5'h10);
      dr_scan(32, 64'h0001_0000, idle);            // dmireset
    end
  endtask

  logic [31:0] v, r;

  initial begin
    c_req_valid = 0; c_req_write = 0; c_req_addr = '0; c_req_wdata = '0; c_req_size = 3'd2; c_ack_accept = 0;
    hart_unavail = 0;
    for (int i = 0; i < 1024; i++)
      sram[i] = (SB_DATA_W == 64) ? SB_DATA_W'({32'(2 * i + 1), 32'(2 * i)}) : SB_DATA_W'(i);
    tb_reset();
    for (int i = 0; i < 6; i++) step(1, 0);        // Test-Logic-Reset while the tck reset releases
    step(0, 0);
    // ---- JTAG
    dr_scan(32, '0, 0);
    `CHECK(sh_out[31:0] == IDCODE, "IDCODE")
    ir_scan(5'h10);
    dr_scan(32, '0, 0);
    `CHECK(sh_out[3:0] == 4'd1 && sh_out[9:4] == 6'd7 && sh_out[14:12] == 3'd1, "dtmcs: version 1, abits 7, idle 1")
    // ---- DM
    dmi(2'd2, 7'h10, 32'h1, r);
    dmi(2'd1, 7'h11, '0, v);
    `CHECK(v[3:0] == 4'd3 && v[11], "dmstatus: version 3, running")
    // ---- SBA, three sizes
    dmi(2'd2, 7'h38, {11'd0, 1'b0, 3'd2, 2'b00, 15'd0}, r);
    if (SB_ADDR_W > 32) dmi(2'd2, 7'h3A, 32'h0, r);
    dmi(2'd2, 7'h39, 32'h0000_0040, r);
    dmi(2'd2, 7'h3C, 32'hCAFE_F00D, r);
    dmi(2'd2, 7'h38, {11'd0, 1'b0, 3'd0, 2'b00, 15'd0}, r);
    dmi(2'd2, 7'h39, 32'h0000_0045, r);
    dmi(2'd2, 7'h3C, 32'h0000_00A5, r);
    dmi(2'd2, 7'h38, {11'd0, 1'b0, 3'd1, 2'b00, 15'd0}, r);
    dmi(2'd2, 7'h39, 32'h0000_004A, r);
    dmi(2'd2, 7'h3C, 32'h0000_1234, r);
    repeat (10) @(posedge clk);
    `CHECK(word32('h40) == 32'hCAFE_F00D && word32('h44) == 32'h0000_A511 && word32('h48) == 32'h1234_0012,
           "SBA 32 / 8 / 16-bit writes reached the system bus memory")
    if (SB_DATA_W == 64) begin
      dmi(2'd2, 7'h38, {11'd0, 1'b0, 3'd3, 2'b00, 15'd0}, r);
      dmi(2'd2, 7'h39, 32'h0000_0050, r);
      dmi(2'd2, 7'h3D, 32'h0123_4567, r);
      dmi(2'd2, 7'h3C, 32'h89AB_CDEF, r);
      repeat (10) @(posedge clk);
      `CHECK(word32('h50) == 32'h89AB_CDEF && word32('h54) == 32'h0123_4567, "SBA 64-bit write")
      dmi(2'd2, 7'h38, {11'd0, 1'b1, 3'd3, 2'b00, 15'd0}, r);
      dmi(2'd2, 7'h39, 32'h0000_0040, r);
      dmi(2'd1, 7'h3C, '0, v);
      dmi(2'd1, 7'h3D, '0, r);
      `CHECK(v == 32'hCAFE_F00D && r == 32'h0000_A511, "SBA 64-bit read")
    end
    dmi(2'd2, 7'h38, {11'd0, 1'b1, 3'd0, 2'b00, 15'd0}, r);     // byte reads on sbaddress0
    dmi(2'd2, 7'h39, 32'h0000_0043, r);
    dmi(2'd1, 7'h3C, '0, v);
    `CHECK(v == 32'h0000_00CA, "SBA byte read")
    dmi(2'd1, 7'h38, '0, v);
    `CHECK(v[14:12] == 3'd0 && !v[22], "sbcs: no error")
    // ---- halt: debug_req, the hart's HALTED store
    dmi(2'd2, 7'h10, 32'h8000_0001, r);
    repeat (4) @(posedge clk);
    `CHECK(debug_req, "haltreq raises debug_req")
    for (int i = 0; i < ROM_WORDS; i++) begin
      cpu(0, A_ROM + 32'(4 * i), '0, v);
      `CHECK(v == GOLDEN_ROM[i], "ROM over AHB against GNU as")
    end
    cpu(1, A_HALTED, '0, v);
    dmi(2'd2, 7'h10, 32'h0000_0001, r);
    dmi(2'd1, 7'h11, '0, v);
    `CHECK(v[9] && v[8], "dmstatus halted after the hart's HALTED store")
    // ---- resume: FLAGS bit 1, the hart's RESUMING store
    dmi(2'd2, 7'h10, 32'h4000_0001, r);
    cpu(0, A_FLAGS, '0, v);
    `CHECK(v[1] && !v[0], "FLAGS: resume set, go clear")
    cpu(1, A_RESUMING, '0, v);
    dmi(2'd1, 7'h11, '0, v);
    `CHECK(v[17] && !v[9], "resumeack, not halted")
    // ---- ndmreset
    dmi(2'd2, 7'h10, 32'h0000_0003, r);
    repeat (4) @(posedge clk);
    `CHECK(ndmreset, "ndmreset reaches the pin")
    dmi(2'd2, 7'h10, 32'h0000_0001, r);
    $display("busy retries %0d, final idle %0d", n_busy, idle);
    tb_pass();
  end
endmodule
