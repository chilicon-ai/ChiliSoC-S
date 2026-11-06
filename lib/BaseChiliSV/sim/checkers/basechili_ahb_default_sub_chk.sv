// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_default_sub_chk (bound into every basechili_ahb_default_sub)
//   - HRESP high only in S_ERR1 / S_ERR2                     (header Invariant)
//   - HREADYOUT low only in S_ERR1; S_ERR1 is always followed by S_ERR2
//     (the ERROR response is two cycles)                     (header Invariant)
// -----------------------------------------------------------------------------
module basechili_ahb_default_sub_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [1:0] state,       // state_q: 0 S_IDLE, 1 S_ERR1, 2 S_ERR2
  input logic       HREADYOUT,
  input logic       HRESP
);

  localparam logic [1:0] S_ERR1 = 2'd1;
  localparam logic [1:0] S_ERR2 = 2'd2;

  assert property (@(posedge clk) disable iff (!rst_n) HRESP |-> (state == S_ERR1 || state == S_ERR2))
    else $error("basechili_ahb_default_sub: HRESP high only in S_ERR1 / S_ERR2 violated: state=%0d", state);

  assert property (@(posedge clk) disable iff (!rst_n) !HREADYOUT |-> state == S_ERR1)
    else $error("basechili_ahb_default_sub: HREADYOUT low only in S_ERR1 violated: state=%0d", state);

  assert property (@(posedge clk) disable iff (!rst_n) state == S_ERR1 |=> state == S_ERR2)
    else $error("basechili_ahb_default_sub: two-cycle ERROR violated: S_ERR1 not followed by S_ERR2");

endmodule

bind basechili_ahb_default_sub basechili_ahb_default_sub_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state     (state_q),
  .HREADYOUT (HREADYOUT),
  .HRESP     (HRESP)
);
