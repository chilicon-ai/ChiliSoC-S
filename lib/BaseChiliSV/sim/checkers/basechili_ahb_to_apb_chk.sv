// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_to_apb_chk (bound into every basechili_ahb_to_apb)
//   - PENABLE only in S_ACCESS; PSEL in S_SETUP and S_ACCESS
//   - HREADYOUT low in S_SETUP, S_ACCESS and S_ERR1
//   - HRESP high only in S_ERR1 and S_ERR2                  (header Invariants)
// State encodings follow the module's state_e.
// -----------------------------------------------------------------------------
module basechili_ahb_to_apb_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [2:0] state,
  input logic       PSEL,
  input logic       PENABLE,
  input logic       HREADYOUT,
  input logic       HRESP
);

  localparam logic [2:0] S_SETUP  = 3'd1;
  localparam logic [2:0] S_ACCESS = 3'd2;
  localparam logic [2:0] S_ERR1   = 3'd4;
  localparam logic [2:0] S_ERR2   = 3'd5;

  logic in_apb;   // S_SETUP or S_ACCESS
  assign in_apb = (state == S_SETUP) || (state == S_ACCESS);

  assert property (@(posedge clk) disable iff (!rst_n) PENABLE == (state == S_ACCESS))
    else $error("basechili_ahb_to_apb: PENABLE only in S_ACCESS violated: state=%0d PENABLE=%b", state, PENABLE);

  assert property (@(posedge clk) disable iff (!rst_n) PSEL == in_apb)
    else $error("basechili_ahb_to_apb: PSEL in S_SETUP / S_ACCESS violated: state=%0d PSEL=%b", state, PSEL);

  assert property (@(posedge clk) disable iff (!rst_n) HREADYOUT == !(in_apb || state == S_ERR1))
    else $error("basechili_ahb_to_apb: HREADYOUT low in S_SETUP / S_ACCESS / S_ERR1 violated: state=%0d HREADYOUT=%b",
                state, HREADYOUT);

  assert property (@(posedge clk) disable iff (!rst_n) HRESP == (state == S_ERR1 || state == S_ERR2))
    else $error("basechili_ahb_to_apb: HRESP only in S_ERR1 / S_ERR2 violated: state=%0d HRESP=%b", state, HRESP);

endmodule

bind basechili_ahb_to_apb basechili_ahb_to_apb_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state     (state),
  .PSEL      (PSEL),
  .PENABLE   (PENABLE),
  .HREADYOUT (HREADYOUT),
  .HRESP     (HRESP)
);
