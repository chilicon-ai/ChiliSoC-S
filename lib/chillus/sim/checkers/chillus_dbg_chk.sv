// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_dbg_chk (bound into chillus_dbg)
//   - dpc[0] == 0 (dpc[1:0] == 0 for IALIGN 32)           (header Invariants)
//   - debug_mode -> dcsr.cause is 1 .. 4                  (header Invariants)
//   - debug_mode -> !dbg_pending                          (header Invariants)
//   - at most one of entry, reenter, exc, dbg_return      (header Invariants)
//   - entry only outside debug mode; reenter, exc and dbg_return only in it
//   - a step entry (cause 4) comes after exactly one instruction left the
//     stage (or was taken by a trigger breakpoint) outside debug mode since
//     the last dret (header single step)
//   - DEBUG = 0: never in debug mode, no redirect, no CSR
// -----------------------------------------------------------------------------
module chillus_dbg_chk #(
  parameter int XLEN   = 32,
  parameter int IALIGN = 32,
  parameter bit DEBUG  = 1'b1
) (
  input logic            clk,
  input logic            rst_n,
  input logic [XLEN-1:0] dpc,
  input logic            debug_mode,
  input logic [2:0]      dcsr_cause,
  input logic            dbg_pending,
  input logic            entry,
  input logic            reenter,
  input logic            exc,
  input logic            dbg_return,
  input logic            dbg_take,
  input logic            halt_req,
  input logic            act,
  input logic            brk_take,
  input logic            trig_dbg,
  input logic            dbg_redirect,
  input logic            csr_hit
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  int n_act;                 // instructions that left the stage outside debug mode since the last dret

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)          n_act <= 0;
    else if (dbg_return) n_act <= 0;
    else if ((act || brk_take) && !debug_mode) n_act <= n_act + 1;
  end

  `CHK(dpc[0] == 1'b0 && (IALIGN == 16 || dpc[1] == 1'b0),
       ("chillus_dbg: dpc low bit(s) not 0: dpc=%h", dpc))
  `CHK(debug_mode |-> dcsr_cause >= 3'd1 && dcsr_cause <= 3'd4,
       ("chillus_dbg: illegal dcsr.cause in debug mode: cause=%0d", dcsr_cause))
  `CHK(debug_mode |-> !dbg_pending,
       ("chillus_dbg: entry requested while in debug mode"))
  `CHK($onehot0({entry, reenter, exc, dbg_return}),
       ("chillus_dbg: entry / reenter / exc / dbg_return not exclusive: %b %b %b %b",
        entry, reenter, exc, dbg_return))
  `CHK(entry |-> !debug_mode,
       ("chillus_dbg: entry while in debug mode"))
  `CHK(reenter || exc || dbg_return |-> debug_mode,
       ("chillus_dbg: debug-mode event outside debug mode: reenter=%b exc=%b dbg_return=%b",
        reenter, exc, dbg_return))
  `CHK(dbg_take && !halt_req && !trig_dbg |-> n_act == 1,
       ("chillus_dbg: step entry after %0d instructions (expected 1)", n_act))
  `CHK(!DEBUG |-> !debug_mode && !dbg_redirect && !dbg_pending && !csr_hit,
       ("chillus_dbg: DEBUG = 0 but debug activity"))

  `undef CHK

endmodule

bind chillus_dbg chillus_dbg_chk #(.XLEN(XLEN), .IALIGN(IALIGN), .DEBUG(DEBUG)) u_chk (
  .clk          (clk),
  .rst_n        (rst_n),
  .dpc          (dpc),
  .debug_mode   (debug_mode),
  .dcsr_cause   (dcsr_cause),
  .dbg_pending  (dbg_pending),
  .entry        (entry),
  .reenter      (reenter),
  .exc          (exc),
  .dbg_return   (dbg_return),
  .dbg_take     (dbg_take),
  .halt_req     (halt_req),
  .act          (act),
  .brk_take     (brk_take),
  .trig_dbg     (trig_dbg),
  .dbg_redirect (dbg_redirect),
  .csr_hit      (csr_hit)
);
