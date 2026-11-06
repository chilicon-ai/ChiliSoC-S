// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_spi_regs_chk (simulation and formal; bound into every chilimix_spi_regs)
//
// The spi register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_spi_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [6:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [11:0] sckdiv_div,
  input logic sckmode_pha,
  input logic sckmode_pol,
  input logic [1:0] csid_csid,
  input logic csid_wr,
  input logic [3:0] csdef_csdef,
  input logic csdef_wr,
  input logic [1:0] csmode_mode,
  input logic csmode_wr,
  input logic [7:0] delay0_cssck,
  input logic [7:0] delay0_sckcs,
  input logic [7:0] delay1_intercs,
  input logic [7:0] delay1_interxfr,
  input logic [1:0] fmt_proto,
  input logic fmt_endian,
  input logic fmt_dir,
  input logic [3:0] fmt_len,
  input logic [7:0] txdata_data,
  input logic txdata_full,
  input logic txdata_wr,
  input logic [7:0] rxdata_data,
  input logic rxdata_empty,
  input logic rxdata_rd,
  input logic [2:0] txmark_txmark,
  input logic [2:0] rxmark_rxmark,
  input logic fctrl_en,
  input logic fctrl_wr,
  input logic ffmt_cmd_en,
  input logic [2:0] ffmt_addr_len,
  input logic [3:0] ffmt_pad_cnt,
  input logic [1:0] ffmt_cmd_proto,
  input logic [1:0] ffmt_addr_proto,
  input logic [1:0] ffmt_data_proto,
  input logic [7:0] ffmt_cmd_code,
  input logic [7:0] ffmt_pad_code,
  input logic ffmt_wr,
  input logic ie_txwm,
  input logic ie_rxwm,
  input logic ip_txwm,
  input logic ip_rxwm
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [15:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[6:2] == 5'd0;  // sckdiv
  assign hit[1] = PADDR[6:2] == 5'd1;  // sckmode
  assign hit[2] = PADDR[6:2] == 5'd4;  // csid
  assign hit[3] = PADDR[6:2] == 5'd5;  // csdef
  assign hit[4] = PADDR[6:2] == 5'd6;  // csmode
  assign hit[5] = PADDR[6:2] == 5'd10;  // delay0
  assign hit[6] = PADDR[6:2] == 5'd11;  // delay1
  assign hit[7] = PADDR[6:2] == 5'd16;  // fmt
  assign hit[8] = PADDR[6:2] == 5'd18;  // txdata
  assign hit[9] = PADDR[6:2] == 5'd19;  // rxdata
  assign hit[10] = PADDR[6:2] == 5'd20;  // txmark
  assign hit[11] = PADDR[6:2] == 5'd21;  // rxmark
  assign hit[12] = PADDR[6:2] == 5'd24;  // fctrl
  assign hit[13] = PADDR[6:2] == 5'd25;  // ffmt
  assign hit[14] = PADDR[6:2] == 5'd28;  // ie
  assign hit[15] = PADDR[6:2] == 5'd29;  // ip
  assign err = !((1'b1 && {1'b0, PADDR[6:2]} < 6'd30));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11] || hit[12] || hit[13] || hit[14] || hit[15]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_spi_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_spi_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_spi_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // sckdiv at 0x0
    p_sckdiv_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {20'b0, sckdiv_div})
      else $error("chilimix_spi_regs: sckdiv read %h", PRDATA);
    p_sckdiv_rd_cov: cover (access && !PWRITE && hit[0]);
    // sckmode at 0x4
    p_sckmode_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {30'b0, sckmode_pol, sckmode_pha})
      else $error("chilimix_spi_regs: sckmode read %h", PRDATA);
    p_sckmode_rd_cov: cover (access && !PWRITE && hit[1]);
    // csid at 0x10
    p_csid_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {30'b0, csid_csid})
      else $error("chilimix_spi_regs: csid read %h", PRDATA);
    p_csid_rd_cov: cover (access && !PWRITE && hit[2]);
    // csdef at 0x14
    p_csdef_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {28'b0, csdef_csdef})
      else $error("chilimix_spi_regs: csdef read %h", PRDATA);
    p_csdef_rd_cov: cover (access && !PWRITE && hit[3]);
    // csmode at 0x18
    p_csmode_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {30'b0, csmode_mode})
      else $error("chilimix_spi_regs: csmode read %h", PRDATA);
    p_csmode_rd_cov: cover (access && !PWRITE && hit[4]);
    // delay0 at 0x28
    p_delay0_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {8'b0, delay0_sckcs, 8'b0, delay0_cssck})
      else $error("chilimix_spi_regs: delay0 read %h", PRDATA);
    p_delay0_rd_cov: cover (access && !PWRITE && hit[5]);
    // delay1 at 0x2c
    p_delay1_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == {8'b0, delay1_interxfr, 8'b0, delay1_intercs})
      else $error("chilimix_spi_regs: delay1 read %h", PRDATA);
    p_delay1_rd_cov: cover (access && !PWRITE && hit[6]);
    // fmt at 0x40
    p_fmt_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == {12'b0, fmt_len, 12'b0, fmt_dir, fmt_endian, fmt_proto})
      else $error("chilimix_spi_regs: fmt read %h", PRDATA);
    p_fmt_rd_cov: cover (access && !PWRITE && hit[7]);
    // txdata at 0x48
    p_txdata_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == {txdata_full, 31'b0})
      else $error("chilimix_spi_regs: txdata read %h", PRDATA);
    p_txdata_rd_cov: cover (access && !PWRITE && hit[8]);
    // rxdata at 0x4c
    p_rxdata_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == {rxdata_empty, 23'b0, rxdata_data})
      else $error("chilimix_spi_regs: rxdata read %h", PRDATA);
    p_rxdata_rd_cov: cover (access && !PWRITE && hit[9]);
    p_rxdata_rdp: assert (rxdata_rd == (access && !PWRITE && hit[9]))
      else $error("chilimix_spi_regs: rxdata read pulse wrong");
    // txmark at 0x50
    p_txmark_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == {29'b0, txmark_txmark})
      else $error("chilimix_spi_regs: txmark read %h", PRDATA);
    p_txmark_rd_cov: cover (access && !PWRITE && hit[10]);
    // rxmark at 0x54
    p_rxmark_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == {29'b0, rxmark_rxmark})
      else $error("chilimix_spi_regs: rxmark read %h", PRDATA);
    p_rxmark_rd_cov: cover (access && !PWRITE && hit[11]);
    // fctrl at 0x60
    p_fctrl_rd: assert (!(access && !PWRITE && hit[12]) || PRDATA == {31'b0, fctrl_en})
      else $error("chilimix_spi_regs: fctrl read %h", PRDATA);
    p_fctrl_rd_cov: cover (access && !PWRITE && hit[12]);
    // ffmt at 0x64
    p_ffmt_rd: assert (!(access && !PWRITE && hit[13]) || PRDATA == {ffmt_pad_code, ffmt_cmd_code, 2'b0, ffmt_data_proto, ffmt_addr_proto, ffmt_cmd_proto, ffmt_pad_cnt, ffmt_addr_len, ffmt_cmd_en})
      else $error("chilimix_spi_regs: ffmt read %h", PRDATA);
    p_ffmt_rd_cov: cover (access && !PWRITE && hit[13]);
    // ie at 0x70
    p_ie_rd: assert (!(access && !PWRITE && hit[14]) || PRDATA == {30'b0, ie_rxwm, ie_txwm})
      else $error("chilimix_spi_regs: ie read %h", PRDATA);
    p_ie_rd_cov: cover (access && !PWRITE && hit[14]);
    // ip at 0x74
    p_ip_rd: assert (!(access && !PWRITE && hit[15]) || PRDATA == {30'b0, ip_rxwm, ip_txwm})
      else $error("chilimix_spi_regs: ip read %h", PRDATA);
    p_ip_rd_cov: cover (access && !PWRITE && hit[15]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // sckdiv writes
    p_sckdiv_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_sckdiv_div_rst: assert (!past_ok || $past(rst_n) || sckdiv_div == 12'h003)
      else $error("chilimix_spi_regs: sckdiv.div reset value %h", sckdiv_div);
    p_sckdiv_div_wr: assert (!rst_n || !past_ok || !$past(rst_n) || sckdiv_div == ($past((access && PWRITE && hit[0])) ? (($past(sckdiv_div) & ~$past(bit_en[11:0])) | ($past(PWDATA[11:0]) & $past(bit_en[11:0]))) : $past(sckdiv_div)))
      else $error("chilimix_spi_regs: sckdiv.div is %h after a write / hold", sckdiv_div);
    // sckmode writes
    p_sckmode_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_sckmode_pha_rst: assert (!past_ok || $past(rst_n) || sckmode_pha == 1'h0)
      else $error("chilimix_spi_regs: sckmode.pha reset value %h", sckmode_pha);
    p_sckmode_pha_wr: assert (!rst_n || !past_ok || !$past(rst_n) || sckmode_pha == ($past((access && PWRITE && hit[1])) ? (($past(sckmode_pha) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(sckmode_pha)))
      else $error("chilimix_spi_regs: sckmode.pha is %h after a write / hold", sckmode_pha);
    p_sckmode_pol_rst: assert (!past_ok || $past(rst_n) || sckmode_pol == 1'h0)
      else $error("chilimix_spi_regs: sckmode.pol reset value %h", sckmode_pol);
    p_sckmode_pol_wr: assert (!rst_n || !past_ok || !$past(rst_n) || sckmode_pol == ($past((access && PWRITE && hit[1])) ? (($past(sckmode_pol) & ~$past(bit_en[1:1])) | ($past(PWDATA[1:1]) & $past(bit_en[1:1]))) : $past(sckmode_pol)))
      else $error("chilimix_spi_regs: sckmode.pol is %h after a write / hold", sckmode_pol);
    // csid writes
    p_csid_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_csid_wrp: assert (!rst_n || csid_wr == (access && PWRITE && hit[2]))
      else $error("chilimix_spi_regs: csid write pulse wrong");
    p_csid_csid_rst: assert (!past_ok || $past(rst_n) || csid_csid == 2'h0)
      else $error("chilimix_spi_regs: csid.csid reset value %h", csid_csid);
    p_csid_csid_wr: assert (!rst_n || !past_ok || !$past(rst_n) || csid_csid == ($past((access && PWRITE && hit[2])) ? (($past(csid_csid) & ~$past(bit_en[1:0])) | ($past(PWDATA[1:0]) & $past(bit_en[1:0]))) : $past(csid_csid)))
      else $error("chilimix_spi_regs: csid.csid is %h after a write / hold", csid_csid);
    // csdef writes
    p_csdef_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_csdef_wrp: assert (!rst_n || csdef_wr == (access && PWRITE && hit[3]))
      else $error("chilimix_spi_regs: csdef write pulse wrong");
    p_csdef_csdef_rst: assert (!past_ok || $past(rst_n) || csdef_csdef == 4'hf)
      else $error("chilimix_spi_regs: csdef.csdef reset value %h", csdef_csdef);
    p_csdef_csdef_wr: assert (!rst_n || !past_ok || !$past(rst_n) || csdef_csdef == ($past((access && PWRITE && hit[3])) ? (($past(csdef_csdef) & ~$past(bit_en[3:0])) | ($past(PWDATA[3:0]) & $past(bit_en[3:0]))) : $past(csdef_csdef)))
      else $error("chilimix_spi_regs: csdef.csdef is %h after a write / hold", csdef_csdef);
    // csmode writes
    p_csmode_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_csmode_wrp: assert (!rst_n || csmode_wr == (access && PWRITE && hit[4]))
      else $error("chilimix_spi_regs: csmode write pulse wrong");
    p_csmode_mode_rst: assert (!past_ok || $past(rst_n) || csmode_mode == 2'h0)
      else $error("chilimix_spi_regs: csmode.mode reset value %h", csmode_mode);
    p_csmode_mode_wr: assert (!rst_n || !past_ok || !$past(rst_n) || csmode_mode == ($past((access && PWRITE && hit[4])) ? (($past(csmode_mode) & ~$past(bit_en[1:0])) | ($past(PWDATA[1:0]) & $past(bit_en[1:0]))) : $past(csmode_mode)))
      else $error("chilimix_spi_regs: csmode.mode is %h after a write / hold", csmode_mode);
    // delay0 writes
    p_delay0_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_delay0_cssck_rst: assert (!past_ok || $past(rst_n) || delay0_cssck == 8'h01)
      else $error("chilimix_spi_regs: delay0.cssck reset value %h", delay0_cssck);
    p_delay0_cssck_wr: assert (!rst_n || !past_ok || !$past(rst_n) || delay0_cssck == ($past((access && PWRITE && hit[5])) ? (($past(delay0_cssck) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(delay0_cssck)))
      else $error("chilimix_spi_regs: delay0.cssck is %h after a write / hold", delay0_cssck);
    p_delay0_sckcs_rst: assert (!past_ok || $past(rst_n) || delay0_sckcs == 8'h01)
      else $error("chilimix_spi_regs: delay0.sckcs reset value %h", delay0_sckcs);
    p_delay0_sckcs_wr: assert (!rst_n || !past_ok || !$past(rst_n) || delay0_sckcs == ($past((access && PWRITE && hit[5])) ? (($past(delay0_sckcs) & ~$past(bit_en[23:16])) | ($past(PWDATA[23:16]) & $past(bit_en[23:16]))) : $past(delay0_sckcs)))
      else $error("chilimix_spi_regs: delay0.sckcs is %h after a write / hold", delay0_sckcs);
    // delay1 writes
    p_delay1_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_delay1_intercs_rst: assert (!past_ok || $past(rst_n) || delay1_intercs == 8'h01)
      else $error("chilimix_spi_regs: delay1.intercs reset value %h", delay1_intercs);
    p_delay1_intercs_wr: assert (!rst_n || !past_ok || !$past(rst_n) || delay1_intercs == ($past((access && PWRITE && hit[6])) ? (($past(delay1_intercs) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(delay1_intercs)))
      else $error("chilimix_spi_regs: delay1.intercs is %h after a write / hold", delay1_intercs);
    p_delay1_interxfr_rst: assert (!past_ok || $past(rst_n) || delay1_interxfr == 8'h00)
      else $error("chilimix_spi_regs: delay1.interxfr reset value %h", delay1_interxfr);
    p_delay1_interxfr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || delay1_interxfr == ($past((access && PWRITE && hit[6])) ? (($past(delay1_interxfr) & ~$past(bit_en[23:16])) | ($past(PWDATA[23:16]) & $past(bit_en[23:16]))) : $past(delay1_interxfr)))
      else $error("chilimix_spi_regs: delay1.interxfr is %h after a write / hold", delay1_interxfr);
    // fmt writes
    p_fmt_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_fmt_proto_rst: assert (!past_ok || $past(rst_n) || fmt_proto == 2'h0)
      else $error("chilimix_spi_regs: fmt.proto reset value %h", fmt_proto);
    p_fmt_proto_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fmt_proto == ($past((access && PWRITE && hit[7])) ? (($past(fmt_proto) & ~$past(bit_en[1:0])) | ($past(PWDATA[1:0]) & $past(bit_en[1:0]))) : $past(fmt_proto)))
      else $error("chilimix_spi_regs: fmt.proto is %h after a write / hold", fmt_proto);
    p_fmt_endian_rst: assert (!past_ok || $past(rst_n) || fmt_endian == 1'h0)
      else $error("chilimix_spi_regs: fmt.endian reset value %h", fmt_endian);
    p_fmt_endian_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fmt_endian == ($past((access && PWRITE && hit[7])) ? (($past(fmt_endian) & ~$past(bit_en[2:2])) | ($past(PWDATA[2:2]) & $past(bit_en[2:2]))) : $past(fmt_endian)))
      else $error("chilimix_spi_regs: fmt.endian is %h after a write / hold", fmt_endian);
    p_fmt_dir_rst: assert (!past_ok || $past(rst_n) || fmt_dir == 1'h0)
      else $error("chilimix_spi_regs: fmt.dir reset value %h", fmt_dir);
    p_fmt_dir_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fmt_dir == ($past((access && PWRITE && hit[7])) ? (($past(fmt_dir) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(fmt_dir)))
      else $error("chilimix_spi_regs: fmt.dir is %h after a write / hold", fmt_dir);
    p_fmt_len_rst: assert (!past_ok || $past(rst_n) || fmt_len == 4'h8)
      else $error("chilimix_spi_regs: fmt.len reset value %h", fmt_len);
    p_fmt_len_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fmt_len == ($past((access && PWRITE && hit[7])) ? (($past(fmt_len) & ~$past(bit_en[19:16])) | ($past(PWDATA[19:16]) & $past(bit_en[19:16]))) : $past(fmt_len)))
      else $error("chilimix_spi_regs: fmt.len is %h after a write / hold", fmt_len);
    // txdata writes
    p_txdata_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_txdata_wrp: assert (!rst_n || txdata_wr == (access && PWRITE && hit[8]))
      else $error("chilimix_spi_regs: txdata write pulse wrong");
    // rxdata writes
    p_rxdata_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    // txmark writes
    p_txmark_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    p_txmark_txmark_rst: assert (!past_ok || $past(rst_n) || txmark_txmark == 3'h1)
      else $error("chilimix_spi_regs: txmark.txmark reset value %h", txmark_txmark);
    p_txmark_txmark_wr: assert (!rst_n || !past_ok || !$past(rst_n) || txmark_txmark == ($past((access && PWRITE && hit[10])) ? (($past(txmark_txmark) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(txmark_txmark)))
      else $error("chilimix_spi_regs: txmark.txmark is %h after a write / hold", txmark_txmark);
    // rxmark writes
    p_rxmark_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_rxmark_rxmark_rst: assert (!past_ok || $past(rst_n) || rxmark_rxmark == 3'h0)
      else $error("chilimix_spi_regs: rxmark.rxmark reset value %h", rxmark_rxmark);
    p_rxmark_rxmark_wr: assert (!rst_n || !past_ok || !$past(rst_n) || rxmark_rxmark == ($past((access && PWRITE && hit[11])) ? (($past(rxmark_rxmark) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(rxmark_rxmark)))
      else $error("chilimix_spi_regs: rxmark.rxmark is %h after a write / hold", rxmark_rxmark);
    // fctrl writes
    p_fctrl_wr_cov: cover (rst_n && (access && PWRITE && hit[12]));
    p_fctrl_wrp: assert (!rst_n || fctrl_wr == (access && PWRITE && hit[12]))
      else $error("chilimix_spi_regs: fctrl write pulse wrong");
    p_fctrl_en_rst: assert (!past_ok || $past(rst_n) || fctrl_en == 1'h1)
      else $error("chilimix_spi_regs: fctrl.en reset value %h", fctrl_en);
    p_fctrl_en_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fctrl_en == ($past((access && PWRITE && hit[12])) ? (($past(fctrl_en) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(fctrl_en)))
      else $error("chilimix_spi_regs: fctrl.en is %h after a write / hold", fctrl_en);
    // ffmt writes
    p_ffmt_wr_cov: cover (rst_n && (access && PWRITE && hit[13]));
    p_ffmt_wrp: assert (!rst_n || ffmt_wr == (access && PWRITE && hit[13]))
      else $error("chilimix_spi_regs: ffmt write pulse wrong");
    p_ffmt_cmd_en_rst: assert (!past_ok || $past(rst_n) || ffmt_cmd_en == 1'h1)
      else $error("chilimix_spi_regs: ffmt.cmd_en reset value %h", ffmt_cmd_en);
    p_ffmt_cmd_en_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_cmd_en == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_cmd_en) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(ffmt_cmd_en)))
      else $error("chilimix_spi_regs: ffmt.cmd_en is %h after a write / hold", ffmt_cmd_en);
    p_ffmt_addr_len_rst: assert (!past_ok || $past(rst_n) || ffmt_addr_len == 3'h3)
      else $error("chilimix_spi_regs: ffmt.addr_len reset value %h", ffmt_addr_len);
    p_ffmt_addr_len_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_addr_len == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_addr_len) & ~$past(bit_en[3:1])) | ($past(PWDATA[3:1]) & $past(bit_en[3:1]))) : $past(ffmt_addr_len)))
      else $error("chilimix_spi_regs: ffmt.addr_len is %h after a write / hold", ffmt_addr_len);
    p_ffmt_pad_cnt_rst: assert (!past_ok || $past(rst_n) || ffmt_pad_cnt == 4'h0)
      else $error("chilimix_spi_regs: ffmt.pad_cnt reset value %h", ffmt_pad_cnt);
    p_ffmt_pad_cnt_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_pad_cnt == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_pad_cnt) & ~$past(bit_en[7:4])) | ($past(PWDATA[7:4]) & $past(bit_en[7:4]))) : $past(ffmt_pad_cnt)))
      else $error("chilimix_spi_regs: ffmt.pad_cnt is %h after a write / hold", ffmt_pad_cnt);
    p_ffmt_cmd_proto_rst: assert (!past_ok || $past(rst_n) || ffmt_cmd_proto == 2'h0)
      else $error("chilimix_spi_regs: ffmt.cmd_proto reset value %h", ffmt_cmd_proto);
    p_ffmt_cmd_proto_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_cmd_proto == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_cmd_proto) & ~$past(bit_en[9:8])) | ($past(PWDATA[9:8]) & $past(bit_en[9:8]))) : $past(ffmt_cmd_proto)))
      else $error("chilimix_spi_regs: ffmt.cmd_proto is %h after a write / hold", ffmt_cmd_proto);
    p_ffmt_addr_proto_rst: assert (!past_ok || $past(rst_n) || ffmt_addr_proto == 2'h0)
      else $error("chilimix_spi_regs: ffmt.addr_proto reset value %h", ffmt_addr_proto);
    p_ffmt_addr_proto_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_addr_proto == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_addr_proto) & ~$past(bit_en[11:10])) | ($past(PWDATA[11:10]) & $past(bit_en[11:10]))) : $past(ffmt_addr_proto)))
      else $error("chilimix_spi_regs: ffmt.addr_proto is %h after a write / hold", ffmt_addr_proto);
    p_ffmt_data_proto_rst: assert (!past_ok || $past(rst_n) || ffmt_data_proto == 2'h0)
      else $error("chilimix_spi_regs: ffmt.data_proto reset value %h", ffmt_data_proto);
    p_ffmt_data_proto_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_data_proto == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_data_proto) & ~$past(bit_en[13:12])) | ($past(PWDATA[13:12]) & $past(bit_en[13:12]))) : $past(ffmt_data_proto)))
      else $error("chilimix_spi_regs: ffmt.data_proto is %h after a write / hold", ffmt_data_proto);
    p_ffmt_cmd_code_rst: assert (!past_ok || $past(rst_n) || ffmt_cmd_code == 8'h03)
      else $error("chilimix_spi_regs: ffmt.cmd_code reset value %h", ffmt_cmd_code);
    p_ffmt_cmd_code_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_cmd_code == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_cmd_code) & ~$past(bit_en[23:16])) | ($past(PWDATA[23:16]) & $past(bit_en[23:16]))) : $past(ffmt_cmd_code)))
      else $error("chilimix_spi_regs: ffmt.cmd_code is %h after a write / hold", ffmt_cmd_code);
    p_ffmt_pad_code_rst: assert (!past_ok || $past(rst_n) || ffmt_pad_code == 8'h00)
      else $error("chilimix_spi_regs: ffmt.pad_code reset value %h", ffmt_pad_code);
    p_ffmt_pad_code_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ffmt_pad_code == ($past((access && PWRITE && hit[13])) ? (($past(ffmt_pad_code) & ~$past(bit_en[31:24])) | ($past(PWDATA[31:24]) & $past(bit_en[31:24]))) : $past(ffmt_pad_code)))
      else $error("chilimix_spi_regs: ffmt.pad_code is %h after a write / hold", ffmt_pad_code);
    // ie writes
    p_ie_wr_cov: cover (rst_n && (access && PWRITE && hit[14]));
    p_ie_txwm_rst: assert (!past_ok || $past(rst_n) || ie_txwm == 1'h0)
      else $error("chilimix_spi_regs: ie.txwm reset value %h", ie_txwm);
    p_ie_txwm_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ie_txwm == ($past((access && PWRITE && hit[14])) ? (($past(ie_txwm) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(ie_txwm)))
      else $error("chilimix_spi_regs: ie.txwm is %h after a write / hold", ie_txwm);
    p_ie_rxwm_rst: assert (!past_ok || $past(rst_n) || ie_rxwm == 1'h0)
      else $error("chilimix_spi_regs: ie.rxwm reset value %h", ie_rxwm);
    p_ie_rxwm_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ie_rxwm == ($past((access && PWRITE && hit[14])) ? (($past(ie_rxwm) & ~$past(bit_en[1:1])) | ($past(PWDATA[1:1]) & $past(bit_en[1:1]))) : $past(ie_rxwm)))
      else $error("chilimix_spi_regs: ie.rxwm is %h after a write / hold", ie_rxwm);
    // ip writes
    p_ip_wr_cov: cover (rst_n && (access && PWRITE && hit[15]));
  end

endmodule

bind chilimix_spi_regs chilimix_spi_regs_chk u_chk (.*);
