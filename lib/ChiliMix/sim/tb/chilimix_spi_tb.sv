// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_spi -- register-level FIFO transfers and XIP reads
// through the pins, against a loopback (FIFO frames) and a SPI flash model
// (XIP reads).
//
// FIFO part (fctrl.en cleared): batches of txdata writes with random
// sckdiv, sckmode, csmode (AUTO / HOLD / OFF), endianness, direction and
// watermarks, dq0 looped back to dq1. Checked: txdata.full and dropped
// writes, the received bytes in rxdata (equal to the sent ones, none for
// fmt.dir 1), rxdata.empty, ip.txwm / ip.rxwm and irq against the FIFO
// counts, cs pin assertions per csmode (one per frame, one per HOLD, none
// for OFF), a HOLD ending on a csmode write.
// Flash part: fctrl.en set, random ffmt (command, 0 .. 4 address bytes,
// dummy cycles, single / dual / quad phases) in modes 0 and 3; random AHB
// reads of the window. The flash model decodes the instruction from the
// pins (command code, address) and drives the data. Checked: the command
// code, every read word, ERROR for writes; TX frames wait while fctrl.en
// is set and run once it is cleared; a HOLD ends when fctrl.en is set.
`include "tb_common.svh"
module chilimix_spi_tb;
  localparam int XIP_AW = 24;
  localparam int LINE_B = 16;

  `TB_CLOCK_RESET

  logic              PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [6:0]        PADDR;
  logic [31:0]       PWDATA, PRDATA;
  logic [3:0]        PSTRB;
  logic              HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [XIP_AW-1:0] HADDR;
  logic [1:0]        HTRANS;
  logic [2:0]        HSIZE;
  logic [31:0]       HWDATA, HRDATA;
  logic              sck;
  logic [0:0]        cs;
  logic [3:0]        dq_o, dq_oe, dq_i;
  logic              irq;

  chilimix_spi #(.N_CS(1), .XIP_AW(XIP_AW), .XIP_LINES(4), .XIP_LINE_B(LINE_B)) dut (.*);

  assign HREADY = HREADYOUT;

  // ---- register offsets ------------------------------------------------------
  localparam logic [6:0] SCKDIV = 7'h00, SCKMODE = 7'h04, CSID = 7'h10, CSDEF = 7'h14, CSMODE = 7'h18,
                         DELAY0 = 7'h28, DELAY1 = 7'h2c, FMT = 7'h40, TXDATA = 7'h48, RXDATA = 7'h4c,
                         TXMARK = 7'h50, RXMARK = 7'h54, FCTRL = 7'h60, FFMT = 7'h64, IE = 7'h70, IP = 7'h74;

  // ---- flash model state -----------------------------------------------------
  logic        loopback;               // FIFO part: dq1 = dq0
  logic        m_cmd_en;
  int          m_addr_n, m_pad;
  logic [1:0]  m_cmd_p, m_addr_p, m_data_p;
  logic [7:0]  m_cmd;
  logic        sck_q, cs_q;
  int          rises;                  // rising sck edges in this cs assertion
  logic [7:0]  got_cmd;
  logic [31:0] got_addr;
  logic [3:0]  fl_out;                 // bits the flash drives
  int          n_inst, n_fall, n_cs, n_hit_reads;
  int          last_txc;               // TX FIFO count during the last APB access


  function automatic logic [7:0] flash(logic [31:0] a);
    return 8'(a * 32'd5 + (a >> 8) * 32'd11 + 32'd3);
  endfunction

  function automatic int wd(logic [1:0] p);
    return (p == 2'd2) ? 4 : (p == 2'd1) ? 2 : 1;
  endfunction

  function automatic int cyc8(logic [1:0] p);
    return 8 / wd(p);
  endfunction

  function automatic logic [3:0] in_bits(logic [1:0] p);
    return (wd(p) == 1) ? {3'd0, dq_o[0]} : (wd(p) == 2) ? {2'd0, dq_o[1:0]} : dq_o;
  endfunction

  assign dq_i = loopback ? {2'd0, dq_o[0], 1'b0} : fl_out;

  // flash: samples on rising sck, shifts on falling sck (modes 0 and 3)
  always @(negedge clk) begin
    int c_cmd, c_addr, s_data, j, byte_i, grp;
    logic [7:0] b;
    if (!rst_n) begin
      sck_q = 0; cs_q = 1; rises = 0; fl_out = '0;
    end else begin
      c_cmd  = m_cmd_en ? cyc8(m_cmd_p) : 0;
      c_addr = m_addr_n * cyc8(m_addr_p);
      s_data = c_cmd + c_addr + m_pad;
      if (cs[0] && !cs_q) begin                      // deassert
        if (!loopback && rises > 0) begin
          if (m_cmd_en) `CHECK(got_cmd == m_cmd, "flash: command code")
          n_inst++;
        end
      end
      if (!cs[0] && cs_q) begin rises = 0; got_cmd = '0; got_addr = '0; n_cs++; end
      if (!cs[0] && !loopback) begin
        if (sck && !sck_q) begin                     // rising: sample
          if (rises < c_cmd) begin
            got_cmd = (got_cmd << wd(m_cmd_p)) | 8'(in_bits(m_cmd_p));
          end else if (rises < c_cmd + c_addr) begin
            got_addr = (got_addr << wd(m_addr_p)) | 32'(in_bits(m_addr_p));
          end
          rises++;
        end
        if (!sck && sck_q && rises >= s_data) begin  // falling: drive the next data bits
          j      = rises - s_data;
          byte_i = j / cyc8(m_data_p);
          grp    = j % cyc8(m_data_p);
          b      = flash(got_addr + 32'(byte_i));
          if (wd(m_data_p) == 4)      fl_out = (grp == 0) ? b[7:4] : b[3:0];
          else if (wd(m_data_p) == 2) fl_out = {2'd0, b[7 - 2 * grp -: 2]};
          else                        fl_out = {2'd0, b[7 - grp], 1'b0};
        end
      end
      if (sck != sck_q && !sck) n_fall++;
      sck_q = sck;
      cs_q  = cs[0];
    end
  end

  // The first data bits must be out before the first rising edge of
  // the data phase: the falling edge ending the last dummy or address cycle
  // (mode 0) or starting the data cycle (mode 3).

  // ---- APB ---------------------------------------------------------------------
  task automatic apb(input logic wr, input logic [6:0] a, input logic [31:0] d, output logic [31:0] q);
    PSEL = 1; PENABLE = 0; PWRITE = wr; PADDR = a; PWDATA = d; PSTRB = 4'hf;
    @(negedge clk);
    PENABLE = 1;
    #1;
    q = PRDATA;
    last_push = dut.tx_push && dut.tx_in_accept;
    last_txc  = dut.tx_count;
    `CHECK(PREADY && !PSLVERR, "APB access")
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr(input logic [6:0] a, input logic [31:0] d);
    logic [31:0] q;
    apb(1'b1, a, d, q);
  endtask

  task automatic rd(input logic [6:0] a, output logic [31:0] q);
    apb(1'b0, a, '0, q);
  endtask

  task automatic wait_idle();
    int n;
    n = 0;
    // HELD counts as idle (a HOLD keeps cs asserted after the last frame)
    while ((dut.tx_count != 0 || (dut.u_phy.busy && dut.u_phy.state != 3'd3)) && n < 200000) begin
      @(negedge clk); n++;
    end
    if (n >= 200000) $display("stuck: tx %0d phy st %0d xip st %0d fctrl %0b fifo_valid %0b rx_room %0b rx_pend %0b rxc %0d", dut.tx_count, dut.u_phy.state, dut.u_xip.state, dut.fctrl_en, dut.fifo_valid, dut.rx_room, dut.rx_pend, dut.rx_count);
    `CHECK(n < 200000, "transfers finish")
  endtask

  // ---- AHB ---------------------------------------------------------------------
  task automatic ahb_read(input logic write, input logic [XIP_AW-1:0] a);
    logic [31:0] w, exp;
    int          waits;
    HSEL = 1; HTRANS = 2'b10; HWRITE = write; HADDR = a; HSIZE = 3'($urandom % 3);
    @(posedge clk);
    @(negedge clk);
    HSEL = 0; HTRANS = 2'b00; HWDATA = $urandom;
    waits = 0;
    while (!HREADYOUT) begin @(negedge clk); waits++; end
    if (write) begin
      `CHECK(HRESP, "XIP write: ERROR")
    end else begin
      `CHECK(!HRESP, "XIP read: OKAY")
      w = (32'(a) & ~32'(3));
      if (m_addr_n < 4) w = (32'(a) & ((32'd1 << (8 * m_addr_n)) - 1)) & ~32'(3);
      exp = {flash(w + 3), flash(w + 2), flash(w + 1), flash(w)};
      `CHECK(HRDATA == exp, "XIP read data")
      if (waits == 1) n_hit_reads++;
    end
    @(negedge clk);
  endtask

  // ---- tests ---------------------------------------------------------------------
  logic [31:0] q;
  logic        last_push;              // the last APB access pushed the TX FIFO
  logic [7:0]  sent [$];
  int          n_frames, n_rx, n_full, cs_before, mode, nb, n_hold, n_irq;

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    HSEL = 0; HTRANS = 0; HWRITE = 0; HADDR = '0; HSIZE = 0; HWDATA = '0;
    loopback = 1; m_cmd_en = 1; m_addr_n = 3; m_pad = 0; m_cmd_p = 0; m_addr_p = 0; m_data_p = 0; m_cmd = 8'h03;
    n_inst = 0; n_fall = 0; n_cs = 0; n_hit_reads = 0; n_frames = 0; n_rx = 0; n_full = 0; n_hold = 0; n_irq = 0;
    tb_reset();
    rd(FCTRL, q);   `CHECK(q == 32'h1, "fctrl reset: flash reads on")
    rd(FFMT, q);    `CHECK(q == 32'h0003_0007, "ffmt reset: read 0x03, 3 address bytes")
    rd(TXMARK, q);  `CHECK(q == 32'h1, "txmark reset")
    rd(RXDATA, q);  `CHECK(q == 32'h8000_0000, "rxdata empty")

    // TX frames wait while fctrl.en is set
    wr(FMT, 32'h0008_0000);
    wr(TXDATA, 32'h5a);
    repeat (200) @(negedge clk);
    `CHECK(dut.tx_count == 1 && cs[0] == 1'b1, "no frame while fctrl.en is set")
    wr(FCTRL, 0);
    wait_idle();
    rd(RXDATA, q);  `CHECK(q == 32'h5a, "frame runs once fctrl.en is clear (loopback)")

    // ---- FIFO batches ----
    for (int b = 0; b < 150; b++) begin
      logic dir;
      logic [2:0] txm, rxm;
      logic ie_t, ie_r;
      mode = $urandom % 3;                        // 0 AUTO, 1 HOLD, 2 OFF
      dir  = $urandom % 4 == 0;
      txm  = 3'($urandom); rxm = 3'($urandom); ie_t = $urandom; ie_r = $urandom;
      wr(SCKDIV, $urandom % 3);
      wr(SCKMODE, $urandom % 4);
      wr(DELAY0, {8'd0, 8'($urandom % 2), 8'd0, 8'($urandom % 2)});
      wr(DELAY1, {8'd0, 8'($urandom % 2), 8'd0, 8'($urandom % 2)});
      wr(CSMODE, (mode == 0) ? 0 : (mode == 1) ? 2 : 3);
      // other lengths, dual and quad only for transmit frames (the loopback
      // checks single-wire bytes)
      wr(FMT, {12'd0, dir ? 4'($urandom % 9) : 4'd8, 12'd0, dir, 1'($urandom), dir ? 2'($urandom % 3) : 2'd0});
      if ($urandom % 8 == 0) begin wr(CSID, 0); wr(CSDEF, 1); end
      wr(TXMARK, txm); wr(RXMARK, rxm); wr(IE, {ie_r, ie_t});
      cs_before = n_cs;
      sent.delete();
      nb = 1 + $urandom % (dir ? 14 : 8);       // fmt.dir 0: at most the RX FIFO depth
      for (int i = 0; i < nb; i++) begin
        logic [7:0] d;
        d = $urandom;
        rd(TXDATA, q);
        if (q[31]) n_full++;
        wr(TXDATA, 32'(d));
        if (last_push) sent.push_back(d);
        else `CHECK(last_txc == 8, "a txdata write is dropped only while full")
      end
      // watermarks and irq while frames run
      rd(IP, q);
      wait_idle();
      repeat (3) @(negedge clk);
      rd(IP, q);
      `CHECK(q[0] == (0 < int'(txm)) && q[1] == (int'(dut.rx_count) > int'(rxm)), "ip after the batch")
      `CHECK(irq == ((ie_t && q[0]) || (ie_r && q[1])), "irq after the batch")
      if (irq) n_irq++;
      if (mode == 0) `CHECK(n_cs - cs_before == sent.size(), "AUTO: one cs assertion per frame")
      if (mode == 1) begin `CHECK(n_cs - cs_before == 1 && cs[0] == 1'b0, "HOLD: cs stays asserted"); n_hold++; end
      if (mode == 2) `CHECK(n_cs - cs_before == 0, "OFF: no cs assertion")
      n_frames += sent.size();
      // received bytes
      foreach (sent[i]) begin
        if (dir) break;
        rd(RXDATA, q);
        `CHECK(!q[31] && q[7:0] == sent[i], "received byte (loopback)")
        n_rx++;
      end
      rd(RXDATA, q);
      `CHECK(q[31], "RX FIFO empty after the batch")
      wr(CSMODE, 0);                              // ends a HOLD
      repeat (20) @(negedge clk);
      `CHECK(cs[0] == 1'b1, "cs deasserted after the csmode write")
    end

    // a HOLD ends when fctrl.en is set
    wr(CSMODE, 2); wr(FMT, 32'h0008_0008); wr(TXDATA, 32'h11);
    wait_idle();
    `CHECK(cs[0] == 1'b0, "HOLD before fctrl.en")
    wr(SCKDIV, 0); wr(SCKMODE, 0); wr(FCTRL, 1);
    repeat (20) @(negedge clk);
    `CHECK(cs[0] == 1'b1, "fctrl.en ends a HOLD")
    loopback = 0;                                 // the flash model takes the pins from here
    wr(CSMODE, 0);

    // ---- XIP reads ----
    for (int f = 0; f < 60; f++) begin
      logic [31:0] ff;
      logic [XIP_AW-1:0] base [4];                // the lines read with this format
      for (int i = 0; i < 4; i++) base[i] = XIP_AW'($urandom) & ~XIP_AW'(63);
      // the last fill's read is answered before its cs deasserts
      while (dut.u_phy.busy) @(negedge clk);
      @(negedge clk);                             // the flash model sees the deassert first
      m_cmd_en = $urandom % 4 != 0;
      m_addr_n = 1 + $urandom % 4;
      m_pad    = ($urandom % 2 == 0) ? 0 : 1 + $urandom % 10;
      m_cmd_p  = 2'($urandom % 3);
      m_addr_p = 2'($urandom % 3);
      m_data_p = 2'($urandom % 3);
      m_cmd    = $urandom;
      // with the address in single and data wider, the flash needs the dummy
      // cycles to turn the bus around; the model needs none
      ff = {8'($urandom), m_cmd, 2'b00, m_data_p, m_addr_p, m_cmd_p, 4'(m_pad), 3'(m_addr_n), m_cmd_en};
      wr(SCKDIV, $urandom % 2);
      wr(SCKMODE, ($urandom % 2 == 0) ? 0 : 3);
      wr(FFMT, ff);
      for (int r = 0; r < 25; r++) begin
        logic [XIP_AW-1:0] a;
        a = base[$urandom % 4] + XIP_AW'($urandom % 64);
        ahb_read($urandom % 12 == 0, a);
      end
    end
    $display("FIFO frames %0d (received %0d, full %0d, holds %0d, irq %0d); flash instructions %0d, cache hits %0d",
             n_frames, n_rx, n_full, n_hold, n_irq, n_inst, n_hit_reads);
    `CHECK(n_frames > 500 && n_full > 5 && n_inst > 300 && n_hit_reads > 200, "coverage")
    tb_pass();
  end
endmodule
