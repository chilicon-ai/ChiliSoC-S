// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_lfsr
//
// Galois linear-feedback shift register (pseudo-random sequence, test
// pattern, scrambler). On each enabled step the state shifts right and,
// when the bit shifted out is 1, is XORed with POLY:
//
//   state_d = {1'b0, state[WIDTH-1:1]} ^ (state[0] ? POLY : 0)
//
// With a primitive polynomial (bit k of POLY = the x^(k+1) term, top bit
// set) the sequence visits all 2**WIDTH - 1 non-zero states. The default is
// x^16 + x^14 + x^13 + x^11 + 1.
//
// Priority  : load > en.
// Timing    : state shows the next value the cycle after en / load.
// Invariant : state != 0 when SEED != 0 and no zero was loaded (zero is a
//             lock-up state).
// -----------------------------------------------------------------------------
module basechili_lfsr #(
  parameter int               WIDTH = 16,          // state width in bits
  parameter logic [WIDTH-1:0] POLY  = 16'hB400,    // feedback taps (Galois form)
  parameter logic [WIDTH-1:0] SEED  = 1            // reset state, non-zero
) (
  input  logic             clk,
  input  logic             rst_n,      // async, active-low
  input  logic             en,         // advance one step
  input  logic             load,       // sync load of load_val
  input  logic [WIDTH-1:0] load_val,   // non-zero
  output logic [WIDTH-1:0] state
);

  logic [WIDTH-1:0] step;       // state after one step
  logic [WIDTH-1:0] state_d;
  logic             state_en;

  assign step     = {1'b0, state[WIDTH-1:1]} ^ (POLY & {WIDTH{state[0]}});
  assign state_d  = load ? load_val : step;
  assign state_en = load || en;

  basechili_dffe #(.WIDTH(WIDTH), .RESET_VAL(SEED)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (state_en),
    .d     (state_d),
    .q     (state)
  );

endmodule
