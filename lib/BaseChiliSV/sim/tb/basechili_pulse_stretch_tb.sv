// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_pulse_stretch -- single pulses, bursts and
// retriggers per bit against a model: out is high for CYCLES cycles after
// the last high cycle of in.
`include "tb_common.svh"
module basechili_pulse_stretch_tb #(
  parameter int WIDTH  = 1,
  parameter int CYCLES = 4
);
  `TB_CLOCK_RESET
  logic [WIDTH-1:0] in, out, exp_o;
  int               left [WIDTH];   // model: high cycles still to come

  basechili_pulse_stretch #(.WIDTH(WIDTH), .CYCLES(CYCLES)) dut (.clk, .rst_n, .in, .out);

  initial begin
    in = '0;
    tb_reset();
    for (int i = 0; i < WIDTH; i++) left[i] = 0;
    for (int t = 0; t < 20000; t++) begin
      for (int i = 0; i < WIDTH; i++) exp_o[i] = left[i] > 0;
      `CHECK(out == exp_o, $sformatf("t=%0d out=%b expected %b", t, out, exp_o))
      for (int i = 0; i < WIDTH; i++) begin
        // phases: sparse single pulses, then bursts and gaps near CYCLES
        in[i] = (t < 10000) ? (($urandom % (2 * CYCLES + 3)) == 0) : (($urandom % 3) == 0);
        if (in[i]) left[i] = CYCLES;
        else if (left[i] > 0) left[i]--;
      end
      @(negedge clk);
    end
    tb_reset();
    tb_pass();
  end
endmodule
