// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_spi_phy
//
// SPI serial engine of chilimix_spi: takes one frame at a time (up to 15 sck
// cycles of 1, 2 or 4 bits) and runs it on the pins with the SiFive clock
// and chip-select timing:
//   sck   half period = div + 1 clocks; idle level pol; pha 0 samples on the
//         leading edge and shifts on the trailing edge, pha 1 shifts on the
//         leading edge (from the second) and samples on the trailing edge.
//   width proto 0 single (dq0 out, dq1 in), 1 dual (dq1:0), 2 quad (dq3:0),
//         3 single; msb: the first bits out / in are data[7] (else data[0]).
//   cs    a frame with f_cs asserts cs pin csid (none for csid >= N_CS) and
//         waits cssck sck periods before the first edge; after a frame
//         without f_keep it waits sckcs periods, deasserts and keeps cs
//         deasserted for intercs periods. A frame with f_keep leaves cs
//         asserted (S_HELD): the next frame follows after interxfr periods
//         (f_gap) or at once; release, a frame without f_cs or a frame with
//         f_first ends the hold first. A frame without f_cs runs with no cs.
//   rx    a frame with f_rx returns its received bits on rx_data (a fresh
//         register shifted from the input side: MSB first they sit in the
//         low bits, LSB first in the high bits) with rx_valid.
//
// Frame port: f_accept is high in S_IDLE / S_HELD when the frame starts; the
// fields are stored then. f_valid may drop without a transfer (the phy only
// looks at it in S_IDLE and S_HELD).
//
// Timing    : sck and cs are registered (glitch-free); dq_o / dq_oe come from
//             flops through a width mux and stay one clock past the frame's
//             last edge (hold time); rx_valid is a one-cycle pulse the
//             cycle after the last sck edge, rx_data holds until the next
//             frame starts. dq_i is sampled at the sck edge (no synchronizer:
//             the device answers on the opposite edge, half a period earlier).
// Invariants: in S_XFER step < 2 * cycles (0 for an empty frame); cs_active
//             is set in S_LEAD / S_XFER-with-cs / S_HELD / S_GAP / S_TRAIL
//             and clear in S_INTERCS / S_IDLE; cs_q and cs_active are stable
//             during S_XFER; at most one cs pin differs from csdef; sck only
//             changes at a tick of S_XFER, when leaving it, or with pol.
// Debug     : no sck -> state, f_valid, tick_cnt vs div; stuck with cs low
//             -> state S_HELD and release; wrong bits -> fr_proto, fr_msb,
//             tx_sr, step (half periods), pha.
// -----------------------------------------------------------------------------
module chilimix_spi_phy #(
  parameter int N_CS = 1                 // chip select pins, 1 .. 4
) (
  input  logic            clk,
  input  logic            rst_n,         // async, active-low
  // configuration (registers)
  input  logic [11:0]     div,           // sck half period - 1, in clocks
  input  logic            pol,
  input  logic            pha,
  input  logic [7:0]      cssck,
  input  logic [7:0]      sckcs,
  input  logic [7:0]      intercs,
  input  logic [7:0]      interxfr,
  input  logic [1:0]      csid,
  input  logic [N_CS-1:0] csdef,
  input  logic            release_cs,    // end a cs hold (S_HELD)
  // frame in
  input  logic            f_valid,
  output logic            f_accept,
  input  logic [7:0]      f_data,        // bits to send
  input  logic [3:0]      f_cycles,      // sck cycles (0: no edges)
  input  logic [1:0]      f_proto,
  input  logic            f_msb,         // MSB first
  input  logic            f_oe,          // drive the dq pins of the width
  input  logic            f_rx,          // return the received bits
  input  logic            f_cs,          // run with a chip select
  input  logic            f_keep,        // keep cs asserted after the frame
  input  logic            f_gap,         // interxfr before it in a cs hold
  input  logic            f_first,       // needs a fresh cs assertion
  // received frame
  output logic            rx_valid,
  output logic [7:0]      rx_data,
  // status
  output logic            cs_active,     // a chip select is asserted
  output logic            busy,          // not in S_IDLE
  // pins
  output logic            sck,
  output logic [N_CS-1:0] cs,            // csdef, the selected pin inverted while asserted
  output logic [3:0]      dq_o,
  output logic [3:0]      dq_oe,
  input  logic [3:0]      dq_i
);

  typedef enum logic [2:0] {
    S_IDLE    = 3'd0,   // cs deasserted, waiting for a frame
    S_LEAD    = 3'd1,   // cs asserted, cssck before the first edge
    S_XFER    = 3'd2,   // frame on the pins
    S_HELD    = 3'd3,   // cs held between frames
    S_GAP     = 3'd4,   // cs held, interxfr before the next frame
    S_TRAIL   = 3'd5,   // sckcs after the last edge
    S_INTERCS = 3'd6    // cs deasserted, intercs before the next assertion
  } state_e;

  logic [2:0]      state_q;
  state_e          state;
  state_e          state_d;
  logic            st_chg;       // state changes at this edge
  logic [11:0]     tick_cnt;     // clocks in this half period
  logic            tick;         // half period ends at this edge
  logic            tick_clr;
  logic [8:0]      step;         // ticks since entering the state (S_XFER: half period index)
  logic [8:0]      step_d;
  logic            step_load;
  logic [8:0]      last_half;    // index of the frame's last half period
  logic            done;         // frame ends at this edge
  logic [8:0]      wait_tgt;     // ticks the delay state waits
  logic            wait_done;
  logic [7:0]      dly;          // delay of the current delay state
  logic            end_wait;     // S_TRAIL needed after a frame
  state_e          end_state;    // state after the last frame of a cs assertion
  logic            end_deassert; // that state already has cs deasserted
  logic            hold_end;     // S_HELD: end the hold
  logic            assert_cs;    // cs asserted at this edge
  logic            deassert_cs;  // cs deasserted at this edge
  logic            cs_active_d;
  logic [N_CS-1:0] cs_sel;       // csid one-hot (0 for csid >= N_CS)
  logic [3:0]      cs_dec;
  logic [N_CS-1:0] cs_q;         // pin selected at the assertion
  logic [N_CS-1:0] cs_q_d;
  logic [N_CS-1:0] cs_d;
  logic            sck_d;
  // stored frame
  logic [9:0]      f_fields;     // {cycles, proto, msb, oe, rx, keep} of the frame in
  logic [9:0]      fr_fields;
  logic [3:0]      fr_cycles;
  logic [1:0]      fr_proto;
  logic            fr_msb, fr_oe, fr_rx, fr_keep;
  logic            fr_quad, fr_dual;
  logic [7:0]      tx_sr;        // bits still to send (output end: [7] MSB first, [0] LSB first)
  logic [7:0]      tx_sr_d;
  logic            tx_shift;
  logic            tx_sr_en;
  logic [7:0]      tx_next;      // tx_sr after one sck cycle
  logic [7:0]      rx_sr_d;
  logic            rx_shift;
  logic            rx_sr_en;
  logic [7:0]      rx_next;      // rx_data with this edge's input bits
  logic            rx_valid_d;
  logic            in_xfer;
  logic            sck_run;     // S_XFER with sck cycles to run
  logic            was_xfer;     // in S_XFER the cycle before
  logic            drive;        // dq pins driven (S_XFER and one clock after)
  logic            lead_edge;    // tick ends an idle-level half (leading edge)
  logic            trail_edge;   // tick ends an active half (trailing edge)

  basechili_dff #(.WIDTH(3)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state  = state_e'(state_q);
  assign st_chg = (state_d != state);
  assign busy   = (state != S_IDLE);

  // ---- time base: a tick every div + 1 clocks, restarted with each state ---
  assign tick     = (tick_cnt == div);
  assign tick_clr = tick || st_chg;

  basechili_counter #(.WIDTH(12)) u_tick_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (tick_clr),
    .en    (1'b1),
    .count (tick_cnt)
  );

  assign step_load = st_chg;

  basechili_updown_counter #(.WIDTH(9)) u_step (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (step_load),
    .load_val (9'd0),
    .inc      (tick),
    .dec      (1'b0),
    .count    (step),
    .count_d  (step_d)
  );

  assign last_half = {4'd0, fr_cycles, 1'b0} - 9'd1;
  assign done      = (state == S_XFER) && ((fr_cycles == 4'd0) || (tick && step == last_half));

  always_comb begin
    if (state == S_LEAD)       dly = cssck;
    else if (state == S_GAP)   dly = interxfr;
    else if (state == S_TRAIL) dly = sckcs;
    else                       dly = intercs;
  end

  assign wait_tgt  = {dly, 1'b0};
  assign wait_done = (step >= wait_tgt);

  // ---- chip select ----------------------------------------------------------
  basechili_decoder #(.N(4)) u_cs_dec (
    .in  (csid),
    .out (cs_dec)
  );

  assign cs_sel = cs_dec[N_CS-1:0];

  // after the last frame of an assertion: sckcs, then intercs, then idle
  assign end_wait     = (sckcs != 8'd0);
  assign end_state    = end_wait ? S_TRAIL : ((intercs != 8'd0) ? S_INTERCS : S_IDLE);
  assign end_deassert = !end_wait;
  assign hold_end     = release_cs || (f_valid && (!f_cs || f_first));

  always_comb begin
    state_d     = state;
    f_accept    = 1'b0;
    assert_cs   = 1'b0;
    deassert_cs = 1'b0;
    case (state)
      S_IDLE: begin
        if (f_valid) begin
          f_accept  = 1'b1;
          assert_cs = f_cs;
          state_d   = (f_cs && cssck != 8'd0) ? S_LEAD : S_XFER;
        end
      end
      S_LEAD: begin
        if (wait_done) state_d = S_XFER;
      end
      S_XFER: begin
        if (done) begin
          if (!cs_active) begin
            state_d = S_IDLE;
          end else if (fr_keep) begin
            state_d = S_HELD;
          end else begin
            state_d     = end_state;
            deassert_cs = end_deassert;
          end
        end
      end
      S_HELD: begin
        if (hold_end) begin
          state_d     = end_state;
          deassert_cs = end_deassert;
        end else if (f_valid) begin
          f_accept = 1'b1;
          state_d  = (f_gap && interxfr != 8'd0) ? S_GAP : S_XFER;
        end
      end
      S_GAP: begin
        if (wait_done) state_d = S_XFER;
      end
      S_TRAIL: begin
        if (wait_done) begin
          deassert_cs = 1'b1;
          state_d     = (intercs != 8'd0) ? S_INTERCS : S_IDLE;
        end
      end
      S_INTERCS: begin
        if (wait_done) state_d = S_IDLE;
      end
      default: state_d = S_IDLE;
    endcase
  end

  assign cs_active_d = assert_cs || (cs_active && !deassert_cs);
  assign cs_q_d      = assert_cs ? cs_sel : cs_q;

  basechili_dff #(.WIDTH(1)) u_cs_active (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (cs_active_d),
    .q     (cs_active)
  );

  basechili_dffe #(.WIDTH(N_CS)) u_cs_q (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (assert_cs),
    .d     (cs_sel),
    .q     (cs_q)
  );

  always_comb begin
    for (int i = 0; i < N_CS; i++) begin
      cs_d[i] = csdef[i] ^ (cs_active_d && cs_q_d[i]);
    end
  end

  basechili_dff #(.WIDTH(N_CS), .RESET_VAL({N_CS{1'b1}})) u_cs (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (cs_d),
    .q     (cs)
  );

  // ---- serial clock ---------------------------------------------------------
  assign sck_d = pol ^ ((state_d == S_XFER) && step_d[0]);

  basechili_dff #(.WIDTH(1)) u_sck (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (sck_d),
    .q     (sck)
  );

  // ---- stored frame ---------------------------------------------------------
  assign f_fields = {f_cycles, f_proto, f_msb, f_oe, f_rx, f_keep};

  basechili_dffe #(.WIDTH(10)) u_frame (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (f_accept),
    .d     (f_fields),
    .q     (fr_fields)
  );

  assign {fr_cycles, fr_proto, fr_msb, fr_oe, fr_rx, fr_keep} = fr_fields;

  assign fr_quad = (fr_proto == 2'd2);
  assign fr_dual = (fr_proto == 2'd1);

  // ---- data -----------------------------------------------------------------
  assign sck_run   = (state == S_XFER) && (fr_cycles != 4'd0);
  assign lead_edge  = sck_run && tick && !step[0];
  assign trail_edge = sck_run && tick && step[0];
  assign tx_shift   = pha ? (lead_edge && step != 9'd0) : trail_edge;
  assign rx_shift   = pha ? trail_edge : lead_edge;

  always_comb begin
    if (fr_msb) begin
      if (fr_quad)      tx_next = {tx_sr[3:0], 4'd0};
      else if (fr_dual) tx_next = {tx_sr[5:0], 2'd0};
      else              tx_next = {tx_sr[6:0], 1'b0};
      if (fr_quad)      rx_next = {rx_data[3:0], dq_i[3:0]};
      else if (fr_dual) rx_next = {rx_data[5:0], dq_i[1:0]};
      else              rx_next = {rx_data[6:0], dq_i[1]};
      if (fr_quad)      dq_o = tx_sr[7:4];
      else if (fr_dual) dq_o = {2'd0, tx_sr[7:6]};
      else              dq_o = {3'd0, tx_sr[7]};
    end else begin
      if (fr_quad)      tx_next = {4'd0, tx_sr[7:4]};
      else if (fr_dual) tx_next = {2'd0, tx_sr[7:2]};
      else              tx_next = {1'b0, tx_sr[7:1]};
      if (fr_quad)      rx_next = {dq_i[3:0], rx_data[7:4]};
      else if (fr_dual) rx_next = {dq_i[1:0], rx_data[7:2]};
      else              rx_next = {dq_i[1], rx_data[7:1]};
      if (fr_quad)      dq_o = tx_sr[3:0];
      else if (fr_dual) dq_o = {2'd0, tx_sr[1:0]};
      else              dq_o = {3'd0, tx_sr[0]};
    end
  end

  // the pins stay driven one clock past the last edge (hold time at the device)
  assign in_xfer = (state == S_XFER);

  basechili_dff #(.WIDTH(1)) u_was_xfer (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (in_xfer),
    .q     (was_xfer)
  );

  assign drive = in_xfer || was_xfer;

  always_comb begin
    if (!drive || !fr_oe)          dq_oe = 4'b0000;
    else if (fr_quad)              dq_oe = 4'b1111;
    else if (fr_dual)              dq_oe = 4'b0011;
    else                           dq_oe = 4'b0001;
  end

  assign tx_sr_d  = f_accept ? f_data : tx_next;
  assign tx_sr_en = f_accept || tx_shift;

  basechili_dffe #(.WIDTH(8)) u_tx_sr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (tx_sr_en),
    .d     (tx_sr_d),
    .q     (tx_sr)
  );

  assign rx_sr_d  = f_accept ? 8'd0 : rx_next;
  assign rx_sr_en = f_accept || rx_shift;

  basechili_dffe #(.WIDTH(8)) u_rx_sr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rx_sr_en),
    .d     (rx_sr_d),
    .q     (rx_data)
  );

  assign rx_valid_d = done && fr_rx;

  basechili_dff #(.WIDTH(1)) u_rx_valid (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rx_valid_d),
    .q     (rx_valid)
  );

endmodule
