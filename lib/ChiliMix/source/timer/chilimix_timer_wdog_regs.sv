// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_timer_wdog_regs
//
// Watchdog in the SiFive AON watchdog layout: a key-unlocked 31-bit counter with a power-of-2 scale, one 16-bit comparator, an interrupt and a reset request register block: an APB4 subordinate (6-bit PADDR, 32-bit data).
// Register layout compatible with sifive,wdt.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   0x0000  cfg          ip0[28] ro, coreawake[13] ro, enalways[12] ro, zerocmp[9] ro, rsten[8] ro, scale[3:0] ro
//   0x0008  count        value[30:0] ro
//   0x0010  s            value[15:0] ro
//   0x0018  feed         value[31:0] wo
//   0x001c  key          unlocked[0] ro
//   0x0020  cmp0         value[15:0] ro
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
module chilimix_timer_wdog_regs (
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
  input  logic [3:0] cfg_scale,     // ro: wdogscale: wdogs = wdogcount >> wdogscale
  input  logic cfg_rsten,           // ro: wdogrsten: a match requests a reset
  input  logic cfg_zerocmp,         // ro: wdogzerocmp: wdogcount restarts at 0 once wdogs >= wdogcmp0
  input  logic cfg_enalways,        // ro: wdogenalways: count on every tick
  input  logic cfg_coreawake,       // ro: wdogcoreawake: count on every tick while the core is awake
  input  logic cfg_ip0,             // ro: wdogip0: wdogs reached wdogcmp0; drives the interrupt
  output logic cfg_wr,              // cfg write this cycle (APB ACCESS)
  input  logic [30:0] count_value,  // ro: Counter
  output logic count_wr,            // count write this cycle (APB ACCESS)
  input  logic [15:0] s_value,      // ro: Scaled counter
  output logic [31:0] feed_value,   // wo: Feed value
  output logic feed_wr,             // feed write this cycle (APB ACCESS)
  input  logic key_unlocked,        // ro: The next write is allowed
  output logic key_wr,              // key write this cycle (APB ACCESS)
  input  logic [15:0] cmp0_value,   // ro: Compare value (ip0 sets once wdogs >= value)
  output logic cmp0_wr              // cmp0 write this cycle (APB ACCESS)
);

  // ---- block wdog: 9 word(s) at 0x0
  localparam int                N_WDOG = 9;
  localparam logic [287:0] RESET_WDOG = 288'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [287:0] RW_WDOG = 288'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [287:0] W1C_WDOG = 288'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [287:0] wdog_hw_rd;    // read-only bit values
  logic [287:0] wdog_hw_set;   // w1c set requests
  logic [8:0] wdog_wr_pulse;    // register written this cycle

  assign wdog_hw_rd[31:0] = {3'b0, cfg_ip0, 14'b0, cfg_coreawake, cfg_enalways, 2'b0, cfg_zerocmp, cfg_rsten, 4'b0, cfg_scale};  // cfg
  assign wdog_hw_set[31:0] = '0;
  assign wdog_hw_rd[63:32] = '0;  // (no register)
  assign wdog_hw_set[63:32] = '0;
  assign wdog_hw_rd[95:64] = {1'b0, count_value};  // count
  assign wdog_hw_set[95:64] = '0;
  assign wdog_hw_rd[127:96] = '0;  // (no register)
  assign wdog_hw_set[127:96] = '0;
  assign wdog_hw_rd[159:128] = {16'b0, s_value};  // s
  assign wdog_hw_set[159:128] = '0;
  assign wdog_hw_rd[191:160] = '0;  // (no register)
  assign wdog_hw_set[191:160] = '0;
  assign wdog_hw_rd[223:192] = '0;  // feed
  assign wdog_hw_set[223:192] = '0;
  assign wdog_hw_rd[255:224] = {31'b0, key_unlocked};  // key
  assign wdog_hw_set[255:224] = '0;
  assign wdog_hw_rd[287:256] = {16'b0, cmp0_value};  // cmp0
  assign wdog_hw_set[287:256] = '0;
  assign cfg_wr = wdog_wr_pulse[0];
  assign count_wr = wdog_wr_pulse[2];
  assign feed_value = PWDATA[31:0];
  assign feed_wr = wdog_wr_pulse[6];
  assign key_wr = wdog_wr_pulse[7];
  assign cmp0_wr = wdog_wr_pulse[8];

  basechili_apb_regbank #(
    .ADDR_W   (6),
    .DATA_W   (32),
    .N        (N_WDOG),
    .RESET    (RESET_WDOG),
    .RW_MASK  (RW_WDOG),
    .W1C_MASK (W1C_WDOG)
  ) u_wdog (
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
    .reg_q    (),
    .hw_rd    (wdog_hw_rd),
    .hw_set   (wdog_hw_set),
    .wr_pulse (wdog_wr_pulse),
    .rd_pulse ()
  );

endmodule
