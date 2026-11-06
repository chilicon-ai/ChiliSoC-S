// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_core_chk (bound into chillus_core): invariants that
// span units, stated in the unit headers / file lists
//   - chillus_rvfi: rvfi_valid && !rvfi_trap == valid_wb && !kill[wb] when wb
//     is not held (the trace and the register write retire together), and
//     the reported pc is the decoder's pc_wb
//   - chillus_result / chillus_lsu: the LSU response is aligned with wb:
//     load_valid -> valid_wb && wb_src_wb == MEM, and a load in wb that
//     leaves it (!hold[wb], !kill[wb]) has load_valid
//   - chillus_ifu (file list constraint): an instruction accepted in a redirect
//     cycle belongs to the old stream and is discarded: redirect_valid ->
//     kill[id], except on predict_fire (the redirect is the accepted
//     instruction's own predicted target: it advances to ex)
//   - static prediction (chillus_bp / chillus_bru / chillus_ctrl): the front
//     end follows the path the branch unit expects: with an ex jump or branch
//     resolved as predicted, a valid id instruction is at its successor
//     (jump && predicted -> ifu_pc == target; no_jump && !predicted ->
//     ifu_pc == link), and predict_fire moves the instruction to ex
//   - chillus_csr: minstret_now == retired instructions (rvfi_valid &&
//     !rvfi_trap) plus the one in wb (valid_wb: it left ex without a
//     trap), since the last minstret write; checked as "the difference
//     is constant", re-based after a minstret write or while
//     minstret is stopped (mcountinhibit.IR, or dcsr.stopcount in debug
//     mode: u_csr.ir_stop); 0 before the first re-base
// -----------------------------------------------------------------------------
module chillus_core_chk
  import chillus_dec_pkg::*;
(
  input logic                clk,
  input logic                rst_n,
  input logic [N_STAGES-1:0] hold,
  input logic [N_STAGES-1:0] kill,
  input logic                valid_wb,
  input logic [XLEN-1:0]     pc_wb,
  input wb_src_e             wb_src_wb,
  input logic                rvfi_valid,
  input logic                rvfi_trap,
  input logic [XLEN-1:0]     rvfi_pc_rdata,
  input logic                load_valid,
  input logic                redirect_valid,
  input logic                predict_fire,
  input logic                ifu_valid,
  input logic [XLEN-1:0]     ifu_pc,
  input logic                valid_ex,
  input logic [XLEN-1:0]     pc_ex,
  input logic                jump,
  input logic                no_jump,
  input logic                predicted,
  input logic [XLEN-1:0]     jump_target,
  input logic [XLEN-1:0]     link,
  input logic [63:0]         minstret_now,
  input logic                minstret_ld,
  input logic                inhibit_ir
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic        rvfi_ok;      // a non-trapping instruction is reported
  logic [63:0] n_ok;         // non-trapping reports so far
  logic [63:0] counted;      // n_ok + the instruction in wb (left ex without a trap)
  logic [63:0] diff;         // minstret_now - counted
  logic [63:0] diff_q;       // diff of the previous cycle
  logic        diff_ok;      // the previous cycle had no minstret write / inhibit
  logic        rebased;      // a re-base happened since reset

  assign rvfi_ok = rvfi_valid && !rvfi_trap;
  assign counted = n_ok + 64'(valid_wb);
  assign diff    = minstret_now - counted;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_ok    <= '0;
      diff_q  <= '0;
      diff_ok <= 1'b1;
      rebased <= 1'b0;
    end else begin
      n_ok    <= n_ok + 64'(rvfi_ok);
      diff_q  <= diff;
      diff_ok <= !minstret_ld && !inhibit_ir;
      if (minstret_ld || inhibit_ir) rebased <= 1'b1;
    end
  end

  `CHK(!hold[STAGE_WB] |-> rvfi_ok == (valid_wb && !kill[STAGE_WB]),
       ("chillus_rvfi/core: rvfi_valid && !rvfi_trap != valid_wb && !kill[wb]: rvfi_valid=%b rvfi_trap=%b valid_wb=%b kill=%b",
        rvfi_valid, rvfi_trap, valid_wb, kill))
  `CHK(rvfi_ok |-> rvfi_pc_rdata == pc_wb,
       ("chillus_rvfi/core: reported pc != decoder pc_wb: rvfi_pc_rdata=%h pc_wb=%h", rvfi_pc_rdata, pc_wb))
  `CHK(load_valid |-> valid_wb && wb_src_wb == WB_SRC_MEM,
       ("chillus_result/lsu: load response not aligned with wb: valid_wb=%b wb_src_wb=%s",
        valid_wb, wb_src_wb.name()))
  `CHK(valid_wb && wb_src_wb == WB_SRC_MEM && !hold[STAGE_WB] && !kill[STAGE_WB] |-> load_valid,
       ("chillus_result/lsu: load leaves wb without its data: load_valid=%b", load_valid))
  `CHK(redirect_valid && !predict_fire |-> kill[STAGE_ID],
       ("chillus_ifu/core: redirect without kill[id] (instruction accepted in the redirect cycle kept)"))
  `CHK(predict_fire |=> valid_ex && pc_ex == $past(ifu_pc),
       ("chillus_bp/core: predicted instruction did not advance to ex: valid_ex=%b pc_ex=%h", valid_ex, pc_ex))
  `CHK(jump && predicted && ifu_valid |-> ifu_pc == jump_target,
       ("chillus_bp/core: predicted-taken jump, id is off the path: ifu_pc=%h target=%h", ifu_pc, jump_target))
  `CHK(no_jump && !predicted && ifu_valid |-> ifu_pc == link,
       ("chillus_bp/core: not-taken branch predicted not taken, id is off the path: ifu_pc=%h link=%h", ifu_pc, link))
  `CHK(diff_ok |-> diff == diff_q,
       ("chillus_csr/core: minstret_now drifted from retired + in-flight instructions: minstret_now=%0d counted=%0d (retired %0d, wb %b) diff=%0d before=%0d",
        minstret_now, counted, n_ok, valid_wb, $signed(diff), $signed(diff_q)))
  `CHK(!rebased |-> diff == '0,
       ("chillus_csr/core: minstret_now != retired + in-flight instructions (no write yet): minstret_now=%0d counted=%0d",
        minstret_now, counted))

  `undef CHK

endmodule

bind chillus_core chillus_core_chk u_core_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .hold           (hold),
  .kill           (kill),
  .valid_wb       (valid_wb),
  .pc_wb          (pc_wb),
  .wb_src_wb      (wb_src_wb),
  .rvfi_valid     (rvfi_valid),
  .rvfi_trap      (rvfi_trap),
  .rvfi_pc_rdata  (rvfi_pc_rdata),
  .load_valid     (u_lsu.load_valid),
  .redirect_valid (redirect_valid),
  .predict_fire   (predict_fire),
  .ifu_valid      (ifu_valid),
  .ifu_pc         (ifu_pc),
  .valid_ex       (valid_ex),
  .pc_ex          (pc_ex),
  .jump           (jump),
  .no_jump        (no_jump),
  .predicted      (predicted),
  .jump_target    (jump_target),
  .link           (link),
  .minstret_now   (u_csr.minstret_now),
  .minstret_ld    (u_csr.minstret_ld),
  .inhibit_ir     (u_csr.ir_stop)
);
