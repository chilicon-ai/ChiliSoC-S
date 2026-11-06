// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_mod_counter
//
// Modulo-MOD up counter (0 .. MOD-1) with synchronous clear, enable and
// asynchronous active-low reset (falling edge of rst_n). MOD need not be a
// power of two.
//
// Priority  : clr > en. clr sets count to 0; en adds 1, wrapping to 0 after
//             MOD-1.
// Timing    : count shows the new value the cycle after clr / en.
// Invariant : count < MOD.
// -----------------------------------------------------------------------------
module basechili_mod_counter #(
  parameter  int MOD   = 4,                           // number of count values
  localparam int WIDTH = (MOD > 1) ? $clog2(MOD) : 1
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic             clr,     // sync clear to zero
  input  logic             en,      // count up by one (modulo MOD)
  output logic [WIDTH-1:0] count
);

  logic             last;      // count is MOD - 1
  logic [WIDTH-1:0] count_d;   // count + 1, modulo MOD

  assign last    = (count == unsigned'(WIDTH'(MOD - 1)));
  assign count_d = last ? '0 : count + 1'b1;

  basechili_dff_sclr #(.WIDTH(WIDTH)) u_count (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (clr),
    .en    (en),
    .d     (count_d),
    .q     (count)
  );

endmodule
