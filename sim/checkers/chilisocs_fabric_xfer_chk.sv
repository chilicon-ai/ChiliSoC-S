// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim / formal checker :: chilisocs_fabric_xfer_chk (bound into chilisocs_fabric)
//
// End to end, from the fabric's ports only: every transfer a manager (I, D,
// SBA, DMA) starts is carried out once by the subordinate its address
// decodes to, and the manager gets that subordinate's response. Per manager
// the checker keeps the transfer in its data phase (pend: decoded region,
// address, direction, size); per subordinate the address phase it took (dp:
// address, direction, size).
//   - route: a subordinate takes an address phase only for a transfer of
//     its region that a manager has started and not finished, with the same
//     address, direction and size (no phantom transfer, the right region)
//   - complete: a manager's data phase ends exactly when a data phase of its
//     subordinate with the same address, direction and size ends: at most
//     one manager per subordinate per cycle, and every subordinate data
//     phase ends with one manager's (so each transfer runs once: none lost,
//     none duplicated); the manager's HRESP and read HRDATA are the
//     subordinate's, and for a write the subordinate saw the manager's HWDATA
//   - default: a transfer to no region ends with an ERROR response (the
//     fabric's default subordinate)
//   - formal only: with every subordinate answering within SUB_WAIT wait
//     states, a manager's data phase lasts fewer than MAX_WAIT cycles (no
//     manager starves: round robin at the D bus and at each shared layer)
// Two managers with the same address, direction and size at one subordinate
// are told apart only by their data (HWDATA, HRDATA), which is checked too.
// Environment rules (asserted in simulation, assumed under FORMAL): managers
// issue IDLE / NONSEQ single, unlocked transfers and I never writes (the
// fabric samples an address phase only with the manager's HREADY high, so a
// manager need not hold one while it waits); a subordinate with no data
// phase answers OKAY with HREADYOUT high, and an ERROR takes two cycles. The
// wait bound is assumed under FORMAL only (the XIP window waits for flash).
// -----------------------------------------------------------------------------
`default_nettype none   // a bind port that names no signal of the target is an error
module chilisocs_fabric_xfer_chk
  import chilisocs_pkg::*;
#(
  parameter int SUB_WAIT = 2,        // formal: wait states a subordinate may insert
  parameter int MAX_WAIT = 40        // formal: bound on a manager's data phase (cycles)
) (
  input logic         clk,
  input logic         rst_n,
  // managers {DMA, SBA, D, I}
  input logic [127:0] m_haddr,
  input logic [7:0]   m_htrans,
  input logic [3:0]   m_hwrite,
  input logic [11:0]  m_hsize,
  input logic [11:0]  m_hburst,      // I and D: SINGLE
  input logic [3:0]   m_hmastlock,
  input logic [127:0] m_hwdata,
  input logic [3:0]   m_hready,
  input logic [3:0]   m_hresp,
  input logic [127:0] m_hrdata,
  // subordinates {APB, SRAM1, XIP, DM, SRAM0, ROM}
  input logic [5:0]   s_hsel,
  input logic [191:0] s_haddr,
  input logic [11:0]  s_htrans,
  input logic [5:0]   s_hwrite,
  input logic [17:0]  s_hsize,
  input logic [191:0] s_hwdata,
  input logic [5:0]   s_hready,      // the HREADY each subordinate sees
  input logic [5:0]   s_hreadyout,
  input logic [5:0]   s_hresp,
  input logic [191:0] s_hrdata
);

  localparam int M   = 4;            // managers: 0 I, 1 D, 2 SBA, 3 DMA
  localparam int S   = 6;            // subordinates: 0 ROM, 1 SRAM0, 2 DM, 3 XIP, 4 SRAM1, 5 APB
  localparam int R   = S + 1;        // regions: the subordinates, then DEF (no region)
  localparam int DEF = S;
  localparam int TW  = 36;           // transfer tag: size, direction, address

  // region an address decodes to for manager m (I reaches ROM, SRAM0, DM, XIP)
  function automatic logic [R-1:0] region(input logic [31:0] a, input int m);
    logic [R-1:0] r;
    r = '0;
    r[0] = (a & ROM_MASK) == ROM_BASE;
    r[1] = (a & SRAM0_MASK) == SRAM0_BASE;
    r[2] = (a & DM_MASK) == DM_BASE;
    r[3] = (a & XIP_MASK) == XIP_BASE;
    if (m != 0) begin
      r[4] = (a & SRAM1_MASK) == SRAM1_BASE;
      r[5] = (a & APBW0_MASK) == APBW0_BASE || (a & APBW1_MASK) == APBW1_BASE
          || (a & APBW2_MASK) == APBW2_BASE || (a & APBW3_MASK) == APBW3_BASE;
    end
    r[DEF] = r[S-1:0] == '0;
    return r;
  endfunction

  // ---- managers: the transfer in the data phase
  logic [M-1:0]    acc;              // address phase taken this cycle (NONSEQ, HREADY_m high)
  logic [M-1:0]    done;             // the data phase ends this cycle
  logic [M-1:0]    pend;             // a transfer is in its data phase
  logic [M*R-1:0]  acc_reg;          // region of the address phase now
  logic [M*TW-1:0] acc_tag;          // tag of the address phase now
  logic [M*R-1:0]  reg_q;            // region of the pending transfer
  logic [M*TW-1:0] tag_q;            // tag of the pending transfer
  logic [M*8-1:0]  wait_cnt;         // cycles the pending transfer has waited (saturating)

  always_comb
    for (int m = 0; m < M; m++) begin
      acc[m]  = m_htrans[m*2+1] && m_hready[m];
      done[m] = pend[m] && m_hready[m];
      acc_reg[m*R +: R]   = region(m_haddr[m*32 +: 32], m);
      acc_tag[m*TW +: TW] = {m_hsize[m*3 +: 3], m_hwrite[m], m_haddr[m*32 +: 32]};
    end

  // ---- subordinates: the address phase taken and its data phase
  logic [S-1:0]    s_take;           // the subordinate takes an address phase
  logic [S-1:0]    s_end;            // its data phase ends this cycle
  logic [S-1:0]    s_dp;             // it is in a data phase
  logic [S*TW-1:0] s_tag;            // tag of the address phase now
  logic [S*TW-1:0] s_tag_q;          // tag of the data phase
  logic [S*4-1:0]  s_wait;           // wait states of the data phase (formal bound)
  logic [S-1:0]    err1;             // the first ERROR cycle was last cycle

  always_comb
    for (int s = 0; s < S; s++) begin
      s_take[s] = s_hsel[s] && s_htrans[s*2+1] && s_hready[s];
      s_end[s]  = s_dp[s] && s_hready[s];
      s_tag[s*TW +: TW] = {s_hsize[s*3 +: 3], s_hwrite[s], s_haddr[s*32 +: 32]};
    end

  always @(posedge clk)
    if (!rst_n) begin
      pend     <= '0;
      wait_cnt <= '0;
      s_dp     <= '0;
      s_wait   <= '0;
      err1     <= '0;
    end else begin
      for (int m = 0; m < M; m++) begin
        if (acc[m]) begin
          pend[m]             <= 1'b1;
          reg_q[m*R +: R]     <= acc_reg[m*R +: R];
          tag_q[m*TW +: TW]   <= acc_tag[m*TW +: TW];
          wait_cnt[m*8 +: 8]  <= 8'd0;
        end else if (done[m]) begin
          pend[m] <= 1'b0;
        end else if (pend[m] && wait_cnt[m*8 +: 8] != 8'hFF) begin
          wait_cnt[m*8 +: 8] <= wait_cnt[m*8 +: 8] + 8'd1;
        end
      end
      for (int s = 0; s < S; s++) begin
        err1[s] <= s_dp[s] && s_hresp[s] && !s_hreadyout[s];
        if (s_take[s]) begin
          s_dp[s]             <= 1'b1;
          s_tag_q[s*TW +: TW] <= s_tag[s*TW +: TW];
          s_wait[s*4 +: 4]    <= 4'd0;
        end else if (s_end[s]) begin
          s_dp[s] <= 1'b0;
        end else if (s_dp[s] && s_wait[s*4 +: 4] != 4'hF) begin
          s_wait[s*4 +: 4] <= s_wait[s*4 +: 4] + 4'd1;
        end
      end
    end

  // ---- environment rules
  logic mgr_single;                  // IDLE / NONSEQ single, unlocked transfers; I reads only
  logic sub_idle_okay;               // no data phase: OKAY, HREADYOUT high
  logic sub_err_two;                 // an ERROR response takes two cycles

  always_comb begin
    mgr_single = !(m_htrans[1] && m_hwrite[0]);
    for (int m = 0; m < M; m++)
      mgr_single &= !m_htrans[m*2] && m_hburst[m*3 +: 3] == 3'd0 && !m_hmastlock[m];
    sub_idle_okay = 1'b1;
    sub_err_two = 1'b1;
    for (int s = 0; s < S; s++) begin
      sub_idle_okay &= s_dp[s] || (s_hreadyout[s] && !s_hresp[s]);
      sub_err_two &= (!s_dp[s] || !s_hresp[s] || !s_hreadyout[s] || err1[s])
                     && (!err1[s] || (s_hresp[s] && s_hreadyout[s]));
    end
  end

`ifdef FORMAL
  logic sub_bounded;                 // every subordinate answers within SUB_WAIT wait states
  always_comb begin
    sub_bounded = 1'b1;
    for (int s = 0; s < S; s++)
      sub_bounded &= !s_dp[s] || s_hreadyout[s] || s_wait[s*4 +: 4] < 4'(SUB_WAIT);
  end
  chilisocs_fabric_env_single:   assume property (@(posedge clk) disable iff (!rst_n) mgr_single);
  chilisocs_fabric_env_sub_idle: assume property (@(posedge clk) disable iff (!rst_n) sub_idle_okay);
  chilisocs_fabric_env_sub_err:  assume property (@(posedge clk) disable iff (!rst_n) sub_err_two);
  chilisocs_fabric_env_sub_wait: assume property (@(posedge clk) disable iff (!rst_n) sub_bounded);
