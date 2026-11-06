// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_spi_phy -- random frames and configurations against a
// pin-level model of an SPI device.
//
// Stimulus: per episode a random clock divisor, mode (pol / pha), chip
// select and delays (changed only while the phy is idle); random frames
// (0 .. 15 cycles, every protocol, MSB / LSB first, driven or floating,
// with or without rx, cs, keep, gap, first) offered on and off, release
// now and then; dq_i random every cycle.
// Checked: per frame the number of leading and trailing sck edges, exact
// half periods, the bits on dq_o and dq_oe at every sample edge, rx_data
// against the bits the master sampled (dq_i of the cycle before the edge),
// rx_valid only at the end of rx frames; sck idle and dq_oe 0 between
// frames; at most one cs pin asserted, the right one (csid) during cs
// frames and none during frames without cs; the cssck, sckcs and intercs
// minimum times.
`include "tb_common.svh"
module chilimix_spi_phy_tb #(
  parameter int N_CS = 1
);
  localparam int N_CYC = 120000;

  `TB_CLOCK_RESET

  logic [11:0]     div;
  logic            pol, pha;
  logic [7:0]      cssck, sckcs, intercs, interxfr;
  logic [1:0]      csid;
  logic [N_CS-1:0] csdef;
  logic            release_cs;
  logic            f_valid, f_accept;
  logic [7:0]      f_data;
  logic [3:0]      f_cycles;
  logic [1:0]      f_proto;
  logic            f_msb, f_oe, f_rx, f_cs, f_keep, f_gap, f_first;
  logic            rx_valid;
  logic [7:0]      rx_data;
  logic            cs_active, busy;
  logic            sck;
  logic [N_CS-1:0] cs;
  logic [3:0]      dq_o, dq_oe, dq_i;

  chilimix_spi_phy #(.N_CS(N_CS)) dut (.*);

  // frame in flight
  logic       cur;                 // a frame was taken and has not ended
  logic [7:0] c_data;
  logic [3:0] c_cycles;
  logic [1:0] c_proto;
  logic       c_msb, c_oe, c_rx, c_cs;
  int         c_lead, c_trail;     // sck edges seen
  logic [7:0] m_rx;                // model of the received bits
  logic       end_next;            // the frame ends at the next rising edge
  logic       taken;               // the frame offered is taken at the next rising edge
  // pins
  logic       sck_prev;
  int         need_intercs;
  int         cyc, t_tog, t_assert, t_deassert, t_last_tog;
  logic       act_prev, first_tog;
  int         n_frames, n_rx, n_hold, n_gap, n_proto[4], n_lsb, n_zero, n_cs_end;
  int         w, k, half;

  function automatic int width(logic [1:0] p);
    return (p == 2'd2) ? 4 : (p == 2'd1) ? 2 : 1;
  endfunction

  // bits the master drives in sck cycle kk of a frame
  function automatic logic [3:0] out_bits(logic [7:0] d, logic m, int ww, int kk);
    logic [3:0] b;
    b = '0;
    for (int i = 0; i < ww; i++) begin
      int bit_i;
      if (m) bit_i = 8 - ww * (kk + 1) + i;   // MSB first: bits 7.. in groups
      else   bit_i = ww * kk + i;
      if (bit_i >= 0 && bit_i < 8) b[i] = d[bit_i];
    end
    return b;
  endfunction

  function automatic logic [3:0] mask(int ww);
    return (ww == 4) ? 4'hf : (ww == 2) ? 4'h3 : 4'h1;
  endfunction

  task automatic new_config();
    div      = ($urandom % 3 == 0) ? 12'($urandom % 4) : 12'd0;
    pol      = $urandom;
    pha      = $urandom;
    cssck    = 8'($urandom % 3);
    sckcs    = 8'($urandom % 3);
    intercs  = 8'($urandom % 3);
    interxfr = 8'($urandom % 3);
    if ($urandom % 25 == 0) begin                  // now and then long delays (every counter bit)
      div = 12'd0;
      case ($urandom % 4)
        0: cssck = 8'($urandom);
        1: sckcs = 8'($urandom);
        2: intercs = 8'($urandom);
        default: interxfr = 8'($urandom);
      endcase
    end
    csid     = 2'($urandom);
    csdef    = N_CS'($urandom);
  endtask

  task automatic new_frame();
    f_data   = $urandom;
    f_proto  = 2'($urandom);
    f_cycles = ($urandom % 4 == 0) ? 4'($urandom) : 4'(8 / width(f_proto));
    f_msb    = $urandom;
    f_oe     = $urandom % 4 != 0;
    f_rx     = $urandom;
    f_cs     = $urandom % 6 != 0;
    f_keep   = $urandom % 2 == 0;
    f_gap    = $urandom;
    f_first  = $urandom % 4 == 0;
  endtask

  initial begin
    new_config();
    new_frame();
    f_valid = 0; release_cs = 0; dq_i = '0;
    cur = 0; end_next = 0; taken = 0; sck_prev = 0; act_prev = 0; first_tog = 0;
    cyc = 0; t_tog = 0; t_assert = 0; t_deassert = -1000; need_intercs = 0; t_last_tog = 0;
    n_frames = 0; n_rx = 0; n_hold = 0; n_gap = 0; n_lsb = 0; n_zero = 0; n_cs_end = 0;
    for (int i = 0; i < 4; i++) n_proto[i] = 0;
    tb_reset();
    sck_prev = sck;
    for (cyc = 0; cyc < N_CYC; cyc++) begin
      @(negedge clk);
      half = int'(div) + 1;
      // ---- monitor: what the last rising edge did ---------------------------
      if (sck != sck_prev && !cur) begin
        `CHECK(sck == pol, "sck changes outside a frame only to follow pol")
      end else if (sck != sck_prev) begin
        if (cur && c_lead + c_trail > 0) `CHECK(cyc - t_tog == half, "half period length")
        t_tog = cyc;
        if (cur) begin
          if (sck_prev == pol) c_lead++;
          else                 c_trail++;
          w = width(c_proto);
          // sample edge of the device / master
          if ((sck_prev == pol) != pha) begin
            k = pha ? c_trail - 1 : c_lead - 1;
            `CHECK(dq_oe == (c_oe ? mask(w) : 4'h0), "dq_oe in the frame")
            if (c_oe) `CHECK((dq_o & mask(w)) == out_bits(c_data, c_msb, w, k), "dq_o bits")
            if (c_msb) begin
              if (w == 4)      m_rx = {m_rx[3:0], dq_i};
              else if (w == 2) m_rx = {m_rx[5:0], dq_i[1:0]};
              else             m_rx = {m_rx[6:0], dq_i[1]};
            end else begin
              if (w == 4)      m_rx = {dq_i, m_rx[7:4]};
              else if (w == 2) m_rx = {dq_i[1:0], m_rx[7:2]};
              else             m_rx = {dq_i[1], m_rx[7:1]};
            end
          end
          // (with sckcs 0 the cs deasserts at the last edge itself)
          if (c_cs && c_trail < int'(c_cycles)) `CHECK(cs_active, "cs asserted while a cs frame clocks")
          if (!c_cs) `CHECK(!cs_active, "no cs while a frame without cs clocks")
          if (c_cs && c_trail < int'(c_cycles) && 32'(csid) < N_CS) `CHECK(cs == (csdef ^ N_CS'(1 << csid)), "the csid pin is asserted")
          if (first_tog) begin
            `CHECK(cyc - t_assert >= 2 * int'(cssck) * half + half, "cssck")
            first_tog = 0;
          end
          t_last_tog = cyc;
        end
      end else if (!cur) begin
        `CHECK(sck == pol, "sck idle level")
      end
      if (!cur) `CHECK(dq_oe == 4'h0, "dq pins float between frames")
      `CHECK($countones(cs ^ csdef) <= 1, "at most one cs pin asserted")
      if (!cs_active) `CHECK(cs == csdef, "cs pins at csdef while deasserted")
      // cs timing
      if (cs_active && !act_prev) begin
        `CHECK(cyc - t_deassert >= need_intercs, "intercs")
        t_assert = cyc; first_tog = 1;
      end
      if (!cs_active && act_prev) begin
        if (!first_tog) `CHECK(cyc - t_last_tog >= 2 * int'(sckcs) * half, "sckcs")
        t_deassert = cyc; n_cs_end++; first_tog = 0;
        need_intercs = 2 * int'(intercs) * half;   // the setting when cs deasserts
      end
      act_prev = cs_active;
      // frame end
      if (end_next) begin
        `CHECK(cur, "frame end with no frame")
        `CHECK(c_lead == int'(c_cycles) && c_trail == int'(c_cycles), "sck cycles of the frame")
        `CHECK(rx_valid == c_rx, "rx_valid at the frame end")
        if (c_rx) begin
          `CHECK(rx_data == m_rx, "rx_data")
          n_rx++;
        end
        if (c_cycles == 4'd0) n_zero++;
        cur = 0;
      end else begin
        `CHECK(!rx_valid, "rx_valid only at a frame end")
      end
      sck_prev = sck;
      // ---- drive ------------------------------------------------------------
      dq_i = 4'($urandom);
      if (taken) begin f_valid = 0; taken = 0; end
      if (!busy && !f_valid && $urandom % 40 == 0) new_config();   // no frame offered in this cycle
      else if (f_valid && $urandom % 6 == 0) f_valid = 0;
      else if (!f_valid && $urandom % 3 == 0) begin new_frame(); f_valid = 1; end
      else if (f_valid && $urandom % 10 == 0) new_frame();
      release_cs = $urandom % 12 == 0;
      #1;
      end_next = dut.done;
      if (f_valid && f_accept) begin
        `CHECK(!cur, "frame taken while one is in flight")
        cur = 1; c_data = f_data; c_cycles = f_cycles; c_proto = f_proto; c_msb = f_msb;
        c_oe = f_oe; c_rx = f_rx; c_cs = f_cs; c_lead = 0; c_trail = 0; m_rx = '0;
        n_frames++; n_proto[f_proto]++;
        if (!f_msb) n_lsb++;
        if (cs_active && f_cs) n_hold++;
        if (dut.state == 3'd3 && f_gap && interxfr != 0) n_gap++;
        taken = 1;
      end
    end
    $display("frames %0d (rx %0d, in a hold %0d, after a gap %0d, LSB first %0d, empty %0d), proto %0d/%0d/%0d/%0d, cs ends %0d",
             n_frames, n_rx, n_hold, n_gap, n_lsb, n_zero, n_proto[0], n_proto[1], n_proto[2], n_proto[3], n_cs_end);
    `CHECK(n_frames > 1000 && n_hold > 100 && n_gap > 20 && n_zero > 10, "coverage of frame kinds")
    tb_pass();
  end
endmodule
