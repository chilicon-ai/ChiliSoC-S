// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_reset_ctrl_chk (bound into every basechili_reset_ctrl)
//   - with sw_rst all zero, releases come in index order: release_d is a
//     run of ones from bit 0, and so is rel when sw_rst was zero the cycle
//     before                                                 (header Invariant)
//   - step never decreases while srst_n is high              (header Invariant)
//   - step <= N; test_en passes rst_n_async to every output  (header)
// -----------------------------------------------------------------------------
module basechili_reset_ctrl_chk #(
  parameter int N  = 3,
  parameter int SW = 2
) (
  input logic          clk,
  input logic          rst_n_async,
  input logic          test_en,
  input logic          srst_n,
  input logic [N-1:0]  sw_rst,
  input logic [N-1:0]  release_d,
  input logic [N-1:0]  rel,
  input logic [N-1:0]  rst_n_out,
  input logic [SW-1:0] step
);

  // a run of ones from bit 0 (0, 1, 11, 111, ...)
  function automatic bit ordered(logic [N-1:0] v);
    return (v & N'(v + 1'b1)) == '0;
  endfunction

  assert property (@(posedge clk) sw_rst == '0 |-> ordered(release_d))
    else $error("basechili_reset_ctrl: release order violated: release_d=%b", release_d);

  assert property (@(posedge clk) sw_rst == '0 |=> ordered(rel))
    else $error("basechili_reset_ctrl: release order violated: rel=%b", rel);

  // srst_n has stayed high since the previous rising edge (a short low pulse
  // between edges, e.g. through test_en, resets step legally)
  logic held = 1'b0;
  always @(posedge clk or negedge srst_n)
    if (!srst_n) held <= 1'b0;
    else         held <= 1'b1;

  assert property (@(posedge clk) held && srst_n |-> step >= $past(step))
    else $error("basechili_reset_ctrl: step decreased while srst_n high: %0d -> %0d", $past(step), step);

  assert property (@(posedge clk) step <= SW'(N))
    else $error("basechili_reset_ctrl: step=%0d above N=%0d", step, N);

  assert property (@(posedge clk) test_en |-> rst_n_out == {N{rst_n_async}})
    else $error("basechili_reset_ctrl: test_en bypass violated: rst_n_out=%b rst_n_async=%b",
                rst_n_out, rst_n_async);

endmodule

bind basechili_reset_ctrl basechili_reset_ctrl_chk #(.N(N), .SW(SW)) u_chk (
  .clk         (clk),
  .rst_n_async (rst_n_async),
  .test_en     (test_en),
  .srst_n      (srst_n),
  .sw_rst      (sw_rst),
  .release_d   (release_d),
  .rel         (rel),
  .rst_n_out   (rst_n_out),
  .step        (step)
);