`else
  chilisocs_fabric_env_single: assert property (@(posedge clk) disable iff (!rst_n) mgr_single)
    else $error("chilisocs_fabric: a manager issues SEQ / BUSY, a burst, a locked transfer, or I writes");
  chilisocs_fabric_env_sub_idle: assert property (@(posedge clk) disable iff (!rst_n) sub_idle_okay)
    else $error("chilisocs_fabric: a subordinate with no data phase is not ready / OKAY: %b %b",
                s_hreadyout, s_hresp);
  chilisocs_fabric_env_sub_err: assert property (@(posedge clk) disable iff (!rst_n) sub_err_two)
    else $error("chilisocs_fabric: an ERROR response that is not two cycles");
`endif

  // ---- properties
  logic route_ok;                    // every subordinate address phase belongs to a started transfer
  logic one_ok;                      // at most one manager finishes per subordinate per cycle
  logic sub_end_ok;                  // every subordinate data phase ends with a manager's
  logic complete_ok;                 // a manager finishes with its subordinate, and its response
  logic default_ok;                  // a transfer to no region gets ERROR

  always_comb begin
    route_ok = 1'b1;
    one_ok = 1'b1;
    sub_end_ok = 1'b1;
    for (int s = 0; s < S; s++) begin
      logic cand, fin, two;
      cand = 1'b0;
      fin = 1'b0;
      two = 1'b0;
      for (int m = 0; m < M; m++) begin
        cand |= (pend[m] && !done[m] && reg_q[m*R+s] && tag_q[m*TW +: TW] == s_tag[s*TW +: TW])
             || (acc[m] && acc_reg[m*R+s] && acc_tag[m*TW +: TW] == s_tag[s*TW +: TW]);
        if (done[m] && reg_q[m*R+s]) begin
          two |= fin;
          fin = 1'b1;
        end
      end
      route_ok &= !s_take[s] || cand;
      one_ok &= !two;
      sub_end_ok &= !s_end[s] || fin;
    end
    complete_ok = 1'b1;
    default_ok = 1'b1;
    for (int m = 0; m < M; m++)
      if (done[m]) begin
        default_ok &= !reg_q[m*R+DEF] || m_hresp[m];
        for (int s = 0; s < S; s++)
          if (reg_q[m*R+s])
            complete_ok &= s_end[s] && s_tag_q[s*TW +: TW] == tag_q[m*TW +: TW]
                           && m_hresp[m] == s_hresp[s]
                           && (!tag_q[m*TW+32] || s_hwdata[s*32 +: 32] == m_hwdata[m*32 +: 32])
                           && (tag_q[m*TW+32] || m_hresp[m] || m_hrdata[m*32 +: 32] == s_hrdata[s*32 +: 32]);
      end
  end

  chilisocs_fabric_route: assert property (@(posedge clk) disable iff (!rst_n) route_ok)
    else $error("chilisocs_fabric: a subordinate took an address phase no manager started: take %b", s_take);
  chilisocs_fabric_one_done: assert property (@(posedge clk) disable iff (!rst_n) one_ok)
    else $error("chilisocs_fabric: two managers finished at one subordinate: done %b", done);
  chilisocs_fabric_sub_end: assert property (@(posedge clk) disable iff (!rst_n) sub_end_ok)
    else $error("chilisocs_fabric: a subordinate data phase ended for no manager: end %b done %b",
                s_end, done);
  chilisocs_fabric_complete: assert property (@(posedge clk) disable iff (!rst_n) complete_ok)
    else $error("chilisocs_fabric: a manager finished without its subordinate's data phase / response: done %b",
                done);
  chilisocs_fabric_default: assert property (@(posedge clk) disable iff (!rst_n) default_ok)
    else $error("chilisocs_fabric: a transfer to no region did not get ERROR: done %b", done);

