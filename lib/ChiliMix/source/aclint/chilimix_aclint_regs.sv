// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_aclint_regs
//
// RISC-V ACLINT MSWI, MTIMER and SSWI for up to 8 harts register block: an APB4 subordinate (16-bit PADDR, 32-bit data).
// Register layout compatible with sifive,clint0 (riscv,clint0); SSWI at +0xC000: riscv,aclint-sswi.
// Built on basechili_apb_regbank (4 bank(s)), blocks selected by basechili_apb_interconnect.
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   block mswi at 0x0, 0x4000 bytes
//   0x0000 + 0x4*i  msip[8]      pending[0] rw  (i < N_HART present)
//   block mtimer_cmp at 0x4000, 0x40 bytes
//   0x4000 + 0x8*i  mtimecmp_lo[8] value[31:0] rw  (i < N_HART present)
//   0x4004 + 0x8*i  mtimecmp_hi[8] value[31:0] rw  (i < N_HART present)
//   block mtimer_time at 0xbff8, 0x8 bytes
//   0xbff8  mtime_lo     value[31:0] ro
//   0xbffc  mtime_hi     value[31:0] ro
//   block sswi at 0xc000, 0x4000 bytes
//   0xc000 + 0x4*i  setssip[8]   set[0] wo  (i < N_HART present)
//
// Words inside a block with no register read 0 and ignore writes; words past
// a block's last register and addresses outside every block give PSLVERR.
//
// Timing    : as basechili_apb_regbank: no wait states (PREADY high), PRDATA
//             combinational from the APB inputs; field outputs are registered
//             and change the cycle after the write or the _set input.
// Debug     : wrong read value -> u_<block>.reg_q / hw_rd; write lost -> PSTRB
//             and u_<block>.wr_pulse; PSLVERR -> u_apb.PSEL_s.
// -----------------------------------------------------------------------------
module chilimix_aclint_regs #(
  parameter int N_HART = 1  // harts present (1 .. 8)
) (
  input  logic clk,
  input  logic rst_n,                      // async, active-low
  input  logic PSEL,                       // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [15:0] PADDR,               // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  output logic [7:0] msip_pending,         // rw: MSIP: drives the hart's machine software interrupt x8
  output logic [255:0] mtimecmp_lo_value,  // rw: Compare value, low word x8
  output logic [255:0] mtimecmp_hi_value,  // rw: Compare value, high word x8
  input  logic [31:0] mtime_lo_value,      // ro: Time, low word
  output logic mtime_lo_wr,                // mtime_lo write this cycle (APB ACCESS)
  input  logic [31:0] mtime_hi_value,      // ro: Time, high word
  output logic mtime_hi_wr,                // mtime_hi write this cycle (APB ACCESS)
  output logic [7:0] setssip_set,          // wo: Write 1: set the hart's mip.SSIP x8
  output logic [7:0] setssip_wr            // setssip write this cycle (APB ACCESS)
);

  localparam logic [63:0] BLOCK_BASE = 64'hc000_bff8_4000_0000;
  localparam logic [63:0] BLOCK_MASK = 64'hc000_fff8_ffc0_c000;
  logic [3:0]      apb_psel_s;      // PSEL of each block
  logic [3:0]      apb_pready_s;
  logic [127:0] apb_prdata_s;
  logic [3:0]      apb_pslverr_s;

  basechili_apb_interconnect #(
    .ADDR_W (16),
    .DATA_W (32),
    .N      (4),
    .BASE   (BLOCK_BASE),
    .MASK   (BLOCK_MASK)
  ) u_apb (
    .PSEL      (PSEL),
    .PADDR     (PADDR),
    .PREADY    (PREADY),
    .PRDATA    (PRDATA),
    .PSLVERR   (PSLVERR),
    .PSEL_s    (apb_psel_s),
    .PREADY_s  (apb_pready_s),
    .PRDATA_s  (apb_prdata_s),
    .PSLVERR_s (apb_pslverr_s)
  );

  // ---- block mswi: 8 word(s) at 0x0
  localparam int                N_MSWI = 8;
  // words of the array elements present (N_HART)
  localparam logic [255:0] ACT_MSWI = {{32{N_HART > 7}}, {32{N_HART > 6}}, {32{N_HART > 5}}, {32{N_HART > 4}}, {32{N_HART > 3}}, {32{N_HART > 2}}, {32{N_HART > 1}}, {32{N_HART > 0}}};
  localparam logic [255:0] RESET_MSWI = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_MSWI;
  localparam logic [255:0] RW_MSWI = 256'h0000_0001_0000_0001_0000_0001_0000_0001_0000_0001_0000_0001_0000_0001_0000_0001 & ACT_MSWI;
  localparam logic [255:0] W1C_MSWI = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_MSWI;
  logic [255:0] mswi_reg_q;    // rw and w1c bit values
  logic [255:0] mswi_hw_rd;    // read-only bit values
  logic [255:0] mswi_hw_set;   // w1c set requests
  logic [13:0] mswi_paddr;    // address inside the block

  assign mswi_hw_rd[31:0] = '0;  // msip[0]
  assign mswi_hw_set[31:0] = '0;
  assign mswi_hw_rd[63:32] = '0;  // msip[1]
  assign mswi_hw_set[63:32] = '0;
  assign mswi_hw_rd[95:64] = '0;  // msip[2]
  assign mswi_hw_set[95:64] = '0;
  assign mswi_hw_rd[127:96] = '0;  // msip[3]
  assign mswi_hw_set[127:96] = '0;
  assign mswi_hw_rd[159:128] = '0;  // msip[4]
  assign mswi_hw_set[159:128] = '0;
  assign mswi_hw_rd[191:160] = '0;  // msip[5]
  assign mswi_hw_set[191:160] = '0;
  assign mswi_hw_rd[223:192] = '0;  // msip[6]
  assign mswi_hw_set[223:192] = '0;
  assign mswi_hw_rd[255:224] = '0;  // msip[7]
  assign mswi_hw_set[255:224] = '0;
  assign mswi_paddr = PADDR[13:0];
  assign msip_pending[0] = mswi_reg_q[0];
  assign msip_pending[1] = mswi_reg_q[32];
  assign msip_pending[2] = mswi_reg_q[64];
  assign msip_pending[3] = mswi_reg_q[96];
  assign msip_pending[4] = mswi_reg_q[128];
  assign msip_pending[5] = mswi_reg_q[160];
  assign msip_pending[6] = mswi_reg_q[192];
  assign msip_pending[7] = mswi_reg_q[224];

  basechili_apb_regbank #(
    .ADDR_W   (14),
    .DATA_W   (32),
    .N        (N_MSWI),
    .RESET    (RESET_MSWI),
    .RW_MASK  (RW_MSWI),
    .W1C_MASK (W1C_MSWI)
  ) u_mswi (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[0]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (mswi_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[0]),
    .PRDATA   (apb_prdata_s[31:0]),
    .PSLVERR  (apb_pslverr_s[0]),
    .reg_q    (mswi_reg_q),
    .hw_rd    (mswi_hw_rd),
    .hw_set   (mswi_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

  // ---- block mtimer_cmp: 16 word(s) at 0x4000
  localparam int                N_MTIMER_CMP = 16;
  // words of the array elements present (N_HART)
  localparam logic [511:0] ACT_MTIMER_CMP = {{32{N_HART > 7}}, {32{N_HART > 7}}, {32{N_HART > 6}}, {32{N_HART > 6}}, {32{N_HART > 5}}, {32{N_HART > 5}}, {32{N_HART > 4}}, {32{N_HART > 4}}, {32{N_HART > 3}}, {32{N_HART > 3}}, {32{N_HART > 2}}, {32{N_HART > 2}}, {32{N_HART > 1}}, {32{N_HART > 1}}, {32{N_HART > 0}}, {32{N_HART > 0}}};
  localparam logic [511:0] RESET_MTIMER_CMP = 512'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff & ACT_MTIMER_CMP;
  localparam logic [511:0] RW_MTIMER_CMP = 512'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff & ACT_MTIMER_CMP;
  localparam logic [511:0] W1C_MTIMER_CMP = 512'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_MTIMER_CMP;
  logic [511:0] mtimer_cmp_reg_q;    // rw and w1c bit values
  logic [511:0] mtimer_cmp_hw_rd;    // read-only bit values
  logic [511:0] mtimer_cmp_hw_set;   // w1c set requests
  logic [5:0] mtimer_cmp_paddr;    // address inside the block

  assign mtimer_cmp_hw_rd[31:0] = '0;  // mtimecmp_lo[0]
  assign mtimer_cmp_hw_set[31:0] = '0;
  assign mtimer_cmp_hw_rd[63:32] = '0;  // mtimecmp_hi[0]
  assign mtimer_cmp_hw_set[63:32] = '0;
  assign mtimer_cmp_hw_rd[95:64] = '0;  // mtimecmp_lo[1]
  assign mtimer_cmp_hw_set[95:64] = '0;
  assign mtimer_cmp_hw_rd[127:96] = '0;  // mtimecmp_hi[1]
  assign mtimer_cmp_hw_set[127:96] = '0;
  assign mtimer_cmp_hw_rd[159:128] = '0;  // mtimecmp_lo[2]
  assign mtimer_cmp_hw_set[159:128] = '0;
  assign mtimer_cmp_hw_rd[191:160] = '0;  // mtimecmp_hi[2]
  assign mtimer_cmp_hw_set[191:160] = '0;
  assign mtimer_cmp_hw_rd[223:192] = '0;  // mtimecmp_lo[3]
  assign mtimer_cmp_hw_set[223:192] = '0;
  assign mtimer_cmp_hw_rd[255:224] = '0;  // mtimecmp_hi[3]
  assign mtimer_cmp_hw_set[255:224] = '0;
  assign mtimer_cmp_hw_rd[287:256] = '0;  // mtimecmp_lo[4]
  assign mtimer_cmp_hw_set[287:256] = '0;
  assign mtimer_cmp_hw_rd[319:288] = '0;  // mtimecmp_hi[4]
  assign mtimer_cmp_hw_set[319:288] = '0;
  assign mtimer_cmp_hw_rd[351:320] = '0;  // mtimecmp_lo[5]
  assign mtimer_cmp_hw_set[351:320] = '0;
  assign mtimer_cmp_hw_rd[383:352] = '0;  // mtimecmp_hi[5]
  assign mtimer_cmp_hw_set[383:352] = '0;
  assign mtimer_cmp_hw_rd[415:384] = '0;  // mtimecmp_lo[6]
  assign mtimer_cmp_hw_set[415:384] = '0;
  assign mtimer_cmp_hw_rd[447:416] = '0;  // mtimecmp_hi[6]
  assign mtimer_cmp_hw_set[447:416] = '0;
  assign mtimer_cmp_hw_rd[479:448] = '0;  // mtimecmp_lo[7]
  assign mtimer_cmp_hw_set[479:448] = '0;
  assign mtimer_cmp_hw_rd[511:480] = '0;  // mtimecmp_hi[7]
  assign mtimer_cmp_hw_set[511:480] = '0;
  assign mtimer_cmp_paddr = PADDR[5:0];
  assign mtimecmp_lo_value[31:0] = mtimer_cmp_reg_q[31:0];
  assign mtimecmp_hi_value[31:0] = mtimer_cmp_reg_q[63:32];
  assign mtimecmp_lo_value[63:32] = mtimer_cmp_reg_q[95:64];
  assign mtimecmp_hi_value[63:32] = mtimer_cmp_reg_q[127:96];
  assign mtimecmp_lo_value[95:64] = mtimer_cmp_reg_q[159:128];
  assign mtimecmp_hi_value[95:64] = mtimer_cmp_reg_q[191:160];
  assign mtimecmp_lo_value[127:96] = mtimer_cmp_reg_q[223:192];
  assign mtimecmp_hi_value[127:96] = mtimer_cmp_reg_q[255:224];
  assign mtimecmp_lo_value[159:128] = mtimer_cmp_reg_q[287:256];
  assign mtimecmp_hi_value[159:128] = mtimer_cmp_reg_q[319:288];
  assign mtimecmp_lo_value[191:160] = mtimer_cmp_reg_q[351:320];
  assign mtimecmp_hi_value[191:160] = mtimer_cmp_reg_q[383:352];
  assign mtimecmp_lo_value[223:192] = mtimer_cmp_reg_q[415:384];
  assign mtimecmp_hi_value[223:192] = mtimer_cmp_reg_q[447:416];
  assign mtimecmp_lo_value[255:224] = mtimer_cmp_reg_q[479:448];
  assign mtimecmp_hi_value[255:224] = mtimer_cmp_reg_q[511:480];

  basechili_apb_regbank #(
    .ADDR_W   (6),
    .DATA_W   (32),
    .N        (N_MTIMER_CMP),
    .RESET    (RESET_MTIMER_CMP),
    .RW_MASK  (RW_MTIMER_CMP),
    .W1C_MASK (W1C_MTIMER_CMP)
  ) u_mtimer_cmp (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[1]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (mtimer_cmp_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[1]),
    .PRDATA   (apb_prdata_s[63:32]),
    .PSLVERR  (apb_pslverr_s[1]),
    .reg_q    (mtimer_cmp_reg_q),
    .hw_rd    (mtimer_cmp_hw_rd),
    .hw_set   (mtimer_cmp_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

  // ---- block mtimer_time: 2 word(s) at 0xbff8
  localparam int                N_MTIMER_TIME = 2;
  localparam logic [63:0] RESET_MTIMER_TIME = 64'h0000_0000_0000_0000;
  localparam logic [63:0] RW_MTIMER_TIME = 64'h0000_0000_0000_0000;
  localparam logic [63:0] W1C_MTIMER_TIME = 64'h0000_0000_0000_0000;
  logic [63:0] mtimer_time_hw_rd;    // read-only bit values
  logic [63:0] mtimer_time_hw_set;   // w1c set requests
  logic [1:0] mtimer_time_wr_pulse;    // register written this cycle
  logic [2:0] mtimer_time_paddr;    // address inside the block

  assign mtimer_time_hw_rd[31:0] = mtime_lo_value;  // mtime_lo
  assign mtimer_time_hw_set[31:0] = '0;
  assign mtimer_time_hw_rd[63:32] = mtime_hi_value;  // mtime_hi
  assign mtimer_time_hw_set[63:32] = '0;
  assign mtimer_time_paddr = PADDR[2:0];
  assign mtime_lo_wr = mtimer_time_wr_pulse[0];
  assign mtime_hi_wr = mtimer_time_wr_pulse[1];

  basechili_apb_regbank #(
    .ADDR_W   (3),
    .DATA_W   (32),
    .N        (N_MTIMER_TIME),
    .RESET    (RESET_MTIMER_TIME),
    .RW_MASK  (RW_MTIMER_TIME),
    .W1C_MASK (W1C_MTIMER_TIME)
  ) u_mtimer_time (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[2]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (mtimer_time_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[2]),
    .PRDATA   (apb_prdata_s[95:64]),
    .PSLVERR  (apb_pslverr_s[2]),
    .reg_q    (),
    .hw_rd    (mtimer_time_hw_rd),
    .hw_set   (mtimer_time_hw_set),
    .wr_pulse (mtimer_time_wr_pulse),
    .rd_pulse ()
  );

  // ---- block sswi: 8 word(s) at 0xc000
  localparam int                N_SSWI = 8;
  // words of the array elements present (N_HART)
  localparam logic [255:0] ACT_SSWI = {{32{N_HART > 7}}, {32{N_HART > 6}}, {32{N_HART > 5}}, {32{N_HART > 4}}, {32{N_HART > 3}}, {32{N_HART > 2}}, {32{N_HART > 1}}, {32{N_HART > 0}}};
  localparam logic [255:0] RESET_SSWI = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_SSWI;
  localparam logic [255:0] RW_SSWI = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_SSWI;
  localparam logic [255:0] W1C_SSWI = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_SSWI;
  logic [255:0] sswi_hw_rd;    // read-only bit values
  logic [255:0] sswi_hw_set;   // w1c set requests
  logic [7:0] sswi_wr_pulse;    // register written this cycle
  logic [13:0] sswi_paddr;    // address inside the block

  assign sswi_hw_rd[31:0] = '0;  // setssip[0]
  assign sswi_hw_set[31:0] = '0;
  assign sswi_hw_rd[63:32] = '0;  // setssip[1]
  assign sswi_hw_set[63:32] = '0;
  assign sswi_hw_rd[95:64] = '0;  // setssip[2]
  assign sswi_hw_set[95:64] = '0;
  assign sswi_hw_rd[127:96] = '0;  // setssip[3]
  assign sswi_hw_set[127:96] = '0;
  assign sswi_hw_rd[159:128] = '0;  // setssip[4]
  assign sswi_hw_set[159:128] = '0;
  assign sswi_hw_rd[191:160] = '0;  // setssip[5]
  assign sswi_hw_set[191:160] = '0;
  assign sswi_hw_rd[223:192] = '0;  // setssip[6]
  assign sswi_hw_set[223:192] = '0;
  assign sswi_hw_rd[255:224] = '0;  // setssip[7]
  assign sswi_hw_set[255:224] = '0;
  assign sswi_paddr = PADDR[13:0];
  assign setssip_set[0] = PWDATA[0];
  assign setssip_wr[0] = sswi_wr_pulse[0] && (N_HART > 0);
  assign setssip_set[1] = PWDATA[0];
  assign setssip_wr[1] = sswi_wr_pulse[1] && (N_HART > 1);
  assign setssip_set[2] = PWDATA[0];
  assign setssip_wr[2] = sswi_wr_pulse[2] && (N_HART > 2);
  assign setssip_set[3] = PWDATA[0];
  assign setssip_wr[3] = sswi_wr_pulse[3] && (N_HART > 3);
  assign setssip_set[4] = PWDATA[0];
  assign setssip_wr[4] = sswi_wr_pulse[4] && (N_HART > 4);
  assign setssip_set[5] = PWDATA[0];
  assign setssip_wr[5] = sswi_wr_pulse[5] && (N_HART > 5);
  assign setssip_set[6] = PWDATA[0];
  assign setssip_wr[6] = sswi_wr_pulse[6] && (N_HART > 6);
  assign setssip_set[7] = PWDATA[0];
  assign setssip_wr[7] = sswi_wr_pulse[7] && (N_HART > 7);

  basechili_apb_regbank #(
    .ADDR_W   (14),
    .DATA_W   (32),
    .N        (N_SSWI),
    .RESET    (RESET_SSWI),
    .RW_MASK  (RW_SSWI),
    .W1C_MASK (W1C_SSWI)
  ) u_sswi (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[3]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (sswi_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[3]),
    .PRDATA   (apb_prdata_s[127:96]),
    .PSLVERR  (apb_pslverr_s[3]),
    .reg_q    (),
    .hw_rd    (sswi_hw_rd),
    .hw_set   (sswi_hw_set),
    .wr_pulse (sswi_wr_pulse),
    .rd_pulse ()
  );

endmodule
