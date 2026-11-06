// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_decoder_chk (bound into every basechili_ahb_decoder)
//   - sel_default == (sel == 0)                              (header Invariant)
//   - sel zero or one-hot, when the BASE / MASK regions do not overlap
//     (checked at elaboration: regions i, j overlap when both can match and
//     their bases agree on the bits both masks compare) (header Invariant)
// -----------------------------------------------------------------------------
module basechili_ahb_decoder_chk #(
  parameter int                  ADDR_W = 32,
  parameter int                  N      = 2,
  parameter logic [N*ADDR_W-1:0] BASE   = '0,
  parameter logic [N*ADDR_W-1:0] MASK   = '0
) (
  input logic [N-1:0] sel,
  input logic         sel_default
);

  function automatic bit disjoint();
    for (int i = 0; i < N; i++) begin
      for (int j = i + 1; j < N; j++) begin
        logic [ADDR_W-1:0] bi = BASE[i*ADDR_W +: ADDR_W], mi = MASK[i*ADDR_W +: ADDR_W];
        logic [ADDR_W-1:0] bj = BASE[j*ADDR_W +: ADDR_W], mj = MASK[j*ADDR_W +: ADDR_W];
        if ((bi & ~mi) == '0 && (bj & ~mj) == '0 && ((bi ^ bj) & mi & mj) == '0)
          return 1'b0;
      end
    end
    return 1'b1;
  endfunction

  localparam bit DISJOINT = disjoint();

  always_comb begin
    assert (sel_default == (sel == '0))
      else $error("basechili_ahb_decoder: sel_default == (sel == 0) violated: sel=%b sel_default=%b", sel, sel_default);
    assert (!DISJOINT || $onehot0(sel))
      else $error("basechili_ahb_decoder: sel zero or one-hot (non-overlapping regions) violated: sel=%b", sel);
  end

endmodule

bind basechili_ahb_decoder basechili_ahb_decoder_chk #(.ADDR_W(ADDR_W), .N(N), .BASE(BASE), .MASK(MASK)) u_chk (
  .sel         (sel),
  .sel_default (sel_default)
);