`ifdef FORMAL
  logic no_starve;                   // no data phase of MAX_WAIT cycles or more
  always_comb begin
    no_starve = 1'b1;
    for (int m = 0; m < M; m++)
      no_starve &= !pend[m] || wait_cnt[m*8 +: 8] < 8'(MAX_WAIT);
  end
  chilisocs_fabric_no_starve: assert property (@(posedge clk) disable iff (!rst_n) no_starve);
  // every manager finishes a transfer in every region it reaches; the D bus
  // managers all wait at once
  for (genvar m = 0; m < M; m++) begin : g_cov
    for (genvar r = 0; r < R; r++) begin : g_r
      if (m != 0 || r < 4 || r == DEF) begin : g_reach
        chilisocs_fabric_cover_done: cover property (@(posedge clk) disable iff (!rst_n)
                                                     done[m] && reg_q[m*R+r]);
      end
    end
  end
  chilisocs_fabric_cover_contend: cover property (@(posedge clk) disable iff (!rst_n)
                                                  pend[1] && pend[2] && pend[3]
                                                  && !m_hready[1] && !m_hready[2] && !m_hready[3]);
`endif

endmodule

bind chilisocs_fabric chilisocs_fabric_xfer_chk u_xfer_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .m_haddr     ({dma_HADDR, sba_HADDR, d_HADDR, i_HADDR}),
  .m_htrans    ({dma_HTRANS, sba_HTRANS, d_HTRANS, i_HTRANS}),
  .m_hwrite    ({dma_HWRITE, sba_HWRITE, d_HWRITE, i_HWRITE}),
  .m_hsize     ({dma_HSIZE, sba_HSIZE, d_HSIZE, i_HSIZE}),
  .m_hburst    ({dma_HBURST, sba_HBURST, 3'd0, 3'd0}),
  .m_hmastlock ({dma_HMASTLOCK, sba_HMASTLOCK, 1'b0, 1'b0}),
  .m_hwdata    ({dma_HWDATA, sba_HWDATA, d_HWDATA, 32'd0}),
  .m_hready    ({dma_HREADY, sba_HREADY, d_HREADY, i_HREADY}),
  .m_hresp     ({dma_HRESP, sba_HRESP, d_HRESP, i_HRESP}),
  .m_hrdata    ({dma_HRDATA, sba_HRDATA, d_HRDATA, i_HRDATA}),
  .s_hsel      ({apb_HSEL, sram1_HSEL, xip_HSEL, dm_HSEL, sram0_HSEL, rom_HSEL}),
  .s_haddr     ({b_HADDR, b_HADDR, xip_HADDR, dm_HADDR, sram0_HADDR, rom_HADDR}),
  .s_htrans    ({b_HTRANS, b_HTRANS, xip_HTRANS, dm_HTRANS, sram0_HTRANS, rom_HTRANS}),
  .s_hwrite    ({b_HWRITE, b_HWRITE, xip_HWRITE, dm_HWRITE, sram0_HWRITE, rom_HWRITE}),
  .s_hsize     ({b_HSIZE, b_HSIZE, xip_HSIZE, dm_HSIZE, sram0_HSIZE, rom_HSIZE}),
  .s_hwdata    ({b_HWDATA, b_HWDATA, xip_HWDATA, dm_HWDATA, sram0_HWDATA, rom_HWDATA}),
  .s_hready    ({apb_HREADY, sram1_HREADY, xip_HREADY, dm_HREADY, sram0_HREADY, rom_HREADY}),
  .s_hreadyout ({apb_HREADYOUT, sram1_HREADYOUT, xip_HREADYOUT, dm_HREADYOUT, sram0_HREADYOUT, rom_HREADYOUT}),
  .s_hresp     ({apb_HRESP, sram1_HRESP, xip_HRESP, dm_HRESP, sram0_HRESP, rom_HRESP}),
  .s_hrdata    ({apb_HRDATA, sram1_HRDATA, xip_HRDATA, dm_HRDATA, sram0_HRDATA, rom_HRDATA})
);
`default_nettype wire
