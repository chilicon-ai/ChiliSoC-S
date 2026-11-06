// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_uart_rx
//
// 16550 receiver. A low rxd in S_IDLE starts a frame; the start bit is
// checked half a bit later (8 ticks), then every data, parity and the first
// stop bit is sampled in its middle (16 ticks apart). After the stop sample
// out_valid pulses for one cycle with the character (right-aligned, upper
// bits 0 for words under 8 bits) and its errors:
//   pe  parity enabled and the parity bit is wrong (even when eps, odd when
//       not; with stick the expected bit is ~eps)
//   fe  the stop bit is 0
//   bi  break: data, parity and stop bits all 0; the receiver then waits in
//       S_BREAK for rxd to return high before the next frame
// A start bit that is high again at its middle is a glitch: back to S_IDLE.
// The line format (wls, pen, eps, stick) is latched at the start bit, so an
// LCR write mid-frame takes effect from the next frame.
//
// Timing    : out_* are registered state plus combinational decode, valid in
//             the cycle of out_valid (the stop bit's middle tick).
// Invariants: out_valid only in S_STOP; bit_cnt <= nbits_m1; fmt only
//             changes on frame_go.
// Debug     : no character -> state, rxd, tick; wrong data -> u_shift.q,
//             nbits_m1, bit_cnt, fmt_wls; false errors -> par_q, rxd at the stop
//             sample, u_tick_cnt.count (sample point).
// -----------------------------------------------------------------------------
module chilimix_uart_rx (
  input  logic       clk,
  input  logic       rst_n,      // async, active-low
  input  logic       tick,       // 16x baud enable
  input  logic       rxd,        // serial input, synchronous to clk, idle high
  // line format (LCR)
  input  logic [1:0] wls,        // word length 5 + wls
  input  logic       pen,        // parity enable
  input  logic       eps,        // even parity
  input  logic       stick,      // stick parity
  // received characters (one-cycle pulse, no backpressure)
  output logic       out_valid,
  output logic [7:0] out_data,
  output logic       out_pe,     // parity error
  output logic       out_fe,     // framing error
  output logic       out_bi,     // break
  output logic       busy        // inside a frame or a break
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_START  = 3'd1,
    S_DATA   = 3'd2,
    S_PARITY = 3'd3,
    S_STOP   = 3'd4,
    S_BREAK  = 3'd5
  } state_e;

  state_e      state;
  logic [2:0]  state_q;          // FSM state register
  state_e      state_d;
  logic [3:0]  tick_cnt;         // ticks since the last sample point
  logic        mid_start;        // middle of the start bit
  logic        mid;              // middle of a data, parity or stop bit
  logic        tick_clr;         // restart the bit timer
  logic        frame_go;         // falling rxd in S_IDLE
  logic [2:0]  bit_cnt;          // data bits received
  logic [2:0]  nbits_m1;         // data bits - 1
  logic        sample;           // shift rxd in (data bit middle)
  logic        bit_inc;
  logic        bit_clr;
  logic [7:0]  shift_q;          // data bits, last received at bit 7
  logic        par_en;           // parity bit sample
  logic        par_q;            // received parity bit
  logic        par_exp;          // expected parity bit
  logic        stop_mid;         // stop bit sample (character complete)
  logic [4:0]  fmt_d;            // line format to latch: {wls, pen, eps, stick}
  logic [4:0]  fmt;              // line format of the frame in progress
  logic [1:0]  fmt_wls;          // its word length 5 + fmt_wls
  logic        fmt_pen;          // its parity enable
  logic        fmt_eps;          // its even parity
  logic        fmt_stick;        // its stick parity

  assign state = state_e'(state_q);

  assign nbits_m1  = {1'b1, fmt_wls};   // 4 + fmt_wls
  assign frame_go  = (state == S_IDLE) && !rxd;
  assign mid_start = tick && (state == S_START) && (tick_cnt == 4'd7);
  assign mid       = tick && (tick_cnt == 4'd15);
  assign tick_clr  = frame_go || mid_start;

  // ---- line format, latched at the start bit -------------------------------
  assign fmt_d = {wls, pen, eps, stick};

  basechili_dffe #(.WIDTH(5)) u_fmt (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (frame_go),
    .d     (fmt_d),
    .q     (fmt)
  );

  assign fmt_wls   = fmt[4:3];
  assign fmt_pen   = fmt[2];
  assign fmt_eps   = fmt[1];
  assign fmt_stick = fmt[0];

  // ---- bit timer: wraps every 16 ticks, so after the start bit's middle
  //      every wrap is the middle of the next bit
  basechili_counter #(.WIDTH(4)) u_tick_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (tick_clr),
    .en    (tick),
    .count (tick_cnt)
  );

  // ---- data bits ------------------------------------------------------------
  assign sample  = mid && (state == S_DATA);
  assign bit_inc = sample && (bit_cnt != nbits_m1);
  assign bit_clr = frame_go || (sample && (bit_cnt == nbits_m1));

  basechili_counter #(.WIDTH(3)) u_bit_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (bit_clr),
    .en    (bit_inc),
    .count (bit_cnt)
  );

  basechili_shift_reg #(.WIDTH(8), .MSB_FIRST(1'b0)) u_shift (
    .clk       (clk),
    .rst_n     (rst_n),
    .load      (1'b0),
    .load_val  (8'h00),
    .shift     (sample),
    .shift_in  (rxd),
    .q         (shift_q),
    .shift_out ()
  );

  // the first data bit (LSB) is shifted down 8 - (5 + fmt_wls) places too few
  always_comb begin
    case (fmt_wls)
      2'd0:    out_data = {3'b0, shift_q[7:3]};
      2'd1:    out_data = {2'b0, shift_q[7:2]};
      2'd2:    out_data = {1'b0, shift_q[7:1]};
      default: out_data = shift_q;
    endcase
  end

  // ---- parity and stop ------------------------------------------------------
  assign par_en = mid && (state == S_PARITY);

  basechili_dffe #(.WIDTH(1)) u_par (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (par_en),
    .d     (rxd),
    .q     (par_q)
  );

  assign par_exp   = fmt_stick ? !fmt_eps : (fmt_eps ? ^out_data : !(^out_data));
  assign stop_mid  = mid && (state == S_STOP);
  assign out_valid = stop_mid;
  assign out_pe    = fmt_pen && (par_q != par_exp);
  assign out_fe    = !rxd;
  assign out_bi    = !rxd && (out_data == 8'h00) && !(fmt_pen && par_q);
  assign busy      = (state != S_IDLE);

  // ---- frame FSM ------------------------------------------------------------
  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:   if (frame_go) state_d = S_START;
      S_START:  if (mid_start) state_d = rxd ? S_IDLE : S_DATA;
      S_DATA:   if (sample && bit_cnt == nbits_m1) state_d = fmt_pen ? S_PARITY : S_STOP;
      S_PARITY: if (mid) state_d = S_STOP;
      S_STOP:   if (mid) state_d = out_bi ? S_BREAK : S_IDLE;
      S_BREAK:  if (rxd) state_d = S_IDLE;   // wait for the line to go high
      default:  state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH(3), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

endmodule
