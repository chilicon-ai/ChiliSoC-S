// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_uart
//
// ns16550a-compatible UART: 16-byte TX and RX FIFOs, 5 to 8 data bits, odd /
// even / stick parity, 1, 1.5 or 2 stop bits, break, modem control and
// status lines, loopback and the 16550 interrupt priorities. Registers are
// 8 bits on 32-bit words (device tree: reg-shift = <2>, reg-io-width = <4>):
//   0x00 RBR (read) / THR (write) / DLL (DLAB)   0x10 MCR
//   0x04 IER / DLM (DLAB)                        0x14 LSR
//   0x08 IIR (read) / FCR (write)                0x18 MSR
//   0x0C LCR                                     0x1C SCR
// Baud rate = clk / (16 * {DLM, DLL}); a divisor of 0 counts as 65536.
// Writes that act (THR push, FCR resets, enabling ETBEI) need PSTRB[0].
//
// FIFOs: with FCR.enable 0 each FIFO holds one character (16450 mode).
// Changing FCR.enable, or writing FCR with a reset bit, clears the FIFO(s).
// A character received with the RX FIFO full is lost and sets LSR.oe.
// LSR pe / fe / bi show the errors of the character at the head of the RX
// FIFO until LSR is read or the character is popped; LSR.rxfe is set while
// any character in the RX FIFO has an error (FIFO mode).
//
// Interrupts (IIR id, highest first; irq is IIR id != 1, registered):
//   0x6 line status   ier.elsi  && (oe || pe || fe || bi)      read LSR
//   0x4 data ready    ier.erbfi && RX count >= trigger (FIFO mode) or DR
//   0xC timeout       ier.erbfi && FIFO mode && RX not empty and no push or
//                     pop for 4 character times               read RBR
//   0x2 THR empty     ier.etbei && THRE && not acknowledged; reading IIR
//                     while it reports 0x2 acknowledges; a THR write or
//                     setting ier.etbei re-arms it
//   0x0 modem status  ier.edssi && any MSR delta bit          read MSR
//
// Timing    : APB reads are combinational (no wait states); irq is
//             registered (one cycle after its cause); pins are synchronized
//             by two flops (rxd and the modem inputs add 2 cycles).
// Invariants: err_cnt <= rx_count (no error characters in an empty RX
//             FIFO); irq is the registered (iir_id != 1) of the cycle before.
// Debug     : nothing sent -> u_tx_fifo.count, u_tx.state, baud_tick
//             (divisor dll / dlm); nothing received -> rx_line,
//             u_rx.state, u_rx_fifo.count, oe; no interrupt -> iir_id,
//             thre_ack, to_hit, rx_trig; wrong register -> u_regs.regs_slot.
// -----------------------------------------------------------------------------
module chilimix_uart (
  input  logic        clk,
  input  logic        rst_n,      // async, active-low
  // APB4 subordinate (registers)
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [4:0]  PADDR,      // byte address inside the UART
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,
  // serial line and modem pins (asynchronous inputs)
  input  logic        rxd,
  output logic        txd,
  input  logic        cts_n,
  input  logic        dsr_n,
  input  logic        ri_n,
  input  logic        dcd_n,
  output logic        rts_n,
  output logic        dtr_n,
  output logic        out1_n,
  output logic        out2_n,
  // interrupt (level, active high)
  output logic        irq
);

  localparam int DEPTH = 16;               // FIFO entries (16550)
  localparam int CNT_W = $clog2(DEPTH + 1);

  // ---- register block ports -------------------------------------------------
  logic [7:0]  rbr_data;          // RX FIFO head (0 when empty)
  logic        rbr_rd;
  logic [7:0]  thr_data;
  logic        thr_wr;
  logic [7:0]  dll_value;
  logic [7:0]  dlm_value;
  logic        ier_erbfi, ier_etbei, ier_elsi, ier_edssi;
  logic        ier_wr;
  logic [3:0]  iir_id;
  logic [1:0]  iir_fifos;
  logic        iir_rd;
  logic        fcr_enable;
  logic        fcr_rx_reset;      // PWDATA bit 1 (with fcr_wr)
  logic        fcr_tx_reset;      // PWDATA bit 2 (with fcr_wr)
  logic [1:0]  fcr_rx_trigger;
  logic        fcr_wr;
  logic [1:0]  lcr_wls;
  logic        lcr_stb, lcr_pen, lcr_eps, lcr_stick, lcr_brk;
  logic        mcr_dtr, mcr_rts, mcr_out1, mcr_out2, mcr_loop;
  logic        lsr_dr, lsr_oe, lsr_pe, lsr_fe, lsr_bi, lsr_thre, lsr_temt, lsr_rxfe;
  logic        lsr_rd;
  logic        msr_dcts, msr_ddsr, msr_teri, msr_ddcd;
  logic        msr_cts, msr_dsr, msr_ri, msr_dcd;
  logic        msr_rd;

  // ---- internal signals -----------------------------------------------------
  logic        lane0_wr;          // the write carries byte lane 0
  logic        fifo_toggle;       // FCR write changes FCR.enable
  logic [15:0] div_m1;            // divisor - 1
  logic [15:0] baud_cnt;          // clocks since the last baud tick
  logic        baud_tick;         // 16x baud enable
  logic [4:0]  pins_async;        // {rxd, dcd_n, ri_n, dsr_n, cts_n}
  logic [4:0]  pins;              // the same, synchronized
  logic        tx_line;           // transmitter output (break included)
  logic        rx_line;           // receiver input (rxd, or tx_line in loopback)
  logic [3:0]  modem;             // {dcd, ri, dsr, cts}, active high (MSR order)
  logic [3:0]  modem_fall;        // per line 1 -> 0
  logic [3:0]  modem_edge;        // per line any change
  logic [3:0]  delta;             // MSR {ddcd, teri, ddsr, dcts}
  logic [3:0]  delta_set;         // delta events this cycle
  logic [3:0]  delta_clr;         // MSR read: clear every delta bit
  logic [3:0]  delta_en;          // ier.edssi for every delta bit
  logic        msr_irq;           // an MSR delta bit with ier.edssi
  // TX path
  logic        tx_push;           // character into the TX FIFO
  logic        tx_room;           // TX FIFO can take a character
  logic        tx_flush;
  logic        tx_in_accept;
  logic        tx_valid;          // TX FIFO head valid
  logic        tx_accept;         // transmitter takes the head
  logic [7:0]  tx_data;
  logic [CNT_W-1:0] tx_count;
  logic        tx_busy;
  // RX path
  logic        rx_valid;          // character received (one cycle)
  logic [7:0]  rx_data;
  logic        rx_pe, rx_fe, rx_bi;
  logic [10:0] rx_entry;          // {bi, fe, pe, data}
  logic        rx_room;           // RX FIFO can take a character
  logic        rx_push;
  logic        rx_flush;
  logic        rx_in_accept;
  logic        rx_head_valid;     // RX FIFO not empty
  logic        rx_pop;
  logic [10:0] rx_head;           // RX FIFO head entry
  logic [CNT_W-1:0] rx_count;
  logic        overrun;           // character lost this cycle
  logic        oe;                // LSR.oe
  logic        rx_err_in;         // pushed character has an error
  logic        rx_err_out;        // popped character has an error
  logic [CNT_W-1:0] err_cnt;      // characters with errors in the RX FIFO
  logic        head_seen_d;
  logic        head_seen;         // LSR read since this head arrived
  // interrupts
  logic [CNT_W-1:0] rx_trig;      // RX FIFO interrupt level
  logic        rda;               // received data available
  logic [3:0]  char_bits;         // bits per character (1.5 stop counts 2)
  logic [9:0]  to_limit;          // 4 character times in baud ticks
  logic [9:0]  to_cnt;            // baud ticks without RX FIFO activity
  logic        to_clr;
  logic        to_en;
  logic        to_hit;            // to_cnt reached 4 character times
  logic        etbei_set;         // IER write turning etbei on
  logic        thre_ack_d;
  logic        thre_ack;          // THR empty interrupt acknowledged
  logic        irq_d;

  chilimix_uart_regs u_regs (
    .clk            (clk),
    .rst_n          (rst_n),
    .PSEL           (PSEL),
    .PENABLE        (PENABLE),
    .PWRITE         (PWRITE),
    .PADDR          (PADDR),
    .PWDATA         (PWDATA),
    .PSTRB          (PSTRB),
    .PREADY         (PREADY),
    .PRDATA         (PRDATA),
    .PSLVERR        (PSLVERR),
    .rbr_data       (rbr_data),
    .rbr_rd         (rbr_rd),
    .thr_data       (thr_data),
    .thr_wr         (thr_wr),
    .dll_value      (dll_value),
    .ier_erbfi      (ier_erbfi),
    .ier_etbei      (ier_etbei),
    .ier_elsi       (ier_elsi),
    .ier_edssi      (ier_edssi),
    .ier_wr         (ier_wr),
    .dlm_value      (dlm_value),
    .iir_id         (iir_id),
    .iir_fifos      (iir_fifos),
    .iir_rd         (iir_rd),
    .fcr_enable     (fcr_enable),
    .fcr_rx_reset   (fcr_rx_reset),
    .fcr_tx_reset   (fcr_tx_reset),
    .fcr_dma_mode   (),
    .fcr_rx_trigger (fcr_rx_trigger),
    .fcr_wr         (fcr_wr),
    .lcr_wls        (lcr_wls),
    .lcr_stb        (lcr_stb),
    .lcr_pen        (lcr_pen),
    .lcr_eps        (lcr_eps),
    .lcr_stick      (lcr_stick),
    .lcr_brk        (lcr_brk),
    .lcr_dlab       (),
    .mcr_dtr        (mcr_dtr),
    .mcr_rts        (mcr_rts),
    .mcr_out1       (mcr_out1),
    .mcr_out2       (mcr_out2),
    .mcr_loop       (mcr_loop),
    .lsr_dr         (lsr_dr),
    .lsr_oe         (lsr_oe),
    .lsr_pe         (lsr_pe),
    .lsr_fe         (lsr_fe),
    .lsr_bi         (lsr_bi),
    .lsr_thre       (lsr_thre),
    .lsr_temt       (lsr_temt),
    .lsr_rxfe       (lsr_rxfe),
    .lsr_rd         (lsr_rd),
    .msr_dcts       (msr_dcts),
    .msr_ddsr       (msr_ddsr),
    .msr_teri       (msr_teri),
    .msr_ddcd       (msr_ddcd),
    .msr_cts        (msr_cts),
    .msr_dsr        (msr_dsr),
    .msr_ri         (msr_ri),
    .msr_dcd        (msr_dcd),
    .msr_rd         (msr_rd),
    .scr_value      ()
  );

  assign lane0_wr    = PSTRB[0];
  assign fifo_toggle = fcr_wr && lane0_wr && (PWDATA[0] != fcr_enable);

  // ---- baud rate: one tick every {DLM, DLL} clocks --------------------------
  assign div_m1    = {dlm_value, dll_value} - 16'd1;
  assign baud_tick = (baud_cnt >= div_m1);

  basechili_counter #(.WIDTH(16)) u_baud_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (baud_tick),
    .en    (1'b1),
    .count (baud_cnt)
  );

  // ---- pins, loopback and modem status --------------------------------------
  assign pins_async = {rxd, dcd_n, ri_n, dsr_n, cts_n};

  basechili_sync #(.WIDTH(5), .STAGES(2), .RESET_VAL(5'b11111)) u_sync (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pins_async),
    .q     (pins)
  );

  assign rx_line = mcr_loop ? tx_line : pins[4];
  assign txd     = mcr_loop || tx_line;
  assign modem   = mcr_loop ? {mcr_out2, mcr_out1, mcr_dtr, mcr_rts} : ~pins[3:0];   // loopback: DCD = OUT2, RI = OUT1, DSR = DTR, CTS = RTS
  assign rts_n   = mcr_loop || !mcr_rts;
  assign dtr_n   = mcr_loop || !mcr_dtr;
  assign out1_n  = mcr_loop || !mcr_out1;
  assign out2_n  = mcr_loop || !mcr_out2;

  basechili_edge_detect #(.WIDTH(4)) u_modem_edge (
    .clk      (clk),
    .rst_n    (rst_n),
    .in       (modem),
    .rise     (),
    .fall     (modem_fall),
    .any_edge (modem_edge)
  );

  // MSR delta bits: set by an event (wins over the read), cleared by an MSR read
  assign delta_set = {modem_edge[3], modem_fall[2], modem_edge[1], modem_edge[0]};
  assign delta_clr = {4{msr_rd}};
  assign delta_en  = {4{ier_edssi}};

  basechili_irq_aggregator #(.N(4)) u_delta (
    .clk      (clk),
    .rst_n    (rst_n),
    .src      (delta_set),
    .edge_sel (4'b0000),
    .enable   (delta_en),
    .clr      (delta_clr),
    .pending  (delta),
    .active   (),
    .irq      (msr_irq)
  );

  assign {msr_ddcd, msr_teri, msr_ddsr, msr_dcts} = delta;
  assign {msr_dcd, msr_ri, msr_dsr, msr_cts}      = modem;

  // ---- transmit -------------------------------------------------------------
  assign tx_room  = fcr_enable ? tx_in_accept : (tx_count == '0);
  assign tx_push  = thr_wr && lane0_wr && tx_room;
  assign tx_flush = fifo_toggle || (fcr_wr && lane0_wr && fcr_tx_reset);

  basechili_fifo #(.WIDTH(8), .DEPTH(DEPTH)) u_tx_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (tx_flush),
    .in_valid   (tx_push),
    .in_accept  (tx_in_accept),
    .in_data    (thr_data),
    .out_valid  (tx_valid),
    .out_accept (tx_accept),
    .out_data   (tx_data),
    .count      (tx_count)
  );

  chilimix_uart_tx u_tx (
    .clk       (clk),
    .rst_n     (rst_n),
    .tick      (baud_tick),
    .wls       (lcr_wls),
    .stb       (lcr_stb),
    .pen       (lcr_pen),
    .eps       (lcr_eps),
    .stick     (lcr_stick),
    .brk       (lcr_brk),
    .in_valid  (tx_valid),
    .in_accept (tx_accept),
    .in_data   (tx_data),
    .txd       (tx_line),
    .busy      (tx_busy)
  );

  assign lsr_thre = (tx_count == '0);
  assign lsr_temt = lsr_thre && !tx_busy;

  // ---- receive --------------------------------------------------------------
  chilimix_uart_rx u_rx (
    .clk       (clk),
    .rst_n     (rst_n),
    .tick      (baud_tick),
    .rxd       (rx_line),
    .wls       (lcr_wls),
    .pen       (lcr_pen),
    .eps       (lcr_eps),
    .stick     (lcr_stick),
    .out_valid (rx_valid),
    .out_data  (rx_data),
    .out_pe    (rx_pe),
    .out_fe    (rx_fe),
    .out_bi    (rx_bi),
    .busy      ()
  );

  assign rx_entry = {rx_bi, rx_fe, rx_pe, rx_data};
  assign rx_room  = fcr_enable ? rx_in_accept : (rx_count == '0);
  assign rx_push  = rx_valid && rx_room;
  assign overrun  = rx_valid && !rx_room;
  assign rx_flush = fifo_toggle || (fcr_wr && lane0_wr && fcr_rx_reset);
  assign rx_pop   = rbr_rd && rx_head_valid;

  basechili_fifo #(.WIDTH(11), .DEPTH(DEPTH)) u_rx_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (rx_flush),
    .in_valid   (rx_push),
    .in_accept  (rx_in_accept),
    .in_data    (rx_entry),
    .out_valid  (rx_head_valid),
    .out_accept (rx_pop),
    .out_data   (rx_head),
    .count      (rx_count)
  );

  assign rbr_data = rx_head_valid ? rx_head[7:0] : 8'h00;

  // errors in the FIFO (LSR.rxfe)
  assign rx_err_in  = rx_push && (rx_pe || rx_fe || rx_bi);
  assign rx_err_out = rx_pop && (|rx_head[10:8]);

  basechili_updown_counter #(.WIDTH(CNT_W)) u_err_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (rx_flush),
    .load_val ('0),
    .inc      (rx_err_in),
    .dec      (rx_err_out),
    .count    (err_cnt),
    .count_d  ()
  );

  // head errors show until LSR is read (or the character is popped)
  assign head_seen_d = rx_head_valid && !rx_pop && !rx_flush && (head_seen || lsr_rd);

  basechili_dff #(.WIDTH(1)) u_head_seen (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (head_seen_d),
    .q     (head_seen)
  );

  // LSR.oe: set by an overrun (wins over the read), cleared by an LSR read
  basechili_irq_aggregator #(.N(1)) u_oe (
    .clk      (clk),
    .rst_n    (rst_n),
    .src      (overrun),
    .edge_sel (1'b0),
    .enable   (1'b1),
    .clr      (lsr_rd),
    .pending  (oe),
    .active   (),
    .irq      ()
  );

  assign lsr_dr   = rx_head_valid;
  assign lsr_oe   = oe;
  assign lsr_pe   = rx_head_valid && !head_seen && rx_head[8];
  assign lsr_fe   = rx_head_valid && !head_seen && rx_head[9];
  assign lsr_bi   = rx_head_valid && !head_seen && rx_head[10];
  assign lsr_rxfe = fcr_enable && (err_cnt != '0);

  // ---- character timeout: 4 character times without RX FIFO activity -------
  assign char_bits = 4'd7 + {2'b0, lcr_wls} + {3'b0, lcr_pen} + {3'b0, lcr_stb};   // start + 5..8 + parity + stop(s)
  assign to_limit  = {char_bits, 6'b0};                                            // x 16 ticks x 4 characters
  assign to_hit    = (to_cnt >= to_limit);
  assign to_clr    = rx_push || rx_pop || rx_flush || !rx_head_valid;
  assign to_en     = baud_tick && !to_hit;

  basechili_counter #(.WIDTH(10)) u_to_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (to_clr),
    .en    (to_en),
    .count (to_cnt)
  );

  // ---- interrupts -----------------------------------------------------------
  always_comb begin
    case (fcr_rx_trigger)
      2'd0:    rx_trig = CNT_W'(1);
      2'd1:    rx_trig = CNT_W'(4);
      2'd2:    rx_trig = CNT_W'(8);
      default: rx_trig = CNT_W'(14);
    endcase
  end

  assign rda = fcr_enable ? (rx_count >= rx_trig) : rx_head_valid;

  assign etbei_set  = ier_wr && lane0_wr && PWDATA[1] && !ier_etbei;
  assign thre_ack_d = !(thr_wr && lane0_wr) && !etbei_set && (thre_ack || (iir_rd && iir_id == 4'h2));

  basechili_dff #(.WIDTH(1)) u_thre_ack (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (thre_ack_d),
    .q     (thre_ack)
  );

  always_comb begin
    if (ier_elsi && (lsr_oe || lsr_pe || lsr_fe || lsr_bi))  iir_id = 4'h6;
    else if (ier_erbfi && rda)                              iir_id = 4'h4;
    else if (ier_erbfi && fcr_enable && rx_head_valid && to_hit) iir_id = 4'hc;
    else if (ier_etbei && lsr_thre && !thre_ack)            iir_id = 4'h2;
    else if (msr_irq)                                       iir_id = 4'h0;
    else                                                    iir_id = 4'h1;
  end

  assign iir_fifos = {2{fcr_enable}};
  assign irq_d     = (iir_id != 4'h1);

  basechili_dff #(.WIDTH(1)) u_irq (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (irq_d),
    .q     (irq)
  );

endmodule
