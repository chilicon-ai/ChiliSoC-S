// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_i2c_regs
//
// I2C master in the OpenCores i2c_master layout (sifive,i2c0, as the FU540): 8-bit registers on 32-bit words (reg-shift 2) register block: an APB4 subordinate (5-bit PADDR, 32-bit data).
// Register layout compatible with sifive,i2c0.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   0x0000  prer_lo      value[7:0] rw
//   0x0004  prer_hi      value[7:0] rw
//   0x0008  ctr          en[7] rw, ien[6] rw
//   0x000c  rxr          data[7:0] ro  (reads only)
//   0x000c  txr          data[7:0] rw  (writes only)
//   0x0010  sr           rxack[7] ro, busy[6] ro, al[5] ro, tip[1] ro, iflag[0] ro  (reads only)
//   0x0010  cr           sta[7] wo, sto[6] wo, read[5] wo, write[4] wo, ack[3] wo, iack[0] wo  (writes only)
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
module chilimix_i2c_regs (
  input  logic clk,
  input  logic rst_n,                // async, active-low
  input  logic PSEL,                 // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [4:0] PADDR,          // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  output logic [7:0] prer_lo_value,  // rw: Prescale bits 7:0
  output logic [7:0] prer_hi_value,  // rw: Prescale bits 15:8
  output logic ctr_ien,              // rw: Interrupt enable
  output logic ctr_en,               // rw: Core enable: clear holds the controller idle with both lines released and ignores cr writes
  input  logic [7:0] rxr_data,       // ro: Received byte
  output logic [7:0] txr_data,       // rw: Byte to send
  input  logic sr_iflag,             // ro: Interrupt flag: a command finished or arbitration was lost (cleared by cr.iack)
  input  logic sr_tip,               // ro: Transfer in progress (a read or write command is running)
  input  logic sr_al,                // ro: Arbitration lost (cleared by the next cr.sta)
  input  logic sr_busy,              // ro: Bus busy: a START was seen and no STOP since
  input  logic sr_rxack,             // ro: Acknowledge bit of the last byte: 0 ACK, 1 NACK
  output logic cr_iack,              // wo: Write 1: clear the interrupt flag
  output logic cr_ack,               // wo: Acknowledge to send after a read: 0 ACK, 1 NACK
  output logic cr_write,             // wo: WR: write txr to the bus
  output logic cr_read,              // wo: RD: read a byte from the bus into rxr
  output logic cr_sto,               // wo: Generate a STOP (after the byte, with read or write)
  output logic cr_sta,               // wo: Generate a (repeated) START (before the byte)
  output logic cr_wr                 // cr write this cycle (APB ACCESS)
);

  // ---- block regs: 8 word(s) at 0x0 (one per register, one empty: offsets are shared)
  localparam int                N_REGS = 8;
  localparam logic [255:0] RESET_REGS = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_00ff_0000_00ff;
  localparam logic [255:0] RW_REGS = 256'h0000_0000_0000_0000_0000_0000_0000_00ff_0000_0000_0000_00c0_0000_00ff_0000_00ff;
  localparam logic [255:0] W1C_REGS = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [255:0] regs_reg_q;    // rw and w1c bit values
  logic [255:0] regs_hw_rd;    // read-only bit values
  logic [255:0] regs_hw_set;   // w1c set requests
  logic [7:0] regs_wr_pulse;    // register written this cycle

  logic [2:0] regs_word;     // word address inside the block
  logic [3:0] regs_slot;     // regbank word of the register selected there
  logic [5:0] regs_rb_addr;  // regbank PADDR

  assign regs_word = PADDR[4:2];
  assign regs_rb_addr = {regs_slot, PADDR[1:0]};

  // shared offsets: the register an access selects (by direction and bank field)
  always_comb begin
    regs_slot = 4'd8;  // past the last register: PSLVERR
    case (regs_word)
      3'd0: regs_slot = 4'd0;  // prer_lo
      3'd1: regs_slot = 4'd1;  // prer_hi
      3'd2: regs_slot = 4'd2;  // ctr
      3'd3: regs_slot = (!PWRITE) ? 4'd3 : (PWRITE) ? 4'd4 : 4'd7;  // rxr, txr
      3'd4: regs_slot = (!PWRITE) ? 4'd5 : (PWRITE) ? 4'd6 : 4'd7;  // sr, cr
      default: ;
    endcase
  end

  assign regs_hw_rd[31:0] = '0;  // prer_lo
  assign regs_hw_set[31:0] = '0;
  assign regs_hw_rd[63:32] = '0;  // prer_hi
  assign regs_hw_set[63:32] = '0;
  assign regs_hw_rd[95:64] = '0;  // ctr
  assign regs_hw_set[95:64] = '0;
  assign regs_hw_rd[127:96] = {24'b0, rxr_data};  // rxr
  assign regs_hw_set[127:96] = '0;
  assign regs_hw_rd[159:128] = '0;  // txr
  assign regs_hw_set[159:128] = '0;
  assign regs_hw_rd[191:160] = {24'b0, sr_rxack, sr_busy, sr_al, 3'b0, sr_tip, sr_iflag};  // sr
  assign regs_hw_set[191:160] = '0;
  assign regs_hw_rd[223:192] = '0;  // cr
  assign regs_hw_set[223:192] = '0;
  assign regs_hw_rd[255:224] = '0;  // (no register)
  assign regs_hw_set[255:224] = '0;
  assign prer_lo_value = regs_reg_q[7:0];
  assign prer_hi_value = regs_reg_q[39:32];
  assign ctr_ien = regs_reg_q[70];
  assign ctr_en = regs_reg_q[71];
  assign txr_data = regs_reg_q[135:128];
  assign cr_iack = PWDATA[0];
  assign cr_ack = PWDATA[3];
  assign cr_write = PWDATA[4];
  assign cr_read = PWDATA[5];
  assign cr_sto = PWDATA[6];
  assign cr_sta = PWDATA[7];
  assign cr_wr = regs_wr_pulse[6];

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
    .rd_pulse ()
  );

endmodule
