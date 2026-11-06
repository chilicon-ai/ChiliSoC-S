// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_tag_compare_chk (bound into every basechili_tag_compare)
//   - hit_way is a subset of valid                           (header Invariant)
//   - hit == |hit_way                                        (header Invariant)
// Combinational module: checked with immediate assertions on every change.
// -----------------------------------------------------------------------------
module basechili_tag_compare_chk #(
  parameter int WAYS = 4
) (
  input logic [WAYS-1:0] valid,
  input logic [WAYS-1:0] hit_way,
  input logic            hit
);

  always_comb begin
    assert ((hit_way & ~valid) == '0)
      else $error("basechili_tag_compare: hit_way subset of valid violated: hit_way=%b valid=%b", hit_way, valid);
    assert (hit == (|hit_way))
      else $error("basechili_tag_compare: hit == |hit_way violated: hit=%b hit_way=%b", hit, hit_way);
  end

endmodule

bind basechili_tag_compare basechili_tag_compare_chk #(.WAYS(WAYS)) u_chk (
  .valid   (valid),
  .hit_way (hit_way),
  .hit     (hit)
);
