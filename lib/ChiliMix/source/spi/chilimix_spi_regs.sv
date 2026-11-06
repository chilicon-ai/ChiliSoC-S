// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_spi_regs
//
// SPI controller in the SiFive SPI layout (sifive,spi0): single / dual / quad frames through 8-entry TX and RX FIFOs, and a memory-mapped flash read interface (XIP) register block: an APB4 subordinate (7-bit PADDR, 32-bit data).
// Register layout compatible with sifive,spi0.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   0x0000  sckdiv       div[11:0] rw
//   0x0004  sckmode      pol[1] rw, pha[0] rw
//   0x0010  csid         csid[1:0] rw
//   0x0014  csdef        csdef[3:0] rw
//   0x0018  csmode       mode[1:0] rw
//   0x0028  delay0       sckcs[23:16] rw, cssck[7:0] rw
//   0x002c  delay1       interxfr[23:16] rw, intercs[7:0] rw
//   0x0040  fmt          len[19:16] rw, dir[3] rw, endian[2] rw, proto[1:0] rw
//   0x0048  txdata       full[31] ro, data[7:0] wo
//   0x004c  rxdata       empty[31] ro, data[7:0] ro
//   0x0050  txmark       txmark[2:0] rw
//   0x0054  rxmark       rxmark[2:0] rw
//   0x0060  fctrl        en[0] rw
//   0x0064  ffmt         pad_code[31:24] rw, cmd_code[23:16] rw, data_proto[13:12] rw, addr_proto[11:10] rw, cmd_proto[9:8] rw, pad_cnt[7:4] rw, addr_len[3:1] rw, cmd_en[0] rw
//   0x0070  ie           rxwm[1] rw, txwm[0] rw
//   0x0074  ip           rxwm[1] ro, txwm[0] ro
//
// Words inside a block with no register read 0 and ignore writes; words past
// a block's last register give PSLVERR.
//
// Timing    : as basechili_apb_regbank: no wait states (PREADY high), PRDATA
//             combinational from the APB inputs; field outputs are registered
//             and change the cycle after the write or the _set input.
// Debug     : wrong read value -> u_<block>.reg_q / hw_rd; write lost -> PSTRB
//             and u_<block>.wr_pulse.
// -----------------------------------------------------------------------------
module chilimix_spi_regs (
  input  logic clk,
  input  logic rst_n,                  // async, active-low
  input  logic PSEL,                   // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [6:0] PADDR,            // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  output logic [11:0] sckdiv_div,      // rw: Divisor
  output logic sckmode_pha,            // rw: Phase: 0 sample on the leading edge, shift on the trailing edge; 1 shift on the leading edge, sample on the trailing edge
  output logic sckmode_pol,            // rw: Polarity: idle level of sck
  output logic [1:0] csid_csid,        // rw: Chip select index
  output logic csid_wr,                // csid write this cycle (APB ACCESS)
  output logic [3:0] csdef_csdef,      // rw: Inactive level of cs pin i
  output logic csdef_wr,               // csdef write this cycle (APB ACCESS)
  output logic [1:0] csmode_mode,      // rw: 0 AUTO: assert per frame; 2 HOLD: keep asserted after the first frame until csmode, csid or csdef is written; 3 OFF: never assert (1 acts as AUTO)
  output logic csmode_wr,              // csmode write this cycle (APB ACCESS)
  output logic [7:0] delay0_cssck,     // rw: cs assertion to the first sck edge
  output logic [7:0] delay0_sckcs,     // rw: Last sck edge to cs deassertion
  output logic [7:0] delay1_intercs,   // rw: Minimum cs deasserted time
  output logic [7:0] delay1_interxfr,  // rw: Delay between frames while cs stays asserted (HOLD)
  output logic [1:0] fmt_proto,        // rw: 0 single (dq0 out, dq1 in), 1 dual (dq1:0), 2 quad (dq3:0); 3 acts as single
  output logic fmt_endian,             // rw: 0 MSB first, 1 LSB first
  output logic fmt_dir,                // rw: 0 Rx: received frames go to the RX FIFO (dual / quad: dq pins not driven); 1 Tx: the RX FIFO is not written
  output logic [3:0] fmt_len,          // rw: Bits per frame, 0 to 8 (above 8 acts as 8)
  output logic [7:0] txdata_data,      // wo: Frame data
  input  logic txdata_full,            // ro: TX FIFO full
  output logic txdata_wr,              // txdata write this cycle (APB ACCESS)
  input  logic [7:0] rxdata_data,      // ro: Received frame (0 when empty)
  input  logic rxdata_empty,           // ro: RX FIFO empty: data is not valid
  output logic rxdata_rd,              // rxdata read this cycle (APB ACCESS)
  output logic [2:0] txmark_txmark,    // rw: ip.txwm is set while the TX FIFO holds fewer frames
  output logic [2:0] rxmark_rxmark,    // rw: ip.rxwm is set while the RX FIFO holds more frames
  output logic fctrl_en,               // rw: Memory-mapped flash reads enabled (FIFO frames wait while set)
  output logic fctrl_wr,               // fctrl write this cycle (APB ACCESS)
  output logic ffmt_cmd_en,            // rw: Send the command code
  output logic [2:0] ffmt_addr_len,    // rw: Address bytes, 0 to 4 (above 4 acts as 4)
  output logic [3:0] ffmt_pad_cnt,     // rw: Dummy sck cycles after the address
  output logic [1:0] ffmt_cmd_proto,   // rw: Command protocol (as fmt.proto)
  output logic [1:0] ffmt_addr_proto,  // rw: Address and dummy protocol
  output logic [1:0] ffmt_data_proto,  // rw: Data protocol
  output logic [7:0] ffmt_cmd_code,    // rw: Command code
  output logic [7:0] ffmt_pad_code,    // rw: Bits driven in the first dummy cycles (e.g
  output logic ffmt_wr,                // ffmt write this cycle (APB ACCESS)
  output logic ie_txwm,                // rw: TX watermark interrupt
  output logic ie_rxwm,                // rw: RX watermark interrupt
  input  logic ip_txwm,                // ro: TX FIFO count below txmark
  input  logic ip_rxwm                 // ro: RX FIFO count above rxmark
);

  // ---- block regs: 30 word(s) at 0x0
  localparam int                N_REGS = 30;
  localparam logic [959:0] RESET_REGS = 960'h0000_0000_0000_0000_0000_0000_0000_0000_0003_0007_0000_0001_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000_0000_0000_0000_0000_0008_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_0001_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003;
  localparam logic [959:0] RW_REGS = 960'h0000_0000_0000_0003_0000_0000_0000_0000_ffff_3fff_0000_0001_0000_0000_0000_0000_0000_0007_0000_0007_0000_0000_0000_0000_0000_0000_000f_000f_0000_0000_0000_0000_0000_0000_0000_0000_00ff_00ff_00ff_00ff_0000_0000_0000_0000_0000_0000_0000_0003_0000_000f_0000_0003_0000_0000_0000_0000_0000_0003_0000_0fff;
  localparam logic [959:0] W1C_REGS = 960'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [959:0] regs_reg_q;    // rw and w1c bit values
  logic [959:0] regs_hw_rd;    // read-only bit values
  logic [959:0] regs_hw_set;   // w1c set requests
  logic [29:0] regs_wr_pulse;    // register written this cycle
  logic [29:0] regs_rd_pulse;    // register read this cycle

  assign regs_hw_rd[31:0] = '0;  // sckdiv
  assign regs_hw_set[31:0] = '0;
  assign regs_hw_rd[63:32] = '0;  // sckmode
  assign regs_hw_set[63:32] = '0;
  assign regs_hw_rd[95:64] = '0;  // (no register)
  assign regs_hw_set[95:64] = '0;
  assign regs_hw_rd[127:96] = '0;  // (no register)
  assign regs_hw_set[127:96] = '0;
  assign regs_hw_rd[159:128] = '0;  // csid
  assign regs_hw_set[159:128] = '0;
  assign regs_hw_rd[191:160] = '0;  // csdef
  assign regs_hw_set[191:160] = '0;
  assign regs_hw_rd[223:192] = '0;  // csmode
  assign regs_hw_set[223:192] = '0;
  assign regs_hw_rd[255:224] = '0;  // (no register)
  assign regs_hw_set[255:224] = '0;
  assign regs_hw_rd[287:256] = '0;  // (no register)
  assign regs_hw_set[287:256] = '0;
  assign regs_hw_rd[319:288] = '0;  // (no register)
  assign regs_hw_set[319:288] = '0;
  assign regs_hw_rd[351:320] = '0;  // delay0
  assign regs_hw_set[351:320] = '0;
  assign regs_hw_rd[383:352] = '0;  // delay1
  assign regs_hw_set[383:352] = '0;
  assign regs_hw_rd[415:384] = '0;  // (no register)
  assign regs_hw_set[415:384] = '0;
  assign regs_hw_rd[447:416] = '0;  // (no register)
  assign regs_hw_set[447:416] = '0;
  assign regs_hw_rd[479:448] = '0;  // (no register)
  assign regs_hw_set[479:448] = '0;
  assign regs_hw_rd[511:480] = '0;  // (no register)
  assign regs_hw_set[511:480] = '0;
  assign regs_hw_rd[543:512] = '0;  // fmt
  assign regs_hw_set[543:512] = '0;
  assign regs_hw_rd[575:544] = '0;  // (no register)
  assign regs_hw_set[575:544] = '0;
  assign regs_hw_rd[607:576] = {txdata_full, 31'b0};  // txdata
  assign regs_hw_set[607:576] = '0;
  assign regs_hw_rd[639:608] = {rxdata_empty, 23'b0, rxdata_data};  // rxdata
  assign regs_hw_set[639:608] = '0;
  assign regs_hw_rd[671:640] = '0;  // txmark
  assign regs_hw_set[671:640] = '0;
  assign regs_hw_rd[703:672] = '0;  // rxmark
  assign regs_hw_set[703:672] = '0;
  assign regs_hw_rd[735:704] = '0;  // (no register)
  assign regs_hw_set[735:704] = '0;
  assign regs_hw_rd[767:736] = '0;  // (no register)
  assign regs_hw_set[767:736] = '0;
  assign regs_hw_rd[799:768] = '0;  // fctrl
  assign regs_hw_set[799:768] = '0;
  assign regs_hw_rd[831:800] = '0;  // ffmt
  assign regs_hw_set[831:800] = '0;
  assign regs_hw_rd[863:832] = '0;  // (no register)
  assign regs_hw_set[863:832] = '0;
  assign regs_hw_rd[895:864] = '0;  // (no register)
  assign regs_hw_set[895:864] = '0;
  assign regs_hw_rd[927:896] = '0;  // ie
  assign regs_hw_set[927:896] = '0;
  assign regs_hw_rd[959:928] = {30'b0, ip_rxwm, ip_txwm};  // ip
  assign regs_hw_set[959:928] = '0;
  assign sckdiv_div = regs_reg_q[11:0];
  assign sckmode_pha = regs_reg_q[32];
  assign sckmode_pol = regs_reg_q[33];
  assign csid_csid = regs_reg_q[129:128];
  assign csid_wr = regs_wr_pulse[4];
  assign csdef_csdef = regs_reg_q[163:160];
  assign csdef_wr = regs_wr_pulse[5];
  assign csmode_mode = regs_reg_q[193:192];
  assign csmode_wr = regs_wr_pulse[6];
  assign delay0_cssck = regs_reg_q[327:320];
  assign delay0_sckcs = regs_reg_q[343:336];
  assign delay1_intercs = regs_reg_q[359:352];
  assign delay1_interxfr = regs_reg_q[375:368];
  assign fmt_proto = regs_reg_q[513:512];
  assign fmt_endian = regs_reg_q[514];
  assign fmt_dir = regs_reg_q[515];
  assign fmt_len = regs_reg_q[531:528];
  assign txdata_data = PWDATA[7:0];
  assign txdata_wr = regs_wr_pulse[18];
  assign rxdata_rd = regs_rd_pulse[19];
  assign txmark_txmark = regs_reg_q[642:640];
  assign rxmark_rxmark = regs_reg_q[674:672];
  assign fctrl_en = regs_reg_q[768];
  assign fctrl_wr = regs_wr_pulse[24];
  assign ffmt_cmd_en = regs_reg_q[800];
  assign ffmt_addr_len = regs_reg_q[803:801];
  assign ffmt_pad_cnt = regs_reg_q[807:804];
  assign ffmt_cmd_proto = regs_reg_q[809:808];
  assign ffmt_addr_proto = regs_reg_q[811:810];
  assign ffmt_data_proto = regs_reg_q[813:812];
  assign ffmt_cmd_code = regs_reg_q[823:816];
  assign ffmt_pad_code = regs_reg_q[831:824];
  assign ffmt_wr = regs_wr_pulse[25];
  assign ie_txwm = regs_reg_q[896];
  assign ie_rxwm = regs_reg_q[897];

  basechili_apb_regbank #(
    .ADDR_W   (7),
    .DATA_W   (32),
    .N        (N_REGS),
    .RESET    (RESET_REGS),
    .RW_MASK  (RW_REGS),
    .W1C_MASK (W1C_REGS)
  ) u_regs (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (PSEL),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (PADDR),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (PREADY),
    .PRDATA   (PRDATA),
    .PSLVERR  (PSLVERR),
    .reg_q    (regs_reg_q),
    .hw_rd    (regs_hw_rd),
    .hw_set   (regs_hw_set),
    .wr_pulse (regs_wr_pulse),
    .rd_pulse (regs_rd_pulse)
  );

endmodule
