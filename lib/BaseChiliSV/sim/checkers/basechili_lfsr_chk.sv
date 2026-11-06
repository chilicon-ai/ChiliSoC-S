// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_lfsr_chk (bound into every basechili_lfsr)
//   - state != 0 when SEED != 0 and no zero was loaded    (header Invariant)
// -----------------------------------------------------------------------------
module basechili_lfsr_chk #(
  parameter int               WIDTH = 16,
  parameter logic [WIDTH-1:0] SEED  = 1
) (
  input logic             clk,
  input logic             rst_n,
  input logic             load,
  input logic [WIDTH-1:0] load_val,
  input logic [WIDTH-1:0] state
);

  logic zero_loaded;   // a zero was loaded since reset (lock-up is the user's)

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)    zero_loaded <= 1'b0;
    else if (load) zero_loaded <= (load_val == '0);
  end

  assert property (@(posedge clk) disable iff (!rst_n) SEED != '0 && !zero_loaded |-> state != '0)
    else $error("basechili_lfsr: state != 0 violated");

endmodule

bind basechili_lfsr basechili_lfsr_chk #(.WIDTH(WIDTH), .SEED(SEED)) u_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .load     (load),
  .load_val (load_val),
  .state    (state)
);
