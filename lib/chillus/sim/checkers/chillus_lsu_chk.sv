// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_lsu_chk (bound into chillus_lsu)
//   header Invariants:
//   - rsp_load && rsp_store never both set
//   - mss_req -> !misaligned && (!outstanding || mss_rvalid)
//   - req_wait -> mss_req, same request (a presented request is held until
//     mss_gnt)
//   - load_valid -> rsp_load && mss_rvalid && !mss_err
//   also:
//   - a request is naturally aligned: the byte enables are non-zero and lie
//     inside the access size at the address offset; the address is a word
//     address
//   - rsp load registers (size, unsigned, offset) are 0 unless a load is
//     outstanding; rsp_addr is 0 with nothing outstanding
//   - access_fault only with an outstanding access and mss_rvalid && mss_err,
//     or a PMP-denied access in rsp (rsp_pmp)
//   - pmp_fire -> !mss_req (a PMP-denied access is never presented)
//   - rsp_pmp -> (rsp_load || rsp_store) && !outstanding (header Invariants)
//   - pmp_wait with the access still in req -> it is still denied (header
//     Invariants: an allowed access never leaves without req_fire)
//   - MSS side (environment): mss_rvalid only with an outstanding access
// -----------------------------------------------------------------------------
module chillus_lsu_chk
  import chillus_dec_pkg::*;
#(
  parameter int XLEN   = 32,
  parameter int N_LANE = 4,
  parameter int OFF_W  = 2,
  parameter int SIZE_W = 2
) (
  input logic              clk,
  input logic              rst_n,
  input logic              misaligned,
  input logic [XLEN-1:0]   addr,
  input mem_size_e         mem_size,
  input logic              req_wait,
  input logic              mss_req,
  input logic              mss_gnt,
  input logic              mss_we,
  input logic [XLEN-1:0]   mss_addr,
  input logic [N_LANE-1:0] mss_be,
  input logic [XLEN-1:0]   mss_wdata,
  input logic              mss_rvalid,
  input logic              mss_err,
  input logic              outstanding,
  input logic              access_fault,
  input logic              pmp_fire,
  input logic              rsp_pmp,
  input logic              pmp_wait,
  input logic              aligned_access,
  input logic              pmp_deny,
  input logic              load_valid,
  input logic              rsp_load,
  input logic              rsp_store,
  input logic [SIZE_W-1:0] rsp_size_q,
  input logic              rsp_unsigned,
  input logic [OFF_W-1:0]  rsp_offset,
  input logic [XLEN-1:0]   rsp_addr
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic [N_LANE-1:0] size_be;   // lanes of an aligned access of this size at the address
  assign size_be = N_LANE'(((1 << (1 << mem_size)) - 1) << addr[OFF_W-1:0]);

  `CHK(!(rsp_load && rsp_store),
       ("chillus_lsu: rsp_load && rsp_store both set"))
  `CHK(mss_req |-> !misaligned && (!outstanding || mss_rvalid),
       ("chillus_lsu: request misaligned or with an access outstanding: misaligned=%b outstanding=%b rvalid=%b",
        misaligned, outstanding, mss_rvalid))
  `CHK(req_wait |-> mss_req && $stable(mss_we) && $stable(mss_addr) && $stable(mss_be)
                    && (!mss_we || $stable(mss_wdata)),
       ("chillus_lsu: request withdrawn / changed before mss_gnt: req=%b addr=%h (was %h) we=%b (was %b) be=%b (was %b)",
        mss_req, mss_addr, $past(mss_addr), mss_we, $past(mss_we), mss_be, $past(mss_be)))
  `CHK(load_valid |-> rsp_load && mss_rvalid && !mss_err,
       ("chillus_lsu: load_valid without a load response: rsp_load=%b rvalid=%b err=%b",
        rsp_load, mss_rvalid, mss_err))
  `CHK(mss_req |-> mss_be == size_be && mss_be != '0 && mss_addr[OFF_W-1:0] == '0,
       ("chillus_lsu: request byte enables / address wrong: addr=%h size=%0d be=%b expected=%b",
        mss_addr, mem_size, mss_be, size_be))
  `CHK(mss_req && !mss_we |-> mss_wdata == '0,
       ("chillus_lsu: load request with wdata != 0: wdata=%h", mss_wdata))
  `CHK(!rsp_load |-> rsp_size_q == '0 && !rsp_unsigned && rsp_offset == '0,
       ("chillus_lsu: rsp load registers != 0 with no load outstanding: size=%0d unsigned=%b offset=%0d",
        rsp_size_q, rsp_unsigned, rsp_offset))
  `CHK(!outstanding && !rsp_pmp |-> rsp_addr == '0,
       ("chillus_lsu: rsp_addr != 0 with nothing outstanding: rsp_addr=%h", rsp_addr))
  `CHK(access_fault |-> (outstanding && mss_rvalid && mss_err) || rsp_pmp,
       ("chillus_lsu: access_fault without an error response: outstanding=%b rvalid=%b err=%b rsp_pmp=%b",
        outstanding, mss_rvalid, mss_err, rsp_pmp))
  `CHK(pmp_fire |-> !mss_req && !misaligned,
       ("chillus_lsu: PMP-denied access presented, or misaligned: req=%b misaligned=%b",
        mss_req, misaligned))
  `CHK(pmp_wait && aligned_access |-> pmp_deny,
       ("chillus_lsu: pmp_wait but the access in req is allowed now: addr=%h", addr))
  `CHK(rsp_pmp |-> (rsp_load || rsp_store) && !outstanding,
       ("chillus_lsu: rsp_pmp with no access in rsp, or a bus access outstanding: load=%b store=%b outstanding=%b",
        rsp_load, rsp_store, outstanding))
  `CHK(mss_rvalid |-> outstanding,
       ("chillus_lsu: (MSS) mss_rvalid with no access outstanding"))

  `undef CHK

endmodule

bind chillus_lsu chillus_lsu_chk #(
  .XLEN   (XLEN),
  .N_LANE (N_LANE),
  .OFF_W  (OFF_W),
  .SIZE_W (SIZE_W)
) u_chk (
  .clk          (clk),
  .rst_n        (rst_n),
  .misaligned   (misaligned),
  .addr         (addr),
  .mem_size     (mem_size),
  .req_wait     (req_wait),
  .mss_req      (mss_req),
  .mss_gnt      (mss_gnt),
  .mss_we       (mss_we),
  .mss_addr     (mss_addr),
  .mss_be       (mss_be),
  .mss_wdata    (mss_wdata),
  .mss_rvalid   (mss_rvalid),
  .mss_err      (mss_err),
  .outstanding  (outstanding),
  .access_fault (access_fault),
  .pmp_fire     (pmp_fire),
  .rsp_pmp      (rsp_pmp),
  .pmp_wait     (pmp_wait),
  .aligned_access (aligned_access),
  .pmp_deny     (pmp_deny),
  .load_valid   (load_valid),
  .rsp_load     (rsp_load),
  .rsp_store    (rsp_store),
  .rsp_size_q   (rsp_size_q),
  .rsp_unsigned (rsp_unsigned),
  .rsp_offset   (rsp_offset),
  .rsp_addr     (rsp_addr)
);
