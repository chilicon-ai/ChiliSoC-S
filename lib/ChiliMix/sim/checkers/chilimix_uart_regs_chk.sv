// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_uart_regs_chk (simulation and formal; bound into every chilimix_uart_regs)
//
// The uart register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_uart_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [4:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [7:0] rbr_data,
  input logic rbr_rd,
  input logic [7:0] thr_data,
  input logic thr_wr,
  input logic [7:0] dll_value,
  input logic ier_erbfi,
  input logic ier_etbei,
  input logic ier_elsi,
  input logic ier_edssi,
  input logic ier_wr,
  input logic [7:0] dlm_value,
  input logic [3:0] iir_id,
  input logic [1:0] iir_fifos,
  input logic iir_rd,
  input logic fcr_enable,
  input logic fcr_rx_reset,
  input logic fcr_tx_reset,
  input logic fcr_dma_mode,
  input logic [1:0] fcr_rx_trigger,
  input logic fcr_wr,
  input logic [1:0] lcr_wls,
  input logic lcr_stb,
  input logic lcr_pen,
  input logic lcr_eps,
  input logic lcr_stick,
  input logic lcr_brk,
  input logic lcr_dlab,
  input logic mcr_dtr,
  input logic mcr_rts,
  input logic mcr_out1,
  input logic mcr_out2,
  input logic mcr_loop,
  input logic lsr_dr,
  input logic lsr_oe,
  input logic lsr_pe,
  input logic lsr_fe,
  input logic lsr_bi,
  input logic lsr_thre,
  input logic lsr_temt,
  input logic lsr_rxfe,
  input logic lsr_rd,
  input logic msr_dcts,
  input logic msr_ddsr,
  input logic msr_teri,
  input logic msr_ddcd,
  input logic msr_cts,
  input logic msr_dsr,
  input logic msr_ri,
  input logic msr_dcd,
  input logic msr_rd,
  input logic [7:0] scr_value
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [11:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[4:2] == 3'd0 && (!PWRITE && lcr_dlab == 1'd0);  // rbr
  assign hit[1] = PADDR[4:2] == 3'd0 && (PWRITE && lcr_dlab == 1'd0);  // thr
  assign hit[2] = PADDR[4:2] == 3'd0 && (lcr_dlab == 1'd1);  // dll
  assign hit[3] = PADDR[4:2] == 3'd1 && (lcr_dlab == 1'd0);  // ier
  assign hit[4] = PADDR[4:2] == 3'd1 && (lcr_dlab == 1'd1);  // dlm
  assign hit[5] = PADDR[4:2] == 3'd2 && (!PWRITE);  // iir
  assign hit[6] = PADDR[4:2] == 3'd2 && (PWRITE);  // fcr
  assign hit[7] = PADDR[4:2] == 3'd3;  // lcr
  assign hit[8] = PADDR[4:2] == 3'd4;  // mcr
  assign hit[9] = PADDR[4:2] == 3'd5;  // lsr
  assign hit[10] = PADDR[4:2] == 3'd6;  // msr
  assign hit[11] = PADDR[4:2] == 3'd7;  // scr
  assign err = !((1'b1 && {1'b0, PADDR[4:2]} < 4'd8));
  assign any_rd = !PWRITE && (hit[0] || hit[2] || hit[3] || hit[4] || hit[5] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_uart_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_uart_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_uart_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // rbr at 0x0
    p_rbr_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {24'b0, rbr_data})
      else $error("chilimix_uart_regs: rbr read %h", PRDATA);
    p_rbr_rd_cov: cover (access && !PWRITE && hit[0]);
    p_rbr_rdp: assert (rbr_rd == (access && !PWRITE && hit[0]))
      else $error("chilimix_uart_regs: rbr read pulse wrong");
    // dll at 0x0
    p_dll_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {24'b0, dll_value})
      else $error("chilimix_uart_regs: dll read %h", PRDATA);
    p_dll_rd_cov: cover (access && !PWRITE && hit[2]);
    // ier at 0x4
    p_ier_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {28'b0, ier_edssi, ier_elsi, ier_etbei, ier_erbfi})
      else $error("chilimix_uart_regs: ier read %h", PRDATA);
    p_ier_rd_cov: cover (access && !PWRITE && hit[3]);
    // dlm at 0x4
    p_dlm_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {24'b0, dlm_value})
      else $error("chilimix_uart_regs: dlm read %h", PRDATA);
    p_dlm_rd_cov: cover (access && !PWRITE && hit[4]);
    // iir at 0x8
    p_iir_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {24'b0, iir_fifos, 2'b0, iir_id})
      else $error("chilimix_uart_regs: iir read %h", PRDATA);
    p_iir_rd_cov: cover (access && !PWRITE && hit[5]);
    p_iir_rdp: assert (iir_rd == (access && !PWRITE && hit[5]))
      else $error("chilimix_uart_regs: iir read pulse wrong");
    // lcr at 0xc
    p_lcr_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == {24'b0, lcr_dlab, lcr_brk, lcr_stick, lcr_eps, lcr_pen, lcr_stb, lcr_wls})
      else $error("chilimix_uart_regs: lcr read %h", PRDATA);
    p_lcr_rd_cov: cover (access && !PWRITE && hit[7]);
    // mcr at 0x10
    p_mcr_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == {27'b0, mcr_loop, mcr_out2, mcr_out1, mcr_rts, mcr_dtr})
      else $error("chilimix_uart_regs: mcr read %h", PRDATA);
    p_mcr_rd_cov: cover (access && !PWRITE && hit[8]);
    // lsr at 0x14
    p_lsr_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == {24'b0, lsr_rxfe, lsr_temt, lsr_thre, lsr_bi, lsr_fe, lsr_pe, lsr_oe, lsr_dr})
      else $error("chilimix_uart_regs: lsr read %h", PRDATA);
    p_lsr_rd_cov: cover (access && !PWRITE && hit[9]);
    p_lsr_rdp: assert (lsr_rd == (access && !PWRITE && hit[9]))
      else $error("chilimix_uart_regs: lsr read pulse wrong");
    // msr at 0x18
    p_msr_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == {24'b0, msr_dcd, msr_ri, msr_dsr, msr_cts, msr_ddcd, msr_teri, msr_ddsr, msr_dcts})
      else $error("chilimix_uart_regs: msr read %h", PRDATA);
    p_msr_rd_cov: cover (access && !PWRITE && hit[10]);
    p_msr_rdp: assert (msr_rd == (access && !PWRITE && hit[10]))
      else $error("chilimix_uart_regs: msr read pulse wrong");
    // scr at 0x1c
    p_scr_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == {24'b0, scr_value})
      else $error("chilimix_uart_regs: scr read %h", PRDATA);
    p_scr_rd_cov: cover (access && !PWRITE && hit[11]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // thr writes
    p_thr_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_thr_wrp: assert (!rst_n || thr_wr == (access && PWRITE && hit[1]))
      else $error("chilimix_uart_regs: thr write pulse wrong");
    // dll writes
    p_dll_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_dll_value_rst: assert (!past_ok || $past(rst_n) || dll_value == 8'h00)
      else $error("chilimix_uart_regs: dll.value reset value %h", dll_value);
    p_dll_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || dll_value == ($past((access && PWRITE && hit[2])) ? (($past(dll_value) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(dll_value)))
      else $error("chilimix_uart_regs: dll.value is %h after a write / hold", dll_value);
    // ier writes
    p_ier_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_ier_wrp: assert (!rst_n || ier_wr == (access && PWRITE && hit[3]))
      else $error("chilimix_uart_regs: ier write pulse wrong");
    p_ier_erbfi_rst: assert (!past_ok || $past(rst_n) || ier_erbfi == 1'h0)
      else $error("chilimix_uart_regs: ier.erbfi reset value %h", ier_erbfi);
    p_ier_erbfi_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ier_erbfi == ($past((access && PWRITE && hit[3])) ? (($past(ier_erbfi) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(ier_erbfi)))
      else $error("chilimix_uart_regs: ier.erbfi is %h after a write / hold", ier_erbfi);
    p_ier_etbei_rst: assert (!past_ok || $past(rst_n) || ier_etbei == 1'h0)
      else $error("chilimix_uart_regs: ier.etbei reset value %h", ier_etbei);
    p_ier_etbei_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ier_etbei == ($past((access && PWRITE && hit[3])) ? (($past(ier_etbei) & ~$past(bit_en[1:1])) | ($past(PWDATA[1:1]) & $past(bit_en[1:1]))) : $past(ier_etbei)))
      else $error("chilimix_uart_regs: ier.etbei is %h after a write / hold", ier_etbei);
    p_ier_elsi_rst: assert (!past_ok || $past(rst_n) || ier_elsi == 1'h0)
      else $error("chilimix_uart_regs: ier.elsi reset value %h", ier_elsi);
    p_ier_elsi_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ier_elsi == ($past((access && PWRITE && hit[3])) ? (($past(ier_elsi) & ~$past(bit_en[2:2])) | ($past(PWDATA[2:2]) & $past(bit_en[2:2]))) : $past(ier_elsi)))
      else $error("chilimix_uart_regs: ier.elsi is %h after a write / hold", ier_elsi);
    p_ier_edssi_rst: assert (!past_ok || $past(rst_n) || ier_edssi == 1'h0)
      else $error("chilimix_uart_regs: ier.edssi reset value %h", ier_edssi);
    p_ier_edssi_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ier_edssi == ($past((access && PWRITE && hit[3])) ? (($past(ier_edssi) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(ier_edssi)))
      else $error("chilimix_uart_regs: ier.edssi is %h after a write / hold", ier_edssi);
    // dlm writes
    p_dlm_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_dlm_value_rst: assert (!past_ok || $past(rst_n) || dlm_value == 8'h00)
      else $error("chilimix_uart_regs: dlm.value reset value %h", dlm_value);
    p_dlm_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || dlm_value == ($past((access && PWRITE && hit[4])) ? (($past(dlm_value) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(dlm_value)))
      else $error("chilimix_uart_regs: dlm.value is %h after a write / hold", dlm_value);
    // fcr writes
    p_fcr_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_fcr_wrp: assert (!rst_n || fcr_wr == (access && PWRITE && hit[6]))
      else $error("chilimix_uart_regs: fcr write pulse wrong");
    p_fcr_enable_rst: assert (!past_ok || $past(rst_n) || fcr_enable == 1'h0)
      else $error("chilimix_uart_regs: fcr.enable reset value %h", fcr_enable);
    p_fcr_enable_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fcr_enable == ($past((access && PWRITE && hit[6])) ? (($past(fcr_enable) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(fcr_enable)))
      else $error("chilimix_uart_regs: fcr.enable is %h after a write / hold", fcr_enable);
    p_fcr_dma_mode_rst: assert (!past_ok || $past(rst_n) || fcr_dma_mode == 1'h0)
      else $error("chilimix_uart_regs: fcr.dma_mode reset value %h", fcr_dma_mode);
    p_fcr_dma_mode_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fcr_dma_mode == ($past((access && PWRITE && hit[6])) ? (($past(fcr_dma_mode) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(fcr_dma_mode)))
      else $error("chilimix_uart_regs: fcr.dma_mode is %h after a write / hold", fcr_dma_mode);
    p_fcr_rx_trigger_rst: assert (!past_ok || $past(rst_n) || fcr_rx_trigger == 2'h0)
      else $error("chilimix_uart_regs: fcr.rx_trigger reset value %h", fcr_rx_trigger);
    p_fcr_rx_trigger_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fcr_rx_trigger == ($past((access && PWRITE && hit[6])) ? (($past(fcr_rx_trigger) & ~$past(bit_en[7:6])) | ($past(PWDATA[7:6]) & $past(bit_en[7:6]))) : $past(fcr_rx_trigger)))
      else $error("chilimix_uart_regs: fcr.rx_trigger is %h after a write / hold", fcr_rx_trigger);
    // lcr writes
    p_lcr_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_lcr_wls_rst: assert (!past_ok || $past(rst_n) || lcr_wls == 2'h0)
      else $error("chilimix_uart_regs: lcr.wls reset value %h", lcr_wls);
    p_lcr_wls_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_wls == ($past((access && PWRITE && hit[7])) ? (($past(lcr_wls) & ~$past(bit_en[1:0])) | ($past(PWDATA[1:0]) & $past(bit_en[1:0]))) : $past(lcr_wls)))
      else $error("chilimix_uart_regs: lcr.wls is %h after a write / hold", lcr_wls);
    p_lcr_stb_rst: assert (!past_ok || $past(rst_n) || lcr_stb == 1'h0)
      else $error("chilimix_uart_regs: lcr.stb reset value %h", lcr_stb);
    p_lcr_stb_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_stb == ($past((access && PWRITE && hit[7])) ? (($past(lcr_stb) & ~$past(bit_en[2:2])) | ($past(PWDATA[2:2]) & $past(bit_en[2:2]))) : $past(lcr_stb)))
      else $error("chilimix_uart_regs: lcr.stb is %h after a write / hold", lcr_stb);
    p_lcr_pen_rst: assert (!past_ok || $past(rst_n) || lcr_pen == 1'h0)
      else $error("chilimix_uart_regs: lcr.pen reset value %h", lcr_pen);
    p_lcr_pen_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_pen == ($past((access && PWRITE && hit[7])) ? (($past(lcr_pen) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(lcr_pen)))
      else $error("chilimix_uart_regs: lcr.pen is %h after a write / hold", lcr_pen);
    p_lcr_eps_rst: assert (!past_ok || $past(rst_n) || lcr_eps == 1'h0)
      else $error("chilimix_uart_regs: lcr.eps reset value %h", lcr_eps);
    p_lcr_eps_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_eps == ($past((access && PWRITE && hit[7])) ? (($past(lcr_eps) & ~$past(bit_en[4:4])) | ($past(PWDATA[4:4]) & $past(bit_en[4:4]))) : $past(lcr_eps)))
      else $error("chilimix_uart_regs: lcr.eps is %h after a write / hold", lcr_eps);
    p_lcr_stick_rst: assert (!past_ok || $past(rst_n) || lcr_stick == 1'h0)
      else $error("chilimix_uart_regs: lcr.stick reset value %h", lcr_stick);
    p_lcr_stick_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_stick == ($past((access && PWRITE && hit[7])) ? (($past(lcr_stick) & ~$past(bit_en[5:5])) | ($past(PWDATA[5:5]) & $past(bit_en[5:5]))) : $past(lcr_stick)))
      else $error("chilimix_uart_regs: lcr.stick is %h after a write / hold", lcr_stick);
    p_lcr_brk_rst: assert (!past_ok || $past(rst_n) || lcr_brk == 1'h0)
      else $error("chilimix_uart_regs: lcr.brk reset value %h", lcr_brk);
    p_lcr_brk_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_brk == ($past((access && PWRITE && hit[7])) ? (($past(lcr_brk) & ~$past(bit_en[6:6])) | ($past(PWDATA[6:6]) & $past(bit_en[6:6]))) : $past(lcr_brk)))
      else $error("chilimix_uart_regs: lcr.brk is %h after a write / hold", lcr_brk);
    p_lcr_dlab_rst: assert (!past_ok || $past(rst_n) || lcr_dlab == 1'h0)
      else $error("chilimix_uart_regs: lcr.dlab reset value %h", lcr_dlab);
    p_lcr_dlab_wr: assert (!rst_n || !past_ok || !$past(rst_n) || lcr_dlab == ($past((access && PWRITE && hit[7])) ? (($past(lcr_dlab) & ~$past(bit_en[7:7])) | ($past(PWDATA[7:7]) & $past(bit_en[7:7]))) : $past(lcr_dlab)))
      else $error("chilimix_uart_regs: lcr.dlab is %h after a write / hold", lcr_dlab);
    // mcr writes
    p_mcr_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_mcr_dtr_rst: assert (!past_ok || $past(rst_n) || mcr_dtr == 1'h0)
      else $error("chilimix_uart_regs: mcr.dtr reset value %h", mcr_dtr);
    p_mcr_dtr_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mcr_dtr == ($past((access && PWRITE && hit[8])) ? (($past(mcr_dtr) & ~$past(bit_en[0:0])) | ($past(PWDATA[0:0]) & $past(bit_en[0:0]))) : $past(mcr_dtr)))
      else $error("chilimix_uart_regs: mcr.dtr is %h after a write / hold", mcr_dtr);
    p_mcr_rts_rst: assert (!past_ok || $past(rst_n) || mcr_rts == 1'h0)
      else $error("chilimix_uart_regs: mcr.rts reset value %h", mcr_rts);
    p_mcr_rts_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mcr_rts == ($past((access && PWRITE && hit[8])) ? (($past(mcr_rts) & ~$past(bit_en[1:1])) | ($past(PWDATA[1:1]) & $past(bit_en[1:1]))) : $past(mcr_rts)))
      else $error("chilimix_uart_regs: mcr.rts is %h after a write / hold", mcr_rts);
    p_mcr_out1_rst: assert (!past_ok || $past(rst_n) || mcr_out1 == 1'h0)
      else $error("chilimix_uart_regs: mcr.out1 reset value %h", mcr_out1);
    p_mcr_out1_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mcr_out1 == ($past((access && PWRITE && hit[8])) ? (($past(mcr_out1) & ~$past(bit_en[2:2])) | ($past(PWDATA[2:2]) & $past(bit_en[2:2]))) : $past(mcr_out1)))
      else $error("chilimix_uart_regs: mcr.out1 is %h after a write / hold", mcr_out1);
    p_mcr_out2_rst: assert (!past_ok || $past(rst_n) || mcr_out2 == 1'h0)
      else $error("chilimix_uart_regs: mcr.out2 reset value %h", mcr_out2);
    p_mcr_out2_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mcr_out2 == ($past((access && PWRITE && hit[8])) ? (($past(mcr_out2) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(mcr_out2)))
      else $error("chilimix_uart_regs: mcr.out2 is %h after a write / hold", mcr_out2);
    p_mcr_loop_rst: assert (!past_ok || $past(rst_n) || mcr_loop == 1'h0)
      else $error("chilimix_uart_regs: mcr.loop reset value %h", mcr_loop);
    p_mcr_loop_wr: assert (!rst_n || !past_ok || !$past(rst_n) || mcr_loop == ($past((access && PWRITE && hit[8])) ? (($past(mcr_loop) & ~$past(bit_en[4:4])) | ($past(PWDATA[4:4]) & $past(bit_en[4:4]))) : $past(mcr_loop)))
      else $error("chilimix_uart_regs: mcr.loop is %h after a write / hold", mcr_loop);
    // lsr writes
    p_lsr_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    // msr writes
    p_msr_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    // scr writes
    p_scr_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_scr_value_rst: assert (!past_ok || $past(rst_n) || scr_value == 8'h00)
      else $error("chilimix_uart_regs: scr.value reset value %h", scr_value);
    p_scr_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || scr_value == ($past((access && PWRITE && hit[11])) ? (($past(scr_value) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(scr_value)))
      else $error("chilimix_uart_regs: scr.value is %h after a write / hold", scr_value);
  end

endmodule

bind chilimix_uart_regs chilimix_uart_regs_chk u_chk (.*);
