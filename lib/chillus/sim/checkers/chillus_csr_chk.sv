// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_csr_chk (bound into chillus_csr)
//   - retire_q && unretire_q never both set               (header Invariants)
//   - writes happen only when the instruction leaves the stage (in_valid &&
//     !stall) and never for an illegal access (header)
//   - mcycle counts every cycle unless mcountinhibit.CY, count_stop or a write (header
//     Counters)
//   - minstret_now advances by exactly the retire / unretire pulses of the
//     previous cycle, or takes the written value (header Counters; the
//     cross-module "minstret_now == retired instructions" part is in
//     chillus_core_chk)
//   - mcountinhibit / counter writes: retire is not counted for the
//     instruction that writes minstret ("its write replaces it")
// -----------------------------------------------------------------------------
module chillus_csr_chk #(
  parameter int XLEN = 32
) (
  input logic        clk,
  input logic        rst_n,
  input logic        stall,
  input logic        in_valid,
  input logic        illegal,
  input logic        do_write,
  input logic        retire_q,
  input logic        unretire_q,
  input logic        retire_d,
  input logic        unretire_d,
  input logic [63:0] mcycle,
  input logic        mcycle_ld,
  input logic [63:0] minstret_now,
  input logic        minstret_ld,
  input logic [63:0] minstret_ld_val,
  input logic [1:0]  inhibit,
  input logic        count_stop
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic [63:0] instret_exp;   // minstret_now expected this cycle (from the previous one)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) instret_exp <= '0;
    else        instret_exp <= (minstret_ld ? minstret_ld_val : minstret_now)
                               + 64'(retire_d) - 64'(unretire_d);
  end

  `CHK(!(retire_q && unretire_q),
       ("chillus_csr: retire_q && unretire_q both set"))
  `CHK(do_write |-> in_valid && !stall && !illegal,
       ("chillus_csr: write while not leaving the stage / illegal: in_valid=%b stall=%b illegal=%b",
        in_valid, stall, illegal))
  `CHK(retire_d |-> !minstret_ld,
       ("chillus_csr: minstret write counted as a retire"))
  `CHK(!mcycle_ld && !inhibit[0] && !count_stop |=> mcycle == $past(mcycle) + 64'd1,
       ("chillus_csr: mcycle +1 per cycle violated: mcycle=%h before=%h", mcycle, $past(mcycle)))
  `CHK(!mcycle_ld && (inhibit[0] || count_stop) |=> $stable(mcycle),
       ("chillus_csr: mcycle counted while inhibited: mcycle=%h before=%h", mcycle, $past(mcycle)))
  `CHK(minstret_now == instret_exp,
       ("chillus_csr: minstret_now != previous + retire - unretire (or written value): minstret_now=%h expected=%h",
        minstret_now, instret_exp))

  `undef CHK

endmodule

bind chillus_csr chillus_csr_chk #(.XLEN(XLEN)) u_chk (
  .clk             (clk),
  .rst_n           (rst_n),
  .stall           (stall),
  .in_valid        (in_valid),
  .illegal         (illegal),
  .do_write        (do_write),
  .retire_q        (retire_q),
  .unretire_q      (unretire_q),
  .retire_d        (retire_d),
  .unretire_d      (unretire_d),
  .mcycle          (mcycle),
  .mcycle_ld       (mcycle_ld),
  .minstret_now    (minstret_now),
  .minstret_ld     (minstret_ld),
  .minstret_ld_val (minstret_ld_val),
  .inhibit         (inhibit),
  .count_stop      (count_stop)
);
