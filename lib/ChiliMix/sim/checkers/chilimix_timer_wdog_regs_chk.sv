// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_timer_wdog_regs_chk (simulation and formal; bound into every chilimix_timer_wdog_regs)
//
// The timer_wdog register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_timer_wdog_regs_chk (
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
  input logic cfg_rsten,
  input logic cfg_zerocmp,
  input logic cfg_enalways,
  input logic cfg_coreawake,
  input logic cfg_ip0,
  input logic cfg_wr,
  input logic [30:0] count_value,
  input logic count_wr,
  input logic [15:0] s_value,
  input logic [31:0] feed_value,
  input logic feed_wr,
  input logic key_unlocked,
  input logic key_wr,
  input logic [15:0] cmp0_value,
  input logic cmp0_wr
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [5:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[5:2] == 4'd0;  // cfg
  assign hit[1] = PADDR[5:2] == 4'd2;  // count
  assign hit[2] = PADDR[5:2] == 4'd4;  // s
  assign hit[3] = PADDR[5:2] == 4'd6;  // feed
  assign hit[4] = PADDR[5:2] == 4'd7;  // key
  assign hit[5] = PADDR[5:2] == 4'd8;  // cmp0
  assign err = !((1'b1 && {1'b0, PADDR[5:2]} < 5'd9));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_timer_wdog_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_timer_wdog_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_timer_wdog_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // cfg at 0x0
    p_cfg_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {3'b0, cfg_ip0, 14'b0, cfg_coreawake, cfg_enalways, 2'b0, cfg_zerocmp, cfg_rsten, 4'b0, cfg_scale})
      else $error("chilimix_timer_wdog_regs: cfg read %h", PRDATA);
    p_cfg_rd_cov: cover (access && !PWRITE && hit[0]);
    // count at 0x8
    p_count_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {1'b0, count_value})
      else $error("chilimix_timer_wdog_regs: count read %h", PRDATA);
    p_count_rd_cov: cover (access && !PWRITE && hit[1]);
    // s at 0x10
    p_s_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {16'b0, s_value})
      else $error("chilimix_timer_wdog_regs: s read %h", PRDATA);
    p_s_rd_cov: cover (access && !PWRITE && hit[2]);
    // feed at 0x18
    p_feed_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == '0)
      else $error("chilimix_timer_wdog_regs: feed read %h", PRDATA);
    p_feed_rd_cov: cover (access && !PWRITE && hit[3]);
    // key at 0x1c
    p_key_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {31'b0, key_unlocked})
      else $error("chilimix_timer_wdog_regs: key read %h", PRDATA);
    p_key_rd_cov: cover (access && !PWRITE && hit[4]);
    // cmp0 at 0x20
    p_cmp0_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {16'b0, cmp0_value})
      else $error("chilimix_timer_wdog_regs: cmp0 read %h", PRDATA);
    p_cmp0_rd_cov: cover (access && !PWRITE && hit[5]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // cfg writes
    p_cfg_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_cfg_wrp: assert (!rst_n || cfg_wr == (access && PWRITE && hit[0]))
      else $error("chilimix_timer_wdog_regs: cfg write pulse wrong");
    // count writes
    p_count_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_count_wrp: assert (!rst_n || count_wr == (access && PWRITE && hit[1]))
      else $error("chilimix_timer_wdog_regs: count write pulse wrong");
    // s writes
    p_s_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    // feed writes
    p_feed_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_feed_wrp: assert (!rst_n || feed_wr == (access && PWRITE && hit[3]))
      else $error("chilimix_timer_wdog_regs: feed write pulse wrong");
    // key writes
    p_key_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_key_wrp: assert (!rst_n || key_wr == (access && PWRITE && hit[4]))
      else $error("chilimix_timer_wdog_regs: key write pulse wrong");
    // cmp0 writes
    p_cmp0_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_cmp0_wrp: assert (!rst_n || cmp0_wr == (access && PWRITE && hit[5]))
      else $error("chilimix_timer_wdog_regs: cmp0 write pulse wrong");
  end

endmodule

bind chilimix_timer_wdog_regs chilimix_timer_wdog_regs_chk u_chk (.*);
