// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_uart_tx
//
// 16550 transmitter: sends one character per accepted in_data as a start bit,
// 5 to 8 data bits LSB first, an optional parity bit and 1, 1.5 or 2 stop
// bits, each bit 16 ticks long (tick: the 16x baud enable). The line format
// (wls, stb, pen, and the parity bit from eps / stick) is latched when a
// character is accepted, so an LCR write mid-frame takes effect from the next
// character. brk is live: it holds txd low without disturbing the frame in
// progress.
//
// Parity (pen): even when eps is 1, odd when 0; with stick the parity bit is
// the constant ~eps (16550 stick parity).
//
// Timing    : in_accept is high in S_IDLE (combinational from the state);
//             txd is combinational from registered state; the start bit
//             begins the cycle after the accept.
// Invariants: in_accept only in S_IDLE; bit_cnt <= nbits_m1;
//             busy == (state != S_IDLE); fmt only changes on in_fire.
// Debug     : no output -> state, in_valid, tick; wrong bits -> u_shift.q,
//             bit_cnt, nbits_m1, fmt_wls, par_q; wrong bit length ->
//             u_tick_cnt.count, last, fmt_stb.
// -----------------------------------------------------------------------------
module chilimix_uart_tx (
  input  logic       clk,
  input  logic       rst_n,      // async, active-low
  input  logic       tick,       // 16x baud enable
  // line format (LCR)
  input  logic [1:0] wls,        // word length 5 + wls
  input  logic       stb,        // two stop bits (1.5 with 5-bit words)
  input  logic       pen,        // parity enable
  input  logic       eps,        // even parity
  input  logic       stick,      // stick parity
  input  logic       brk,        // break: txd low
  // characters (valid / accept)
  input  logic       in_valid,
  output logic       in_accept,
  input  logic [7:0] in_data,
  // line
  output logic       txd,        // serial output, idle high
  output logic       busy        // a character is being sent
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_START  = 3'd1,
    S_DATA   = 3'd2,
    S_PARITY = 3'd3,
    S_STOP   = 3'd4
  } state_e;

  state_e      state;
  logic [2:0]  state_q;          // FSM state register
  state_e      state_d;
  logic        in_fire;          // character accepted
  logic [4:0]  tick_cnt;         // ticks into the current bit
  logic [4:0]  last;             // tick_cnt of the current bit's last tick
  logic        bit_end;          // last tick of the current bit
  logic        tick_clr;         // restart the bit timer
  logic [2:0]  bit_cnt;          // data bits sent
  logic [2:0]  nbits_m1;         // data bits - 1
  logic        bit_inc;          // next data bit
  logic        bit_clr;          // data bits done / new character
  logic        shift;            // shift the next data bit out
  logic        shift_out;        // data bit on the line
  logic [3:0]  nbits;            // data bits of the live format: 5 + wls
  logic [7:0]  data_mask;        // data bits of the word length
  logic        par_d;            // parity bit of in_data
  logic        par_q;            // parity bit of the character in flight
  logic        line;             // frame bit on the line
  logic [3:0]  fmt_d;            // line format to latch: {wls, stb, pen}
  logic [3:0]  fmt;              // line format of the character in flight
  logic [1:0]  fmt_wls;          // its word length 5 + fmt_wls
  logic        fmt_stb;          // its stop bits
  logic        fmt_pen;          // its parity enable

  assign state = state_e'(state_q);

  assign in_accept = (state == S_IDLE);
  assign in_fire   = in_valid && in_accept;
  assign busy      = (state != S_IDLE);
  assign nbits_m1  = {1'b1, fmt_wls};   // 4 + fmt_wls

  // ---- line format, latched per character -----------------------------------
  assign fmt_d = {wls, stb, pen};

  basechili_dffe #(.WIDTH(4)) u_fmt (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (in_fire),
    .d     (fmt_d),
    .q     (fmt)
  );

  assign fmt_wls = fmt[3:2];
  assign fmt_stb = fmt[1];
  assign fmt_pen = fmt[0];

  // ---- bit timer: 16 ticks per bit; stop: 16, 24 (1.5) or 32 (2) ---------
  always_comb begin
    last = 5'd15;
    if (state == S_STOP && fmt_stb) last = (fmt_wls == 2'd0) ? 5'd23 : 5'd31;
  end

  assign bit_end  = tick && (tick_cnt == last);
  assign tick_clr = in_fire || bit_end;

  basechili_counter #(.WIDTH(5)) u_tick_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (tick_clr),
    .en    (tick),
    .count (tick_cnt)
  );

  // ---- data bits ----------------------------------------------------------
  assign shift   = bit_end && (state == S_DATA);
  assign bit_inc = shift && (bit_cnt != nbits_m1);
  assign bit_clr = in_fire || (shift && (bit_cnt == nbits_m1));

  basechili_counter #(.WIDTH(3)) u_bit_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (bit_clr),
    .en    (bit_inc),
    .count (bit_cnt)
  );

  basechili_shift_reg #(.WIDTH(8), .MSB_FIRST(1'b0), .RESET_VAL(8'hff)) u_shift (
    .clk       (clk),
    .rst_n     (rst_n),
    .load      (in_fire),
    .load_val  (in_data),
    .shift     (shift),
    .shift_in  (1'b1),
    .q         (),
    .shift_out (shift_out)
  );

  // ---- parity (of in_data at accept, with the live format) ------------------
  assign nbits = 4'd5 + {2'b0, wls};

  basechili_thermo_encoder #(.N(8)) u_data_mask (
    .in  (nbits),
    .out (data_mask)
  );

  assign par_d = stick ? !eps : (eps ? ^(in_data & data_mask) : !(^(in_data & data_mask)));

  basechili_dffe #(.WIDTH(1), .RESET_VAL(1'b1)) u_par (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (in_fire),
    .d     (par_d),
    .q     (par_q)
  );

  // ---- frame FSM ------------------------------------------------------------
  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:   if (in_fire) state_d = S_START;
      S_START:  if (bit_end) state_d = S_DATA;
      S_DATA:   if (bit_end && bit_cnt == nbits_m1) state_d = fmt_pen ? S_PARITY : S_STOP;
      S_PARITY: if (bit_end) state_d = S_STOP;
      S_STOP:   if (bit_end) state_d = S_IDLE;
      default:  state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH(3), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  always_comb begin
    case (state)
      S_START:  line = 1'b0;
      S_DATA:   line = shift_out;
      S_PARITY: line = par_q;
      S_IDLE,
      S_STOP:   line = 1'b1;
      default:  line = 1'b1;
    endcase
  end

  assign txd = line && !brk;

endmodule
