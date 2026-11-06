// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_mul_lo_chk (bound into every basechili_mul_lo)
//   - vld[k] is in_valid delayed by k edges; out_valid == vld[LATENCY]
//     (header Invariants)
//   - out_valid pulses exactly LATENCY edges after in_valid, with that
//     operation's a * b mod 2^32, in order (header; reference model)
//   - product holds while out_valid is low (header Invariants: stage
//     registers load only on vld[k-1], so product holds after the last result)
// -----------------------------------------------------------------------------
module basechili_mul_lo_chk #(
  parameter int LATENCY = 1
) (
  input logic             clk,
  input logic             rst_n,
  input logic             in_valid,
  input logic [31:0]      a,
  input logic [31:0]      b,
  input logic             out_valid,
  input logic [31:0]      product,
  input logic [LATENCY:0] vld
);

  logic [LATENCY:0] vld_ref;             // vld_ref[k]: in_valid k edges ago
  logic [31:0]      exp_p [LATENCY+1];   // expected product per stage

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vld_ref <= '0;
      for (int k = 0; k <= LATENCY; k++) exp_p[k] <= '0;
    end else begin
      vld_ref <= {vld_ref[LATENCY-1:0], in_valid};
      exp_p[1] <= a * b;
      for (int k = 2; k <= LATENCY; k++) exp_p[k] <= exp_p[k-1];
    end
  end

  assert property (@(posedge clk) disable iff (!rst_n) vld[LATENCY:1] == vld_ref[LATENCY-1:0])
    else $error("basechili_mul_lo: vld[k] == in_valid delayed by k violated: vld=%b expected=%b",
                vld[LATENCY:1], vld_ref[LATENCY-1:0]);

  assert property (@(posedge clk) disable iff (!rst_n) out_valid == vld[LATENCY])
    else $error("basechili_mul_lo: out_valid == vld[LATENCY] violated: out_valid=%b vld=%b", out_valid, vld);

  assert property (@(posedge clk) disable iff (!rst_n) out_valid |-> product == exp_p[LATENCY])
    else $error("basechili_mul_lo: product == a * b mod 2^32 (LATENCY %0d edges earlier) violated: product=%h expected=%h",
                LATENCY, product, exp_p[LATENCY]);

  assert property (@(posedge clk) disable iff (!rst_n) !out_valid |-> $stable(product))
    else $error("basechili_mul_lo: product holds while out_valid is low violated: product=%h before=%h",
                product, $past(product));

endmodule

bind basechili_mul_lo basechili_mul_lo_chk #(.LATENCY(LATENCY)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .in_valid  (in_valid),
  .a         (a),
  .b         (b),
  .out_valid (out_valid),
  .product   (product),
  .vld       (vld)
);
