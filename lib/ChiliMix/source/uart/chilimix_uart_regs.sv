// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_uart_regs
//
// ns16550a UART: 16-byte FIFOs, 8-bit registers on 32-bit words (reg-shift 2) register block: an APB4 subordinate (5-bit PADDR, 32-bit data).
// Register layout compatible with ns16550a.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   0x0000  rbr          data[7:0] ro  (reads only, lcr.dlab = 0)
//   0x0000  thr          data[7:0] wo  (writes only, lcr.dlab = 0)
//   0x0000  dll          value[7:0] rw  (lcr.dlab = 1)
//   0x0004  ier          edssi[3] rw, elsi[2] rw, etbei[1] rw, erbfi[0] rw  (lcr.dlab = 0)
//   0x0004  dlm          value[7:0] rw  (lcr.dlab = 1)
//   0x0008  iir          fifos[7:6] ro, id[3:0] ro  (reads only)
//   0x0008  fcr          rx_trigger[7:6] rw, dma_mode[3] rw, tx_reset[2] wo, rx_reset[1] wo, enable[0] rw  (writes only)
//   0x000c  lcr          dlab[7] rw, brk[6] rw, stick[5] rw, eps[4] rw, pen[3] rw, stb[2] rw, wls[1:0] rw
//   0x0010  mcr          loop[4] rw, out2[3] rw, out1[2] rw, rts[1] rw, dtr[0] rw
//   0x0014  lsr          rxfe[7] ro, temt[6] ro, thre[5] ro, bi[4] ro, fe[3] ro, pe[2] ro, oe[1] ro, dr[0] ro
//   0x0018  msr          dcd[7] ro, ri[6] ro, dsr[5] ro, cts[4] ro, ddcd[3] ro, teri[2] ro, ddsr[1] ro, dcts[0] ro
//   0x001c  scr          value[7:0] rw
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
module chilimix_uart_regs (
  input  logic clk,
  input  logic rst_n,                 // async, active-low
  input  logic PSEL,                  // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [4:0] PADDR,           // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  input  logic [7:0] rbr_data,        // ro: Received character (head of the RX FIFO)
  output logic rbr_rd,                // rbr read this cycle (APB ACCESS)
  output logic [7:0] thr_data,        // wo: Character to send
  output logic thr_wr,                // thr write this cycle (APB ACCESS)
  output logic [7:0] dll_value,       // rw: Divisor bits 7:0
  output logic ier_erbfi,             // rw: Received data available and character timeout
  output logic ier_etbei,             // rw: Transmitter holding register empty
  output logic ier_elsi,              // rw: Receiver line status (overrun, parity, framing, break)
  output logic ier_edssi,             // rw: Modem status
  output logic ier_wr,                // ier write this cycle (APB ACCESS)
  output logic [7:0] dlm_value,       // rw: Divisor bits 15:8
  input  logic [3:0] iir_id,          // ro: 0x1 none, 0x6 line status, 0x4 data available, 0xc character timeout, 0x2 THR empty, 0x0 modem status
  input  logic [1:0] iir_fifos,       // ro: 0x3 when the FIFOs are enabled
  output logic iir_rd,                // iir read this cycle (APB ACCESS)
  output logic fcr_enable,            // rw: FIFOs enabled (else one-character buffers); changing it clears both FIFOs
  output logic fcr_rx_reset,          // wo: Write 1: clear the RX FIFO
  output logic fcr_tx_reset,          // wo: Write 1: clear the TX FIFO
  output logic fcr_dma_mode,          // rw: DMA mode select (stored, no effect: no DMA handshake pins)
  output logic [1:0] fcr_rx_trigger,  // rw: RX FIFO interrupt level: 1, 4, 8 or 14 characters
  output logic fcr_wr,                // fcr write this cycle (APB ACCESS)
  output logic [1:0] lcr_wls,         // rw: Word length: 5 + wls bits
  output logic lcr_stb,               // rw: Stop bits: 0 one; 1 two (1.5 with 5-bit words)
  output logic lcr_pen,               // rw: Parity enable
  output logic lcr_eps,               // rw: Even parity select
  output logic lcr_stick,             // rw: Stick parity: the parity bit is the inverse of eps
  output logic lcr_brk,               // rw: Break control: hold the TX line low
  output logic lcr_dlab,              // rw: Divisor latch access: offsets 0x0 and 0x4 select DLL and DLM
  output logic mcr_dtr,               // rw: Data terminal ready (dtr_n output low)
  output logic mcr_rts,               // rw: Request to send (rts_n output low)
  output logic mcr_out1,              // rw: User output 1 (RI in loopback)
  output logic mcr_out2,              // rw: User output 2 (DCD in loopback)
  output logic mcr_loop,              // rw: Loopback: TX feeds RX, modem outputs feed modem inputs
  input  logic lsr_dr,                // ro: Data ready: the RX FIFO is not empty
  input  logic lsr_oe,                // ro: Overrun: a character arrived with the RX FIFO full and was lost
  input  logic lsr_pe,                // ro: Parity error of the character at the head of the RX FIFO
  input  logic lsr_fe,                // ro: Framing error (stop bit 0) of the character at the head
  input  logic lsr_bi,                // ro: Break: the character at the head was a break
  input  logic lsr_thre,              // ro: TX FIFO (holding register) empty
  input  logic lsr_temt,              // ro: Transmitter empty: TX FIFO and shift register idle
  input  logic lsr_rxfe,              // ro: A character in the RX FIFO has a parity, framing or break error
  output logic lsr_rd,                // lsr read this cycle (APB ACCESS)
  input  logic msr_dcts,              // ro: CTS changed
  input  logic msr_ddsr,              // ro: DSR changed
  input  logic msr_teri,              // ro: RI went inactive
  input  logic msr_ddcd,              // ro: DCD changed
  input  logic msr_cts,               // ro: Clear to send (cts_n low)
  input  logic msr_dsr,               // ro: Data set ready (dsr_n low)
  input  logic msr_ri,                // ro: Ring indicator (ri_n low)
  input  logic msr_dcd,               // ro: Data carrier detect (dcd_n low)
  output logic msr_rd,                // msr read this cycle (APB ACCESS)
  output logic [7:0] scr_value        // rw: Software scratch byte
);

  // ---- block regs: 13 word(s) at 0x0 (one per register, one empty: offsets are shared)
  localparam int                N_REGS = 13;
  localparam logic [415:0] RESET_REGS = 416'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [415:0] RW_REGS = 416'h0000_0000_0000_00ff_0000_0000_0000_0000_0000_001f_0000_00ff_0000_00c9_0000_0000_0000_00ff_0000_000f_0000_00ff_0000_0000_0000_0000;
  localparam logic [415:0] W1C_REGS = 416'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [415:0] regs_reg_q;    // rw and w1c bit values
  logic [415:0] regs_hw_rd;    // read-only bit values
  logic [415:0] regs_hw_set;   // w1c set requests
  logic [12:0] regs_wr_pulse;    // register written this cycle
  logic [12:0] regs_rd_pulse;    // register read this cycle

  logic [2:0] regs_word;     // word address inside the block
  logic [3:0] regs_slot;     // regbank word of the register selected there
  logic [5:0] regs_rb_addr;  // regbank PADDR

  assign regs_word = PADDR[4:2];
  assign regs_rb_addr = {regs_slot, PADDR[1:0]};

  // shared offsets: the register an access selects (by direction and bank field)
  always_comb begin
    regs_slot = 4'd13;  // past the last register: PSLVERR
    case (regs_word)
      3'd0: regs_slot = (!PWRITE && lcr_dlab == 1'd0) ? 4'd0 : (PWRITE && lcr_dlab == 1'd0) ? 4'd1 : (lcr_dlab == 1'd1) ? 4'd2 : 4'd12;  // rbr, thr, dll
      3'd1: regs_slot = (lcr_dlab == 1'd0) ? 4'd3 : (lcr_dlab == 1'd1) ? 4'd4 : 4'd12;  // ier, dlm
      3'd2: regs_slot = (!PWRITE) ? 4'd5 : (PWRITE) ? 4'd6 : 4'd12;  // iir, fcr
      3'd3: regs_slot = 4'd7;  // lcr
      3'd4: regs_slot = 4'd8;  // mcr
      3'd5: regs_slot = 4'd9;  // lsr
      3'd6: regs_slot = 4'd10;  // msr
      default: regs_slot = 4'd11;  // scr
    endcase
  end

  assign regs_hw_rd[31:0] = {24'b0, rbr_data};  // rbr
  assign regs_hw_set[31:0] = '0;
  assign regs_hw_rd[63:32] = '0;  // thr
  assign regs_hw_set[63:32] = '0;
  assign regs_hw_rd[95:64] = '0;  // dll
  assign regs_hw_set[95:64] = '0;
  assign regs_hw_rd[127:96] = '0;  // ier
  assign regs_hw_set[127:96] = '0;
  assign regs_hw_rd[159:128] = '0;  // dlm
  assign regs_hw_set[159:128] = '0;
  assign regs_hw_rd[191:160] = {24'b0, iir_fifos, 2'b0, iir_id};  // iir
  assign regs_hw_set[191:160] = '0;
  assign regs_hw_rd[223:192] = '0;  // fcr
  assign regs_hw_set[223:192] = '0;
  assign regs_hw_rd[255:224] = '0;  // lcr
  assign regs_hw_set[255:224] = '0;
  assign regs_hw_rd[287:256] = '0;  // mcr
  assign regs_hw_set[287:256] = '0;
  assign regs_hw_rd[319:288] = {24'b0, lsr_rxfe, lsr_temt, lsr_thre, lsr_bi, lsr_fe, lsr_pe, lsr_oe, lsr_dr};  // lsr
  assign regs_hw_set[319:288] = '0;
  assign regs_hw_rd[351:320] = {24'b0, msr_dcd, msr_ri, msr_dsr, msr_cts, msr_ddcd, msr_teri, msr_ddsr, msr_dcts};  // msr
  assign regs_hw_set[351:320] = '0;
  assign regs_hw_rd[383:352] = '0;  // scr
  assign regs_hw_set[383:352] = '0;
  assign regs_hw_rd[415:384] = '0;  // (no register)
  assign regs_hw_set[415:384] = '0;
  assign rbr_rd = regs_rd_pulse[0];
  assign thr_data = PWDATA[7:0];
  assign thr_wr = regs_wr_pulse[1];
  assign dll_value = regs_reg_q[71:64];
  assign ier_erbfi = regs_reg_q[96];
  assign ier_etbei = regs_reg_q[97];
  assign ier_elsi = regs_reg_q[98];
  assign ier_edssi = regs_reg_q[99];
  assign ier_wr = regs_wr_pulse[3];
  assign dlm_value = regs_reg_q[135:128];
  assign iir_rd = regs_rd_pulse[5];
  assign fcr_enable = regs_reg_q[192];
  assign fcr_rx_reset = PWDATA[1];
  assign fcr_tx_reset = PWDATA[2];
  assign fcr_dma_mode = regs_reg_q[195];
  assign fcr_rx_trigger = regs_reg_q[199:198];
  assign fcr_wr = regs_wr_pulse[6];
  assign lcr_wls = regs_reg_q[225:224];
  assign lcr_stb = regs_reg_q[226];
  assign lcr_pen = regs_reg_q[227];
  assign lcr_eps = regs_reg_q[228];
  assign lcr_stick = regs_reg_q[229];
  assign lcr_brk = regs_reg_q[230];
  assign lcr_dlab = regs_reg_q[231];
  assign mcr_dtr = regs_reg_q[256];
  assign mcr_rts = regs_reg_q[257];
  assign mcr_out1 = regs_reg_q[258];
  assign mcr_out2 = regs_reg_q[259];
  assign mcr_loop = regs_reg_q[260];
  assign lsr_rd = regs_rd_pulse[9];
  assign msr_rd = regs_rd_pulse[10];
  assign scr_value = regs_reg_q[359:352];

  basechili_apb_regbank #(
    .ADDR_W   (6),
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
    .PADDR    (regs_rb_addr),
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
