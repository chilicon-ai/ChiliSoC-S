// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_rf
//
// RV32I integer register file (riscv-unprivileged.pdf, Chapter 2.1): x0..x31,
// XLEN bits each. x0 is hardwired to zero and has no storage. Two
// combinational read ports (rs1, rs2) and one write port (rd).
// Storage for x1..x31 is BaseChiliSV basechili_latch_array (LATCH = 1, the
// default: latches written through clock gates, one XLEN-bit write-data flop)
// or basechili_reg_array (LATCH = 0: flops, reset to zero). Latch entries are
// not reset; the ISA leaves the registers undefined after reset.
// test_en (scan / test) opens the latch array's clock gates; 0 in
// functional mode. The flop array has no gates and ignores it.
// Register x<i> is array entry ~i (5-bit invert, x31 = entry 0, x1 = entry
// 30): x0 maps to entry 31, which a 31-entry array does not have, so reads of
// x0 return zero and writes to x0 are dropped by the array itself.
//
// Timing
//   rs*_data follows rs*_addr combinationally. A write is stored on the clock
//   edge where rd_we is high (LATCH: the entry's latches are open for that
//   edge's high phase and hold the write-data flop's value). With BYPASS = 1
//   a read of the register being written in the same cycle returns rd_data
//   (write-before-read), so WB -> ID needs no extra forwarding; this adds a
//   path rd_data -> rs*_data.
//
// Invariants
//   rs*_addr == 0 -> rs*_data == 0.
//   A write with rd_addr == 0 changes nothing.
//
// Debug
//   Register x<i> is g_latch.u_regs.mem (or g_flop.u_regs.mem) at
//   [(31-i)*XLEN +: XLEN]; in simulation the checker gives each register its
//   ABI name (u_chk.x1_ra, u_chk.x2_sp, u_chk.x10_a0, ...). A missed write ->
//   g_latch.u_regs.wen / gclk of entry 31-rd_addr. A read value one write too
//   old: check BYPASS and that rd_we / rd_addr come from the stage that
//   retires the instruction.
// -----------------------------------------------------------------------------
module chillus_rf #(
  parameter int XLEN   = 32,      // register width (RV32: 32)
  parameter bit BYPASS = 1'b1,    // same-cycle write visible on the read ports
  parameter bit LATCH  = 1'b1     // latch storage (basechili_latch_array); 0: flops
) (
  input  logic            clk,
  input  logic            rst_n,      // async, active-low
  input  logic            test_en,    // scan / test: open the latch array's clock gates
  // read port 1
  input  logic [4:0]      rs1_addr,
  output logic [XLEN-1:0] rs1_data,
  // read port 2
  input  logic [4:0]      rs2_addr,
  output logic [XLEN-1:0] rs2_data,
  // write port
  input  logic            rd_we,
  input  logic [4:0]      rd_addr,    // 0 (x0): write ignored
  input  logic [XLEN-1:0] rd_data
);

  localparam int N_ENTRIES = 31;      // x1..x31

  logic [4:0]        rd_idx;          // array entry of rd (~rd_addr; x0 -> 31, dropped)
  logic [9:0]        rs_idx;          // array entries of {rs2, rs1} (x0 -> 31, reads zero)
  logic [2*XLEN-1:0] rs_stored;       // {rs2, rs1} values from the array
  logic [XLEN-1:0]   rs1_stored;      // rs1 value from the array
  logic [XLEN-1:0]   rs2_stored;      // rs2 value from the array
  logic              rs1_bypass;      // rs1 is being written this cycle
  logic              rs2_bypass;      // rs2 is being written this cycle

  // ---------------------------------------------------------------------------
  // Storage: x1..x31
  // ---------------------------------------------------------------------------
  assign rd_idx  = ~rd_addr;
  assign rs_idx  = {~rs2_addr, ~rs1_addr};

  if (LATCH) begin : g_latch
    basechili_latch_array #(.WIDTH(XLEN), .DEPTH(N_ENTRIES), .N_RD(2)) u_regs (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .we      (rd_we),
      .waddr   (rd_idx),
      .wdata   (rd_data),
      .raddr   (rs_idx),
      .rdata   (rs_stored)
    );
  end else begin : g_flop
    basechili_reg_array #(.WIDTH(XLEN), .DEPTH(N_ENTRIES), .N_RD(2)) u_regs (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .we      (rd_we),
      .waddr   (rd_idx),
      .wdata   (rd_data),
      .raddr   (rs_idx),
      .rdata   (rs_stored)
    );
  end

  // ---------------------------------------------------------------------------
  // Read ports
  // ---------------------------------------------------------------------------
  assign rs1_stored = rs_stored[0 +: XLEN];
  assign rs2_stored = rs_stored[XLEN +: XLEN];

  // x0 is never bypassed: a write to x0 is ignored.
  assign rs1_bypass = BYPASS && rd_we && (rd_addr == rs1_addr) && (rs1_addr != '0);
  assign rs2_bypass = BYPASS && rd_we && (rd_addr == rs2_addr) && (rs2_addr != '0);

  assign rs1_data = rs1_bypass ? rd_data : rs1_stored;
  assign rs2_data = rs2_bypass ? rd_data : rs2_stored;

endmodule
