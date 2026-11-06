// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_dff_sclr
//
// D flip-flop with synchronous clear, enable and asynchronous active-low
// reset (falling edge of rst_n). Storage primitive: one of the few modules
// allowed to contain always_ff.
//
// Priority: clr > en. clr loads CLR_VAL; en loads d; otherwise q holds.
// Timing  : q shows the new value the cycle after clr / en.
// Reset   : q = RESET_VAL as soon as rst_n falls, and while rst_n is low.
// -----------------------------------------------------------------------------
module basechili_dff_sclr #(
  parameter int               WIDTH     = 1,           // data width in bits
  parameter logic [WIDTH-1:0] RESET_VAL = '0,          // value loaded on reset
  parameter logic [WIDTH-1:0] CLR_VAL   = RESET_VAL    // value loaded by clr
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic             clr,     // sync clear to CLR_VAL
  input  logic             en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)   q <= RESET_VAL;
    else if (clr) q <= CLR_VAL;
    else if (en)  q <= d;
  end

endmodule
