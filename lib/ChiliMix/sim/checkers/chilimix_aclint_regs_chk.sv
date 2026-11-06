// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_aclint_regs_chk (simulation and formal; bound into every chilimix_aclint_regs)
//
// The aclint register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_aclint_regs_chk #(
  parameter int N_HART = 1  // harts present (1 .. 8)
) (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [15:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [7:0] msip_pending,
  input logic [255:0] mtimecmp_lo_value,
  input logic [255:0] mtimecmp_hi_value,
  input logic [31:0] mtime_lo_value,
  input logic mtime_lo_wr,
  input logic [31:0] mtime_hi_value,
  input logic mtime_hi_wr,
  input logic [7:0] setssip_set,
  input logic [7:0] setssip_wr
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [33:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[15:2] == 14'd0;  // msip[0]
  assign hit[1] = PADDR[15:2] == 14'd1;  // msip[1]
  assign hit[2] = PADDR[15:2] == 14'd2;  // msip[2]
  assign hit[3] = PADDR[15:2] == 14'd3;  // msip[3]
  assign hit[4] = PADDR[15:2] == 14'd4;  // msip[4]
  assign hit[5] = PADDR[15:2] == 14'd5;  // msip[5]
  assign hit[6] = PADDR[15:2] == 14'd6;  // msip[6]
  assign hit[7] = PADDR[15:2] == 14'd7;  // msip[7]
  assign hit[8] = PADDR[15:2] == 14'd4096;  // mtimecmp_lo[0]
  assign hit[9] = PADDR[15:2] == 14'd4097;  // mtimecmp_hi[0]
  assign hit[10] = PADDR[15:2] == 14'd4098;  // mtimecmp_lo[1]
  assign hit[11] = PADDR[15:2] == 14'd4099;  // mtimecmp_hi[1]
  assign hit[12] = PADDR[15:2] == 14'd4100;  // mtimecmp_lo[2]
  assign hit[13] = PADDR[15:2] == 14'd4101;  // mtimecmp_hi[2]
  assign hit[14] = PADDR[15:2] == 14'd4102;  // mtimecmp_lo[3]
  assign hit[15] = PADDR[15:2] == 14'd4103;  // mtimecmp_hi[3]
  assign hit[16] = PADDR[15:2] == 14'd4104;  // mtimecmp_lo[4]
  assign hit[17] = PADDR[15:2] == 14'd4105;  // mtimecmp_hi[4]
  assign hit[18] = PADDR[15:2] == 14'd4106;  // mtimecmp_lo[5]
  assign hit[19] = PADDR[15:2] == 14'd4107;  // mtimecmp_hi[5]
  assign hit[20] = PADDR[15:2] == 14'd4108;  // mtimecmp_lo[6]
  assign hit[21] = PADDR[15:2] == 14'd4109;  // mtimecmp_hi[6]
  assign hit[22] = PADDR[15:2] == 14'd4110;  // mtimecmp_lo[7]
  assign hit[23] = PADDR[15:2] == 14'd4111;  // mtimecmp_hi[7]
  assign hit[24] = PADDR[15:2] == 14'd12286;  // mtime_lo
  assign hit[25] = PADDR[15:2] == 14'd12287;  // mtime_hi
  assign hit[26] = PADDR[15:2] == 14'd12288;  // setssip[0]
  assign hit[27] = PADDR[15:2] == 14'd12289;  // setssip[1]
  assign hit[28] = PADDR[15:2] == 14'd12290;  // setssip[2]
  assign hit[29] = PADDR[15:2] == 14'd12291;  // setssip[3]
  assign hit[30] = PADDR[15:2] == 14'd12292;  // setssip[4]
  assign hit[31] = PADDR[15:2] == 14'd12293;  // setssip[5]
  assign hit[32] = PADDR[15:2] == 14'd12294;  // setssip[6]
  assign hit[33] = PADDR[15:2] == 14'd12295;  // setssip[7]
  assign err = !((PADDR[15:14] == 2'd0 && {1'b0, PADDR[13:2]} < 13'd8) || (PADDR[15:6] == 10'd256 && {1'b0, PADDR[5:2]} < 5'd16) || (PADDR[15:3] == 13'd6143 && {1'b0, PADDR[2:2]} < 2'd2) || (PADDR[15:14] == 2'd3 && {1'b0, PADDR[13:2]} < 13'd8));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11] || hit[12] || hit[13] || hit[14] || hit[15] || hit[16] || hit[17] || hit[18] || hit[19] || hit[20] || hit[21] || hit[22] || hit[23] || hit[24] || hit[25] || hit[26] || hit[27] || hit[28] || hit[29] || hit[30] || hit[31] || hit[32] || hit[33]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_aclint_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_aclint_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_aclint_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // msip[0] at 0x0
    p_msip_0_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == ((N_HART > 0) ? {31'b0, msip_pending[0]} : '0))
      else $error("chilimix_aclint_regs: msip[0] read %h", PRDATA);
    p_msip_0_rd_cov: cover (access && !PWRITE && hit[0]);
    // msip[1] at 0x4
    p_msip_1_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == ((N_HART > 1) ? {31'b0, msip_pending[1]} : '0))
      else $error("chilimix_aclint_regs: msip[1] read %h", PRDATA);
    p_msip_1_rd_cov: cover (access && !PWRITE && hit[1]);
    // msip[2] at 0x8
    p_msip_2_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == ((N_HART > 2) ? {31'b0, msip_pending[2]} : '0))
      else $error("chilimix_aclint_regs: msip[2] read %h", PRDATA);
    p_msip_2_rd_cov: cover (access && !PWRITE && hit[2]);
    // msip[3] at 0xc
    p_msip_3_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == ((N_HART > 3) ? {31'b0, msip_pending[3]} : '0))
      else $error("chilimix_aclint_regs: msip[3] read %h", PRDATA);
    p_msip_3_rd_cov: cover (access && !PWRITE && hit[3]);
    // msip[4] at 0x10
    p_msip_4_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == ((N_HART > 4) ? {31'b0, msip_pending[4]} : '0))
      else $error("chilimix_aclint_regs: msip[4] read %h", PRDATA);
    p_msip_4_rd_cov: cover (access && !PWRITE && hit[4]);
    // msip[5] at 0x14
    p_msip_5_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == ((N_HART > 5) ? {31'b0, msip_pending[5]} : '0))
      else $error("chilimix_aclint_regs: msip[5] read %h", PRDATA);
    p_msip_5_rd_cov: cover (access && !PWRITE && hit[5]);
    // msip[6] at 0x18
    p_msip_6_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == ((N_HART > 6) ? {31'b0, msip_pending[6]} : '0))
      else $error("chilimix_aclint_regs: msip[6] read %h", PRDATA);
    p_msip_6_rd_cov: cover (access && !PWRITE && hit[6]);
    // msip[7] at 0x1c
    p_msip_7_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == ((N_HART > 7) ? {31'b0, msip_pending[7]} : '0))
      else $error("chilimix_aclint_regs: msip[7] read %h", PRDATA);
    p_msip_7_rd_cov: cover (access && !PWRITE && hit[7]);
    // mtimecmp_lo[0] at 0x4000
    p_mtimecmp_lo_0_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == ((N_HART > 0) ? mtimecmp_lo_value[31:0] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[0] read %h", PRDATA);
    p_mtimecmp_lo_0_rd_cov: cover (access && !PWRITE && hit[8]);
    // mtimecmp_hi[0] at 0x4004
    p_mtimecmp_hi_0_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == ((N_HART > 0) ? mtimecmp_hi_value[31:0] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[0] read %h", PRDATA);
    p_mtimecmp_hi_0_rd_cov: cover (access && !PWRITE && hit[9]);
    // mtimecmp_lo[1] at 0x4008
    p_mtimecmp_lo_1_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == ((N_HART > 1) ? mtimecmp_lo_value[63:32] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[1] read %h", PRDATA);
    p_mtimecmp_lo_1_rd_cov: cover (access && !PWRITE && hit[10]);
    // mtimecmp_hi[1] at 0x400c
    p_mtimecmp_hi_1_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == ((N_HART > 1) ? mtimecmp_hi_value[63:32] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[1] read %h", PRDATA);
    p_mtimecmp_hi_1_rd_cov: cover (access && !PWRITE && hit[11]);
    // mtimecmp_lo[2] at 0x4010
    p_mtimecmp_lo_2_rd: assert (!(access && !PWRITE && hit[12]) || PRDATA == ((N_HART > 2) ? mtimecmp_lo_value[95:64] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[2] read %h", PRDATA);
    p_mtimecmp_lo_2_rd_cov: cover (access && !PWRITE && hit[12]);
    // mtimecmp_hi[2] at 0x4014
    p_mtimecmp_hi_2_rd: assert (!(access && !PWRITE && hit[13]) || PRDATA == ((N_HART > 2) ? mtimecmp_hi_value[95:64] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[2] read %h", PRDATA);
    p_mtimecmp_hi_2_rd_cov: cover (access && !PWRITE && hit[13]);
    // mtimecmp_lo[3] at 0x4018
    p_mtimecmp_lo_3_rd: assert (!(access && !PWRITE && hit[14]) || PRDATA == ((N_HART > 3) ? mtimecmp_lo_value[127:96] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[3] read %h", PRDATA);
    p_mtimecmp_lo_3_rd_cov: cover (access && !PWRITE && hit[14]);
    // mtimecmp_hi[3] at 0x401c
    p_mtimecmp_hi_3_rd: assert (!(access && !PWRITE && hit[15]) || PRDATA == ((N_HART > 3) ? mtimecmp_hi_value[127:96] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[3] read %h", PRDATA);
    p_mtimecmp_hi_3_rd_cov: cover (access && !PWRITE && hit[15]);
    // mtimecmp_lo[4] at 0x4020
    p_mtimecmp_lo_4_rd: assert (!(access && !PWRITE && hit[16]) || PRDATA == ((N_HART > 4) ? mtimecmp_lo_value[159:128] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[4] read %h", PRDATA);
    p_mtimecmp_lo_4_rd_cov: cover (access && !PWRITE && hit[16]);
    // mtimecmp_hi[4] at 0x4024
    p_mtimecmp_hi_4_rd: assert (!(access && !PWRITE && hit[17]) || PRDATA == ((N_HART > 4) ? mtimecmp_hi_value[159:128] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[4] read %h", PRDATA);
    p_mtimecmp_hi_4_rd_cov: cover (access && !PWRITE && hit[17]);
    // mtimecmp_lo[5] at 0x4028
    p_mtimecmp_lo_5_rd: assert (!(access && !PWRITE && hit[18]) || PRDATA == ((N_HART > 5) ? mtimecmp_lo_value[191:160] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[5] read %h", PRDATA);
    p_mtimecmp_lo_5_rd_cov: cover (access && !PWRITE && hit[18]);
    // mtimecmp_hi[5] at 0x402c
    p_mtimecmp_hi_5_rd: assert (!(access && !PWRITE && hit[19]) || PRDATA == ((N_HART > 5) ? mtimecmp_hi_value[191:160] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[5] read %h", PRDATA);
    p_mtimecmp_hi_5_rd_cov: cover (access && !PWRITE && hit[19]);
    // mtimecmp_lo[6] at 0x4030
    p_mtimecmp_lo_6_rd: assert (!(access && !PWRITE && hit[20]) || PRDATA == ((N_HART > 6) ? mtimecmp_lo_value[223:192] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[6] read %h", PRDATA);
    p_mtimecmp_lo_6_rd_cov: cover (access && !PWRITE && hit[20]);
    // mtimecmp_hi[6] at 0x4034
    p_mtimecmp_hi_6_rd: assert (!(access && !PWRITE && hit[21]) || PRDATA == ((N_HART > 6) ? mtimecmp_hi_value[223:192] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[6] read %h", PRDATA);
    p_mtimecmp_hi_6_rd_cov: cover (access && !PWRITE && hit[21]);
    // mtimecmp_lo[7] at 0x4038
    p_mtimecmp_lo_7_rd: assert (!(access && !PWRITE && hit[22]) || PRDATA == ((N_HART > 7) ? mtimecmp_lo_value[255:224] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[7] read %h", PRDATA);
    p_mtimecmp_lo_7_rd_cov: cover (access && !PWRITE && hit[22]);
    // mtimecmp_hi[7] at 0x403c
    p_mtimecmp_hi_7_rd: assert (!(access && !PWRITE && hit[23]) || PRDATA == ((N_HART > 7) ? mtimecmp_hi_value[255:224] : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[7] read %h", PRDATA);
    p_mtimecmp_hi_7_rd_cov: cover (access && !PWRITE && hit[23]);
    // mtime_lo at 0xbff8
    p_mtime_lo_rd: assert (!(access && !PWRITE && hit[24]) || PRDATA == mtime_lo_value)
      else $error("chilimix_aclint_regs: mtime_lo read %h", PRDATA);
    p_mtime_lo_rd_cov: cover (access && !PWRITE && hit[24]);
    // mtime_hi at 0xbffc
    p_mtime_hi_rd: assert (!(access && !PWRITE && hit[25]) || PRDATA == mtime_hi_value)
      else $error("chilimix_aclint_regs: mtime_hi read %h", PRDATA);
    p_mtime_hi_rd_cov: cover (access && !PWRITE && hit[25]);
    // setssip[0] at 0xc000
    p_setssip_0_rd: assert (!(access && !PWRITE && hit[26]) || PRDATA == ((N_HART > 0) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[0] read %h", PRDATA);
    p_setssip_0_rd_cov: cover (access && !PWRITE && hit[26]);
    // setssip[1] at 0xc004
    p_setssip_1_rd: assert (!(access && !PWRITE && hit[27]) || PRDATA == ((N_HART > 1) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[1] read %h", PRDATA);
    p_setssip_1_rd_cov: cover (access && !PWRITE && hit[27]);
    // setssip[2] at 0xc008
    p_setssip_2_rd: assert (!(access && !PWRITE && hit[28]) || PRDATA == ((N_HART > 2) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[2] read %h", PRDATA);
    p_setssip_2_rd_cov: cover (access && !PWRITE && hit[28]);
    // setssip[3] at 0xc00c
    p_setssip_3_rd: assert (!(access && !PWRITE && hit[29]) || PRDATA == ((N_HART > 3) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[3] read %h", PRDATA);
    p_setssip_3_rd_cov: cover (access && !PWRITE && hit[29]);
    // setssip[4] at 0xc010
    p_setssip_4_rd: assert (!(access && !PWRITE && hit[30]) || PRDATA == ((N_HART > 4) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[4] read %h", PRDATA);
    p_setssip_4_rd_cov: cover (access && !PWRITE && hit[30]);
    // setssip[5] at 0xc014
    p_setssip_5_rd: assert (!(access && !PWRITE && hit[31]) || PRDATA == ((N_HART > 5) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[5] read %h", PRDATA);
    p_setssip_5_rd_cov: cover (access && !PWRITE && hit[31]);
    // setssip[6] at 0xc018
    p_setssip_6_rd: assert (!(access && !PWRITE && hit[32]) || PRDATA == ((N_HART > 6) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[6] read %h", PRDATA);
    p_setssip_6_rd_cov: cover (access && !PWRITE && hit[32]);
    // setssip[7] at 0xc01c
    p_setssip_7_rd: assert (!(access && !PWRITE && hit[33]) || PRDATA == ((N_HART > 7) ? '0 : '0))
      else $error("chilimix_aclint_regs: setssip[7] read %h", PRDATA);
    p_setssip_7_rd_cov: cover (access && !PWRITE && hit[33]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // msip[0] writes
    p_msip_0_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_msip_0_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[0] == ((N_HART > 0) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[0].pending reset value %h", msip_pending[0]);
    p_msip_0_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[0] == ((N_HART > 0) ? ($past((access && PWRITE && hit[0])) ? (($past(msip_pending[0]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[0])) : '0))
      else $error("chilimix_aclint_regs: msip[0].pending is %h after a write / hold", msip_pending[0]);
    // msip[1] writes
    p_msip_1_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_msip_1_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[1] == ((N_HART > 1) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[1].pending reset value %h", msip_pending[1]);
    p_msip_1_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[1] == ((N_HART > 1) ? ($past((access && PWRITE && hit[1])) ? (($past(msip_pending[1]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[1])) : '0))
      else $error("chilimix_aclint_regs: msip[1].pending is %h after a write / hold", msip_pending[1]);
    // msip[2] writes
    p_msip_2_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_msip_2_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[2] == ((N_HART > 2) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[2].pending reset value %h", msip_pending[2]);
    p_msip_2_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[2] == ((N_HART > 2) ? ($past((access && PWRITE && hit[2])) ? (($past(msip_pending[2]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[2])) : '0))
      else $error("chilimix_aclint_regs: msip[2].pending is %h after a write / hold", msip_pending[2]);
    // msip[3] writes
    p_msip_3_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_msip_3_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[3] == ((N_HART > 3) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[3].pending reset value %h", msip_pending[3]);
    p_msip_3_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[3] == ((N_HART > 3) ? ($past((access && PWRITE && hit[3])) ? (($past(msip_pending[3]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[3])) : '0))
      else $error("chilimix_aclint_regs: msip[3].pending is %h after a write / hold", msip_pending[3]);
    // msip[4] writes
    p_msip_4_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_msip_4_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[4] == ((N_HART > 4) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[4].pending reset value %h", msip_pending[4]);
    p_msip_4_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[4] == ((N_HART > 4) ? ($past((access && PWRITE && hit[4])) ? (($past(msip_pending[4]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[4])) : '0))
      else $error("chilimix_aclint_regs: msip[4].pending is %h after a write / hold", msip_pending[4]);
    // msip[5] writes
    p_msip_5_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_msip_5_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[5] == ((N_HART > 5) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[5].pending reset value %h", msip_pending[5]);
    p_msip_5_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[5] == ((N_HART > 5) ? ($past((access && PWRITE && hit[5])) ? (($past(msip_pending[5]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[5])) : '0))
      else $error("chilimix_aclint_regs: msip[5].pending is %h after a write / hold", msip_pending[5]);
    // msip[6] writes
    p_msip_6_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_msip_6_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[6] == ((N_HART > 6) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[6].pending reset value %h", msip_pending[6]);
    p_msip_6_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[6] == ((N_HART > 6) ? ($past((access && PWRITE && hit[6])) ? (($past(msip_pending[6]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[6])) : '0))
      else $error("chilimix_aclint_regs: msip[6].pending is %h after a write / hold", msip_pending[6]);
    // msip[7] writes
    p_msip_7_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_msip_7_pending_rst: assert (!past_ok || $past(rst_n) || msip_pending[7] == ((N_HART > 7) ? 1'h0 : '0))
      else $error("chilimix_aclint_regs: msip[7].pending reset value %h", msip_pending[7]);
    p_msip_7_pending_wr: assert (!rst_n || !past_ok || !$past(rst_n) || msip_pending[7] == ((N_HART > 7) ? ($past((access && PWRITE && hit[7])) ? (($past(msip_pending[7]) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(msip_pending[7])) : '0))
      else $error("chilimix_aclint_regs: msip[7].pending is %h after a write / hold", msip_pending[7]);
    // mtimecmp_lo[0] writes
    p_mtimecmp_lo_0_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_mtimecmp_lo_0_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[31:0] == ((N_HART > 0) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[0].value reset value %h", mtimecmp_lo_value[31:0]);
    p_mtimecmp_lo_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[31:0] == ((N_HART > 0) ? ($past((access && PWRITE && hit[8])) ? (($past(mtimecmp_lo_value[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[31:0])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[0].value is %h after a write / hold", mtimecmp_lo_value[31:0]);
    // mtimecmp_hi[0] writes
    p_mtimecmp_hi_0_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    p_mtimecmp_hi_0_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[31:0] == ((N_HART > 0) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[0].value reset value %h", mtimecmp_hi_value[31:0]);
    p_mtimecmp_hi_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[31:0] == ((N_HART > 0) ? ($past((access && PWRITE && hit[9])) ? (($past(mtimecmp_hi_value[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[31:0])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[0].value is %h after a write / hold", mtimecmp_hi_value[31:0]);
    // mtimecmp_lo[1] writes
    p_mtimecmp_lo_1_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    p_mtimecmp_lo_1_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[63:32] == ((N_HART > 1) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[1].value reset value %h", mtimecmp_lo_value[63:32]);
    p_mtimecmp_lo_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[63:32] == ((N_HART > 1) ? ($past((access && PWRITE && hit[10])) ? (($past(mtimecmp_lo_value[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[63:32])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[1].value is %h after a write / hold", mtimecmp_lo_value[63:32]);
    // mtimecmp_hi[1] writes
    p_mtimecmp_hi_1_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_mtimecmp_hi_1_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[63:32] == ((N_HART > 1) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[1].value reset value %h", mtimecmp_hi_value[63:32]);
    p_mtimecmp_hi_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[63:32] == ((N_HART > 1) ? ($past((access && PWRITE && hit[11])) ? (($past(mtimecmp_hi_value[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[63:32])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[1].value is %h after a write / hold", mtimecmp_hi_value[63:32]);
    // mtimecmp_lo[2] writes
    p_mtimecmp_lo_2_wr_cov: cover (rst_n && (access && PWRITE && hit[12]));
    p_mtimecmp_lo_2_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[95:64] == ((N_HART > 2) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[2].value reset value %h", mtimecmp_lo_value[95:64]);
    p_mtimecmp_lo_2_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[95:64] == ((N_HART > 2) ? ($past((access && PWRITE && hit[12])) ? (($past(mtimecmp_lo_value[95:64]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[95:64])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[2].value is %h after a write / hold", mtimecmp_lo_value[95:64]);
    // mtimecmp_hi[2] writes
    p_mtimecmp_hi_2_wr_cov: cover (rst_n && (access && PWRITE && hit[13]));
    p_mtimecmp_hi_2_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[95:64] == ((N_HART > 2) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[2].value reset value %h", mtimecmp_hi_value[95:64]);
    p_mtimecmp_hi_2_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[95:64] == ((N_HART > 2) ? ($past((access && PWRITE && hit[13])) ? (($past(mtimecmp_hi_value[95:64]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[95:64])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[2].value is %h after a write / hold", mtimecmp_hi_value[95:64]);
    // mtimecmp_lo[3] writes
    p_mtimecmp_lo_3_wr_cov: cover (rst_n && (access && PWRITE && hit[14]));
    p_mtimecmp_lo_3_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[127:96] == ((N_HART > 3) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[3].value reset value %h", mtimecmp_lo_value[127:96]);
    p_mtimecmp_lo_3_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[127:96] == ((N_HART > 3) ? ($past((access && PWRITE && hit[14])) ? (($past(mtimecmp_lo_value[127:96]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[127:96])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[3].value is %h after a write / hold", mtimecmp_lo_value[127:96]);
    // mtimecmp_hi[3] writes
    p_mtimecmp_hi_3_wr_cov: cover (rst_n && (access && PWRITE && hit[15]));
    p_mtimecmp_hi_3_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[127:96] == ((N_HART > 3) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[3].value reset value %h", mtimecmp_hi_value[127:96]);
    p_mtimecmp_hi_3_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[127:96] == ((N_HART > 3) ? ($past((access && PWRITE && hit[15])) ? (($past(mtimecmp_hi_value[127:96]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[127:96])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[3].value is %h after a write / hold", mtimecmp_hi_value[127:96]);
    // mtimecmp_lo[4] writes
    p_mtimecmp_lo_4_wr_cov: cover (rst_n && (access && PWRITE && hit[16]));
    p_mtimecmp_lo_4_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[159:128] == ((N_HART > 4) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[4].value reset value %h", mtimecmp_lo_value[159:128]);
    p_mtimecmp_lo_4_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[159:128] == ((N_HART > 4) ? ($past((access && PWRITE && hit[16])) ? (($past(mtimecmp_lo_value[159:128]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[159:128])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[4].value is %h after a write / hold", mtimecmp_lo_value[159:128]);
    // mtimecmp_hi[4] writes
    p_mtimecmp_hi_4_wr_cov: cover (rst_n && (access && PWRITE && hit[17]));
    p_mtimecmp_hi_4_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[159:128] == ((N_HART > 4) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[4].value reset value %h", mtimecmp_hi_value[159:128]);
    p_mtimecmp_hi_4_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[159:128] == ((N_HART > 4) ? ($past((access && PWRITE && hit[17])) ? (($past(mtimecmp_hi_value[159:128]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[159:128])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[4].value is %h after a write / hold", mtimecmp_hi_value[159:128]);
    // mtimecmp_lo[5] writes
    p_mtimecmp_lo_5_wr_cov: cover (rst_n && (access && PWRITE && hit[18]));
    p_mtimecmp_lo_5_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[191:160] == ((N_HART > 5) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[5].value reset value %h", mtimecmp_lo_value[191:160]);
    p_mtimecmp_lo_5_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[191:160] == ((N_HART > 5) ? ($past((access && PWRITE && hit[18])) ? (($past(mtimecmp_lo_value[191:160]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[191:160])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[5].value is %h after a write / hold", mtimecmp_lo_value[191:160]);
    // mtimecmp_hi[5] writes
    p_mtimecmp_hi_5_wr_cov: cover (rst_n && (access && PWRITE && hit[19]));
    p_mtimecmp_hi_5_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[191:160] == ((N_HART > 5) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[5].value reset value %h", mtimecmp_hi_value[191:160]);
    p_mtimecmp_hi_5_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[191:160] == ((N_HART > 5) ? ($past((access && PWRITE && hit[19])) ? (($past(mtimecmp_hi_value[191:160]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[191:160])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[5].value is %h after a write / hold", mtimecmp_hi_value[191:160]);
    // mtimecmp_lo[6] writes
    p_mtimecmp_lo_6_wr_cov: cover (rst_n && (access && PWRITE && hit[20]));
    p_mtimecmp_lo_6_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[223:192] == ((N_HART > 6) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[6].value reset value %h", mtimecmp_lo_value[223:192]);
    p_mtimecmp_lo_6_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[223:192] == ((N_HART > 6) ? ($past((access && PWRITE && hit[20])) ? (($past(mtimecmp_lo_value[223:192]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[223:192])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[6].value is %h after a write / hold", mtimecmp_lo_value[223:192]);
    // mtimecmp_hi[6] writes
    p_mtimecmp_hi_6_wr_cov: cover (rst_n && (access && PWRITE && hit[21]));
    p_mtimecmp_hi_6_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[223:192] == ((N_HART > 6) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[6].value reset value %h", mtimecmp_hi_value[223:192]);
    p_mtimecmp_hi_6_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[223:192] == ((N_HART > 6) ? ($past((access && PWRITE && hit[21])) ? (($past(mtimecmp_hi_value[223:192]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[223:192])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[6].value is %h after a write / hold", mtimecmp_hi_value[223:192]);
    // mtimecmp_lo[7] writes
    p_mtimecmp_lo_7_wr_cov: cover (rst_n && (access && PWRITE && hit[22]));
    p_mtimecmp_lo_7_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_lo_value[255:224] == ((N_HART > 7) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[7].value reset value %h", mtimecmp_lo_value[255:224]);
    p_mtimecmp_lo_7_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_lo_value[255:224] == ((N_HART > 7) ? ($past((access && PWRITE && hit[22])) ? (($past(mtimecmp_lo_value[255:224]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_lo_value[255:224])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_lo[7].value is %h after a write / hold", mtimecmp_lo_value[255:224]);
    // mtimecmp_hi[7] writes
    p_mtimecmp_hi_7_wr_cov: cover (rst_n && (access && PWRITE && hit[23]));
    p_mtimecmp_hi_7_value_rst: assert (!past_ok || $past(rst_n) || mtimecmp_hi_value[255:224] == ((N_HART > 7) ? 32'hffff_ffff : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[7].value reset value %h", mtimecmp_hi_value[255:224]);
    p_mtimecmp_hi_7_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mtimecmp_hi_value[255:224] == ((N_HART > 7) ? ($past((access && PWRITE && hit[23])) ? (($past(mtimecmp_hi_value[255:224]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(mtimecmp_hi_value[255:224])) : '0))
      else $error("chilimix_aclint_regs: mtimecmp_hi[7].value is %h after a write / hold", mtimecmp_hi_value[255:224]);
    // mtime_lo writes
    p_mtime_lo_wr_cov: cover (rst_n && (access && PWRITE && hit[24]));
    p_mtime_lo_wrp: assert (!rst_n || mtime_lo_wr == (access && PWRITE && hit[24]))
      else $error("chilimix_aclint_regs: mtime_lo write pulse wrong");
    // mtime_hi writes
    p_mtime_hi_wr_cov: cover (rst_n && (access && PWRITE && hit[25]));
    p_mtime_hi_wrp: assert (!rst_n || mtime_hi_wr == (access && PWRITE && hit[25]))
      else $error("chilimix_aclint_regs: mtime_hi write pulse wrong");
    // setssip[0] writes
    p_setssip_0_wr_cov: cover (rst_n && (access && PWRITE && hit[26]));
    p_setssip_0_wrp: assert (!rst_n || setssip_wr[0] == ((N_HART > 0) ? (access && PWRITE && hit[26]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[0] write pulse wrong");
    // setssip[1] writes
    p_setssip_1_wr_cov: cover (rst_n && (access && PWRITE && hit[27]));
    p_setssip_1_wrp: assert (!rst_n || setssip_wr[1] == ((N_HART > 1) ? (access && PWRITE && hit[27]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[1] write pulse wrong");
    // setssip[2] writes
    p_setssip_2_wr_cov: cover (rst_n && (access && PWRITE && hit[28]));
    p_setssip_2_wrp: assert (!rst_n || setssip_wr[2] == ((N_HART > 2) ? (access && PWRITE && hit[28]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[2] write pulse wrong");
    // setssip[3] writes
    p_setssip_3_wr_cov: cover (rst_n && (access && PWRITE && hit[29]));
    p_setssip_3_wrp: assert (!rst_n || setssip_wr[3] == ((N_HART > 3) ? (access && PWRITE && hit[29]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[3] write pulse wrong");
    // setssip[4] writes
    p_setssip_4_wr_cov: cover (rst_n && (access && PWRITE && hit[30]));
    p_setssip_4_wrp: assert (!rst_n || setssip_wr[4] == ((N_HART > 4) ? (access && PWRITE && hit[30]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[4] write pulse wrong");
    // setssip[5] writes
    p_setssip_5_wr_cov: cover (rst_n && (access && PWRITE && hit[31]));
    p_setssip_5_wrp: assert (!rst_n || setssip_wr[5] == ((N_HART > 5) ? (access && PWRITE && hit[31]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[5] write pulse wrong");
    // setssip[6] writes
    p_setssip_6_wr_cov: cover (rst_n && (access && PWRITE && hit[32]));
    p_setssip_6_wrp: assert (!rst_n || setssip_wr[6] == ((N_HART > 6) ? (access && PWRITE && hit[32]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[6] write pulse wrong");
    // setssip[7] writes
    p_setssip_7_wr_cov: cover (rst_n && (access && PWRITE && hit[33]));
    p_setssip_7_wrp: assert (!rst_n || setssip_wr[7] == ((N_HART > 7) ? (access && PWRITE && hit[33]) : 1'b0))
      else $error("chilimix_aclint_regs: setssip[7] write pulse wrong");
  end

endmodule

bind chilimix_aclint_regs chilimix_aclint_regs_chk #(.N_HART(N_HART)) u_chk (.*);
