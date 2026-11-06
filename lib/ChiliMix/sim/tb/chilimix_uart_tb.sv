// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_uart -- a software-like APB manager and serial line
// models against the 16550 programming model.
//
// A serial monitor decodes txd (start, data, parity, stop at the middle of
// each bit, 16 * divisor clocks per bit) and checks each character against
// the THR writes; a serial driver sends frames on rxd. Directed sequences,
// each repeated with random divisors, line formats and trigger levels:
//   reset values; scratch, byte strobes, DLAB banking of DLL / DLM;
//   TX: FIFO bursts, overfill (17 of 20 characters sent), THR empty
//   interrupt and its acknowledge by an IIR read, FCR TX reset;
//   RX: trigger-level and timeout interrupts, parity / framing / break
//   errors in LSR (head errors until an LSR read, rxfe), overrun, FCR RX
//   reset and the FIFO enable toggle;
//   16450 mode (FIFOs off): one-character buffers, overrun;
//   loopback (data and modem lines), modem pins and MSR deltas, TX break,
//   the IIR priority order and irq (registered IIR id != 1).
`include "tb_common.svh"
module chilimix_uart_tb;
  `TB_CLOCK_RESET

  logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [4:0]  PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0]  PSTRB;
  logic        rxd, txd, cts_n, dsr_n, ri_n, dcd_n, rts_n, dtr_n, out1_n, out2_n, irq;

  chilimix_uart dut (.*);

  localparam logic [4:0] RBR = 5'h00, THR = 5'h00, DLL = 5'h00, IER = 5'h04, DLM = 5'h04,
                         IIR = 5'h08, FCR = 5'h08, LCR = 5'h0c, MCR = 5'h10, LSR = 5'h14,
                         MSR = 5'h18, SCR = 5'h1c;

  // line format and divisor as programmed
  int         div;
  logic [1:0] f_wls;
  logic       f_stb, f_pen, f_eps, f_stick;
  bit         fifo_on;

  logic [7:0] tx_exp [$];   // characters the monitor must see on txd
  bit         mon_en;       // txd monitor active (off during TX break)
  int         n_tx;         // characters decoded

  // ---- APB manager ------------------------------------------------------------
  task automatic apb(bit wr, logic [4:0] a, logic [31:0] d, logic [3:0] strb, output logic [31:0] rd);
    PSEL = 1; PENABLE = 0; PWRITE = wr; PADDR = a | 5'($urandom % 4); PWDATA = d; PSTRB = wr ? strb : 4'h0;
    @(negedge clk);
    PENABLE = 1;
    #1;
    `CHECK(PREADY, "PREADY high")
    `CHECK(!PSLVERR, "no PSLVERR")
    rd = PRDATA;
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr(logic [4:0] a, logic [7:0] d);
    logic [31:0] unused;
    apb(1'b1, a, {24'($urandom), d}, 4'hf, unused);
  endtask

  task automatic rd(logic [4:0] a, output logic [7:0] d);
    logic [31:0] w;
    apb(1'b0, a, '0, 4'h0, w);
    `CHECK(w[31:8] == '0, "upper read bits are 0")
    d = w[7:0];
  endtask

  task automatic expect_reg(logic [4:0] a, logic [7:0] e, string what);
    logic [7:0] d;
    rd(a, d);
    if (d !== e) $display("%s: read %h, expected %h", what, d, e);
    `CHECK(d === e, what)
  endtask

  task automatic idle(int n);
    repeat (n) @(negedge clk);
  endtask

  function automatic int bit_clk();
    return 16 * div;
  endfunction

  function automatic int char_clk();
    return bit_clk() * (1 + 5 + int'(f_wls) + int'(f_pen) + (f_stb ? 2 : 1));
  endfunction

  function automatic logic [7:0] mask(logic [7:0] d);
    return d & 8'((1 << (5 + int'(f_wls))) - 1);
  endfunction

  function automatic logic par_bit(logic [7:0] d);
    return f_stick ? !f_eps : (f_eps ? ^mask(d) : !(^mask(d)));
  endfunction

  // ---- serial monitor on txd ------------------------------------------------
  always begin
    logic [7:0] d;
    logic       p;
    @(negedge txd);
    if (mon_en && rst_n) begin
      d = '0;
      repeat (bit_clk() / 2) @(posedge clk);
      `CHECK(!txd, "TX start bit")
      for (int b = 0; b < 5 + int'(f_wls); b++) begin
        repeat (bit_clk()) @(posedge clk);
        d[b] = txd;
      end
      if (f_pen) begin
        repeat (bit_clk()) @(posedge clk);
        p = txd;
        `CHECK(p == par_bit(d), "TX parity bit")
      end
      repeat (bit_clk()) @(posedge clk);
      `CHECK(txd, "TX stop bit")
      `CHECK(tx_exp.size() != 0, "unexpected TX character")
      if (tx_exp.size() != 0) begin
        logic [7:0] e;
        e = tx_exp.pop_front();
        if (d != mask(e)) $display("TX: got %h, expected %h", d, mask(e));
        `CHECK(d == mask(e), "TX character")
      end
      n_tx++;
    end
  end

  // ---- serial driver on rxd ---------------------------------------------------
  task automatic send(logic [7:0] d, bit bad_par, bit bad_stop);
    rxd = 0;
    repeat (bit_clk()) @(posedge clk);
    for (int b = 0; b < 5 + int'(f_wls); b++) begin
      rxd = d[b];
      repeat (bit_clk()) @(posedge clk);
    end
    if (f_pen) begin
      rxd = par_bit(d) ^ bad_par;
      repeat (bit_clk()) @(posedge clk);
    end
    rxd = !bad_stop;
    // a 0 stop bit ends just after the receiver's sample point (sync and tick phase)
    repeat (bad_stop ? bit_clk() / 2 + div + 4 : bit_clk() * (f_stb ? 2 : 1)) @(posedge clk);
    rxd = 1;
    if (bad_stop) repeat (bit_clk()) @(posedge clk);
  endtask

  task automatic send_break();
    rxd = 0;
    repeat (char_clk() + bit_clk()) @(posedge clk);
    rxd = 1;
    repeat (bit_clk()) @(posedge clk);
  endtask

  // ---- setup ----------------------------------------------------------------
  int n_fmt;   // formats set so far (word length cycles through 5..8)

  task automatic set_format(int dv);
    div = dv;
    f_wls = 2'(n_fmt++); f_stb = $urandom % 2; f_pen = $urandom % 2; f_eps = $urandom % 2;
    f_stick = $urandom % 4 == 0;
    wr(LCR, 8'h80);                              // DLAB
    wr(DLL, 8'(dv)); wr(DLM, 8'(dv >> 8));
    wr(LCR, {2'b00, f_stick, f_eps, f_pen, f_stb, f_wls});
  endtask

  task automatic set_fifo(bit on, logic [1:0] trig);
    fifo_on = on;
    wr(FCR, {trig, 2'b00, 1'b0, 2'b11, on});   // enable, clear both FIFOs
  endtask

  function automatic int trig_lvl(logic [1:0] t);
    return (t == 0) ? 1 : (t == 1) ? 4 : (t == 2) ? 8 : 14;
  endfunction

  function automatic logic [7:0] iir(logic [3:0] id);
    return {fifo_on, fifo_on, 2'b00, id};
  endfunction

  task automatic wait_tx_empty();
    logic [7:0] l;
    do begin rd(LSR, l); idle(8); end while (!l[6]);
  endtask

  task automatic check_irq(logic [3:0] id, string what);
    idle(2);
    `CHECK(irq == (id != 4'h1), "irq is IIR id != 1")
    expect_reg(IIR, iir(id), what);
  endtask

  // ---- sequences ----------------------------------------------------------------
  task automatic t_reset_values();
    expect_reg(IIR, 8'h01, "reset IIR");
    expect_reg(LSR, 8'h60, "reset LSR");
    expect_reg(LCR, 8'h00, "reset LCR");
    expect_reg(MCR, 8'h00, "reset MCR");
    expect_reg(IER, 8'h00, "reset IER");
    expect_reg(MSR, 8'h00, "reset MSR");
    expect_reg(SCR, 8'h00, "reset SCR");
    `CHECK(!irq && txd && rts_n && dtr_n && out1_n && out2_n, "reset pins")
  endtask

  task automatic t_registers();
    logic [31:0] unused;
    logic [7:0]  s;
    s = 8'($urandom);
    wr(SCR, s);
    expect_reg(SCR, s, "SCR");
    apb(1'b1, SCR, {24'h0, ~s}, 4'he, unused);   // no byte lane 0: ignored
    expect_reg(SCR, s, "SCR byte strobe");
    wr(LCR, 8'h83);
    for (int i = 0; i < 4; i++) begin
      s = 8'($urandom);
      wr(DLL, s); wr(DLM, ~s);
      expect_reg(DLL, s, "DLL");
      expect_reg(DLM, ~s, "DLM");
    end
    wr(DLL, 8'h5a); wr(DLM, 8'ha5);
    expect_reg(LCR, 8'h83, "LCR with DLAB");
    wr(LCR, 8'h03);
    wr(IER, 8'h00);
    expect_reg(IER, 8'h00, "IER apart from DLM");
    wr(IER, 8'hff);
    expect_reg(IER, 8'h0f, "IER bits 3:0");
    wr(IER, 8'h00);
    wr(LCR, 8'h80);
    expect_reg(DLM, 8'ha5, "DLM apart from IER");
    wr(LCR, 8'h03);
    expect_reg(RBR, 8'h00, "empty RBR reads 0");
  endtask

  task automatic t_tx(int n);
    logic [7:0] d;
    for (int i = 0; i < n; i++) begin
      d = 8'($urandom);
      wr(THR, d);
      if (!fifo_on || i < 17) tx_exp.push_back(d);   // 16 in the FIFO + 1 in the shifter
      if (!fifo_on) wait_tx_empty();
    end
    wait_tx_empty();
    if (!fifo_on) begin   // 16450: one in the shifter, one in THR, the third write is lost
      for (int i = 0; i < 3; i++) begin
        d = 8'($urandom);
        wr(THR, d);
        if (i < 2) tx_exp.push_back(d);
      end
      wait_tx_empty();
    end
    `CHECK(tx_exp.size() == 0, "TX characters sent")
    expect_reg(LSR, 8'h60, "LSR after TX");
  endtask

  task automatic t_thre_irq();
    logic [7:0] d;
    wr(IER, 8'h02);
    check_irq(4'h2, "THR empty interrupt");
    expect_reg(IIR, iir(4'h1), "IIR read acknowledged THR empty");
    `CHECK(!irq, "irq low after the acknowledge")
    d = 8'($urandom);
    tx_exp.push_back(d);
    wr(THR, d);
    idle(3);
    if (fifo_on) `CHECK(irq, "THR empty again once the character moved to the shifter")
    wait_tx_empty();
    check_irq(4'h2, "THR empty interrupt re-armed by a THR write");
    wr(IER, 8'h00);
    check_irq(4'h1, "no interrupt with IER 0");
    wr(IER, 8'h02);
    check_irq(4'h2, "setting etbei re-arms THR empty");
    wr(IER, 8'h00);
  endtask

  task automatic t_tx_reset();
    logic [7:0] d;
    for (int i = 0; i < 5; i++) begin
      d = 8'($urandom);
      if (i == 0) tx_exp.push_back(d);   // already in the shift register
      wr(THR, d);
    end
    wr(FCR, 8'h05);   // FIFO on, TX reset
    expect_reg(LSR, 8'h20, "TX FIFO empty, shifter busy");
    wait_tx_empty();
  endtask

  task automatic t_rx(logic [1:0] trig);
    int         n;
    logic [7:0] q [$];
    logic [7:0] d;
    q.delete();   // (Verilator keeps queues of automatic tasks between calls)
    set_fifo(1'b1, trig);
    wr(IER, 8'h01);
    case ($urandom % 3)   // just below, at, or anywhere around the trigger level
      0:       n = (trig_lvl(trig) > 1) ? trig_lvl(trig) - 1 : 1;
      1:       n = trig_lvl(trig);
      default: n = 1 + $urandom % 16;
    endcase
    for (int i = 0; i < n; i++) begin
      d = mask(8'($urandom));
      q.push_back(d);
      send(d, 1'b0, 1'b0);
    end
    idle(4 * div + 8);
    if (n >= trig_lvl(trig)) check_irq(4'h4, "RX data available");
    else begin
      check_irq(4'h1, "below the trigger level");
      idle(3 * char_clk() - 2 * bit_clk());   // the last push was 0.5 to 1.5 bits ago
      check_irq(4'h1, "no timeout before 4 character times");
      idle(char_clk() + 4 * bit_clk());
      check_irq(4'hc, "character timeout");
      if (n > 1) begin
        expect_reg(RBR, q.pop_front(), "RX character");
        n--;
        check_irq(4'h1, "an RBR read restarts the timeout");
      end
    end
    for (int i = 0; i < n; i++) begin
      expect_reg(LSR, 8'h61, "LSR data ready");
      expect_reg(RBR, q[i], "RX character");
    end
    expect_reg(LSR, 8'h60, "RX FIFO empty");
    check_irq(4'h1, "RX interrupts cleared");
    wr(IER, 8'h00);
  endtask

  task automatic t_rx_errors();
    typedef struct packed { logic [7:0] d; logic pe, fe, bi; } rx_t;
    rx_t        q [$];
    rx_t        c;
    int         n, errs;
    logic [7:0] l;
    q.delete();
    set_fifo(1'b1, 2'd3);
    wr(IER, 8'h04);
    n = 4 + $urandom % 12;
    errs = 0;
    for (int i = 0; i < n; i++) begin
      c = '0;
      case ($urandom % 5)
        0: begin c.d = mask(8'($urandom)); c.pe = f_pen; send(c.d, 1'b1, 1'b0); end
        1: begin c.d = mask(8'($urandom)) | 8'h01; c.fe = 1; send(c.d, 1'b0, 1'b1); end
        2: begin c.fe = 1; c.bi = 1; c.pe = f_pen && !f_eps; send_break(); end
        default: begin c.d = mask(8'($urandom)); send(c.d, 1'b0, 1'b0); end
      endcase
      if (c.pe || c.fe || c.bi) errs++;
      q.push_back(c);
    end
    idle(8);
    for (int i = 0; i < n; i++) begin
      c = q[i];
      if (c.pe || c.fe || c.bi) check_irq(4'h6, "line status interrupt");
      rd(LSR, l);
      `CHECK(l[0], "LSR dr")
      `CHECK(l[4:2] == {c.bi, c.fe, c.pe}, "LSR head errors")
      `CHECK(l[7] == (errs != 0), "LSR rxfe")
      expect_reg(LSR, {errs != 0, 6'b110000, 1'b1}, "LSR read clears the head errors");
      expect_reg(RBR, c.d, "RX character with its errors");
      if (c.pe || c.fe || c.bi) errs--;
    end
    check_irq(4'h1, "no line status left");
    // overrun: 18 characters, 16 kept
    for (int i = 0; i < 18; i++) send(8'(i), 1'b0, 1'b0);
    idle(8);
    check_irq(4'h6, "overrun interrupt");
    expect_reg(LSR, 8'h63, "LSR overrun");
    expect_reg(LSR, 8'h61, "LSR read clears the overrun");
    for (int i = 0; i < 16; i++) expect_reg(RBR, mask(8'(i)), "characters before the overrun kept");
    expect_reg(LSR, 8'h60, "RX FIFO empty after the overrun");
    // FCR RX reset and the FIFO enable toggle
    for (int i = 0; i < 3; i++) send(8'(i), 1'b0, 1'b0);
    wr(FCR, 8'hc3);
    expect_reg(LSR, 8'h60, "FCR RX reset");
    send(8'h01, 1'b0, 1'b0);
    wr(FCR, 8'h00);
    expect_reg(LSR, 8'h60, "FIFO disable clears the RX FIFO");
    fifo_on = 0;
    wr(IER, 8'h00);
  endtask

  task automatic t_16450();
    set_fifo(1'b0, 2'd0);
    wr(IER, 8'h05);
    expect_reg(IIR, 8'h01, "IIR in 16450 mode");
    send(8'h15, 1'b0, 1'b0);
    idle(8);
    check_irq(4'h4, "16450 data ready");
    expect_reg(RBR, mask(8'h15), "16450 RX character");
    send(8'h0a, 1'b0, 1'b0);
    send(8'h0b, 1'b0, 1'b0);
    idle(8);
    check_irq(4'h6, "16450 overrun");
    expect_reg(LSR, 8'h63, "16450 overrun LSR");
    expect_reg(RBR, mask(8'h0a), "16450 keeps the first character");
    check_irq(4'h1, "16450 interrupts cleared");
    send(8'h13, 1'b0, 1'b1);
    idle(8);
    expect_reg(LSR, 8'h69, "16450 framing error, no rxfe");
    expect_reg(RBR, mask(8'h13), "16450 character with a framing error");
    wr(IER, 8'h00);
  endtask

  task automatic t_loopback();
    logic [7:0] d;
    set_fifo(1'b1, 2'd0);
    wr(MCR, 8'h10);
    `CHECK(txd && rts_n && dtr_n && out1_n && out2_n, "loopback: pins inactive")
    expect_reg(MSR, 8'h00, "loopback MSR");
    for (int i = 0; i < 3; i++) begin
      d = 8'($urandom);
      wr(THR, d);
      `CHECK(txd, "loopback: txd high")
      wait_tx_empty();
      idle(bit_clk());
      expect_reg(RBR, mask(d), "loopback character");
    end
    wr(IER, 8'h08);
    wr(MCR, 8'h1f);   // dtr, rts, out1, out2
    idle(3);
    check_irq(4'h0, "modem status interrupt");
    expect_reg(MSR, 8'hfb, "loopback modem lines and deltas");
    expect_reg(MSR, 8'hf0, "MSR read clears the deltas");
    wr(MCR, 8'h1b);   // out1 off: RI goes inactive
    idle(3);
    expect_reg(MSR, 8'hb4, "TERI on RI going inactive");
    wr(MCR, 8'h10);
    idle(3);
    expect_reg(MSR, 8'h0b, "deltas on the other lines");
    // break looped back
    wr(LCR, {2'b01, f_stick, f_eps, f_pen, f_stb, f_wls});
    `CHECK(txd, "loopback: txd high during break")
    idle(char_clk() + 2 * bit_clk());
    wr(LCR, {2'b00, f_stick, f_eps, f_pen, f_stb, f_wls});
    idle(2 * bit_clk());
    rd(LSR, d);
    `CHECK(d[4] && d[3] && d[0], "loopback break received")
    expect_reg(RBR, 8'h00, "break character");
    wr(MCR, 8'h00);
    wr(IER, 8'h00);
    check_irq(4'h1, "loopback interrupts cleared");
  endtask

  task automatic t_modem_pins();
    logic [7:0] m;
    wr(MCR, 8'h0f);
    `CHECK(!rts_n && !dtr_n && !out1_n && !out2_n, "MCR drives the pins")
    wr(MCR, 8'h00);
    `CHECK(rts_n && dtr_n && out1_n && out2_n, "MCR pins off")
    rd(MSR, m);
    cts_n = 0; idle(4);
    expect_reg(MSR, 8'h11, "CTS active");
    dsr_n = 0; dcd_n = 0; ri_n = 0; idle(4);
    expect_reg(MSR, 8'hfa, "DSR, DCD, RI active");
    ri_n = 1; idle(4);
    expect_reg(MSR, 8'hb4, "RI inactive");
    cts_n = 1; dsr_n = 1; dcd_n = 1; idle(4);
    expect_reg(MSR, 8'h0b, "all inactive");
  endtask

  task automatic t_tx_break();
    mon_en = 0;
    wr(LCR, {2'b01, f_stick, f_eps, f_pen, f_stb, f_wls});
    idle(2);
    `CHECK(!txd, "TX break holds txd low")
    idle(bit_clk());
    wr(LCR, {2'b00, f_stick, f_eps, f_pen, f_stb, f_wls});
    idle(2);
    `CHECK(txd, "TX break released")
    mon_en = 1;
  endtask

  task automatic t_priority();
    logic [7:0] d;
    set_fifo(1'b1, 2'd0);
    wr(MCR, 8'h10);
    wr(MCR, 8'h12);   // loopback: CTS delta
    send(8'h01, 1'b0, 1'b0);   // with loop on, rxd is ignored: no character
    wr(MCR, 8'h00);
    send(8'h02, 1'b1, 1'b1);   // parity (if on) and framing error
    idle(8);
    wr(IER, 8'h0f);
    check_irq(4'h6, "line status first");
    rd(LSR, d);
    check_irq(4'h4, "then data available");
    rd(RBR, d);
    check_irq(4'h2, "then THR empty");
    check_irq(4'h0, "then modem status (THR empty acknowledged)");
    rd(MSR, d);
    check_irq(4'h1, "none left");
    wr(IER, 8'h00);
  endtask

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    rxd = 1; cts_n = 1; dsr_n = 1; ri_n = 1; dcd_n = 1;
    div = 1; f_wls = 3; n_fmt = 0; f_stb = 0; f_pen = 0; f_eps = 0; f_stick = 0; fifo_on = 0;
    mon_en = 1; n_tx = 0;
    tb_reset();
    t_reset_values();
    t_registers();
    t_modem_pins();
    for (int it = 0; it < 6; it++) begin
      set_format(1 + it % 3);
      set_fifo(1'b1, 2'($urandom));
      t_tx(1 + $urandom % 20);
      t_thre_irq();
      t_tx_reset();
      t_tx_break();
      for (int t = 0; t < 4; t++) t_rx(2'(t));
      t_rx_errors();
      t_16450();
      set_fifo(1'b0, 2'd0);
      t_tx(3);
      t_loopback();
      t_priority();
    end
    // divisor 0 counts as 65536 clocks per tick
    set_format(0);
    idle(65530 - int'(dut.baud_cnt));
    `CHECK(!dut.baud_tick, "divisor 0: no tick before 65536 clocks")
    idle(10);
    `CHECK(dut.baud_cnt < 16'd16, "divisor 0: the tick came")
    `CHECK(tx_exp.size() == 0, "TX characters all decoded")
    $display("TX characters decoded: %0d", n_tx);
    tb_pass();
  end
endmodule
