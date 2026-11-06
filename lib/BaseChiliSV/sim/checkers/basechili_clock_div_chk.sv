// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_clock_div_chk (bound into every basechili_clock_div)
//   - cnt < div_q; tick == (cnt == div_q - 1)               (header Invariants)
//   - div_q >= 2 (values below 2 act as 2)                  (header)
//   - even_hi and odd_hi never both high                    (header Invariant)
// -----------------------------------------------------------------------------
module basechili_clock_div_chk #(
  parameter int W = 8
) (
  input logic         clk,
  input logic [W-1:0] cnt,
  input logic [W-1:0] div_q,
  input logic         tick,
  input logic         even_hi,
  input logic         odd_hi
);

  assert property (@(posedge clk) cnt < div_q)
    else $error("basechili_clock_div: cnt < div_q violated: cnt=%0d div_q=%0d", cnt, div_q);

  assert property (@(posedge clk) tick == (cnt == W'(div_q - 1'b1)))
    else $error("basechili_clock_div: tick == (cnt == div_q - 1) violated: tick=%b cnt=%0d div_q=%0d",
                tick, cnt, div_q);

  assert property (@(posedge clk) div_q >= W'(2))
    else $error("basechili_clock_div: div_q=%0d below 2", div_q);

  assert property (@(posedge clk) !(even_hi && odd_hi))
    else $error("basechili_clock_div: even_hi and odd_hi both high");

endmodule

bind basechili_clock_div basechili_clock_div_chk #(.W(W)) u_chk (
  .clk   (clk),
  .cnt   (cnt),
  .div_q (div_q),
  .tick    (tick),
  .even_hi (even_hi),
  .odd_hi  (odd_hi)
);
