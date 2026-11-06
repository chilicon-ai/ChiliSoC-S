// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_latch
//
// Level-sensitive D latch, transparent while en is high, no reset.
// Storage primitive and an approved latch: a documented exception to the
// no-latch rule (the other is basechili_clock_gate). Use it only as a
// storage element (e.g. basechili_latch_array), never for logic.
//
// Timing: q follows d while en is high; q holds the value d had when en fell.
// Reset : none; q is undefined until the first en pulse.
// -----------------------------------------------------------------------------
module basechili_latch #(
  parameter int WIDTH = 1    // data width in bits
) (
  input  logic             en,   // transparent while high
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);

  always_latch begin
    if (en) q = d;
  end

endmodule
