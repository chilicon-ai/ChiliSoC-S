// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_rvfi_chk (bound into chillus_rvfi)
//   - valid_<s> == 0 -> every field of stage <s> is 0 (header Invariants;
//     wb: entry, load offset, reported load data)
//   - RVFI semantics (riscv-formal rvfi.md, header Fields):
//     rvfi_trap -> no rd write, no memory access; rvfi_rd_addr == 0 ->
//     rvfi_rd_wdata == 0; rvfi_order counts 0, 1, 2, ... per rvfi_valid;
//     rvfi_pc_rdata == pc_wdata of the previous report unless rvfi_intr (interrupt or debug entry);
//     rvfi_halt == 0, rvfi_mode is M (3) or U (0), rmask / wmask exclusive
//   (the cross-module part "rvfi_valid && !rvfi_trap == valid_wb && !kill[wb]"
//   is in chillus_core_chk)
// -----------------------------------------------------------------------------
module chillus_rvfi_chk #(
  parameter int XLEN    = 32,
  parameter int N_LANE  = 4,
  parameter int OFF_W   = 2,
  parameter int ENTRY_W = 300
) (
  input logic               clk,
  input logic               rst_n,
  input logic               valid_wb,
  input logic [ENTRY_W-1:0] entry_wb,
  input logic [OFF_W-1:0]   off_wb,
  input logic               rvfi_valid,
  input logic [63:0]        rvfi_order,
  input logic               rvfi_trap,
  input logic               rvfi_halt,
  input logic               rvfi_intr,
  input logic [1:0]         rvfi_mode,
  input logic [4:0]         rvfi_rd_addr,
  input logic [XLEN-1:0]    rvfi_rd_wdata,
  input logic [XLEN-1:0]    rvfi_pc_rdata,
  input logic [XLEN-1:0]    rvfi_pc_wdata,
  input logic [N_LANE-1:0]  rvfi_mem_rmask,
  input logic [N_LANE-1:0]  rvfi_mem_wmask,
  input logic [XLEN-1:0]    rvfi_mem_rdata
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic [63:0]     n_ret;        // reports so far
  logic [XLEN-1:0] last_pc_wdata;
  logic            seen;         // a report was seen

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_ret         <= '0;
      last_pc_wdata <= '0;
      seen          <= 1'b0;
    end else if (rvfi_valid) begin
      n_ret         <= n_ret + 64'd1;
      last_pc_wdata <= rvfi_pc_wdata;
      seen          <= 1'b1;
    end
  end

  `CHK(!valid_wb |-> entry_wb == '0 && off_wb == '0 && rvfi_mem_rdata == '0,
       ("chillus_rvfi: valid_wb == 0 -> wb fields 0 violated: off_wb=%0d mem_rdata=%h", off_wb, rvfi_mem_rdata))
  `CHK(rvfi_valid && rvfi_trap |-> rvfi_rd_addr == '0 && rvfi_mem_rmask == '0 && rvfi_mem_wmask == '0,
       ("chillus_rvfi: trap with rd write / memory access: pc=%h rd=x%0d rmask=%b wmask=%b",
        rvfi_pc_rdata, rvfi_rd_addr, rvfi_mem_rmask, rvfi_mem_wmask))
  `CHK(rvfi_rd_addr == '0 |-> rvfi_rd_wdata == '0,
       ("chillus_rvfi: rd_addr == 0 -> rd_wdata == 0 violated: rd_wdata=%h", rvfi_rd_wdata))
  `CHK(rvfi_valid |-> rvfi_order == n_ret,
       ("chillus_rvfi: rvfi_order not sequential: order=%0d expected=%0d", rvfi_order, n_ret))
  `CHK(rvfi_valid && seen && !rvfi_intr |-> rvfi_pc_rdata == last_pc_wdata,
       ("chillus_rvfi: pc_rdata != previous pc_wdata: pc_rdata=%h previous pc_wdata=%h order=%0d",
        rvfi_pc_rdata, last_pc_wdata, rvfi_order))
  `CHK(!rvfi_halt && (rvfi_mode == 2'b11 || rvfi_mode == 2'b00),
       ("chillus_rvfi: halt = 0 / mode M or U violated: halt=%b mode=%0d", rvfi_halt, rvfi_mode))
  `CHK((rvfi_mem_rmask & rvfi_mem_wmask) == '0 && !(rvfi_mem_rmask != '0 && rvfi_mem_wmask != '0),
       ("chillus_rvfi: both rmask and wmask set: rmask=%b wmask=%b", rvfi_mem_rmask, rvfi_mem_wmask))

  `undef CHK

endmodule

bind chillus_rvfi chillus_rvfi_chk #(
  .XLEN    (XLEN),
  .N_LANE  (N_LANE),
  .OFF_W   (OFF_W),
  .ENTRY_W (ENTRY_W)
) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .valid_wb       (valid_wb),
  .entry_wb       (entry_wb),
  .off_wb         (off_wb),
  .rvfi_valid     (rvfi_valid),
  .rvfi_order     (rvfi_order),
  .rvfi_trap      (rvfi_trap),
  .rvfi_halt      (rvfi_halt),
  .rvfi_intr      (rvfi_intr),
  .rvfi_mode      (rvfi_mode),
  .rvfi_rd_addr   (rvfi_rd_addr),
  .rvfi_rd_wdata  (rvfi_rd_wdata),
  .rvfi_pc_rdata  (rvfi_pc_rdata),
  .rvfi_pc_wdata  (rvfi_pc_wdata),
  .rvfi_mem_rmask (rvfi_mem_rmask),
  .rvfi_mem_wmask (rvfi_mem_wmask),
  .rvfi_mem_rdata (rvfi_mem_rdata)
);
