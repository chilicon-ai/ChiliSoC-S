// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_timer_pwm
//
// PWM / general-purpose timer in the SiFive PWM layout (sifive,pwm0: four
// 16-bit comparators), so existing drivers work. It behaves like SiFive's
// PWMTimer (sifive-blocks), except that registers reset to 0 where SiFive
// leaves them unreset, and the comparators reset to 0xFFFF (so no ip bit or
// output is set out of reset):
//   count   pwmcount (31 bits) counts clk cycles while enalways or oneshot
//           is set and halt is low. s = (count >> scale)[15:0].
//   restart count goes to 0 when the low scale + 16 bits of count would
//           carry out of an increment (pwms wraps) or when zerocmp is set and
//           elapsed[0] (pwms >= pwmcmp0). A restart clears oneshot.
//   ip X    set by elapsed[X] = (center[X] && s[15] ? ~s : s) >= pwmcmpX; with
//           sticky (or deglitch, until the next restart) it stays set,
//           otherwise it follows elapsed each cycle. In the second half of a
//           centered period it always follows elapsed.
//   out X   (ip X && !(gang X && ip X+1 mod 4)) ^ invert X: high while
//           pwms >= pwmcmpX.
// Software writes: the strobed bytes of pwmcount load the counter (a write
// wins over a restart and an increment, unwritten bytes take the restart
// value); byte 1 of pwmcfg writes oneshot (cleared if a restart happens in
// the same cycle) and byte 3 the ip bits (wins over hardware).
//
// Timing    : APB reads are combinational (no wait states). count, oneshot
//             and ip are registered; s and elapsed are combinational from
//             count, so ip follows a count change one cycle later; out is
//             combinational from ip and the cfg registers; irq is ip.
// Invariants: count changes only by +1 while counting (en and not halt), by
//             a restart to 0 or by a write; oneshot falls only on a restart
//             or a write; irq == ip.
// Debug     : not counting -> cfg_enalways, oneshot, halt; wrong period ->
//             cfg_scale, cfg_zerocmp, restart; wrong output -> elapsed,
//             u_regs.cmp_value, cfg_center / cfg_gang / cfg_invert.
// -----------------------------------------------------------------------------
module chilimix_timer_pwm (
  input  logic        clk,
  input  logic        rst_n,      // async, active-low
  // APB4 subordinate (registers)
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [5:0]  PADDR,      // byte address inside the PWM
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,
  // control
  input  logic        halt,       // freeze the counter (e.g. debug mode)
  // outputs and interrupts, one per comparator
  output logic [3:0]  out,        // PWM outputs (pwmXgpio)
  output logic [3:0]  irq         // level: ip X
);

  logic [3:0]  cfg_scale;
  logic        cfg_sticky;
  logic        cfg_zerocmp;
  logic        cfg_deglitch;
  logic        cfg_enalways;
  logic [3:0]  cfg_center;
  logic [3:0]  cfg_invert;
  logic [3:0]  cfg_gang;
  logic        cfg_wr;            // APB write to pwmcfg
  logic        count_wr;          // APB write to pwmcount
  logic [63:0] cmp_value;         // pwmcmp3 .. pwmcmp0
  logic [30:0] count;             // pwmcount
  logic        count_en;          // count up this cycle
  logic [31:0] wrap_mask;         // low scale + 16 bits of count
  logic        wrap;              // an increment carries out of wrap_mask
  logic        restart;           // count goes to 0
  logic [3:0]  count_strb;        // pwmcount bytes written
  logic        count_load;        // load count (restart or write)
  logic [30:0] count_base;        // count before the write bytes
  logic [30:0] count_load_val;    // restart value with the written bytes
  logic [30:0] count_shr;         // count >> scale
  logic [15:0] s;                 // pwms
  logic [15:0] s_fold;            // ~s in the second half of a period
  logic [3:0]  elapsed;           // pwms (folded if centered) >= pwmcmpX
  logic [3:0]  sel;               // centered comparator, second half
  logic        oneshot;           // pwmenoneshot
  logic        oneshot_wr;        // APB write to pwmcfg byte 1
  logic        oneshot_en;
  logic        oneshot_d;
  logic        sticky_d;          // next sticky_q
  logic        sticky_q;          // ip bits hold this cycle
  logic [3:0]  ip;                // pwmcmpXip
  logic        ip_wr;             // APB write to pwmcfg byte 3
  logic [3:0]  ip_hold;           // ip bits kept by sticky / deglitch
  logic [3:0]  ip_d;              // next ip
  logic [3:0]  ip_next;           // ip X + 1 mod 4
  logic [3:0]  gang_off;          // output X forced low by ganging

  chilimix_timer_pwm_regs u_regs (
    .clk          (clk),
    .rst_n        (rst_n),
    .PSEL         (PSEL),
    .PENABLE      (PENABLE),
    .PWRITE       (PWRITE),
    .PADDR        (PADDR),
    .PWDATA       (PWDATA),
    .PSTRB        (PSTRB),
    .PREADY       (PREADY),
    .PRDATA       (PRDATA),
    .PSLVERR      (PSLVERR),
    .cfg_scale    (cfg_scale),
    .cfg_sticky   (cfg_sticky),
    .cfg_zerocmp  (cfg_zerocmp),
    .cfg_deglitch (cfg_deglitch),
    .cfg_enalways (cfg_enalways),
    .cfg_oneshot  (oneshot),
    .cfg_center   (cfg_center),
    .cfg_invert   (cfg_invert),
    .cfg_gang     (cfg_gang),
    .cfg_ip       (ip),
    .cfg_wr       (cfg_wr),
    .count_value  (count),
    .count_wr     (count_wr),
    .s_value      (s),
    .cmp_value    (cmp_value)
  );

  // ---- scaled count and comparators
  assign count_shr = count >> cfg_scale;
  assign s         = count_shr[15:0];
  assign s_fold    = ~s;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      sel[i]     = s[15] && cfg_center[i];
      elapsed[i] = (sel[i] ? s_fold : s) >= cmp_value[i*16 +: 16];
    end
  end

  // ---- counter: +1 while enabled, restart on a wrap or a zerocmp match
  assign count_en  = (cfg_enalways || oneshot) && !halt;
  assign wrap_mask = (32'd1 << (5'd16 + 5'(cfg_scale))) - 32'd1;
  assign wrap      = count_en && ((count & wrap_mask[30:0]) == wrap_mask[30:0]);
  assign restart   = wrap || (cfg_zerocmp && elapsed[0]);

  assign count_strb = PSTRB & {4{count_wr}};
  assign count_load = restart || (count_strb != 4'b0000);
  assign count_base = restart ? 31'd0 : count;

  always_comb begin
    for (int b = 0; b < 31; b++)
      count_load_val[b] = count_strb[b/8] ? PWDATA[b] : count_base[b];
  end

  basechili_updown_counter #(.WIDTH(31)) u_count (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (count_load),
    .load_val (count_load_val),
    .inc      (count_en),
    .dec      (1'b0),
    .count    (count),
    .count_d  ()
  );

  // ---- oneshot: written by software, cleared by a restart
  assign oneshot_wr = cfg_wr && PSTRB[1];
  assign oneshot_en = oneshot_wr || restart;
  assign oneshot_d  = oneshot_wr && PWDATA[13] && !restart;

  basechili_dffe #(.WIDTH(1)) u_oneshot (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (oneshot_en),
    .d     (oneshot_d),
    .q     (oneshot)
  );

  // ---- interrupt pending bits
  assign sticky_d = (cfg_deglitch && !restart) || cfg_sticky;

  basechili_dff #(.WIDTH(1)) u_sticky (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (sticky_d),
    .q     (sticky_q)
  );

  assign ip_wr   = cfg_wr && PSTRB[3];
  assign ip_hold = {4{sticky_q}} & ip;
  assign ip_d    = ip_wr ? PWDATA[31:28] : ((sel & elapsed) | (~sel & (elapsed | ip_hold)));

  basechili_dff #(.WIDTH(4)) u_ip (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (ip_d),
    .q     (ip)
  );

  // ---- outputs
  assign ip_next  = {ip[0], ip[3:1]};
  assign gang_off = cfg_gang & ip_next;
  assign out      = (ip & ~gang_off) ^ cfg_invert;
  assign irq      = ip;

endmodule
