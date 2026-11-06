// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_i2c_chk (simulation and formal; bound into every chilimix_i2c)
//   - the byte state machine is IDLE one clock after ctr.en clear  (header Invariant)
//   - while the bit engine runs a command it is the byte state's    (header Invariant;
//     in ACK a cr write may change read, so only the state is checked)
//   - bit_cnt is 0 in the START, ACK and STOP states                 (header Invariant)
//   - sta / sto / read / write clear after the command ends          (header Invariant)
//   - irq is the registered iflag & ien                              (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_i2c_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [2:0] state_q,
  input logic       ctr_en,
  input logic [2:0] bit_state,   // u_bit.state_q
  input logic [1:0] bit_cmd_q,   // u_bit.cmd_q: the command the engine runs
  input logic [1:0] bit_cmd,     // the byte state's command
  input logic [2:0] bit_cnt,
  input logic       cmd_end,
  input logic       cr_we,
  input logic [4:0] cmd_q,
  input logic       iflag,
  input logic       ctr_ien,
  input logic       irq
);

  localparam logic [2:0] S_IDLE = 3'd0, S_WRITE = 3'd2, S_READ = 3'd3, S_ACK = 3'd4, S_STOP = 3'd5;

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  i2c_state: assert property (@(posedge clk) disable iff (!rst_n) state_q <= S_STOP)
    else $error("chilimix_i2c: byte state outside the enum");

  i2c_disable: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(ctr_en) || state_q == S_IDLE)
    else $error("chilimix_i2c: byte state machine not idle after ctr.en clear");

  i2c_bit_match: assert property (@(posedge clk) disable iff (!rst_n)
                   bit_state == 3'd0
                   || (state_q != S_IDLE && (state_q == S_ACK || bit_cmd_q == bit_cmd)))
    else $error("chilimix_i2c: the bit engine runs a command the byte state does not issue");

  i2c_bit_cnt: assert property (@(posedge clk) disable iff (!rst_n)
                   state_q == S_IDLE || state_q == S_WRITE || state_q == S_READ || bit_cnt == 3'd0)
    else $error("chilimix_i2c: bit_cnt not 0 in START, ACK or STOP");

  i2c_cmd_clear: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(cmd_end) || $past(cr_we) || cmd_q[4:1] == 4'd0)
    else $error("chilimix_i2c: sta / sto / read / write still set after the command ended");

  i2c_irq: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || irq == $past(iflag && ctr_ien))
    else $error("chilimix_i2c: irq is not the registered iflag & ien");

endmodule

bind chilimix_i2c chilimix_i2c_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state_q   (state_q),
  .ctr_en    (ctr_en),
  .bit_state (u_bit.state_q),
  .bit_cmd_q (u_bit.cmd_q),
  .bit_cmd   (bit_cmd),
  .bit_cnt   (bit_cnt),
  .cmd_end   (cmd_end),
  .cr_we     (cr_we),
  .cmd_q     (cmd_q),
  .iflag     (iflag),
  .ctr_ien   (ctr_ien),
  .irq       (irq)
);
