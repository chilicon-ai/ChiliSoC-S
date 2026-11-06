// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_counter
//
// Up counter with synchronous clear, enable and asynchronous active-low
// reset (falling edge of rst_n).
//
// Priority: clr > en. clr sets count to 0; en adds 1, wrapping to 0 after
//           2**WIDTH - 1.
// Timing  : count shows the new value the cycle after clr / en.
// -----------------------------------------------------------------------------
module basechili_counter #(
  parameter int WIDTH = 8    // counter width in bits
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic             clr,     // sync clear to zero
  input  logic             en,      // count up by one
  output logic [WIDTH-1:0] count
);

  logic [WIDTH-1:0] count_inc;   // count + 1

  assign count_inc = count + 1'b1;

  basechili_dff_sclr #(.WIDTH(WIDTH)) u_count (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (clr),
    .en    (en),
    .d     (count_inc),
    .q     (count)
  );

endmodule
