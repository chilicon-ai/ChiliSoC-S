// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_result_chk (bound into chillus_result)
//   - result_wb stays aligned with the decoder stages (header: the register
//     follows the decoder rule; bubble = 0): valid_wb == 0 -> result_wb == 0
//   - rf_we == valid_wb && !hold[wb] && !kill[wb]; rf_rd == rd_wb (header)
//   - result_wb is the ex result of the instruction that advanced
//   - late_wb -> wb_src_wb == MD (header Invariant)
// -----------------------------------------------------------------------------
module chillus_result_chk
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32
) (
  input logic                clk,
  input logic                rst_n,
  input logic [N_STAGES-1:0] hold,
  input logic [N_STAGES-1:0] kill,
  input logic                valid_wb,
  input wb_src_e             wb_src_wb,
  input logic [4:0]          rd_wb,
  input logic [XLEN-1:0]     result_ex,
  input logic [XLEN-1:0]     result_wb,
  input logic                late_wb,
  input logic                adv_ex,
  input logic                rf_we,
  input logic [4:0]          rf_rd
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(!valid_wb |-> result_wb == '0,
       ("chillus_result: result_wb != 0 for a wb bubble: result_wb=%h", result_wb))
  `CHK(rf_we == (valid_wb && !hold[STAGE_WB] && !kill[STAGE_WB]) && rf_rd == rd_wb,
       ("chillus_result: rf_we / rf_rd != valid_wb && !hold[wb] && !kill[wb] / rd_wb: rf_we=%b valid_wb=%b rf_rd=%0d rd_wb=%0d",
        rf_we, valid_wb, rf_rd, rd_wb))
  `CHK(adv_ex |=> result_wb == $past(result_ex),
       ("chillus_result: result_wb != ex result of the advancing instruction: result_wb=%h expected=%h",
        result_wb, $past(result_ex)))
  `CHK(late_wb |-> wb_src_wb == WB_SRC_MD,
       ("chillus_result: late_wb with wb_src_wb=%s", wb_src_wb.name()))

  `undef CHK

endmodule

bind chillus_result chillus_result_chk #(.XLEN(XLEN)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .hold      (hold),
  .kill      (kill),
  .valid_wb  (valid_wb),
  .wb_src_wb (wb_src_wb),
  .rd_wb     (rd_wb),
  .result_ex (result_ex),
  .result_wb (result_wb),
  .late_wb   (late_wb),
  .adv_ex    (adv_ex),
  .rf_we     (rf_we),
  .rf_rd     (rf_rd)
);
