// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_apb_regbank_chk (bound into every basechili_apb_regbank)
//   - wr_pulse / rd_pulse are zero or one-hot and only in an ACCESS phase
//   - reg_q bits outside RW_MASK | W1C_MASK are 0           (header Invariants)
// -----------------------------------------------------------------------------
module basechili_apb_regbank_chk #(
  parameter int                  DATA_W   = 32,
  parameter int                  N        = 4,
  parameter logic [N*DATA_W-1:0] RW_MASK  = '1,
  parameter logic [N*DATA_W-1:0] W1C_MASK = '0
) (
  input logic                clk,
  input logic                rst_n,
  input logic                PSEL,
  input logic                PENABLE,
  input logic [N*DATA_W-1:0] reg_q,
  input logic [N-1:0]        wr_pulse,
  input logic [N-1:0]        rd_pulse
);

  assert property (@(posedge clk) disable iff (!rst_n) $onehot0(wr_pulse) && $onehot0(rd_pulse))
    else $error("basechili_apb_regbank: pulses zero or one-hot violated: wr_pulse=%b rd_pulse=%b", wr_pulse, rd_pulse);

  assert property (@(posedge clk) disable iff (!rst_n) !(PSEL && PENABLE) |-> (wr_pulse | rd_pulse) == '0)
    else $error("basechili_apb_regbank: pulse outside ACCESS: wr_pulse=%b rd_pulse=%b", wr_pulse, rd_pulse);

  assert property (@(posedge clk) disable iff (!rst_n) (reg_q & ~(RW_MASK | W1C_MASK)) == '0)
    else $error("basechili_apb_regbank: reg_q read-only bits not 0: reg_q=%h", reg_q);

endmodule

bind basechili_apb_regbank basechili_apb_regbank_chk #(.DATA_W(DATA_W), .N(N), .RW_MASK(RW_MASK),
                                                       .W1C_MASK(W1C_MASK)) u_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .PSEL     (PSEL),
  .PENABLE  (PENABLE),
  .reg_q    (reg_q),
  .wr_pulse (wr_pulse),
  .rd_pulse (rd_pulse)
);
