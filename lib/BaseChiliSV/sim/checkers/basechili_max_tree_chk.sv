// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_max_tree_chk (bound into every basechili_max_tree)
//   - max_valid == (valid != 0)                              (header Invariant)
//   - when max_valid: valid[max_idx] is set and no valid input is greater
//     than max_val                                           (header Invariant)
// Combinational module: checked with immediate assertions on every change.
// -----------------------------------------------------------------------------
module basechili_max_tree_chk #(
  parameter int N      = 8,
  parameter int W      = 8,
  parameter bit SIGNED = 1'b0,
  parameter int IDX_W  = 3
) (
  input logic [N*W-1:0]   val,
  input logic [N-1:0]     valid,
  input logic             max_valid,
  input logic [W-1:0]     max_val,
  input logic [IDX_W-1:0] max_idx
);

  always_comb begin
    assert (max_valid == (valid != '0))
      else $error("basechili_max_tree: max_valid == (valid != 0) violated: max_valid=%b valid=%b", max_valid, valid);
    if (max_valid) begin
      assert (int'(max_idx) < N && valid[max_idx])
        else $error("basechili_max_tree: valid[max_idx] violated: max_idx=%0d valid=%b", max_idx, valid);
      for (int i = 0; i < N; i++) begin
        if (valid[i]) begin
          assert (SIGNED ? !($signed(val[i*W +: W]) > $signed(max_val)) : !(val[i*W +: W] > max_val))
            else $error("basechili_max_tree: input %0d (%h) greater than max_val %h", i, val[i*W +: W], max_val);
        end
      end
    end
  end

endmodule

bind basechili_max_tree basechili_max_tree_chk #(.N(N), .W(W), .SIGNED(SIGNED), .IDX_W(IDX_W)) u_chk (
  .val       (val),
  .valid     (valid),
  .max_valid (max_valid),
  .max_val   (max_val),
  .max_idx   (max_idx)
);
