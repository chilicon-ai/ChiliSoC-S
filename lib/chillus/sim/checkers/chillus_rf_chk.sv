// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_rf_chk (bound into chillus_rf)
//   - rs*_addr == 0 -> rs*_data == 0                     (header Invariants)
//   - a write with rd_addr == 0 changes nothing: x0 reads stay zero and the
//     storage entries keep the written values             (header Invariants)
//   - reference model: the storage (u_regs.mem, entry 31-i = x<i>) equals a
//     shadow copy of all writes for every register written since reset, and
//     each read port returns the shadow value (rd_data when BYPASS and the
//     register is written in the same cycle). With LATCH = 1 a register not
//     yet written is undefined (latches are not reset) and is not compared;
//     with LATCH = 0 every register starts at zero.     (header Timing)
// Debug: x1_ra, x2_sp, ... x31_t6 are the shadow (architectural) values.
// -----------------------------------------------------------------------------
module chillus_rf_chk #(
  parameter int XLEN   = 32,
  parameter bit BYPASS = 1'b1,
  parameter bit LATCH  = 1'b1
) (
  input logic             clk,
  input logic             rst_n,
  input logic [4:0]       rs1_addr,
  input logic [XLEN-1:0]  rs1_data,
  input logic [4:0]       rs2_addr,
  input logic [XLEN-1:0]  rs2_data,
  input logic             rd_we,
  input logic [4:0]       rd_addr,
  input logic [XLEN-1:0]  rd_data
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic [31*XLEN-1:0] mem;      // chillus_rf storage (u_regs.mem): x<i> at entry 31-i
  logic [32*XLEN-1:0] shadow;   // x<i> at shadow[i*XLEN +: XLEN]
  logic [31:0]        valid;    // x<i> written since reset (all with LATCH = 0)
  logic [32*XLEN-1:0] stored;   // mem in register order: x<i> at stored[i*XLEN +: XLEN]
  logic [32*XLEN-1:0] vmask;    // valid, one bit per data bit
  logic [XLEN-1:0]    exp1, exp2;
  logic               chk1, chk2;   // the read is defined (compare it)

  // upward references into the bound chillus_rf: the selected storage branch
  if (LATCH) begin : g_mem_latch
    assign mem = g_latch.u_regs.mem;
  end else begin : g_mem_flop
    assign mem = g_flop.u_regs.mem;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shadow <= '0;
      valid  <= LATCH ? 32'h1 : '1;       // x0 always defined
    end else if (rd_we && rd_addr != '0) begin
      shadow[rd_addr*XLEN +: XLEN] <= rd_data;
      valid[rd_addr]               <= 1'b1;
    end
  end

  always_comb begin
    stored = '0;
    vmask  = '0;
    for (int i = 1; i < 32; i++) begin
      stored[i*XLEN +: XLEN] = mem[(31-i)*XLEN +: XLEN];
      vmask[i*XLEN +: XLEN]  = {XLEN{valid[i]}};
    end
    exp1 = shadow[rs1_addr*XLEN +: XLEN];
    exp2 = shadow[rs2_addr*XLEN +: XLEN];
    chk1 = valid[rs1_addr];
    chk2 = valid[rs2_addr];
    if (BYPASS && rd_we && rd_addr != '0 && rd_addr == rs1_addr) begin exp1 = rd_data; chk1 = 1'b1; end
    if (BYPASS && rd_we && rd_addr != '0 && rd_addr == rs2_addr) begin exp2 = rd_data; chk2 = 1'b1; end
  end

  `CHK(rs1_addr == '0 |-> rs1_data == '0,
       ("chillus_rf: rs1_addr == 0 -> rs1_data == 0 violated: rs1_data=%h", rs1_data))
  `CHK(rs2_addr == '0 |-> rs2_data == '0,
       ("chillus_rf: rs2_addr == 0 -> rs2_data == 0 violated: rs2_data=%h", rs2_data))
  `CHK((stored & vmask) == (shadow & vmask),
       ("chillus_rf: stored registers != written values (shadow model)"))
  `CHK(chk1 |-> rs1_data == exp1,
       ("chillus_rf: rs1 read != model: rs1_addr=%0d rs1_data=%h expected=%h", rs1_addr, rs1_data, exp1))
  `CHK(chk2 |-> rs2_data == exp2,
       ("chillus_rf: rs2 read != model: rs2_addr=%0d rs2_data=%h expected=%h", rs2_addr, rs2_data, exp2))

  `undef CHK

  // Debug view: registers by ABI name (shadow, i.e. architectural values)
  logic [XLEN-1:0] x1_ra,  x2_sp,  x3_gp,  x4_tp,  x5_t0,  x6_t1,  x7_t2;
  logic [XLEN-1:0] x8_s0,  x9_s1,  x10_a0, x11_a1, x12_a2, x13_a3, x14_a4;
  logic [XLEN-1:0] x15_a5, x16_a6, x17_a7, x18_s2, x19_s3, x20_s4, x21_s5;
  logic [XLEN-1:0] x22_s6, x23_s7, x24_s8, x25_s9, x26_s10, x27_s11;
  logic [XLEN-1:0] x28_t3, x29_t4, x30_t5, x31_t6;
  assign x1_ra   = shadow[ 1*XLEN +: XLEN];
  assign x2_sp   = shadow[ 2*XLEN +: XLEN];
  assign x3_gp   = shadow[ 3*XLEN +: XLEN];
  assign x4_tp   = shadow[ 4*XLEN +: XLEN];
  assign x5_t0   = shadow[ 5*XLEN +: XLEN];
  assign x6_t1   = shadow[ 6*XLEN +: XLEN];
  assign x7_t2   = shadow[ 7*XLEN +: XLEN];
  assign x8_s0   = shadow[ 8*XLEN +: XLEN];
  assign x9_s1   = shadow[ 9*XLEN +: XLEN];
  assign x10_a0  = shadow[10*XLEN +: XLEN];
  assign x11_a1  = shadow[11*XLEN +: XLEN];
  assign x12_a2  = shadow[12*XLEN +: XLEN];
  assign x13_a3  = shadow[13*XLEN +: XLEN];
  assign x14_a4  = shadow[14*XLEN +: XLEN];
  assign x15_a5  = shadow[15*XLEN +: XLEN];
  assign x16_a6  = shadow[16*XLEN +: XLEN];
  assign x17_a7  = shadow[17*XLEN +: XLEN];
  assign x18_s2  = shadow[18*XLEN +: XLEN];
  assign x19_s3  = shadow[19*XLEN +: XLEN];
  assign x20_s4  = shadow[20*XLEN +: XLEN];
  assign x21_s5  = shadow[21*XLEN +: XLEN];
  assign x22_s6  = shadow[22*XLEN +: XLEN];
  assign x23_s7  = shadow[23*XLEN +: XLEN];
  assign x24_s8  = shadow[24*XLEN +: XLEN];
  assign x25_s9  = shadow[25*XLEN +: XLEN];
  assign x26_s10 = shadow[26*XLEN +: XLEN];
  assign x27_s11 = shadow[27*XLEN +: XLEN];
  assign x28_t3  = shadow[28*XLEN +: XLEN];
  assign x29_t4  = shadow[29*XLEN +: XLEN];
  assign x30_t5  = shadow[30*XLEN +: XLEN];
  assign x31_t6  = shadow[31*XLEN +: XLEN];

endmodule

bind chillus_rf chillus_rf_chk #(.XLEN(XLEN), .BYPASS(BYPASS), .LATCH(LATCH)) u_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .rs1_addr (rs1_addr),
  .rs1_data (rs1_data),
  .rs2_addr (rs2_addr),
  .rs2_data (rs2_data),
  .rd_we    (rd_we),
  .rd_addr  (rd_addr),
  .rd_data  (rd_data)
);
