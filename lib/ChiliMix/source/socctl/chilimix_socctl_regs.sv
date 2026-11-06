// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_socctl_regs
//
// SoC control: SoC ID, reset causes, software resets, per-hart resets and boot addresses, clock dividers and scratch registers kept across system resets register block: an APB4 subordinate (8-bit PADDR, 32-bit data).
// Register layout compatible with chilicon,socctl0.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   0x0000  id           value[31:0] ro
//   0x0004  rst_cause    dbg[4] w1c, req[3] w1c, sw[2] w1c, ext[1] w1c, por[0] w1c
//   0x0008  sysrst       key[31:0] wo
//   0x000c  rst_hold     dom[7:0] rw
//   0x0010  rst_status   dom[15:8] ro, done[0] ro
//   0x0014 + 0x4*i  clkdiv[2]    div[15:0] rw
//   0x001c + 0x4*i  scratch[2]   value[31:0] rw
//   0x0040  hart_hold    hart[7:0] rw
//   0x0044  hart_status  run[7:0] ro
//   0x0080 + 0x8*i  boot_lo[8]   addr[31:0] rw  (i < N_HART present)
//   0x0084 + 0x8*i  boot_hi[8]   addr[31:0] rw  (i < N_HART present)
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
module chilimix_socctl_regs #(
  parameter int N_HART = 1  // harts with a reset and a boot address (1 .. 8)
) (
  input  logic clk,
  input  logic rst_n,                  // async, active-low
  input  logic PSEL,                   // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [7:0] PADDR,            // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  input  logic [31:0] id_value,        // ro: SoC ID
  output logic rst_cause_por,          // w1c: Power-on reset
  input  logic rst_cause_por_set,      // set rst_cause.por bits
  output logic rst_cause_ext,          // w1c: External reset pin
  input  logic rst_cause_ext_set,      // set rst_cause.ext bits
  output logic rst_cause_sw,           // w1c: Software system reset (sysrst write)
  input  logic rst_cause_sw_set,       // set rst_cause.sw bits
  output logic rst_cause_req,          // w1c: Reset request from IP (rst_req input, e.g
  input  logic rst_cause_req_set,      // set rst_cause.req bits
  output logic rst_cause_dbg,          // w1c: Debugger reset (dbg_rst_req input: the debug module's ndmreset)
  input  logic rst_cause_dbg_set,      // set rst_cause.dbg bits
  output logic [31:0] sysrst_key,      // wo: Key; other values are ignored
  output logic sysrst_wr,              // sysrst write this cycle (APB ACCESS)
  output logic [7:0] rst_hold_dom,     // rw: Hold domain i (and every later domain) in reset
  output logic rst_hold_wr,            // rst_hold write this cycle (APB ACCESS)
  input  logic rst_status_done,        // ro: The release sequence after the last system reset has finished
  input  logic [7:0] rst_status_dom,   // ro: Domain i is out of reset
  output logic [31:0] clkdiv_div,      // rw: Divisor (values below 2 act as 2); a new value starts with the next output period x2
  output logic [63:0] scratch_value,   // rw: Software-defined x2
  output logic [7:0] hart_hold_hart,   // rw: Hold hart h in reset (bits at and above N_HART have no effect)
  output logic hart_hold_wr,           // hart_hold write this cycle (APB ACCESS)
  input  logic [7:0] hart_status_run,  // ro: Hart h is out of reset
  output logic [255:0] boot_lo_addr,   // rw: Boot address, low word x8
  output logic [255:0] boot_hi_addr    // rw: Boot address, high word x8
);

  // ---- block socctl: 48 word(s) at 0x0
  localparam int                N_SOCCTL = 48;
  // words of the array elements present (N_HART)
  localparam logic [1535:0] ACT_SOCCTL = {{32{N_HART > 7}}, {32{N_HART > 7}}, {32{N_HART > 6}}, {32{N_HART > 6}}, {32{N_HART > 5}}, {32{N_HART > 5}}, {32{N_HART > 4}}, {32{N_HART > 4}}, {32{N_HART > 3}}, {32{N_HART > 3}}, {32{N_HART > 2}}, {32{N_HART > 2}}, {32{N_HART > 1}}, {32{N_HART > 1}}, {32{N_HART > 0}}, {32{N_HART > 0}}, {1024{1'b1}}};
  localparam logic [1535:0] RESET_SOCCTL = 1536'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002_0000_0002_0000_0000_0000_0000_0000_0000_0000_0001_0000_0000 & ACT_SOCCTL;
  localparam logic [1535:0] RW_SOCCTL = 1536'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ffff_ffff_ffff_ffff_0000_ffff_0000_ffff_0000_0000_0000_00ff_0000_0000_0000_0000_0000_0000 & ACT_SOCCTL;
  localparam logic [1535:0] W1C_SOCCTL = 1536'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_001f_0000_0000 & ACT_SOCCTL;
  logic [1535:0] socctl_reg_q;    // rw and w1c bit values
  logic [1535:0] socctl_hw_rd;    // read-only bit values
  logic [1535:0] socctl_hw_set;   // w1c set requests
  logic [47:0] socctl_wr_pulse;    // register written this cycle

  assign socctl_hw_rd[31:0] = id_value;  // id
  assign socctl_hw_set[31:0] = '0;
  assign socctl_hw_rd[63:32] = '0;  // rst_cause
  assign socctl_hw_set[63:32] = {27'b0, rst_cause_dbg_set, rst_cause_req_set, rst_cause_sw_set, rst_cause_ext_set, rst_cause_por_set};
  assign socctl_hw_rd[95:64] = '0;  // sysrst
  assign socctl_hw_set[95:64] = '0;
  assign socctl_hw_rd[127:96] = '0;  // rst_hold
  assign socctl_hw_set[127:96] = '0;
  assign socctl_hw_rd[159:128] = {16'b0, rst_status_dom, 7'b0, rst_status_done};  // rst_status
  assign socctl_hw_set[159:128] = '0;
  assign socctl_hw_rd[191:160] = '0;  // clkdiv[0]
  assign socctl_hw_set[191:160] = '0;
  assign socctl_hw_rd[223:192] = '0;  // clkdiv[1]
  assign socctl_hw_set[223:192] = '0;
  assign socctl_hw_rd[255:224] = '0;  // scratch[0]
  assign socctl_hw_set[255:224] = '0;
  assign socctl_hw_rd[287:256] = '0;  // scratch[1]
  assign socctl_hw_set[287:256] = '0;
  assign socctl_hw_rd[319:288] = '0;  // (no register)
  assign socctl_hw_set[319:288] = '0;
  assign socctl_hw_rd[351:320] = '0;  // (no register)
  assign socctl_hw_set[351:320] = '0;
  assign socctl_hw_rd[383:352] = '0;  // (no register)
  assign socctl_hw_set[383:352] = '0;
  assign socctl_hw_rd[415:384] = '0;  // (no register)
  assign socctl_hw_set[415:384] = '0;
  assign socctl_hw_rd[447:416] = '0;  // (no register)
  assign socctl_hw_set[447:416] = '0;
  assign socctl_hw_rd[479:448] = '0;  // (no register)
  assign socctl_hw_set[479:448] = '0;
  assign socctl_hw_rd[511:480] = '0;  // (no register)
  assign socctl_hw_set[511:480] = '0;
  assign socctl_hw_rd[543:512] = '0;  // hart_hold
  assign socctl_hw_set[543:512] = '0;
  assign socctl_hw_rd[575:544] = {24'b0, hart_status_run};  // hart_status
  assign socctl_hw_set[575:544] = '0;
  assign socctl_hw_rd[607:576] = '0;  // (no register)
  assign socctl_hw_set[607:576] = '0;
  assign socctl_hw_rd[639:608] = '0;  // (no register)
  assign socctl_hw_set[639:608] = '0;
  assign socctl_hw_rd[671:640] = '0;  // (no register)
  assign socctl_hw_set[671:640] = '0;
  assign socctl_hw_rd[703:672] = '0;  // (no register)
  assign socctl_hw_set[703:672] = '0;
  assign socctl_hw_rd[735:704] = '0;  // (no register)
  assign socctl_hw_set[735:704] = '0;
  assign socctl_hw_rd[767:736] = '0;  // (no register)
  assign socctl_hw_set[767:736] = '0;
  assign socctl_hw_rd[799:768] = '0;  // (no register)
  assign socctl_hw_set[799:768] = '0;
  assign socctl_hw_rd[831:800] = '0;  // (no register)
  assign socctl_hw_set[831:800] = '0;
  assign socctl_hw_rd[863:832] = '0;  // (no register)
  assign socctl_hw_set[863:832] = '0;
  assign socctl_hw_rd[895:864] = '0;  // (no register)
  assign socctl_hw_set[895:864] = '0;
  assign socctl_hw_rd[927:896] = '0;  // (no register)
  assign socctl_hw_set[927:896] = '0;
  assign socctl_hw_rd[959:928] = '0;  // (no register)
  assign socctl_hw_set[959:928] = '0;
  assign socctl_hw_rd[991:960] = '0;  // (no register)
  assign socctl_hw_set[991:960] = '0;
  assign socctl_hw_rd[1023:992] = '0;  // (no register)
  assign socctl_hw_set[1023:992] = '0;
  assign socctl_hw_rd[1055:1024] = '0;  // boot_lo[0]
  assign socctl_hw_set[1055:1024] = '0;
  assign socctl_hw_rd[1087:1056] = '0;  // boot_hi[0]
  assign socctl_hw_set[1087:1056] = '0;
  assign socctl_hw_rd[1119:1088] = '0;  // boot_lo[1]
  assign socctl_hw_set[1119:1088] = '0;
  assign socctl_hw_rd[1151:1120] = '0;  // boot_hi[1]
  assign socctl_hw_set[1151:1120] = '0;
  assign socctl_hw_rd[1183:1152] = '0;  // boot_lo[2]
  assign socctl_hw_set[1183:1152] = '0;
  assign socctl_hw_rd[1215:1184] = '0;  // boot_hi[2]
  assign socctl_hw_set[1215:1184] = '0;
  assign socctl_hw_rd[1247:1216] = '0;  // boot_lo[3]
  assign socctl_hw_set[1247:1216] = '0;
  assign socctl_hw_rd[1279:1248] = '0;  // boot_hi[3]
  assign socctl_hw_set[1279:1248] = '0;
  assign socctl_hw_rd[1311:1280] = '0;  // boot_lo[4]
  assign socctl_hw_set[1311:1280] = '0;
  assign socctl_hw_rd[1343:1312] = '0;  // boot_hi[4]
  assign socctl_hw_set[1343:1312] = '0;
  assign socctl_hw_rd[1375:1344] = '0;  // boot_lo[5]
  assign socctl_hw_set[1375:1344] = '0;
  assign socctl_hw_rd[1407:1376] = '0;  // boot_hi[5]
  assign socctl_hw_set[1407:1376] = '0;
  assign socctl_hw_rd[1439:1408] = '0;  // boot_lo[6]
  assign socctl_hw_set[1439:1408] = '0;
  assign socctl_hw_rd[1471:1440] = '0;  // boot_hi[6]
  assign socctl_hw_set[1471:1440] = '0;
  assign socctl_hw_rd[1503:1472] = '0;  // boot_lo[7]
  assign socctl_hw_set[1503:1472] = '0;
  assign socctl_hw_rd[1535:1504] = '0;  // boot_hi[7]
  assign socctl_hw_set[1535:1504] = '0;
  assign rst_cause_por = socctl_reg_q[32];
  assign rst_cause_ext = socctl_reg_q[33];
  assign rst_cause_sw = socctl_reg_q[34];
  assign rst_cause_req = socctl_reg_q[35];
  assign rst_cause_dbg = socctl_reg_q[36];
  assign sysrst_key = PWDATA[31:0];
  assign sysrst_wr = socctl_wr_pulse[2];
  assign rst_hold_dom = socctl_reg_q[103:96];
  assign rst_hold_wr = socctl_wr_pulse[3];
  assign clkdiv_div[15:0] = socctl_reg_q[175:160];
  assign clkdiv_div[31:16] = socctl_reg_q[207:192];
  assign scratch_value[31:0] = socctl_reg_q[255:224];
  assign scratch_value[63:32] = socctl_reg_q[287:256];
  assign hart_hold_hart = socctl_reg_q[519:512];
  assign hart_hold_wr = socctl_wr_pulse[16];
  assign boot_lo_addr[31:0] = socctl_reg_q[1055:1024];
  assign boot_hi_addr[31:0] = socctl_reg_q[1087:1056];
  assign boot_lo_addr[63:32] = socctl_reg_q[1119:1088];
  assign boot_hi_addr[63:32] = socctl_reg_q[1151:1120];
  assign boot_lo_addr[95:64] = socctl_reg_q[1183:1152];
  assign boot_hi_addr[95:64] = socctl_reg_q[1215:1184];
  assign boot_lo_addr[127:96] = socctl_reg_q[1247:1216];
  assign boot_hi_addr[127:96] = socctl_reg_q[1279:1248];
  assign boot_lo_addr[159:128] = socctl_reg_q[1311:1280];
  assign boot_hi_addr[159:128] = socctl_reg_q[1343:1312];
  assign boot_lo_addr[191:160] = socctl_reg_q[1375:1344];
  assign boot_hi_addr[191:160] = socctl_reg_q[1407:1376];
  assign boot_lo_addr[223:192] = socctl_reg_q[1439:1408];
  assign boot_hi_addr[223:192] = socctl_reg_q[1471:1440];
  assign boot_lo_addr[255:224] = socctl_reg_q[1503:1472];
  assign boot_hi_addr[255:224] = socctl_reg_q[1535:1504];

  basechili_apb_regbank #(
    .ADDR_W   (8),
    .DATA_W   (32),
    .N        (N_SOCCTL),
    .RESET    (RESET_SOCCTL),
    .RW_MASK  (RW_SOCCTL),
    .W1C_MASK (W1C_SOCCTL)
  ) u_socctl (
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
    .reg_q    (socctl_reg_q),
    .hw_rd    (socctl_hw_rd),
    .hw_set   (socctl_hw_set),
    .wr_pulse (socctl_wr_pulse),
    .rd_pulse ()
  );

endmodule
