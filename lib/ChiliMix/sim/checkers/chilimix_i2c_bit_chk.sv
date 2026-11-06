// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_i2c_bit_chk (simulation and formal; bound into every chilimix_i2c_bit)
//   - state is IDLE or a phase A .. E                           (header Invariant)
//   - cmd_accept only in IDLE                                   (header Invariant)
//   - done only at the tick that ends phase E                   (header Invariant)
//   - in phases B .. E of a WRITE / READ sda_oe is the data     (header Invariant)
//   - with ena clear: IDLE and both lines released next clock   (header Invariant)
//   - al only while a command runs
// -----------------------------------------------------------------------------
module chilimix_i2c_bit_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [2:0] state_q,
  input logic [1:0] cmd_q,
  input logic       din_q,
  input logic       ena,
  input logic       tick,
  input logic       cmd_accept,
  input logic       done,
  input logic       al,
  input logic       scl_oe,
  input logic       sda_oe
);

  localparam logic [2:0] S_IDLE = 3'd0, S_B = 3'd2, S_C = 3'd3, S_D = 3'd4, S_E = 3'd5;
  localparam logic [1:0] C_WRITE = 2'd2, C_READ = 2'd3;

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic data_phase;      // phases B .. E of a WRITE or READ
  assign data_phase = (state_q == S_B || state_q == S_C || state_q == S_D || state_q == S_E)
                      && (cmd_q == C_WRITE || cmd_q == C_READ);

  i2c_bit_state: assert property (@(posedge clk) disable iff (!rst_n) state_q <= S_E)
    else $error("chilimix_i2c_bit: state outside IDLE / A .. E");

  i2c_bit_accept: assert property (@(posedge clk) disable iff (!rst_n)
                   !cmd_accept || state_q == S_IDLE)
    else $error("chilimix_i2c_bit: command taken outside IDLE");

  i2c_bit_done: assert property (@(posedge clk) disable iff (!rst_n)
                   !done || (tick && state_q == S_E))
    else $error("chilimix_i2c_bit: done outside the end of phase E");

  i2c_bit_data: assert property (@(posedge clk) disable iff (!rst_n)
                   !data_phase || sda_oe == (cmd_q == C_WRITE && !din_q))
    else $error("chilimix_i2c_bit: sda changed while scl may be high in a bit");

  i2c_bit_disable: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(ena) || (state_q == S_IDLE && !scl_oe && !sda_oe))
    else $error("chilimix_i2c_bit: not idle and released after ena clear");

  i2c_bit_al: assert property (@(posedge clk) disable iff (!rst_n) !al || state_q != S_IDLE)
    else $error("chilimix_i2c_bit: al while idle");

endmodule

bind chilimix_i2c_bit chilimix_i2c_bit_chk u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .state_q    (state_q),
  .cmd_q      (cmd_q),
  .din_q      (din_q),
  .ena        (ena),
  .tick       (tick),
  .cmd_accept (cmd_accept),
  .done       (done),
  .al         (al),
  .scl_oe     (scl_oe),
  .sda_oe     (sda_oe)
);
