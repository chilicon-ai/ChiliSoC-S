// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_sram_sp -- memory model with per-lane writes; a
// read returns the word one cycle later; rdata holds during writes and idle
// cycles. Every word is first written all ones, all zeros, then random (all
// lanes), so the uninitialised (X) contents are never compared; then random
// reads, partial writes and idle cycles.
`include "tb_common.svh"
module basechili_sram_sp_tb #(
  parameter  int WIDTH  = 32,
  parameter  int DEPTH  = 1024,
  parameter  int BYTE_W = 8,
  localparam int N_BE   = WIDTH / BYTE_W,
  localparam int AW     = (DEPTH > 1) ? $clog2(DEPTH) : 1
);
  `TB_CLOCK_RESET
  logic             req, we;
  logic [AW-1:0]    addr;
  logic [WIDTH-1:0] wdata, rdata;
  logic [N_BE-1:0]  be;
  logic [WIDTH-1:0] model [DEPTH];   // reference memory
  bit               known [DEPTH];   // word fully written by the TB
  logic [WIDTH-1:0] exp_rd;          // expected rdata
  bit               exp_known;       // exp_rd is defined (a known word was read)

  basechili_sram_sp #(.WIDTH(WIDTH), .DEPTH(DEPTH), .BYTE_W(BYTE_W)) dut (
    .clk, .req, .we, .addr, .wdata, .be, .rdata);

  function automatic logic [WIDTH-1:0] rnd();
    logic [WIDTH-1:0] v;
    for (int b = 0; b < WIDTH; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  // one cycle: drive, clock, update the model, check rdata
  task automatic cycle(logic r, logic w, int a, logic [WIDTH-1:0] d, logic [N_BE-1:0] e);
    req = r; we = w; addr = AW'(a); wdata = d; be = e;
    @(posedge clk); #1;
    if (r && w) begin
      for (int l = 0; l < N_BE; l++)
        if (e[l]) model[a][l*BYTE_W +: BYTE_W] = d[l*BYTE_W +: BYTE_W];
      if (&e) known[a] = 1'b1;
    end else if (r) begin
      exp_rd    = model[a];
      exp_known = known[a];
    end
    if (exp_known) `CHECK(rdata === exp_rd, $sformatf("addr=%0d rdata=%h expected %h", a, rdata, exp_rd))
    @(negedge clk);
  endtask

  initial begin
    req = 1'b0; we = 1'b0; addr = '0; wdata = '0; be = '0;
    exp_known = 1'b0;
    for (int a = 0; a < DEPTH; a++) known[a] = 1'b0;
    tb_reset();
    for (int a = 0; a < DEPTH; a++) cycle(1'b1, 1'b1, a, '1, '1);
    for (int a = 0; a < DEPTH; a++) cycle(1'b1, 1'b0, a, rnd(), N_BE'($urandom));
    for (int a = 0; a < DEPTH; a++) cycle(1'b1, 1'b1, a, '0, '1);
    for (int a = 0; a < DEPTH; a++) cycle(1'b1, 1'b0, a, rnd(), N_BE'($urandom));
    for (int a = 0; a < DEPTH; a++) cycle(1'b1, 1'b1, a, rnd(), '1);
    for (int t = 0; t < 20000; t++) begin
      int a;
      a = $urandom % DEPTH;
      if (t % 4000 < 100) a = (t % 2 == 0) ? 0 : DEPTH - 1;   // corner addresses
      cycle(($urandom % 4 != 0), 1'($urandom), a, rnd(), N_BE'($urandom));
    end
    tb_pass();
  end
endmodule
