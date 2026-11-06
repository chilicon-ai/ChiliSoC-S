// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_i2c_bit
//
// I2C bit engine of chilimix_i2c (as the OpenCores i2c_master bit controller):
// runs one bus command at a time on open-drain scl / sda in five phases of
// prescale + 1 clocks each (a bit period is 5 * (prescale + 1) clocks):
//   phase    A          B        C         D           E
//   START    sda rel.   scl rel. -         sda low     scl low
//   STOP     scl+sda lo scl rel. -         sda rel.    -
//   WRITE    scl low,   -        scl rel.  - (sample)  scl low
//            sda = din
//   READ     as WRITE with sda released
// (START keeps scl as it is in phase A, so it also makes a repeated START
// after a byte.) The engine samples sda at the end of phase D (dout). Between
// commands, and while the next one is not there, both lines hold their last
// level (the master holds scl low after a byte).
//
// Clock stretching: a phase does not count while scl is released but still
// low (a target, or another master, holds it). Arbitration: when the engine
// releases sda and sees it low while scl is high (WRITE C / D with din 1,
// START C), or sees a STOP it did not make, it pulses al, releases both lines
// and goes idle. busy follows the bus: set by a START condition (sda falls
// with scl high), cleared by a STOP (sda rises with scl high), seen from
// any master.
//
// Pins: scl_oe / sda_oe pull the line low (the pad drives 0 while oe is set);
// scl_i / sda_i are the line levels, synchronized here (2 flops).
//
// Timing    : scl_oe / sda_oe are registered; done / al are one-cycle pulses;
//             the inputs reach the checks 2 clocks after the pins.
// Invariants: state is IDLE or a phase A..E; cmd_accept only in IDLE; done
//             only at the tick that ends phase E; in phases B..E of a WRITE
//             or READ sda_oe is the command's data (driven for a WRITE of 0,
//             else released); with ena clear the engine is IDLE and both
//             lines are released one clock later.
// Debug     : no scl -> ena, state, tick_cnt vs prescale, stretch (scl_s low
//             with scl released); al -> state, cmd_q, din_q, sda_s, sto_cond;
//             busy stuck -> sta_cond / sto_cond, scl_s / sda_s.
// -----------------------------------------------------------------------------
module chilimix_i2c_bit (
  input  logic        clk,
  input  logic        rst_n,        // async, active-low
  input  logic        ena,          // core enable (clear: idle, lines released)
  input  logic [15:0] prescale,     // phase length - 1, in clocks (>= 2)
  // command (held until taken)
  input  logic        cmd_valid,
  input  logic [1:0]  cmd,          // 0 START, 1 STOP, 2 WRITE, 3 READ
  input  logic        din,          // WRITE: the bit to send
  output logic        cmd_accept,   // the command starts (IDLE)
  output logic        done,         // pulse: the command finished
  output logic        dout,         // sda sampled in phase D of the last command
  output logic        al,           // pulse: arbitration lost (engine now idle)
  output logic        busy,         // bus busy (START seen, no STOP since)
  // pins (open drain)
  input  logic        scl_i,
  input  logic        sda_i,
  output logic        scl_oe,       // pull scl low
  output logic        sda_oe        // pull sda low
);

  localparam logic [1:0] C_START = 2'd0, C_STOP = 2'd1, C_WRITE = 2'd2, C_READ = 2'd3;

  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_A    = 3'd1,
    S_B    = 3'd2,
    S_C    = 3'd3,
    S_D    = 3'd4,
    S_E    = 3'd5
  } state_e;

  logic [2:0]  state_q;
  state_e      state;
  state_e      state_d;
  logic [1:0]  cmd_q;          // command being run
  logic        din_q;          // its data bit
  logic [15:0] tick_cnt;       // clocks into the phase
  logic        tick;           // the phase ends this cycle
  logic        tick_clr;
  logic        tick_en;
  logic        stretch;        // scl released but low: the phase waits
  logic [1:0]  pins_s;         // {scl, sda} synchronized
  logic        scl_s, sda_s;
  logic        sda_s_q;        // sda_s one clock earlier
  logic        sta_cond;       // START on the bus (sda falls, scl high)
  logic        sto_cond;       // STOP on the bus (sda rises, scl high)
  logic        lost;           // arbitration lost this cycle
  logic        busy_d;
  logic        scl_rel;        // scl released (= !scl_oe)
  logic        sda_rel;
  logic        scl_rel_d, sda_rel_d;
  logic [1:0]  rel_d;          // {scl, sda} released, next
  logic [1:0]  rel_q;
  logic        dout_en;
  logic        sda_want;       // the command's sda in phases A..E (1 released)
  logic        check_sda;      // the engine releases sda and scl is high: sda must be high

  // ---- state ------------------------------------------------------------------
  basechili_dff #(.WIDTH(3)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state      = state_e'(state_q);
  assign cmd_accept = ena && cmd_valid && (state == S_IDLE);

  basechili_dffe #(.WIDTH(3)) u_cmd (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cmd_accept),
    .d     ({cmd, din}),
    .q     ({cmd_q, din_q})
  );

  // ---- inputs -------------------------------------------------------------------
  basechili_sync #(.WIDTH(2), .RESET_VAL(2'b11)) u_sync (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({scl_i, sda_i}),
    .q     (pins_s)
  );

  assign scl_s = pins_s[1];
  assign sda_s = pins_s[0];

  basechili_dff #(.RESET_VAL(1'b1)) u_sda_q (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (sda_s),
    .q     (sda_s_q)
  );

  assign sta_cond = scl_s && sda_s_q && !sda_s;
  assign sto_cond = scl_s && !sda_s_q && sda_s;
  assign busy_d   = sta_cond || (busy && !sto_cond);

  basechili_dff u_busy (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (busy_d),
    .q     (busy)
  );

  // ---- phase time base ------------------------------------------------------------
  assign stretch  = scl_rel && !scl_s;
  assign tick     = (state != S_IDLE) && !stretch && (tick_cnt == prescale);
  assign tick_clr = tick || (state == S_IDLE);
  assign tick_en  = !stretch;

  basechili_counter #(.WIDTH(16)) u_tick_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (tick_clr),
    .en    (tick_en),
    .count (tick_cnt)
  );

  // ---- arbitration --------------------------------------------------------------
  assign check_sda = ((cmd_q == C_WRITE) && din_q && (state == S_C || state == S_D))
                   || ((cmd_q == C_START) && state == S_C);
  assign lost      = (state != S_IDLE)
                   && ((tick && check_sda && !sda_s) || (sto_cond && cmd_q != C_STOP));
  assign al        = lost;

  // ---- sequencing -------------------------------------------------------------------
  always_comb begin
    state_d = state;
    if (!ena || lost) begin
      state_d = S_IDLE;
    end else if (state == S_IDLE) begin
      if (cmd_valid) state_d = S_A;
    end else if (tick) begin
      if (state == S_A)      state_d = S_B;
      else if (state == S_B) state_d = S_C;
      else if (state == S_C) state_d = S_D;
      else if (state == S_D) state_d = S_E;
      else                   state_d = S_IDLE;
    end
  end

  assign done    = ena && !lost && tick && (state == S_E);
  assign dout_en = tick && (state == S_D);

  basechili_dffe #(.RESET_VAL(1'b1)) u_dout (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (dout_en),
    .d     (sda_s),
    .q     (dout)
  );

  // ---- line levels per phase (1 = released) --------------------------------------
  assign sda_want = (cmd_q == C_READ) || din_q;

  always_comb begin
    scl_rel_d = scl_rel;
    sda_rel_d = sda_rel;
    if (!ena || lost) begin
      scl_rel_d = 1'b1;
      sda_rel_d = 1'b1;
    end else begin
      case (state)
        S_A: begin
          if (cmd_q == C_START) begin
            sda_rel_d = 1'b1;
          end else begin
            scl_rel_d = 1'b0;
            sda_rel_d = (cmd_q == C_STOP) ? 1'b0 : sda_want;
          end
        end
        S_B: begin
          if (cmd_q == C_START || cmd_q == C_STOP) scl_rel_d = 1'b1;
        end
        S_C: begin
          scl_rel_d = 1'b1;
        end
        S_D: begin
          if (cmd_q == C_START)     sda_rel_d = 1'b0;
          else if (cmd_q == C_STOP) sda_rel_d = 1'b1;
        end
        S_E: begin
          if (cmd_q != C_STOP) scl_rel_d = 1'b0;
        end
        S_IDLE:  ;
        default: ;
      endcase
    end
  end

  assign rel_d = {scl_rel_d, sda_rel_d};

  basechili_dff #(.WIDTH(2), .RESET_VAL(2'b11)) u_rel (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rel_d),
    .q     (rel_q)
  );

  assign scl_rel = rel_q[1];
  assign sda_rel = rel_q[0];
  assign scl_oe  = !scl_rel;
  assign sda_oe  = !sda_rel;

endmodule
