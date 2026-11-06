// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_result
//
// Result pipeline and write-back of the in-order pipeline id -> ex -> wb
// (pipeline-aware: uses the STAGE_* indices and the decoder's hold / kill).
//
//   ex : result_ex = wb_src_ex  ALU -> alu_result, LINK -> link (branch
//        unit), CSR -> csr_rdata (old CSR value), MD -> md_result (multiply
//        / divide unit, valid when the instruction leaves ex), MEM -> 0
//        (loaded later)
//   wb : result_wb, registered from ex (forwarding source of chillus_sb)
//        late MUL (md_late in ex, late_wb in wb): its product
//        (md_late_result) exists only in wb; result_wb holds a dummy and is
//        never forwarded (chillus_scoreboard stalls the consumer)
//        register file write: rf_wdata = load_data (LSU, combinational from
//        the data MSS rdata) for wb_src MEM, md_late_result for a late MUL,
//        else result_wb; rd_wb is written when valid_wb && !hold[wb] &&
//        !kill[wb] (a load / store waiting for rvalid holds wb; a bus error
//        kills it)
//
// The ex -> wb registers follow the decoder's rule exactly (load when
// !hold[wb] || kill[wb]; the ex value when it advances, else a bubble = 0),
// so result_wb stays aligned with rd_wb. rd_wb = 0 (bubble, or no
// destination) makes the write a no-op in chillus_rf.
//
// Timing   : result_wb is a register; rf_wdata is combinational from
//            load_data (data MSS rdata), the multiplier's stage registers
//            and result_wb; rf_we from the decoder's hold / kill of wb.
// Invariant: late_wb -> wb_src_wb == MD.
// Debug    : result_ex shows the ex value; wrong load result -> load_data and
//            wb_src_wb; wrong ALU / link / CSR / MD result -> result_ex in ex;
//            wrong MUL -> late_wb, md_late_result.
// -----------------------------------------------------------------------------
module chillus_result
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                          // register width
) (
  input  logic                clk,
  input  logic                rst_n,               // async, active-low
  // pipeline control (decoder)
  input  logic [N_STAGES-1:0] hold,
  input  logic [N_STAGES-1:0] kill,
  // ex
  input  logic                valid_ex,
  input  wb_src_e             wb_src_ex,
  input  logic [XLEN-1:0]     alu_result,
  input  logic [XLEN-1:0]     link,                // branch unit: pc + 4 / pc + 2
  input  logic [XLEN-1:0]     csr_rdata,           // CSR unit: old CSR value
  input  logic [XLEN-1:0]     md_result,           // multiply / divide unit
  input  logic                md_late,             // late MUL in ex: result is md_late_result in wb
  input  logic [XLEN-1:0]     md_late_result,      // late MUL product (valid with late_wb)
  // wb
  input  logic                valid_wb,
  input  wb_src_e             wb_src_wb,
  input  logic [4:0]          rd_wb,
  input  logic [XLEN-1:0]     load_data,           // LSU: the load value in its rvalid cycle
  output logic [XLEN-1:0]     result_wb,           // result register (forwarding source)
  // register file write port
  output logic                rf_we,
  output logic [4:0]          rf_rd,
  output logic [XLEN-1:0]     rf_wdata
);

  logic [XLEN-1:0] result_ex;       // value produced in ex
  logic            adv_ex;          // the ex instruction moves to wb at this edge
  logic            en_wb;
  logic [XLEN-1:0] result_wb_d;
  logic            late_wb;         // a late MUL is in wb
  logic            late_wb_d;

  // ---------------------------------------------------------------------------
  // ex: result selection
  // ---------------------------------------------------------------------------
  always_comb begin
    case (wb_src_ex)
      WB_SRC_ALU:  result_ex = alu_result;
      WB_SRC_LINK: result_ex = link;
      WB_SRC_CSR:  result_ex = csr_rdata;
      WB_SRC_MD:   result_ex = md_result;
      WB_SRC_MEM:  result_ex = '0;
      default:     result_ex = '0;
    endcase
  end

  // ---------------------------------------------------------------------------
  // ex -> wb
  // ---------------------------------------------------------------------------
  assign adv_ex      = valid_ex && !hold[STAGE_EX] && !kill[STAGE_EX];
  assign en_wb       = !hold[STAGE_WB] || kill[STAGE_WB];
  assign result_wb_d = adv_ex ? result_ex : '0;
  assign late_wb_d   = adv_ex && md_late;

  basechili_dffe #(.WIDTH(XLEN)) u_result_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (result_wb_d),
    .q     (result_wb)
  );

  basechili_dffe #(.WIDTH(1)) u_late_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (late_wb_d),
    .q     (late_wb)
  );

  // ---------------------------------------------------------------------------
  // wb: register file write
  // ---------------------------------------------------------------------------
  assign rf_we    = valid_wb && !hold[STAGE_WB] && !kill[STAGE_WB];
  assign rf_rd    = rd_wb;
  assign rf_wdata = (wb_src_wb == WB_SRC_MEM) ? load_data :
                    late_wb                   ? md_late_result :
                                                result_wb;

endmodule
