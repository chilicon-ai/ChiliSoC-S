// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_updown_counter
//
// Up/down counter with synchronous load and asynchronous active-low reset
// (falling edge of rst_n).
//
// Priority: load > inc/dec. inc and dec together hold. Wraps modulo
//           2**WIDTH (no saturation).
// Timing  : count_d is combinational: the value count takes on the next
//           clock edge. count shows it the cycle after load / inc / dec.
// -----------------------------------------------------------------------------
module basechili_updown_counter #(
  parameter int               WIDTH     = 8,    // counter width in bits
  parameter logic [WIDTH-1:0] RESET_VAL = '0    // value loaded on reset
) (
  input  logic             clk,
  input  logic             rst_n,     // async, active-low
  input  logic             load,      // sync load of load_val
  input  logic [WIDTH-1:0] load_val,
  input  logic             inc,       // count up by one
  input  logic             dec,       // count down by one
  output logic [WIDTH-1:0] count,
  output logic [WIDTH-1:0] count_d    // next value
);

  always_comb begin
    if (load)             count_d = load_val;
    else if (inc && !dec) count_d = count + 1'b1;
    else if (dec && !inc) count_d = count - 1'b1;
    else                  count_d = count;
  end

  basechili_dff #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_count (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (count_d),
    .q     (count)
  );

endmodule
