// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_i2c
//
// I2C master in the OpenCores i2c_master register layout (sifive,i2c0, as
// the FU540), so the Linux i2c-ocores and Zephyr i2c_sifive drivers work:
//   0x00 prer_lo   0x08 ctr        0x10 cr (write) / sr (read)
//   0x04 prer_hi   0x0C txr (write) / rxr (read)
// A command (cr, while ctr.en is set) runs a byte transfer: an optional
// (repeated) START (sta), then a byte written from txr (write) or read into
// rxr (read) with its acknowledge bit (the target's into sr.rxack for a
// write, cr.ack sent for a read), then an optional STOP (sto); sto alone
// sends just a STOP. sta, sto, read and write clear themselves when the
// command finishes or arbitration is lost; sr.tip is set meanwhile. The
// bus phases come from chilimix_i2c_bit (bit period 5 * (prescale + 1)
// clocks, clock stretching, arbitration, bus busy).
//
// Interrupt: sr.iflag is set when a command finishes or arbitration is lost
// and cleared by cr.iack; irq = iflag & ctr.ien, registered.
//
// Timing    : APB reads are combinational (no wait states); irq is
//             registered; pins as chilimix_i2c_bit (registered).
// Invariants: the byte state machine is IDLE while ctr.en is clear (one
//             clock later); while the bit engine runs a command it is the
//             command of the byte state; bit_cnt is 0 in the START, ACK
//             and STOP states; sta / sto / read / write are clear the cycle
//             after a command finishes or arbitration is lost (unless cr is
//             written then); irq is the registered iflag & ien.
// Debug     : nothing on the bus -> ctr_en, cmd_wr / cmd_rd / cmd_sto,
//             state, u_bit.state; stuck in a byte -> u_bit.stretch (scl held
//             low by the target), bit_cnt; sr.al -> u_bit.lost.
// -----------------------------------------------------------------------------
module chilimix_i2c (
  input  logic        clk,
  input  logic        rst_n,       // async, active-low
  // APB4 subordinate (registers)
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [4:0]  PADDR,       // byte address inside the controller
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,
  // pins (open drain: the pad drives 0 while oe is set)
  input  logic        scl_i,
  input  logic        sda_i,
  output logic        scl_oe,
  output logic        sda_oe,
  // interrupt (level, active high)
  output logic        irq
);

  localparam logic [1:0] C_START = 2'd0, C_STOP = 2'd1, C_WRITE = 2'd2, C_READ = 2'd3;

  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_START = 3'd1,
    S_WRITE = 3'd2,
    S_READ  = 3'd3,
    S_ACK   = 3'd4,
    S_STOP  = 3'd5
  } state_e;

  // ---- register fields --------------------------------------------------------
  logic [7:0]  prer_lo_value, prer_hi_value;
  logic        ctr_ien, ctr_en;
  logic [7:0]  txr_data;
  logic        cr_iack, cr_ack, cr_write, cr_read, cr_sto, cr_sta, cr_wr;

  // ---- command and status ---------------------------------------------------------
  logic        cr_we;          // a cr write that counts (byte 0, ctr.en set)
  logic        iack;
  logic [4:0]  cmd_d, cmd_q;   // {sta, sto, read, write, ack}
  logic        cmd_sta, cmd_sto, cmd_rd, cmd_wr, cmd_ack;
  logic        cmd_end;        // command finished or arbitration lost
  logic        iflag, iflag_d;
  logic        al_q, al_d;
  logic        rxack, rxack_en;
  logic        irq_d;
  logic        tip;

  // ---- byte state machine -------------------------------------------------------
  logic [2:0]  state_q;
  state_e      state;
  state_e      state_d;
  logic        go;             // a command waits and the bus engine is free
  logic        cmd_done;       // pulse: the command finished
  logic        bit_valid;
  logic [1:0]  bit_cmd;
  logic        bit_din;
  logic        bit_done;
  logic        bit_dout;
  logic        bit_al;
  logic        bit_busy;
  logic [15:0] prescale;
  logic [7:0]  sr;             // shift register: txr out, bus bits in (rxr)
  logic        sr_msb;
  logic        sr_shift;
  logic        last_bit;       // the eighth bit of the byte
  logic [2:0]  bit_cnt;        // bits of the byte done

  // ---- registers ----------------------------------------------------------------
  chilimix_i2c_regs u_regs (
    .clk           (clk),
    .rst_n         (rst_n),
    .PSEL          (PSEL),
    .PENABLE       (PENABLE),
    .PWRITE        (PWRITE),
    .PADDR         (PADDR),
    .PWDATA        (PWDATA),
    .PSTRB         (PSTRB),
    .PREADY        (PREADY),
    .PRDATA        (PRDATA),
    .PSLVERR       (PSLVERR),
    .prer_lo_value (prer_lo_value),
    .prer_hi_value (prer_hi_value),
    .ctr_ien       (ctr_ien),
    .ctr_en        (ctr_en),
    .rxr_data      (sr),
    .txr_data      (txr_data),
    .sr_iflag      (iflag),
    .sr_tip        (tip),
    .sr_al         (al_q),
    .sr_busy       (bit_busy),
    .sr_rxack      (rxack),
    .cr_iack       (cr_iack),
    .cr_ack        (cr_ack),
    .cr_write      (cr_write),
    .cr_read       (cr_read),
    .cr_sto        (cr_sto),
    .cr_sta        (cr_sta),
    .cr_wr         (cr_wr)
  );

  assign prescale = {prer_hi_value, prer_lo_value};

  // ---- command register (cr) ------------------------------------------------------
  assign cr_we   = cr_wr && PSTRB[0] && ctr_en;
  assign iack    = cr_we && cr_iack;
  assign cmd_end = cmd_done || bit_al;

  always_comb begin
    cmd_d = cmd_q;
    if (cr_we) begin
      cmd_d = {cr_sta, cr_sto, cr_read, cr_write, cr_ack};
    end else if (cmd_end) begin
      cmd_d[4:1] = 4'd0;
    end
  end

  basechili_dff #(.WIDTH(5)) u_cmd (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (cmd_d),
    .q     (cmd_q)
  );

  assign {cmd_sta, cmd_sto, cmd_rd, cmd_wr, cmd_ack} = cmd_q;
  assign tip = cmd_rd || cmd_wr;

  // ---- status -------------------------------------------------------------------
  assign iflag_d = (cmd_end || iflag) && !iack;
  assign al_d    = bit_al || (al_q && !cmd_sta);
  assign irq_d   = iflag && ctr_ien;

  basechili_dff #(.WIDTH(3)) u_status (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({iflag_d, al_d, irq_d}),
    .q     ({iflag, al_q, irq})
  );

  assign rxack_en = bit_done && (state == S_ACK);

  basechili_dffe u_rxack (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rxack_en),
    .d     (bit_dout),
    .q     (rxack)
  );

  // ---- byte state machine -------------------------------------------------------
  basechili_dff #(.WIDTH(3)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state    = state_e'(state_q);
  assign go       = ctr_en && (state == S_IDLE) && (cmd_rd || cmd_wr || cmd_sto);
  assign last_bit = (bit_cnt == 3'd7);

  always_comb begin
    state_d  = state;
    cmd_done = 1'b0;
    if (!ctr_en || bit_al) begin
      state_d = S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (go) begin
            if (cmd_sta)     state_d = S_START;
            else if (cmd_rd) state_d = S_READ;
            else if (cmd_wr) state_d = S_WRITE;
            else             state_d = S_STOP;
          end
        end
        S_START: begin
          if (bit_done) begin
            if (cmd_rd)      state_d = S_READ;
            else if (cmd_wr) state_d = S_WRITE;
            else             state_d = S_STOP;
          end
        end
        S_WRITE, S_READ: begin
          if (bit_done && last_bit) state_d = S_ACK;
        end
        S_ACK: begin
          if (bit_done) begin
            if (cmd_sto) begin
              state_d = S_STOP;
            end else begin
              state_d  = S_IDLE;
              cmd_done = 1'b1;
            end
          end
        end
        S_STOP: begin
          if (bit_done) begin
            state_d  = S_IDLE;
            cmd_done = 1'b1;
          end
        end
        default: state_d = S_IDLE;
      endcase
    end
  end

  // ---- byte shift register and bit count ----------------------------------------
  assign sr_shift = bit_done && (state == S_WRITE || state == S_READ);

  basechili_shift_reg #(.WIDTH(8), .MSB_FIRST(1'b1)) u_sr (
    .clk       (clk),
    .rst_n     (rst_n),
    .load      (go),
    .load_val  (txr_data),
    .shift     (sr_shift),
    .shift_in  (bit_dout),
    .q         (sr),
    .shift_out (sr_msb)
  );

  basechili_counter #(.WIDTH(3)) u_bit_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (go),
    .en    (sr_shift),
    .count (bit_cnt)
  );

  // ---- bus commands ---------------------------------------------------------------
  always_comb begin
    bit_valid = 1'b1;
    bit_cmd   = C_WRITE;
    bit_din   = 1'b1;
    if (state == S_START) begin
      bit_cmd = C_START;
    end else if (state == S_STOP) begin
      bit_cmd = C_STOP;
    end else if (state == S_WRITE) begin
      bit_din = sr_msb;
    end else if (state == S_READ) begin
      bit_cmd = C_READ;
    end else if (state == S_ACK) begin
      bit_cmd = cmd_rd ? C_WRITE : C_READ;   // a read sends ack, a write takes it
      bit_din = cmd_ack;
    end else begin
      bit_valid = 1'b0;
    end
  end

  chilimix_i2c_bit u_bit (
    .clk        (clk),
    .rst_n      (rst_n),
    .ena        (ctr_en),
    .prescale   (prescale),
    .cmd_valid  (bit_valid),
    .cmd        (bit_cmd),
    .din        (bit_din),
    .cmd_accept (),
    .done       (bit_done),
    .dout       (bit_dout),
    .al         (bit_al),
    .busy       (bit_busy),
    .scl_i      (scl_i),
    .sda_i      (sda_i),
    .scl_oe     (scl_oe),
    .sda_oe     (sda_oe)
  );

endmodule
