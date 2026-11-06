// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_socctl_regs_chk (simulation and formal; bound into every chilimix_socctl_regs)
//
// The socctl register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_socctl_regs_chk #(
  parameter int N_HART = 1  // harts with a reset and a boot address (1 .. 8)
) (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [7:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [31:0] id_value,
  input logic rst_cause_por,
  input logic rst_cause_por_set,
  input logic rst_cause_ext,
  input logic rst_cause_ext_set,
  input logic rst_cause_sw,
  input logic rst_cause_sw_set,
  input logic rst_cause_req,
  input logic rst_cause_req_set,
  input logic rst_cause_dbg,
  input logic rst_cause_dbg_set,
  input logic [31:0] sysrst_key,
  input logic sysrst_wr,
  input logic [7:0] rst_hold_dom,
  input logic rst_hold_wr,
  input logic rst_status_done,
  input logic [7:0] rst_status_dom,
  input logic [31:0] clkdiv_div,
  input logic [63:0] scratch_value,
  input logic [7:0] hart_hold_hart,
  input logic hart_hold_wr,
  input logic [7:0] hart_status_run,
  input logic [255:0] boot_lo_addr,
  input logic [255:0] boot_hi_addr
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [26:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[7:2] == 6'd0;  // id
  assign hit[1] = PADDR[7:2] == 6'd1;  // rst_cause
  assign hit[2] = PADDR[7:2] == 6'd2;  // sysrst
  assign hit[3] = PADDR[7:2] == 6'd3;  // rst_hold
  assign hit[4] = PADDR[7:2] == 6'd4;  // rst_status
  assign hit[5] = PADDR[7:2] == 6'd5;  // clkdiv[0]
  assign hit[6] = PADDR[7:2] == 6'd6;  // clkdiv[1]
  assign hit[7] = PADDR[7:2] == 6'd7;  // scratch[0]
  assign hit[8] = PADDR[7:2] == 6'd8;  // scratch[1]
  assign hit[9] = PADDR[7:2] == 6'd16;  // hart_hold
  assign hit[10] = PADDR[7:2] == 6'd17;  // hart_status
  assign hit[11] = PADDR[7:2] == 6'd32;  // boot_lo[0]
  assign hit[12] = PADDR[7:2] == 6'd33;  // boot_hi[0]
  assign hit[13] = PADDR[7:2] == 6'd34;  // boot_lo[1]
  assign hit[14] = PADDR[7:2] == 6'd35;  // boot_hi[1]
  assign hit[15] = PADDR[7:2] == 6'd36;  // boot_lo[2]
  assign hit[16] = PADDR[7:2] == 6'd37;  // boot_hi[2]
  assign hit[17] = PADDR[7:2] == 6'd38;  // boot_lo[3]
  assign hit[18] = PADDR[7:2] == 6'd39;  // boot_hi[3]
  assign hit[19] = PADDR[7:2] == 6'd40;  // boot_lo[4]
  assign hit[20] = PADDR[7:2] == 6'd41;  // boot_hi[4]
  assign hit[21] = PADDR[7:2] == 6'd42;  // boot_lo[5]
  assign hit[22] = PADDR[7:2] == 6'd43;  // boot_hi[5]
  assign hit[23] = PADDR[7:2] == 6'd44;  // boot_lo[6]
  assign hit[24] = PADDR[7:2] == 6'd45;  // boot_hi[6]
  assign hit[25] = PADDR[7:2] == 6'd46;  // boot_lo[7]
  assign hit[26] = PADDR[7:2] == 6'd47;  // boot_hi[7]
  assign err = !((1'b1 && {1'b0, PADDR[7:2]} < 7'd48));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11] || hit[12] || hit[13] || hit[14] || hit[15] || hit[16] || hit[17] || hit[18] || hit[19] || hit[20] || hit[21] || hit[22] || hit[23] || hit[24] || hit[25] || hit[26]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_socctl_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_socctl_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_socctl_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // id at 0x0
    p_id_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == id_value)
      else $error("chilimix_socctl_regs: id read %h", PRDATA);
    p_id_rd_cov: cover (access && !PWRITE && hit[0]);
    // rst_cause at 0x4
    p_rst_cause_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {27'b0, rst_cause_dbg, rst_cause_req, rst_cause_sw, rst_cause_ext, rst_cause_por})
      else $error("chilimix_socctl_regs: rst_cause read %h", PRDATA);
    p_rst_cause_rd_cov: cover (access && !PWRITE && hit[1]);
    // sysrst at 0x8
    p_sysrst_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == '0)
      else $error("chilimix_socctl_regs: sysrst read %h", PRDATA);
    p_sysrst_rd_cov: cover (access && !PWRITE && hit[2]);
    // rst_hold at 0xc
    p_rst_hold_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {24'b0, rst_hold_dom})
      else $error("chilimix_socctl_regs: rst_hold read %h", PRDATA);
    p_rst_hold_rd_cov: cover (access && !PWRITE && hit[3]);
    // rst_status at 0x10
    p_rst_status_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {16'b0, rst_status_dom, 7'b0, rst_status_done})
      else $error("chilimix_socctl_regs: rst_status read %h", PRDATA);
    p_rst_status_rd_cov: cover (access && !PWRITE && hit[4]);
    // clkdiv[0] at 0x14
    p_clkdiv_0_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {16'b0, clkdiv_div[15:0]})
      else $error("chilimix_socctl_regs: clkdiv[0] read %h", PRDATA);
    p_clkdiv_0_rd_cov: cover (access && !PWRITE && hit[5]);
    // clkdiv[1] at 0x18
    p_clkdiv_1_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == {16'b0, clkdiv_div[31:16]})
      else $error("chilimix_socctl_regs: clkdiv[1] read %h", PRDATA);
    p_clkdiv_1_rd_cov: cover (access && !PWRITE && hit[6]);
    // scratch[0] at 0x1c
    p_scratch_0_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == scratch_value[31:0])
      else $error("chilimix_socctl_regs: scratch[0] read %h", PRDATA);
    p_scratch_0_rd_cov: cover (access && !PWRITE && hit[7]);
    // scratch[1] at 0x20
    p_scratch_1_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == scratch_value[63:32])
      else $error("chilimix_socctl_regs: scratch[1] read %h", PRDATA);
    p_scratch_1_rd_cov: cover (access && !PWRITE && hit[8]);
    // hart_hold at 0x40
    p_hart_hold_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == {24'b0, hart_hold_hart})
      else $error("chilimix_socctl_regs: hart_hold read %h", PRDATA);
    p_hart_hold_rd_cov: cover (access && !PWRITE && hit[9]);
    // hart_status at 0x44
    p_hart_status_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == {24'b0, hart_status_run})
      else $error("chilimix_socctl_regs: hart_status read %h", PRDATA);
    p_hart_status_rd_cov: cover (access && !PWRITE && hit[10]);
    // boot_lo[0] at 0x80
    p_boot_lo_0_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == ((N_HART > 0) ? boot_lo_addr[31:0] : '0))
      else $error("chilimix_socctl_regs: boot_lo[0] read %h", PRDATA);
    p_boot_lo_0_rd_cov: cover (access && !PWRITE && hit[11]);
    // boot_hi[0] at 0x84
    p_boot_hi_0_rd: assert (!(access && !PWRITE && hit[12]) || PRDATA == ((N_HART > 0) ? boot_hi_addr[31:0] : '0))
      else $error("chilimix_socctl_regs: boot_hi[0] read %h", PRDATA);
    p_boot_hi_0_rd_cov: cover (access && !PWRITE && hit[12]);
    // boot_lo[1] at 0x88
    p_boot_lo_1_rd: assert (!(access && !PWRITE && hit[13]) || PRDATA == ((N_HART > 1) ? boot_lo_addr[63:32] : '0))
      else $error("chilimix_socctl_regs: boot_lo[1] read %h", PRDATA);
    p_boot_lo_1_rd_cov: cover (access && !PWRITE && hit[13]);
    // boot_hi[1] at 0x8c
    p_boot_hi_1_rd: assert (!(access && !PWRITE && hit[14]) || PRDATA == ((N_HART > 1) ? boot_hi_addr[63:32] : '0))
      else $error("chilimix_socctl_regs: boot_hi[1] read %h", PRDATA);
    p_boot_hi_1_rd_cov: cover (access && !PWRITE && hit[14]);
    // boot_lo[2] at 0x90
    p_boot_lo_2_rd: assert (!(access && !PWRITE && hit[15]) || PRDATA == ((N_HART > 2) ? boot_lo_addr[95:64] : '0))
      else $error("chilimix_socctl_regs: boot_lo[2] read %h", PRDATA);
    p_boot_lo_2_rd_cov: cover (access && !PWRITE && hit[15]);
    // boot_hi[2] at 0x94
    p_boot_hi_2_rd: assert (!(access && !PWRITE && hit[16]) || PRDATA == ((N_HART > 2) ? boot_hi_addr[95:64] : '0))
      else $error("chilimix_socctl_regs: boot_hi[2] read %h", PRDATA);
    p_boot_hi_2_rd_cov: cover (access && !PWRITE && hit[16]);
    // boot_lo[3] at 0x98
    p_boot_lo_3_rd: assert (!(access && !PWRITE && hit[17]) || PRDATA == ((N_HART > 3) ? boot_lo_addr[127:96] : '0))
      else $error("chilimix_socctl_regs: boot_lo[3] read %h", PRDATA);
    p_boot_lo_3_rd_cov: cover (access && !PWRITE && hit[17]);
    // boot_hi[3] at 0x9c
    p_boot_hi_3_rd: assert (!(access && !PWRITE && hit[18]) || PRDATA == ((N_HART > 3) ? boot_hi_addr[127:96] : '0))
      else $error("chilimix_socctl_regs: boot_hi[3] read %h", PRDATA);
    p_boot_hi_3_rd_cov: cover (access && !PWRITE && hit[18]);
    // boot_lo[4] at 0xa0
    p_boot_lo_4_rd: assert (!(access && !PWRITE && hit[19]) || PRDATA == ((N_HART > 4) ? boot_lo_addr[159:128] : '0))
      else $error("chilimix_socctl_regs: boot_lo[4] read %h", PRDATA);
    p_boot_lo_4_rd_cov: cover (access && !PWRITE && hit[19]);
    // boot_hi[4] at 0xa4
    p_boot_hi_4_rd: assert (!(access && !PWRITE && hit[20]) || PRDATA == ((N_HART > 4) ? boot_hi_addr[159:128] : '0))
      else $error("chilimix_socctl_regs: boot_hi[4] read %h", PRDATA);
    p_boot_hi_4_rd_cov: cover (access && !PWRITE && hit[20]);
    // boot_lo[5] at 0xa8
    p_boot_lo_5_rd: assert (!(access && !PWRITE && hit[21]) || PRDATA == ((N_HART > 5) ? boot_lo_addr[191:160] : '0))
      else $error("chilimix_socctl_regs: boot_lo[5] read %h", PRDATA);
    p_boot_lo_5_rd_cov: cover (access && !PWRITE && hit[21]);
    // boot_hi[5] at 0xac
    p_boot_hi_5_rd: assert (!(access && !PWRITE && hit[22]) || PRDATA == ((N_HART > 5) ? boot_hi_addr[191:160] : '0))
      else $error("chilimix_socctl_regs: boot_hi[5] read %h", PRDATA);
    p_boot_hi_5_rd_cov: cover (access && !PWRITE && hit[22]);
    // boot_lo[6] at 0xb0
    p_boot_lo_6_rd: assert (!(access && !PWRITE && hit[23]) || PRDATA == ((N_HART > 6) ? boot_lo_addr[223:192] : '0))
      else $error("chilimix_socctl_regs: boot_lo[6] read %h", PRDATA);
    p_boot_lo_6_rd_cov: cover (access && !PWRITE && hit[23]);
    // boot_hi[6] at 0xb4
    p_boot_hi_6_rd: assert (!(access && !PWRITE && hit[24]) || PRDATA == ((N_HART > 6) ? boot_hi_addr[223:192] : '0))
      else $error("chilimix_socctl_regs: boot_hi[6] read %h", PRDATA);
    p_boot_hi_6_rd_cov: cover (access && !PWRITE && hit[24]);
    // boot_lo[7] at 0xb8
    p_boot_lo_7_rd: assert (!(access && !PWRITE && hit[25]) || PRDATA == ((N_HART > 7) ? boot_lo_addr[255:224] : '0))
      else $error("chilimix_socctl_regs: boot_lo[7] read %h", PRDATA);
    p_boot_lo_7_rd_cov: cover (access && !PWRITE && hit[25]);
    // boot_hi[7] at 0xbc
    p_boot_hi_7_rd: assert (!(access && !PWRITE && hit[26]) || PRDATA == ((N_HART > 7) ? boot_hi_addr[255:224] : '0))
      else $error("chilimix_socctl_regs: boot_hi[7] read %h", PRDATA);
    p_boot_hi_7_rd_cov: cover (access && !PWRITE && hit[26]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // id writes
    p_id_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    // rst_cause writes
    p_rst_cause_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_rst_cause_por_rst: assert (!past_ok || $past(rst_n) || rst_cause_por == 1'h1)
      else $error("chilimix_socctl_regs: rst_cause.por reset value %h", rst_cause_por);
    p_rst_cause_por_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rst_cause_por == (($past(rst_cause_por) & ~($past((access && PWRITE && hit[1])) ? ($past(PWDATA[0:0]) & $past(bit_en[0:0])) : '0)) | $past(rst_cause_por_set)))
      else $error("chilimix_socctl_regs: rst_cause.por is %h after a clear / set", rst_cause_por);
    p_rst_cause_ext_rst: assert (!past_ok || $past(rst_n) || rst_cause_ext == 1'h0)
      else $error("chilimix_socctl_regs: rst_cause.ext reset value %h", rst_cause_ext);
    p_rst_cause_ext_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rst_cause_ext == (($past(rst_cause_ext) & ~($past((access && PWRITE && hit[1])) ? ($past(PWDATA[1:1]) & $past(bit_en[1:1])) : '0)) | $past(rst_cause_ext_set)))
      else $error("chilimix_socctl_regs: rst_cause.ext is %h after a clear / set", rst_cause_ext);
    p_rst_cause_sw_rst: assert (!past_ok || $past(rst_n) || rst_cause_sw == 1'h0)
      else $error("chilimix_socctl_regs: rst_cause.sw reset value %h", rst_cause_sw);
    p_rst_cause_sw_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rst_cause_sw == (($past(rst_cause_sw) & ~($past((access && PWRITE && hit[1])) ? ($past(PWDATA[2:2]) & $past(bit_en[2:2])) : '0)) | $past(rst_cause_sw_set)))
      else $error("chilimix_socctl_regs: rst_cause.sw is %h after a clear / set", rst_cause_sw);
    p_rst_cause_req_rst: assert (!past_ok || $past(rst_n) || rst_cause_req == 1'h0)
      else $error("chilimix_socctl_regs: rst_cause.req reset value %h", rst_cause_req);
    p_rst_cause_req_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rst_cause_req == (($past(rst_cause_req) & ~($past((access && PWRITE && hit[1])) ? ($past(PWDATA[3:3]) & $past(bit_en[3:3])) : '0)) | $past(rst_cause_req_set)))
      else $error("chilimix_socctl_regs: rst_cause.req is %h after a clear / set", rst_cause_req);
    p_rst_cause_dbg_rst: assert (!past_ok || $past(rst_n) || rst_cause_dbg == 1'h0)
      else $error("chilimix_socctl_regs: rst_cause.dbg reset value %h", rst_cause_dbg);
    p_rst_cause_dbg_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rst_cause_dbg == (($past(rst_cause_dbg) & ~($past((access && PWRITE && hit[1])) ? ($past(PWDATA[4:4]) & $past(bit_en[4:4])) : '0)) | $past(rst_cause_dbg_set)))
      else $error("chilimix_socctl_regs: rst_cause.dbg is %h after a clear / set", rst_cause_dbg);
    // sysrst writes
    p_sysrst_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_sysrst_wrp: assert (!rst_n || sysrst_wr == (access && PWRITE && hit[2]))
      else $error("chilimix_socctl_regs: sysrst write pulse wrong");
    // rst_hold writes
    p_rst_hold_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_rst_hold_wrp: assert (!rst_n || rst_hold_wr == (access && PWRITE && hit[3]))
      else $error("chilimix_socctl_regs: rst_hold write pulse wrong");
    p_rst_hold_dom_rst: assert (!past_ok || $past(rst_n) || rst_hold_dom == 8'h00)
      else $error("chilimix_socctl_regs: rst_hold.dom reset value %h", rst_hold_dom);
    p_rst_hold_dom_wr: assert (!rst_n || !past_ok || !$past(rst_n) || rst_hold_dom == ($past((access && PWRITE && hit[3])) ? (($past(rst_hold_dom) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(rst_hold_dom)))
      else $error("chilimix_socctl_regs: rst_hold.dom is %h after a write / hold", rst_hold_dom);
    // rst_status writes
    p_rst_status_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    // clkdiv[0] writes
    p_clkdiv_0_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_clkdiv_0_div_rst: assert (!past_ok || $past(rst_n) || clkdiv_div[15:0] == 16'h0002)
      else $error("chilimix_socctl_regs: clkdiv[0].div reset value %h", clkdiv_div[15:0]);
    p_clkdiv_0_div_wr: assert (!rst_n || !past_ok || !$past(rst_n) || clkdiv_div[15:0] == ($past((access && PWRITE && hit[5])) ? (($past(clkdiv_div[15:0]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(clkdiv_div[15:0])))
      else $error("chilimix_socctl_regs: clkdiv[0].div is %h after a write / hold", clkdiv_div[15:0]);
    // clkdiv[1] writes
    p_clkdiv_1_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_clkdiv_1_div_rst: assert (!past_ok || $past(rst_n) || clkdiv_div[31:16] == 16'h0002)
      else $error("chilimix_socctl_regs: clkdiv[1].div reset value %h", clkdiv_div[31:16]);
    p_clkdiv_1_div_wr: assert (!rst_n || !past_ok || !$past(rst_n) || clkdiv_div[31:16] == ($past((access && PWRITE && hit[6])) ? (($past(clkdiv_div[31:16]) & ~$past(bit_en[15:0])) | ($past(PWDATA[15:0]) & $past(bit_en[15:0]))) : $past(clkdiv_div[31:16])))
      else $error("chilimix_socctl_regs: clkdiv[1].div is %h after a write / hold", clkdiv_div[31:16]);
    // scratch[0] writes
    p_scratch_0_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_scratch_0_value_rst: assert (!past_ok || $past(rst_n) || scratch_value[31:0] == 32'h0000_0000)
      else $error("chilimix_socctl_regs: scratch[0].value reset value %h", scratch_value[31:0]);
    p_scratch_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || scratch_value[31:0] == ($past((access && PWRITE && hit[7])) ? (($past(scratch_value[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(scratch_value[31:0])))
      else $error("chilimix_socctl_regs: scratch[0].value is %h after a write / hold", scratch_value[31:0]);
    // scratch[1] writes
    p_scratch_1_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_scratch_1_value_rst: assert (!past_ok || $past(rst_n) || scratch_value[63:32] == 32'h0000_0000)
      else $error("chilimix_socctl_regs: scratch[1].value reset value %h", scratch_value[63:32]);
    p_scratch_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || scratch_value[63:32] == ($past((access && PWRITE && hit[8])) ? (($past(scratch_value[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(scratch_value[63:32])))
      else $error("chilimix_socctl_regs: scratch[1].value is %h after a write / hold", scratch_value[63:32]);
    // hart_hold writes
    p_hart_hold_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    p_hart_hold_wrp: assert (!rst_n || hart_hold_wr == (access && PWRITE && hit[9]))
      else $error("chilimix_socctl_regs: hart_hold write pulse wrong");
    p_hart_hold_hart_rst: assert (!past_ok || $past(rst_n) || hart_hold_hart == 8'h00)
      else $error("chilimix_socctl_regs: hart_hold.hart reset value %h", hart_hold_hart);
    p_hart_hold_hart_wr: assert (!rst_n || !past_ok || !$past(rst_n) || hart_hold_hart == ($past((access && PWRITE && hit[9])) ? (($past(hart_hold_hart) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(hart_hold_hart)))
      else $error("chilimix_socctl_regs: hart_hold.hart is %h after a write / hold", hart_hold_hart);
    // hart_status writes
    p_hart_status_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    // boot_lo[0] writes
    p_boot_lo_0_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_boot_lo_0_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[31:0] == ((N_HART > 0) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[0].addr reset value %h", boot_lo_addr[31:0]);
    p_boot_lo_0_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[31:0] == ((N_HART > 0) ? ($past((access && PWRITE && hit[11])) ? (($past(boot_lo_addr[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[31:0])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[0].addr is %h after a write / hold", boot_lo_addr[31:0]);
    // boot_hi[0] writes
    p_boot_hi_0_wr_cov: cover (rst_n && (access && PWRITE && hit[12]));
    p_boot_hi_0_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[31:0] == ((N_HART > 0) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[0].addr reset value %h", boot_hi_addr[31:0]);
    p_boot_hi_0_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[31:0] == ((N_HART > 0) ? ($past((access && PWRITE && hit[12])) ? (($past(boot_hi_addr[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[31:0])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[0].addr is %h after a write / hold", boot_hi_addr[31:0]);
    // boot_lo[1] writes
    p_boot_lo_1_wr_cov: cover (rst_n && (access && PWRITE && hit[13]));
    p_boot_lo_1_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[63:32] == ((N_HART > 1) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[1].addr reset value %h", boot_lo_addr[63:32]);
    p_boot_lo_1_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[63:32] == ((N_HART > 1) ? ($past((access && PWRITE && hit[13])) ? (($past(boot_lo_addr[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[63:32])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[1].addr is %h after a write / hold", boot_lo_addr[63:32]);
    // boot_hi[1] writes
    p_boot_hi_1_wr_cov: cover (rst_n && (access && PWRITE && hit[14]));
    p_boot_hi_1_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[63:32] == ((N_HART > 1) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[1].addr reset value %h", boot_hi_addr[63:32]);
    p_boot_hi_1_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[63:32] == ((N_HART > 1) ? ($past((access && PWRITE && hit[14])) ? (($past(boot_hi_addr[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[63:32])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[1].addr is %h after a write / hold", boot_hi_addr[63:32]);
    // boot_lo[2] writes
    p_boot_lo_2_wr_cov: cover (rst_n && (access && PWRITE && hit[15]));
    p_boot_lo_2_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[95:64] == ((N_HART > 2) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[2].addr reset value %h", boot_lo_addr[95:64]);
    p_boot_lo_2_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[95:64] == ((N_HART > 2) ? ($past((access && PWRITE && hit[15])) ? (($past(boot_lo_addr[95:64]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[95:64])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[2].addr is %h after a write / hold", boot_lo_addr[95:64]);
    // boot_hi[2] writes
    p_boot_hi_2_wr_cov: cover (rst_n && (access && PWRITE && hit[16]));
    p_boot_hi_2_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[95:64] == ((N_HART > 2) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[2].addr reset value %h", boot_hi_addr[95:64]);
    p_boot_hi_2_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[95:64] == ((N_HART > 2) ? ($past((access && PWRITE && hit[16])) ? (($past(boot_hi_addr[95:64]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[95:64])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[2].addr is %h after a write / hold", boot_hi_addr[95:64]);
    // boot_lo[3] writes
    p_boot_lo_3_wr_cov: cover (rst_n && (access && PWRITE && hit[17]));
    p_boot_lo_3_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[127:96] == ((N_HART > 3) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[3].addr reset value %h", boot_lo_addr[127:96]);
    p_boot_lo_3_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[127:96] == ((N_HART > 3) ? ($past((access && PWRITE && hit[17])) ? (($past(boot_lo_addr[127:96]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[127:96])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[3].addr is %h after a write / hold", boot_lo_addr[127:96]);
    // boot_hi[3] writes
    p_boot_hi_3_wr_cov: cover (rst_n && (access && PWRITE && hit[18]));
    p_boot_hi_3_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[127:96] == ((N_HART > 3) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[3].addr reset value %h", boot_hi_addr[127:96]);
    p_boot_hi_3_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[127:96] == ((N_HART > 3) ? ($past((access && PWRITE && hit[18])) ? (($past(boot_hi_addr[127:96]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[127:96])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[3].addr is %h after a write / hold", boot_hi_addr[127:96]);
    // boot_lo[4] writes
    p_boot_lo_4_wr_cov: cover (rst_n && (access && PWRITE && hit[19]));
    p_boot_lo_4_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[159:128] == ((N_HART > 4) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[4].addr reset value %h", boot_lo_addr[159:128]);
    p_boot_lo_4_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[159:128] == ((N_HART > 4) ? ($past((access && PWRITE && hit[19])) ? (($past(boot_lo_addr[159:128]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[159:128])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[4].addr is %h after a write / hold", boot_lo_addr[159:128]);
    // boot_hi[4] writes
    p_boot_hi_4_wr_cov: cover (rst_n && (access && PWRITE && hit[20]));
    p_boot_hi_4_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[159:128] == ((N_HART > 4) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[4].addr reset value %h", boot_hi_addr[159:128]);
    p_boot_hi_4_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[159:128] == ((N_HART > 4) ? ($past((access && PWRITE && hit[20])) ? (($past(boot_hi_addr[159:128]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[159:128])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[4].addr is %h after a write / hold", boot_hi_addr[159:128]);
    // boot_lo[5] writes
    p_boot_lo_5_wr_cov: cover (rst_n && (access && PWRITE && hit[21]));
    p_boot_lo_5_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[191:160] == ((N_HART > 5) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[5].addr reset value %h", boot_lo_addr[191:160]);
    p_boot_lo_5_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[191:160] == ((N_HART > 5) ? ($past((access && PWRITE && hit[21])) ? (($past(boot_lo_addr[191:160]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[191:160])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[5].addr is %h after a write / hold", boot_lo_addr[191:160]);
    // boot_hi[5] writes
    p_boot_hi_5_wr_cov: cover (rst_n && (access && PWRITE && hit[22]));
    p_boot_hi_5_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[191:160] == ((N_HART > 5) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[5].addr reset value %h", boot_hi_addr[191:160]);
    p_boot_hi_5_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[191:160] == ((N_HART > 5) ? ($past((access && PWRITE && hit[22])) ? (($past(boot_hi_addr[191:160]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[191:160])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[5].addr is %h after a write / hold", boot_hi_addr[191:160]);
    // boot_lo[6] writes
    p_boot_lo_6_wr_cov: cover (rst_n && (access && PWRITE && hit[23]));
    p_boot_lo_6_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[223:192] == ((N_HART > 6) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[6].addr reset value %h", boot_lo_addr[223:192]);
    p_boot_lo_6_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[223:192] == ((N_HART > 6) ? ($past((access && PWRITE && hit[23])) ? (($past(boot_lo_addr[223:192]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[223:192])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[6].addr is %h after a write / hold", boot_lo_addr[223:192]);
    // boot_hi[6] writes
    p_boot_hi_6_wr_cov: cover (rst_n && (access && PWRITE && hit[24]));
    p_boot_hi_6_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[223:192] == ((N_HART > 6) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[6].addr reset value %h", boot_hi_addr[223:192]);
    p_boot_hi_6_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[223:192] == ((N_HART > 6) ? ($past((access && PWRITE && hit[24])) ? (($past(boot_hi_addr[223:192]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[223:192])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[6].addr is %h after a write / hold", boot_hi_addr[223:192]);
    // boot_lo[7] writes
    p_boot_lo_7_wr_cov: cover (rst_n && (access && PWRITE && hit[25]));
    p_boot_lo_7_addr_rst: assert (!past_ok || $past(rst_n) || boot_lo_addr[255:224] == ((N_HART > 7) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_lo[7].addr reset value %h", boot_lo_addr[255:224]);
    p_boot_lo_7_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_lo_addr[255:224] == ((N_HART > 7) ? ($past((access && PWRITE && hit[25])) ? (($past(boot_lo_addr[255:224]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_lo_addr[255:224])) : '0))
      else $error("chilimix_socctl_regs: boot_lo[7].addr is %h after a write / hold", boot_lo_addr[255:224]);
    // boot_hi[7] writes
    p_boot_hi_7_wr_cov: cover (rst_n && (access && PWRITE && hit[26]));
    p_boot_hi_7_addr_rst: assert (!past_ok || $past(rst_n) || boot_hi_addr[255:224] == ((N_HART > 7) ? 32'h0000_0000 : '0))
      else $error("chilimix_socctl_regs: boot_hi[7].addr reset value %h", boot_hi_addr[255:224]);
    p_boot_hi_7_addr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || boot_hi_addr[255:224] == ((N_HART > 7) ? ($past((access && PWRITE && hit[26])) ? (($past(boot_hi_addr[255:224]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(boot_hi_addr[255:224])) : '0))
      else $error("chilimix_socctl_regs: boot_hi[7].addr is %h after a write / hold", boot_hi_addr[255:224]);
  end

endmodule

bind chilimix_socctl_regs chilimix_socctl_regs_chk #(.N_HART(N_HART)) u_chk (.*);
