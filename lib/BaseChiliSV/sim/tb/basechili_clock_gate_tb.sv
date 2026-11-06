// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_clock_gate -- gclk pulses exactly in the clk high
// phases after an enabled falling edge; no glitch when en changes while clk
// is high.
`include "tb_common.svh"
module basechili_clock_gate_tb;
  logic clk = 1'b0;
  logic en, test_en, gclk;
  int   pulses, exp_pulses;

  always #5 clk = ~clk;
  basechili_clock_gate dut (.clk, .en, .test_en, .gclk);

  // gclk must never be high while clk is low, and never change mid high phase
  always @(gclk) if (gclk) `CHECK(clk, "gclk high while clk low")
  always @(posedge gclk) pulses++;
  always @(negedge gclk) `CHECK(!clk, "gclk fell while clk high (glitch)")

  initial begin
    en = 1'b0; test_en = 1'b0; pulses = 0; exp_pulses = 0;
    @(negedge clk);
    for (int t = 0; t < 4000; t++) begin
      // drive in the low phase; the enable for the next high phase
      en = $urandom; test_en = ($urandom % 8) == 0;
      if (en || test_en) exp_pulses++;
      @(posedge clk); #2;
      // toggle en while clk is high: must not affect this high phase
      en = $urandom; test_en = 1'b0;
      `CHECK(pulses == exp_pulses, $sformatf("pulses=%0d expected %0d", pulses, exp_pulses))
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
