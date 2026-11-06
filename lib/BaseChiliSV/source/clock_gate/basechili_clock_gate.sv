// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_clock_gate
//
// Glitch-free integrated clock gate (latch + AND): gclk = clk & en_l, where
// en_l is (en || test_en) held by a latch that is transparent while clk is
// low. A change of en while clk is high takes effect after the next falling
// edge, so gclk never glitches.
// Clock primitive and an approved latch: a documented exception to the
// no-latch rule. The latch and the AND are written together in this
// one module, in the standard ICG form, so implementation tools recognize the
// clock gate (and can map it to a library ICG cell).
//
// Timing: en (or test_en) high in the cycle before a rising clk edge gives a
//         full gclk high pulse from that edge to the next falling edge.
// Debug : missing gclk pulse -> en_l at the rising edge; it must have been
//         high while clk was low.
// -----------------------------------------------------------------------------
module basechili_clock_gate (
  input  logic clk,
  input  logic en,        // enable for the next clk high phase
  input  logic test_en,   // scan / test override: clock always on
  output logic gclk       // gated clock
);

  logic en_l;   // en || test_en, held through the clk high phase

  always_latch begin
    if (!clk) en_l = en || test_en;
  end

  assign gclk = clk && en_l;

endmodule
