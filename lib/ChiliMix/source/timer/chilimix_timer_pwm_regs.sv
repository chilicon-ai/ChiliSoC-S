// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_timer_pwm_regs
//
// PWM / timer with four 16-bit comparators in the SiFive PWM layout: a 31-bit counter, a power-of-2 scaled view pwms and per-comparator interrupts and outputs register block: an APB4 subordinate (6-bit PADDR, 32-bit data).
// Register layout compatible with sifive,pwm0.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear):
//   0x0000  cfg          ip[31:28] ro, gang[27:24] rw, invert[23:20] rw, center[19:16] rw, oneshot[13] ro, enalways[12] rw, deglitch[10] rw, zerocmp[9] rw, sticky[8] rw, scale[3:0] rw
//   0x0008  count        value[30:0] ro
//   0x0010  s            value[15:0] ro
//   0x0020 + 0x4*i  cmp[4]       value[15:0] rw
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
module chilimix_timer_pwm_regs (
  input  logic clk,
  input  logic rst_n,               // async, active-low
  input  logic PSEL,                // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [5:0] PADDR,         // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  output logic [3:0] cfg_scale,     // rw: pwmscale: pwms = pwmcount >> pwmscale
  output logic cfg_sticky,          // rw: pwmsticky: ip bits stay set until written 0
  output logic cfg_zerocmp,         // rw: pwmzerocmp: pwmcount restarts at 0 once pwms >= pwmcmp0
  output logic cfg_deglitch,        // rw: pwmdeglitch: ip bits stay set until the period ends
  output logic cfg_enalways,        // rw: pwmenalways: count continuously
  input  logic cfg_oneshot,         // ro: pwmenoneshot (written through the write pulse): count until the next counter restart, then clear
  output logic [3:0] cfg_center,    // rw: pwmcmpXcenter: compare the folded pwms (center-aligned)
  output logic [3:0] cfg_invert,    // rw: pwminvertX: invert output X
  output logic [3:0] cfg_gang,      // rw: pwmcmpXgang: output X is low while ip X+1 (mod 4) is set
  input  logic [3:0] cfg_ip,        // ro: pwmcmpXip (written through the write pulse): comparator X matched; drives interrupt X
  output logic cfg_wr,              // cfg write this cycle (APB ACCESS)
  input  logic [30:0] count_value,  // ro: Counter
  output logic count_wr,            // count write this cycle (APB ACCESS)
  input  logic [15:0] s_value,      // ro: Scaled counter
  output logic [63:0] cmp_value     // rw: Compare value (ip X sets while pwms >= value) x4
);

  // ---- block pwm: 12 word(s) at 0x0
  localparam int                N_PWM = 12;
  localparam logic [383:0] RESET_PWM = 384'h0000_ffff_0000_ffff_0000_ffff_0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [383:0] RW_PWM = 384'h0000_ffff_0000_ffff_0000_ffff_0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0fff_170f;
  localparam logic [383:0] W1C_PWM = 384'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [383:0] pwm_reg_q;    // rw and w1c bit values
  logic [383:0] pwm_hw_rd;    // read-only bit values
  logic [383:0] pwm_hw_set;   // w1c set requests
  logic [11:0] pwm_wr_pulse;    // register written this cycle

  assign pwm_hw_rd[31:0] = {cfg_ip, 14'b0, cfg_oneshot, 13'b0};  // cfg
  assign pwm_hw_set[31:0] = '0;
  assign pwm_hw_rd[63:32] = '0;  // (no register)
  assign pwm_hw_set[63:32] = '0;
  assign pwm_hw_rd[95:64] = {1'b0, count_value};  // count
  assign pwm_hw_set[95:64] = '0;
  assign pwm_hw_rd[127:96] = '0;  // (no register)
  assign pwm_hw_set[127:96] = '0;
  assign pwm_hw_rd[159:128] = {16'b0, s_value};  // s
  assign pwm_hw_set[159:128] = '0;
  assign pwm_hw_rd[191:160] = '0;  // (no register)
  assign pwm_hw_set[191:160] = '0;
  assign pwm_hw_rd[223:192] = '0;  // (no register)
  assign pwm_hw_set[223:192] = '0;
  assign pwm_hw_rd[255:224] = '0;  // (no register)
  assign pwm_hw_set[255:224] = '0;
  assign pwm_hw_rd[287:256] = '0;  // cmp[0]
  assign pwm_hw_set[287:256] = '0;
  assign pwm_hw_rd[319:288] = '0;  // cmp[1]
  assign pwm_hw_set[319:288] = '0;
  assign pwm_hw_rd[351:320] = '0;  // cmp[2]
  assign pwm_hw_set[351:320] = '0;
  assign pwm_hw_rd[383:352] = '0;  // cmp[3]
  assign pwm_hw_set[383:352] = '0;
  assign cfg_scale = pwm_reg_q[3:0];
  assign cfg_sticky = pwm_reg_q[8];
  assign cfg_zerocmp = pwm_reg_q[9];
  assign cfg_deglitch = pwm_reg_q[10];
  assign cfg_enalways = pwm_reg_q[12];
  assign cfg_center = pwm_reg_q[19:16];
  assign cfg_invert = pwm_reg_q[23:20];
  assign cfg_gang = pwm_reg_q[27:24];
  assign cfg_wr = pwm_wr_pulse[0];
  assign count_wr = pwm_wr_pulse[2];
  assign cmp_value[15:0] = pwm_reg_q[271:256];
  assign cmp_value[31:16] = pwm_reg_q[303:288];
  assign cmp_value[47:32] = pwm_reg_q[335:320];
  assign cmp_value[63:48] = pwm_reg_q[367:352];

  basechili_apb_regbank #(
    .ADDR_W   (6),
    .DATA_W   (32),
    .N        (N_PWM),
    .RESET    (RESET_PWM),
    .RW_MASK  (RW_PWM),
    .W1C_MASK (W1C_PWM)
  ) u_pwm (
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
    .reg_q    (pwm_reg_q),
    .hw_rd    (pwm_hw_rd),
    .hw_set   (pwm_hw_set),
    .wr_pulse (pwm_wr_pulse),
    .rd_pulse ()
  );

endmodule
