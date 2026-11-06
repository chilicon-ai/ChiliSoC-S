// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_timer_pwm_regs_chk (simulation and formal; bound into every chilimix_timer_pwm_regs)
//
// The timer_pwm register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_timer_pwm_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [5:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [3:0] cfg_scale,
  input logic cfg_sticky,
  input logic cfg_zerocmp,
  input logic cfg_deglitch,
  input logic cfg_enalways,
  input logic cfg_oneshot,
  input logic [3:0] cfg_center,
  input logic [3:0] cfg_invert,
  input logic [3:0] cfg_gang,
  input logic [3:0] cfg_ip,
  input logic cfg_wr,
  input logic [30:0] count_value,
  input logic count_wr,
  input logic [15:0] s_value,
  input logic [63:0] cmp_value
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [6:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[5:2] == 4'd0;  // cfg
  assign hit[1] = PADDR[5:2] == 4'd2;  // count
  assign hit[2] = PADDR[5:2] == 4'd4;  // s
  assign hit[3] = PADDR[5:2] == 4'd8;  // cmp[0]
  assign hit[4] = PADDR[5:2] == 4'd9;  // cmp[1]
  assign hit[5] = PADDR[5:2] == 4'd10;  // cmp[2]
  assign hit[6] = PADDR[5:2] == 4'd11;  // cmp[3]
  assign err = !((1'b1 && {1'b0, PADDR[5:2]} < 5'd12));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_timer_pwm_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_timer_pwm_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_timer_pwm_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // cfg at 0x0
    p_cfg_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {cfg_ip, cfg_gang, cfg_invert, cfg_center, 2'b0, cfg_oneshot, cfg_enalways, 1'b0, cfg_deglitch, cfg_zerocmp, cfg_sticky, 4'b0, cfg_scale})
      else $error("chilimix_timer_pwm_regs: cfg read %h", PRDATA);
    p_cfg_rd_cov: cover (access && !PWRITE && hit[0]);
    // count at 0x8
    p_count_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {1'b0, count_value})
      else $error("chilimix_timer_pwm_regs: count read %h", PRDATA);
    p_count_rd_cov: cover (access && !PWRITE && hit[1]);
    // s at 0x10
    p_s_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {16'b0, s_value})
      else $error("chilimix_timer_pwm_regs: s read %h", PRDATA);
    p_s_rd_cov: cover (access && !PWRITE && hit[2]);
    // cmp[0] at 0x20
    p_cmp_0_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {16'b0, cmp_value[15:0]})
      else $error("chilimix_timer_pwm_regs: cmp[0] read %h", PRDATA);
    p_cmp_0_rd_cov: cover (access && !PWRITE && hit[3]);
    // cmp[1] at 0x24
    p_cmp_1_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {16'b0, cmp_value[31:16]})
      else $error("chilimix_timer_pwm_regs: cmp[1] read %h", PRDATA);
    p_cmp_1_rd_cov: cover (access && !PWRITE && hit[4]);
    // cmp[2] at 0x28
    p_cmp_2_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {16'b0, cmp_value[47:32]})
      else $error("chilimix_timer_pwm_regs: cmp[2] read %h", PRDATA);
    p_cmp_2_rd_cov: cover (access && !PWRITE && hit[5]);
    // cmp[3] at 0x2c
    p_cmp_3_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == {16'b0, cmp_value[63:48]})
      else $error("chilimix_timer_pwm_regs: cmp[3] read %h", PRDATA);
    p_cmp_3_rd_cov: cover (access && !PWRITE && hit[6]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // cfg writes
    p_cfg_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_cfg_wrp: assert (!rst_n || cfg_wr == (access && PWRITE && hit[0]))
      else $error("chilimix_timer_pwm_regs: cfg write pulse wrong");
    p_cfg_scale_rst: assert (!past_ok || $past(rst_n) || cfg_scale == 4'h0)
      else $error("chilimix_timer_pwm_regs: cfg.scale reset value %h", cfg_scale);
    p_cfg_scale_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_scale == ($past((access && PWRITE && hit[0])) ? (($past(cfg_scale) & ~$past(bit_en[3:0])) | ($past(PWDATA[3:0]) & $past(bit_en[3:0]))) : $past(cfg_scale)))
      else $error("chilimix_timer_pwm_regs: cfg.scale is %h after a write / hold", cfg_scale);
    p_cfg_sticky_rst: assert (!past_ok || $past(rst_n) || cfg_sticky == 1'h0)
      else $error("chilimix_timer_pwm_regs: cfg.sticky reset value %h", cfg_sticky);
    p_cfg_sticky_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_sticky == ($past((access && PWRITE && hit[0])) ? (($past(cfg_sticky) & ~$past(bit_en[8:8])) | ($past(PWDATA[8:8]) & $past(bit_en[8:8]))) : $past(cfg_sticky)))
      else $error("chilimix_timer_pwm_regs: cfg.sticky is %h after a write / hold", cfg_sticky);
    p_cfg_zerocmp_rst: assert (!past_ok || $past(rst_n) || cfg_zerocmp == 1'h0)
      else $error("chilimix_timer_pwm_regs: cfg.zerocmp reset value %h", cfg_zerocmp);
    p_cfg_zerocmp_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_zerocmp == ($past((access && PWRITE && hit[0])) ? (($past(cfg_zerocmp) & ~$past(bit_en[9:9])) | ($past(PWDATA[9:9]) & $past(bit_en[9:9]))) : $past(cfg_zerocmp)))
      else $error("chilimix_timer_pwm_regs: cfg.zerocmp is %h after a write / hold", cfg_zerocmp);
    p_cfg_deglitch_rst: assert (!past_ok || $past(rst_n) || cfg_deglitch == 1'h0)
      else $error("chilimix_timer_pwm_regs: cfg.deglitch reset value %h", cfg_deglitch);
    p_cfg_deglitch_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_deglitch == ($past((access && PWRITE && hit[0])) ? (($past(cfg_deglitch) & ~$past(bit_en[10:10])) | ($past(PWDATA[10:10]) & $past(bit_en[10:10]))) : $past(cfg_deglitch)))
      else $error("chilimix_timer_pwm_regs: cfg.deglitch is %h after a write / hold", cfg_deglitch);
    p_cfg_enalways_rst: assert (!past_ok || $past(rst_n) || cfg_enalways == 1'h0)
      else $error("chilimix_timer_pwm_regs: cfg.enalways reset value %h", cfg_enalways);
    p_cfg_enalways_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_enalways == ($past((access && PWRITE && hit[0])) ? (($past(cfg_enalways) & ~$past(bit_en[12:12])) | ($past(PWDATA[12:12]) & $past(bit_en[12:12]))) : $past(cfg_enalways)))
      else $error("chilimix_timer_pwm_regs: cfg.enalways is %h after a write / hold", cfg_enalways);
    p_cfg_center_rst: assert (!past_ok || $past(rst_n) || cfg_center == 4'h0)
      else $error("chilimix_timer_pwm_regs: cfg.center reset value %h", cfg_center);
    p_cfg_center_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_center == ($past((access && PWRITE && hit[0])) ? (($past(cfg_center) & ~$past(bit_en[19:16])) | ($past(PWDATA[19:16]) & $past(bit_en[19:16]))) : $past(cfg_center)))
      else $error("chilimix_timer_pwm_regs: cfg.center is %h after a write / hold", cfg_center);
    p_cfg_invert_rst: assert (!past_ok || $past(rst_n) || cfg_invert == 4'h0)
      else $error("chilimix_timer_pwm_regs: cfg.invert reset value %h", cfg_invert);
    p_cfg_invert_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_invert == ($past((access && PWRITE && hit[0])) ? (($past(cfg_invert) & ~$past(bit_en[23:20])) | ($past(PWDATA[23:20]) & $past(bit_en[23:20]))) : $past(cfg_invert)))
      else $error("chilimix_timer_pwm_regs: cfg.invert is %h after a write / hold", cfg_invert);
    p_cfg_gang_rst: assert (!past_ok || $past(rst_n) || cfg_gang == 4'h0)
      else $error("chilimix_timer_pwm_regs: cfg.gang reset value %h", cfg_gang);
    p_cfg_gang_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cfg_gang == ($past((access && PWRITE && hit[0])) ? (($past(cfg_gang) & ~$past(bit_en[27:24])) | ($past(PWDATA[27:24]) & $past(bit_en[27:24]))) : $past(cfg_gang)))
      else $error("chilimix_timer_pwm_regs: cfg.gang is %h after a write / hold", cfg_gang);
    // count writes
    p_count_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_count_wrp: assert (!rst_n || count_wr == (access && PWRITE && hit[1]))
      else $error("chilimix_timer_pwm_regs: count write pulse wrong");
    // s writes
    p_s_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    // cmp[0] writes
    p_cmp_0_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_cmp_0_value_rst: assert (!past_ok || $past(rst_n) || cmp_value[15:0] == 16'hffff)
      else $error("chilimix_timer_pwm_regs: cmp[0].value reset value %h", cmp_value[15:0]);
    p_cmp_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cmp_value[15:0] == ($past((access && PWRITE && hit[3])) ? (($past(cmp_value[15:0]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(cmp_value[15:0])))
      else $error("chilimix_timer_pwm_regs: cmp[0].value is %h after a write / hold", cmp_value[15:0]);
    // cmp[1] writes
    p_cmp_1_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_cmp_1_value_rst: assert (!past_ok || $past(rst_n) || cmp_value[31:16] == 16'hffff)
      else $error("chilimix_timer_pwm_regs: cmp[1].value reset value %h", cmp_value[31:16]);
    p_cmp_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cmp_value[31:16] == ($past((access && PWRITE && hit[4])) ? (($past(cmp_value[31:16]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(cmp_value[31:16])))
      else $error("chilimix_timer_pwm_regs: cmp[1].value is %h after a write / hold", cmp_value[31:16]);
    // cmp[2] writes
    p_cmp_2_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_cmp_2_value_rst: assert (!past_ok || $past(rst_n) || cmp_value[47:32] == 16'hffff)
      else $error("chilimix_timer_pwm_regs: cmp[2].value reset value %h", cmp_value[47:32]);
    p_cmp_2_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cmp_value[47:32] == ($past((access && PWRITE && hit[5])) ? (($past(cmp_value[47:32]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(cmp_value[47:32])))
      else $error("chilimix_timer_pwm_regs: cmp[2].value is %h after a write / hold", cmp_value[47:32]);
    // cmp[3] writes
    p_cmp_3_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_cmp_3_value_rst: assert (!past_ok || $past(rst_n) || cmp_value[63:48] == 16'hffff)
      else $error("chilimix_timer_pwm_regs: cmp[3].value reset value %h", cmp_value[63:48]);
    p_cmp_3_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || cmp_value[63:48] == ($past((access && PWRITE && hit[6])) ? (($past(cmp_value[63:48]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(cmp_value[63:48])))
      else $error("chilimix_timer_pwm_regs: cmp[3].value is %h after a write / hold", cmp_value[63:48]);
  end

endmodule

bind chilimix_timer_pwm_regs chilimix_timer_pwm_regs_chk u_chk (.*);
