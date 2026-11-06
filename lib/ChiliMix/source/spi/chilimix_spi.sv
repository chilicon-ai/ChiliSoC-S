// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_spi
//
// SPI controller in the SiFive SPI layout (sifive,spi0, as the FE310 QSPI0),
// so the Linux spi-sifive / Zephyr spi_sifive drivers and the FE310 flash
// setup code work:
//   0x00 sckdiv   0x18 csmode   0x40 fmt      0x50 txmark   0x64 ffmt
//   0x04 sckmode  0x28 delay0   0x48 txdata   0x54 rxmark   0x70 ie
//   0x10 csid     0x2C delay1   0x4C rxdata   0x60 fctrl    0x74 ip
//   0x14 csdef
// Frames: each txdata write pushes one frame (fmt: 0 .. 8 bits, single /
// dual / quad, MSB or LSB first) into an 8-entry TX FIFO; with fmt.dir 0
// its received bits go to an 8-entry RX FIFO (a frame starts only when the
// RX FIFO has room, so nothing is lost). For dual / quad set len to a
// multiple of the width. Chip select: csmode AUTO / HOLD / OFF with the
// delay0 / delay1 timing (chilimix_spi_phy). A HOLD ends when csmode,
// csid or csdef is written, or when the flash interface takes over.
//
// Flash interface (fctrl.en, set at reset): reads of the XIP window (AHB
// port) are served by chilimix_spi_xip with the ffmt instruction; FIFO
// frames wait while fctrl.en is set (clear it to send commands to the
// flash, as the drivers do). Writing fctrl or ffmt empties the read cache.
//
// Interrupts: ip.txwm = TX count < txmark, ip.rxwm = RX count > rxmark;
// irq = |(ie & ip), registered.
//
// Timing    : APB reads are combinational (no wait states); irq is
//             registered; pins as chilimix_spi_phy (sck and cs registered).
// Invariants: a FIFO frame starts only with fctrl.en clear and no fill
//             running; the RX FIFO accepts every frame received for it;
//             rx_pend is set exactly while a FIFO frame with fmt.dir 0 is
//             in the phy; irq is the registered |(ie & ip).
// Debug     : nothing sent -> fctrl_en (frames wait), u_tx_fifo.count,
//             u_phy.state; lost RX frames -> rx_pend, u_rx_fifo.count; cs
//             stuck asserted -> u_phy.state S_HELD, release_cs, cs_chg;
//             XIP read stuck -> u_xip.state, u_phy.state, xip_sel.
// -----------------------------------------------------------------------------
module chilimix_spi #(
  parameter int N_CS       = 1,          // chip select pins, 1 .. 4
  parameter int XIP_AW     = 29,         // flash window address bits (512 MiB)
  parameter int XIP_LINES  = 4,          // read cache lines, a power of 2 (>= 2)
  parameter int XIP_LINE_B = 16          // bytes per cache line, a power of 2 (8 .. 128)
) (
  input  logic              clk,
  input  logic              rst_n,       // async, active-low
  // APB4 subordinate (registers)
  input  logic              PSEL,
  input  logic              PENABLE,
  input  logic              PWRITE,
  input  logic [6:0]        PADDR,       // byte address inside the controller
  input  logic [31:0]       PWDATA,
  input  logic [3:0]        PSTRB,
  output logic              PREADY,
  output logic [31:0]       PRDATA,
  output logic              PSLVERR,
  // AHB-Lite subordinate (flash window, read only)
  input  logic              HSEL,
  input  logic [XIP_AW-1:0] HADDR,       // byte address inside the window
  input  logic [1:0]        HTRANS,
  input  logic              HWRITE,
  input  logic [2:0]        HSIZE,
  input  logic [31:0]       HWDATA,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [31:0]       HRDATA,
  // pins
  output logic              sck,
  output logic [N_CS-1:0]   cs,          // csdef when deasserted
  output logic [3:0]        dq_o,
  output logic [3:0]        dq_oe,
  input  logic [3:0]        dq_i,
  // interrupt (level, active high)
  output logic              irq
);

  localparam int DEPTH = 8;              // FIFO entries (FE310)
  localparam int CNT_W = $clog2(DEPTH + 1);
  localparam logic [CNT_W-1:0] DEPTH_C = DEPTH;

  // ---- register block ports -------------------------------------------------
  logic [11:0] sckdiv_div;
  logic        sckmode_pha, sckmode_pol;
  logic [1:0]  csid_csid;
  logic        csid_wr;
  logic [3:0]  csdef_csdef;
  logic        csdef_wr;
  logic [1:0]  csmode_mode;
  logic        csmode_wr;
  logic [7:0]  delay0_cssck, delay0_sckcs, delay1_intercs, delay1_interxfr;
  logic [1:0]  fmt_proto;
  logic        fmt_endian, fmt_dir;
  logic [3:0]  fmt_len;
  logic [7:0]  txdata_data;
  logic        txdata_full;
  logic        txdata_wr;
  logic [7:0]  rxdata_data;
  logic        rxdata_empty;
  logic        rxdata_rd;
  logic [2:0]  txmark_txmark, rxmark_rxmark;
  logic        fctrl_en, fctrl_wr;
  logic        ffmt_cmd_en;
  logic [2:0]  ffmt_addr_len;
  logic [3:0]  ffmt_pad_cnt;
  logic [1:0]  ffmt_cmd_proto, ffmt_addr_proto, ffmt_data_proto;
  logic [7:0]  ffmt_cmd_code, ffmt_pad_code;
  logic        ffmt_wr;
  logic        ie_txwm, ie_rxwm;
  logic        ip_txwm, ip_rxwm;

  // ---- internal signals -----------------------------------------------------
  logic [N_CS-1:0]  csdef;        // csdef bits of the pins
  logic             cs_wr;        // csmode, csid or csdef written
  logic             cs_chg_d;
  logic             cs_chg;       // written since the cs was asserted (ends a HOLD)
  logic             hold_mode;    // csmode HOLD
  logic             off_mode;     // csmode OFF
  logic             release_cs;
  logic             xip_sel;      // the flash interface owns the phy
  logic             flush;        // empty the read cache
  // TX path
  logic             tx_push;
  logic             tx_in_accept;
  logic             tx_valid;     // TX FIFO head valid
  logic             tx_pop;
  logic [7:0]       tx_head;
  logic [CNT_W-1:0] tx_count;
  // RX path
  logic             rx_room;      // RX FIFO can take the frame about to start
  logic             rx_pend_d;
  logic             rx_pend;      // a FIFO frame with dir 0 is in the phy
  logic             rx_push;
  logic             rx_head_valid;
  logic             rx_pop;
  logic [7:0]       rx_head;
  logic [CNT_W-1:0] rx_count;
  logic             rx_full_pend; // RX count plus the pending frame
  // FIFO frames
  logic [3:0]       len8;         // fmt.len, at most 8
  logic [3:0]       fifo_cycles;
  logic             fifo_valid;
  logic             fifo_fire;    // a FIFO frame starts
  logic             fifo_oe;
  logic             fifo_cs;
  // XIP frames
  logic             xip_valid;
  logic [7:0]       xip_data;
  logic [3:0]       xip_cycles;
  logic [1:0]       xip_proto;
  logic             xip_oe, xip_rx, xip_keep, xip_first;
  logic             xip_busy;
  logic             xip_accept;   // the phy takes a flash interface frame
  logic             xip_rx_valid;
  logic             src_xip;      // the frame in the phy came from the flash interface
  // phy frame port
  logic             f_valid;
  logic             f_accept;
  logic [7:0]       f_data;
  logic [3:0]       f_cycles;
  logic [1:0]       f_proto;
  logic             f_msb, f_oe, f_rx, f_cs, f_keep, f_gap, f_first;
  logic             rx_valid;
  logic [7:0]       rx_data;
  logic             cs_active;
  logic             irq_d;

  chilimix_spi_regs u_regs (
    .clk             (clk),
    .rst_n           (rst_n),
    .PSEL            (PSEL),
    .PENABLE         (PENABLE),
    .PWRITE          (PWRITE),
    .PADDR           (PADDR),
    .PWDATA          (PWDATA),
    .PSTRB           (PSTRB),
    .PREADY          (PREADY),
    .PRDATA          (PRDATA),
    .PSLVERR         (PSLVERR),
    .sckdiv_div      (sckdiv_div),
    .sckmode_pha     (sckmode_pha),
    .sckmode_pol     (sckmode_pol),
    .csid_csid       (csid_csid),
    .csid_wr         (csid_wr),
    .csdef_csdef     (csdef_csdef),
    .csdef_wr        (csdef_wr),
    .csmode_mode     (csmode_mode),
    .csmode_wr       (csmode_wr),
    .delay0_cssck    (delay0_cssck),
    .delay0_sckcs    (delay0_sckcs),
    .delay1_intercs  (delay1_intercs),
    .delay1_interxfr (delay1_interxfr),
    .fmt_proto       (fmt_proto),
    .fmt_endian      (fmt_endian),
    .fmt_dir         (fmt_dir),
    .fmt_len         (fmt_len),
    .txdata_data     (txdata_data),
    .txdata_full     (txdata_full),
    .txdata_wr       (txdata_wr),
    .rxdata_data     (rxdata_data),
    .rxdata_empty    (rxdata_empty),
    .rxdata_rd       (rxdata_rd),
    .txmark_txmark   (txmark_txmark),
    .rxmark_rxmark   (rxmark_rxmark),
    .fctrl_en        (fctrl_en),
    .fctrl_wr        (fctrl_wr),
    .ffmt_cmd_en     (ffmt_cmd_en),
    .ffmt_addr_len   (ffmt_addr_len),
    .ffmt_pad_cnt    (ffmt_pad_cnt),
    .ffmt_cmd_proto  (ffmt_cmd_proto),
    .ffmt_addr_proto (ffmt_addr_proto),
    .ffmt_data_proto (ffmt_data_proto),
    .ffmt_cmd_code   (ffmt_cmd_code),
    .ffmt_pad_code   (ffmt_pad_code),
    .ffmt_wr         (ffmt_wr),
    .ie_txwm         (ie_txwm),
    .ie_rxwm         (ie_rxwm),
    .ip_txwm         (ip_txwm),
    .ip_rxwm         (ip_rxwm)
  );

  // ---- chip select control ----------------------------------------------------
  assign csdef     = csdef_csdef[N_CS-1:0];
  assign hold_mode = (csmode_mode == 2'd2);
  assign off_mode  = (csmode_mode == 2'd3);
  assign cs_wr     = csid_wr || csdef_wr || csmode_wr;
  assign cs_chg_d  = cs_wr || (cs_chg && cs_active);

  basechili_dff #(.WIDTH(1)) u_cs_chg (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (cs_chg_d),
    .q     (cs_chg)
  );

  // a FIFO hold ends on a write or a mode change; the flash interface holds
  // cs through its own frames and starts each read with a fresh assertion
  assign xip_sel    = fctrl_en || xip_busy;
  assign release_cs = !xip_busy && (!hold_mode || cs_chg || fctrl_en);

  // ---- TX FIFO ----------------------------------------------------------------
  assign tx_push     = txdata_wr && PSTRB[0];
  assign txdata_full = !tx_in_accept;

  basechili_fifo #(.WIDTH(8), .DEPTH(DEPTH)) u_tx_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (1'b0),
    .in_valid   (tx_push),
    .in_accept  (tx_in_accept),
    .in_data    (txdata_data),
    .out_valid  (tx_valid),
    .out_accept (tx_pop),
    .out_data   (tx_head),
    .count      (tx_count)
  );

  // ---- FIFO frames --------------------------------------------------------------
  assign len8 = (fmt_len > 4'd8) ? 4'd8 : fmt_len;

  always_comb begin
    case (fmt_proto)
      2'd1:    fifo_cycles = (len8 + 4'd1) >> 1;
      2'd2:    fifo_cycles = (len8 + 4'd3) >> 2;
      default: fifo_cycles = len8;
    endcase
  end

  assign rx_full_pend = (rx_count + CNT_W'(rx_pend)) >= DEPTH_C;
  assign rx_room      = !rx_full_pend;
  assign fifo_valid   = tx_valid && !xip_sel && (fmt_dir || rx_room);
  assign fifo_oe      = fmt_dir || (fmt_proto != 2'd1 && fmt_proto != 2'd2);
  assign fifo_cs      = !off_mode;

  // ---- phy frame source -------------------------------------------------------
  always_comb begin
    if (xip_sel) begin
      f_valid  = xip_valid;
      f_data   = xip_data;
      f_cycles = xip_cycles;
      f_proto  = xip_proto;
      f_msb    = 1'b1;
      f_oe     = xip_oe;
      f_rx     = xip_rx;
      f_cs     = 1'b1;
      f_keep   = xip_keep;
      f_gap    = 1'b0;
      f_first  = xip_first;
    end else begin
      f_valid  = fifo_valid;
      f_data   = tx_head;
      f_cycles = fifo_cycles;
      f_proto  = fmt_proto;
      f_msb    = !fmt_endian;
      f_oe     = fifo_oe;
      f_rx     = !fmt_dir;
      f_cs     = fifo_cs;
      f_keep   = hold_mode;
      f_gap    = 1'b1;
      f_first  = 1'b0;
    end
  end

  assign fifo_fire  = f_accept && !xip_sel;
  assign xip_accept = f_accept && xip_sel;
  assign tx_pop    = fifo_fire;

  basechili_dffe #(.WIDTH(1)) u_src_xip (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (f_accept),
    .d     (xip_sel),
    .q     (src_xip)
  );

  chilimix_spi_phy #(.N_CS(N_CS)) u_phy (
    .clk        (clk),
    .rst_n      (rst_n),
    .div        (sckdiv_div),
    .pol        (sckmode_pol),
    .pha        (sckmode_pha),
    .cssck      (delay0_cssck),
    .sckcs      (delay0_sckcs),
    .intercs    (delay1_intercs),
    .interxfr   (delay1_interxfr),
    .csid       (csid_csid),
    .csdef      (csdef),
    .release_cs (release_cs),
    .f_valid    (f_valid),
    .f_accept   (f_accept),
    .f_data     (f_data),
    .f_cycles   (f_cycles),
    .f_proto    (f_proto),
    .f_msb      (f_msb),
    .f_oe       (f_oe),
    .f_rx       (f_rx),
    .f_cs       (f_cs),
    .f_keep     (f_keep),
    .f_gap      (f_gap),
    .f_first    (f_first),
    .rx_valid   (rx_valid),
    .rx_data    (rx_data),
    .cs_active  (cs_active),
    .busy       (),
    .sck        (sck),
    .cs         (cs),
    .dq_o       (dq_o),
    .dq_oe      (dq_oe),
    .dq_i       (dq_i)
  );

  // ---- RX FIFO ----------------------------------------------------------------
  // rx_valid comes the cycle after the frame's last edge, before src_xip can
  // change (a new frame is taken at the earliest in that cycle)
  assign rx_push      = rx_valid && !src_xip;
  assign xip_rx_valid = rx_valid && src_xip;
  assign rx_pend_d    = (fifo_fire && !fmt_dir) || (rx_pend && !rx_push);

  basechili_dff #(.WIDTH(1)) u_rx_pend (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rx_pend_d),
    .q     (rx_pend)
  );

  assign rx_pop       = rxdata_rd && rx_head_valid;
  assign rxdata_data  = rx_head_valid ? rx_head : 8'h00;
  assign rxdata_empty = !rx_head_valid;

  basechili_fifo #(.WIDTH(8), .DEPTH(DEPTH)) u_rx_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (1'b0),
    .in_valid   (rx_push),
    .in_accept  (),
    .in_data    (rx_data),
    .out_valid  (rx_head_valid),
    .out_accept (rx_pop),
    .out_data   (rx_head),
    .count      (rx_count)
  );

  // ---- flash interface --------------------------------------------------------
  assign flush = fctrl_wr || ffmt_wr;

  chilimix_spi_xip #(.ADDR_W(XIP_AW), .LINES(XIP_LINES), .LINE_B(XIP_LINE_B)) u_xip (
    .clk        (clk),
    .rst_n      (rst_n),
    .HSEL       (HSEL),
    .HADDR      (HADDR),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HSIZE      (HSIZE),
    .HWDATA     (HWDATA),
    .HREADY     (HREADY),
    .HREADYOUT  (HREADYOUT),
    .HRESP      (HRESP),
    .HRDATA     (HRDATA),
    .en         (fctrl_en),
    .flush      (flush),
    .cmd_en     (ffmt_cmd_en),
    .addr_len   (ffmt_addr_len),
    .pad_cnt    (ffmt_pad_cnt),
    .cmd_proto  (ffmt_cmd_proto),
    .addr_proto (ffmt_addr_proto),
    .data_proto (ffmt_data_proto),
    .cmd_code   (ffmt_cmd_code),
    .pad_code   (ffmt_pad_code),
    .f_valid    (xip_valid),
    .f_accept   (xip_accept),
    .f_data     (xip_data),
    .f_cycles   (xip_cycles),
    .f_proto    (xip_proto),
    .f_oe       (xip_oe),
    .f_rx       (xip_rx),
    .f_keep     (xip_keep),
    .f_first    (xip_first),
    .rx_valid   (xip_rx_valid),
    .rx_data    (rx_data),
    .busy       (xip_busy)
  );

  // ---- interrupts -------------------------------------------------------------
  assign ip_txwm = (tx_count < CNT_W'(txmark_txmark));
  assign ip_rxwm = (rx_count > CNT_W'(rxmark_rxmark));
  assign irq_d   = (ie_txwm && ip_txwm) || (ie_rxwm && ip_rxwm);

  basechili_dff #(.WIDTH(1)) u_irq (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (irq_d),
    .q     (irq)
  );

endmodule
