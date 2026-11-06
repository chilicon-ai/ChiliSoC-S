// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_spi_phy_chk (simulation and formal; bound into every chilimix_spi_phy)
//   - in S_XFER step < 2 * cycles (0 for an empty frame)       (header Invariant)
//   - cs_active per state                                       (header Invariant)
//   - cs_active and cs_q stable during a frame                  (header Invariant)
//   - at most one cs pin differs from csdef                     (header Invariant)
//   - sck sits at pol outside S_XFER                            (header Invariant)
//   - dq pins driven only in S_XFER and one clock after
//   - frames are taken only in S_IDLE and S_HELD
// -----------------------------------------------------------------------------
module chilimix_spi_phy_chk #(
  parameter int N_CS = 1
) (
  input logic            clk,
  input logic            rst_n,
  input logic [2:0]      state_q,
  input logic [8:0]      step,
  input logic [3:0]      fr_cycles,
  input logic            cs_active,
  input logic [N_CS-1:0] cs_q,
  input logic [N_CS-1:0] cs,
  input logic [N_CS-1:0] csdef,
  input logic            sck,
  input logic            pol,
  input logic [3:0]      dq_oe,
  input logic            was_xfer,
  input logic            f_accept
);

  localparam logic [2:0] S_IDLE = 3'd0, S_LEAD = 3'd1, S_XFER = 3'd2, S_HELD = 3'd3,
                         S_GAP = 3'd4, S_TRAIL = 3'd5, S_INTERCS = 3'd6;

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic [N_CS-1:0] csdef_q;  // csdef of the previous cycle (the cs pins register it)
  logic [N_CS-1:0] cs_on;    // pins away from it
  always @(posedge clk) csdef_q <= csdef;
  assign cs_on = cs ^ csdef_q;

  spi_phy_step_bound: assert property (@(posedge clk) disable iff (!rst_n)
                   state_q != S_XFER
                   || (fr_cycles == 4'd0 ? step == 9'd0 : step < {4'd0, fr_cycles, 1'b0}))
    else $error("chilimix_spi_phy: half-period index past the frame");

  spi_phy_cs_state: assert property (@(posedge clk) disable iff (!rst_n)
                   ((state_q != S_LEAD && state_q != S_HELD && state_q != S_GAP && state_q != S_TRAIL)
                    || cs_active)
                   && ((state_q != S_IDLE && state_q != S_INTERCS) || !cs_active)
                   && state_q != 3'd7)
    else $error("chilimix_spi_phy: cs_active does not match the state");

  spi_phy_xfer_cs_stable: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(state_q) != S_XFER || state_q != S_XFER
                   || (cs_active == $past(cs_active) && cs_q == $past(cs_q)))
    else $error("chilimix_spi_phy: chip select changed inside a frame");

  spi_phy_cs_onehot: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || (cs_on & (cs_on - N_CS'(1))) == '0)
    else $error("chilimix_spi_phy: more than one cs pin asserted");

  spi_phy_sck_idle: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(state_q) == S_XFER || sck == $past(pol))
    else $error("chilimix_spi_phy: sck moved outside a frame");

  spi_phy_dq_drive: assert property (@(posedge clk) disable iff (!rst_n)
                   dq_oe == 4'd0 || state_q == S_XFER || was_xfer)
    else $error("chilimix_spi_phy: dq pins driven outside a frame");

  spi_phy_accept: assert property (@(posedge clk) disable iff (!rst_n)
                   !f_accept || state_q == S_IDLE || state_q == S_HELD)
    else $error("chilimix_spi_phy: frame taken outside S_IDLE / S_HELD");

endmodule

bind chilimix_spi_phy chilimix_spi_phy_chk #(.N_CS(N_CS)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state_q   (state_q),
  .step      (step),
  .fr_cycles (fr_cycles),
  .cs_active (cs_active),
  .cs_q      (cs_q),
  .cs        (cs),
  .csdef     (csdef),
  .sck       (sck),
  .pol       (pol),
  .dq_oe     (dq_oe),
  .was_xfer  (was_xfer),
  .f_accept  (f_accept)
);
