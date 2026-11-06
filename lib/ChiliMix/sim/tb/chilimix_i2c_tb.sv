// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_i2c -- the OpenCores driver sequences through APB
// against a pin-level I2C target (a 256-byte EEPROM at address 0x50).
//
// Stimulus: random transactions as i2c-ocores issues them: a write
// (address, pointer, 0 .. 6 data bytes, STOP), a read (address and pointer,
// repeated START, address with R, 1 .. 6 bytes, NACK and STOP on the last),
// a transfer to an absent address (NACK, then sto alone); random prescale
// (2 .. 6) set with ctr.en clear, interrupt enable on or off (completion by
// irq or by polling sr.tip); the target stretches scl at random; another
// master pulls sda low during an address byte (arbitration); cr writes
// while ctr.en is clear.
// Checked: the EEPROM contents and every byte read in rxr; sr.rxack per
// byte (ACK, or NACK for an absent address); sr.busy after START and STOP;
// sr.tip while a command runs; iflag, irq (with ien) and iack; sr.al and the
// lines released after arbitration, al cleared by the next sta; cr ignored
// with ctr.en clear; register reset values.
`include "tb_common.svh"
module chilimix_i2c_tb;
  localparam int N_TR = 400;
  localparam logic [6:0] DEV = 7'h50;
  localparam logic [4:0] PRER_LO = 5'h00, PRER_HI = 5'h04, CTR = 5'h08, TXR = 5'h0c, RXR = 5'h0c,
                         CR = 5'h10, SR = 5'h10;
  localparam logic [7:0] STA = 8'h80, STO = 8'h40, RD = 8'h20, WR = 8'h10, ACK = 8'h08, IACK = 8'h01;

  `TB_CLOCK_RESET

  logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [4:0]  PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0]  PSTRB;
  logic        scl_i, sda_i, scl_oe, sda_oe, irq;

  chilimix_i2c dut (.*);

  // ---- open-drain lines --------------------------------------------------------
  logic t_scl_low, t_sda_low, oth_sda_low;
  assign scl_i = !(scl_oe || t_scl_low);
  assign sda_i = !(sda_oe || t_sda_low || oth_sda_low);

  // ---- target: 256-byte EEPROM at DEV ----------------------------------------------
  typedef enum int {T_IDLE, T_RX, T_TX} tst_e;
  logic [7:0] mem [256];
  logic [7:0] ptr, rx_byte, tx_byte;
  tst_e       tst;
  int         bitn;                // bits clocked in this byte (8: the ack clock)
  logic       first_rx;            // the next received byte is the address
  logic       got_ptr;             // the pointer byte arrived in this write
  logic       acking;              // driving our ACK
  logic       m_ack;               // the master's ack bit after a byte we sent
  logic       scl_q, sda_q;
  int         stretch, n_stretch, n_tstart, n_tstop;

  always @(negedge clk) begin
    if (!rst_n) begin
      tst = T_IDLE; t_scl_low = 0; t_sda_low = 0; scl_q = 1; sda_q = 1; stretch = 0;
      acking = 0;
    end else begin
      if (stretch > 0) begin
        stretch--;
        if (stretch == 0) t_scl_low = 0;
      end
      if (scl_i && scl_q && sda_i != sda_q) begin               // START / STOP
        t_sda_low = 0; acking = 0;
        if (!sda_i) begin tst = T_RX; bitn = 0; first_rx = 1; got_ptr = 0; n_tstart++; end
        else begin tst = T_IDLE; n_tstop++; end
      end else if (scl_i && !scl_q) begin                        // rise: sample
        if (tst == T_RX && bitn < 8) begin
          rx_byte = {rx_byte[6:0], sda_i}; bitn++;
        end else if (tst == T_TX) begin
          if (bitn == 8) m_ack = sda_i;
          bitn++;
        end
      end else if (!scl_i && scl_q) begin                        // fall: drive
        if (stretch == 0 && $urandom % 4 == 0) begin
          stretch = 1 + $urandom % 30; t_scl_low = 1; n_stretch++;
        end
        if (tst == T_RX) begin
          if (bitn == 8 && !acking) begin
            if (first_rx && rx_byte[7:1] != DEV) begin
              tst = T_IDLE;                                      // not us: NACK
            end else begin
              t_sda_low = 1; acking = 1;
            end
          end else if (acking) begin
            t_sda_low = 0; acking = 0; bitn = 0;
            if (first_rx) begin
              first_rx = 0;
              if (rx_byte[0]) begin
                tst = T_TX; tx_byte = mem[ptr]; t_sda_low = !tx_byte[7];
              end
            end else if (!got_ptr) begin
              ptr = rx_byte; got_ptr = 1;
            end else begin
              mem[ptr] = rx_byte; ptr++;
            end
          end
        end else if (tst == T_TX) begin
          if (bitn < 8) begin
            t_sda_low = !tx_byte[7 - bitn];
          end else if (bitn == 8) begin
            t_sda_low = 0;                                       // the master's ack clock
          end else begin
            ptr++;
            if (!m_ack) begin
              tx_byte = mem[ptr]; bitn = 0; t_sda_low = !tx_byte[7];
            end else begin
              t_sda_low = 0; tst = T_IDLE;                       // NACK: wait for STOP
            end
          end
        end
      end
      scl_q = scl_i; sda_q = sda_i;
    end
  end

  // ---- APB ---------------------------------------------------------------------
  task automatic apb(input logic w, input logic [4:0] a, input logic [31:0] d, output logic [31:0] q);
    // the registers are 8 bits: the upper write bytes and strobes are ignored
    PSEL = 1; PENABLE = 0; PWRITE = w; PADDR = a; PWDATA = {24'($urandom), d[7:0]};
    PSTRB = {3'($urandom), 1'b1};
    @(negedge clk);
    PENABLE = 1;
    #1;
    q = PRDATA;
    `CHECK(PREADY && !PSLVERR, "APB access")
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr(input logic [4:0] a, input logic [31:0] d);
    logic [31:0] q;
    apb(1'b1, a, d, q);
  endtask

  task automatic rd(input logic [4:0] a, output logic [31:0] q);
    apb(1'b0, a, '0, q);
  endtask

  // ---- driver ------------------------------------------------------------------
  logic        ien;
  logic [7:0]  ref_mem [256];
  int          n_bare;
  int          n_irq, n_poll, n_nack, n_al, n_bytes_w, n_bytes_r, n_ignored;

  // issue one command and wait for it; returns sr
  task automatic command(input logic [7:0] c, output logic [31:0] s);
    int n;
    wr(CR, {24'd0, c});
    rd(SR, s);
    `CHECK(s[1] == ((c & (RD | WR)) != 0) || s[0], "sr.tip while a byte command runs")
    n = 0;
    if (ien) begin
      while (!irq && n < 200000) begin @(negedge clk); n++; end
      n_irq++;
    end else begin
      while (s[1] && n < 20000) begin rd(SR, s); n++; end
      while (!s[0] && n < 20000) begin rd(SR, s); n++; end
      n_poll++;
    end
    `CHECK(n < 20000 || (ien && n < 200000), "command finishes")
    rd(SR, s);
    `CHECK(s[0] && !s[1], "iflag set, tip clear after the command")
    `CHECK(irq == ien, "irq = iflag & ien")
    wr(CR, {24'd0, IACK});
    @(negedge clk);
    `CHECK(!irq, "iack clears the interrupt")
  endtask

  task automatic write_tr(input logic [7:0] p, input int n);
    logic [31:0] s;
    wr(TXR, {DEV, 1'b0});
    command(STA | WR, s);
    `CHECK(!s[7] && s[6] && !s[5], "address ACK, busy")
    wr(TXR, p);
    command((n == 0) ? (WR | STO) : WR, s);
    `CHECK(!s[7], "pointer ACK")
    for (int i = 0; i < n; i++) begin
      logic [7:0] d;
      d = $urandom;
      wr(TXR, d);
      command((i == n - 1) ? (WR | STO) : WR, s);
      `CHECK(!s[7], "data ACK")
      ref_mem[8'(p + 8'(i))] = d;
      n_bytes_w++;
    end
  endtask

  task automatic read_tr(input logic [7:0] p, input int n);
    logic [31:0] s, q;
    wr(TXR, {DEV, 1'b0});
    command(STA | WR, s);
    `CHECK(!s[7], "address ACK")
    wr(TXR, p);
    command(WR, s);
    wr(TXR, {DEV, 1'b1});
    command(STA | WR, s);                          // repeated START
    `CHECK(!s[7], "read address ACK")
    for (int i = 0; i < n; i++) begin
      logic last;
      last = (i == n - 1);
      command(last ? (RD | ACK | STO) : RD, s);
      `CHECK(s[7] == last, "sr.rxack is the ack sent")
      rd(RXR, q);
      `CHECK(q[7:0] == ref_mem[8'(p + 8'(i))], "read byte")
      n_bytes_r++;
    end
  endtask

  task automatic wait_free();
    logic [31:0] s;
    int n;
    n = 0;
    do begin repeat (5) @(negedge clk); rd(SR, s); n++; end while (s[6] && n < 2000);
    `CHECK(!s[6], "busy cleared by STOP")
  endtask

  initial begin
    logic [31:0] q, s;
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    oth_sda_low = 0; ptr = 0;
    n_irq = 0; n_poll = 0; n_bare = 0; n_nack = 0; n_al = 0; n_bytes_w = 0; n_bytes_r = 0; n_ignored = 0;
    n_stretch = 0; n_tstart = 0; n_tstop = 0;
    for (int i = 0; i < 256; i++) begin mem[i] = $urandom; ref_mem[i] = mem[i]; end
    tb_reset();
    @(negedge clk);
    rd(PRER_LO, q); `CHECK(q == 32'hff, "prer_lo reset")
    rd(PRER_HI, q); `CHECK(q == 32'hff, "prer_hi reset")
    rd(CTR, q);     `CHECK(q == 32'h0, "ctr reset")
    rd(SR, q);      `CHECK(q == 32'h0, "sr reset")

    for (int t = 0; t < N_TR; t++) begin
      int kind;
      wr(CTR, 0);
      // cr is ignored while ctr.en is clear
      if ($urandom % 10 == 0) begin
        wr(CR, {24'd0, STA | WR});
        repeat (20) @(negedge clk);
        rd(SR, s);
        `CHECK(s[1:0] == 2'b00 && !scl_oe && !sda_oe, "cr ignored with ctr.en clear")
        n_ignored++;
      end
      wr(PRER_LO, 2 + $urandom % 5);
      wr(PRER_HI, 0);
      ien = $urandom;
      wr(CTR, {24'd0, 1'b1, ien, 6'd0});
      kind = $urandom % 10;
      if (kind < 4) begin
        write_tr($urandom, $urandom % 7);
      end else if (kind < 8) begin
        read_tr($urandom, 1 + $urandom % 6);
      end else if (kind == 8 && $urandom % 3 == 0) begin
        // START and STOP alone, or a read straight after START (no target
        // answers: the bus reads 0xff)
        if ($urandom % 2 == 0) begin
          command(STA | STO, s);
        end else begin
          command(STA | RD | ACK | STO, s);
          rd(RXR, q);
          `CHECK(q == 32'hff && s[7], "read with no target")
        end
        n_bare++;
      end else if (kind == 8) begin
        // absent address: NACK, then STOP alone
        wr(TXR, {7'h23, 1'b0});
        command(STA | WR, s);
        `CHECK(s[7], "absent address NACK")
        command(STO, s);
        n_nack++;
      end else begin
        // arbitration: another master pulls sda low during the address byte
        int n;
        wr(TXR, {DEV, 1'b1});
        wr(CR, {24'd0, STA | WR});
        n = 0;
        while (!(dut.state == 3'd2 && !scl_i) && n < 10000) begin @(negedge clk); n++; end
        repeat ($urandom % 20) @(negedge clk);
        while (scl_i) @(negedge clk);
        oth_sda_low = 1;
        n = 0;
        do begin rd(SR, s); n++; end while (!s[0] && n < 20000);
        `CHECK(s[5] && s[0] && !s[1], "sr.al and iflag after arbitration, tip clear")
        `CHECK(irq == ien, "irq after arbitration")
        `CHECK(!scl_oe && !sda_oe, "lines released after arbitration")
        repeat (10) @(negedge clk);
        oth_sda_low = 0;                            // the other master's STOP
        wr(CR, {24'd0, IACK});
        n_al++;
        wait_free();
        // al stays until the next sta
        rd(SR, s);
        `CHECK(s[5], "al held")
        write_tr($urandom, 0);
        rd(SR, s);
        `CHECK(!s[5], "al cleared by sta")
      end
      wait_free();
    end
    for (int i = 0; i < 256; i++) `CHECK(mem[i] == ref_mem[i], "EEPROM contents")
    $display("bytes written %0d read %0d; irq %0d poll %0d; nack %0d al %0d ignored %0d bare %0d; target starts %0d stops %0d stretches %0d",
             n_bytes_w, n_bytes_r, n_irq, n_poll, n_nack, n_al, n_ignored, n_bare, n_tstart, n_tstop, n_stretch);
    `CHECK(n_bytes_w > 300 && n_bytes_r > 300 && n_al > 20 && n_nack > 10 && n_bare > 5 && n_ignored > 20, "coverage")
    tb_pass();
  end
endmodule
