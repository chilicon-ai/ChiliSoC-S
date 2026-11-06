// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_lfsr -- next state against the Galois step; load;
// for the default 16-bit polynomial, the period is 2**16 - 1.
`include "tb_common.svh"
module basechili_lfsr_tb #(
  parameter int               WIDTH = 16,
  parameter logic [WIDTH-1:0] POLY  = 16'hB400,
  parameter logic [WIDTH-1:0] SEED  = 1,
  parameter int               PERIOD = 65535   // expected period, 0: not checked
);
  `TB_CLOCK_RESET
  logic             en, load;
  logic [WIDTH-1:0] load_val, state, exp_s, first;

  basechili_lfsr #(.WIDTH(WIDTH), .POLY(POLY), .SEED(SEED)) dut (.clk, .rst_n, .en, .load, .load_val, .state);

  initial begin
    en = 1'b0; load = 1'b0; load_val = '0;
    tb_reset();
    exp_s = SEED;
    for (int t = 0; t < 5000; t++) begin
      `CHECK(state == exp_s, $sformatf("state=%h expected %h", state, exp_s))
      en = $urandom; load = ($urandom % 64) == 0;
      load_val = WIDTH'($urandom) | WIDTH'(1);
      @(posedge clk); #1;
      if (load) exp_s = load_val;
      else if (en) exp_s = {1'b0, exp_s[WIDTH-1:1]} ^ (exp_s[0] ? POLY : '0);
      @(negedge clk);
    end
    if (PERIOD > 0) begin
      int n = 0;
      first = state; en = 1'b1; load = 1'b0;
      do begin @(negedge clk); n++; end while (state != first && n <= PERIOD);
      `CHECK(n == PERIOD, $sformatf("period %0d expected %0d", n, PERIOD))
    end
    tb_pass();
  end
endmodule
