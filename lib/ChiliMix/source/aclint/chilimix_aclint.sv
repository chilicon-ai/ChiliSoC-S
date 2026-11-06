// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_aclint
//
// RISC-V ACLINT for N_HART harts (1 .. 8): MSWI (msip) and MTIMER (mtime,
// mtimecmp) in the SiFive CLINT layout, so existing CLINT drivers work, plus
// an SSWI device after them:
//   0x0000 + 4*h  msip[h]        bit 0 drives msip[h]
//   0x4000 + 8*h  mtimecmp[h]    64-bit, low word first; resets to all ones
//   0xBFF8        mtime          64-bit, low word first; writable; shared
//   0xC000 + 4*h  setssip[h]     writing 1 to bit 0 sets hart h's SSIP; reads 0
// Registers of harts h >= N_HART read 0 and ignore writes.
// mtime counts up by one on every tick (a timebase enable from the
// integration, e.g. basechili_frac_tick). A write to an mtime word loads its
// strobed bytes and wins over a tick in the same cycle; a write with no byte
// strobes changes nothing (the tick still counts).
// mtip[h] = mtime >= mtimecmp[h], registered. ssip_set[h] is a one-cycle
// pulse the cycle after a setssip[h] write with bit 0 set (PSTRB[0] high):
// the hart sets mip.SSIP and clears it itself.
//
// Timing    : APB reads are combinational (no wait states); mtime is
//             registered and moves the cycle after a tick or a write; mtip,
//             msip and ssip_set are registered (mtip one cycle after mtime /
//             mtimecmp change).
// Invariants: mtip[h] is the registered (mtime >= mtimecmp[h]) of the
//             previous cycle; mtime changes only by a tick (+1) or an mtime
//             write; ssip_set is zero or one-hot.
// Debug     : no timer interrupt -> u_mtime.count, mtimecmp, tick;
//             mtime not loading -> mtime_load (one bit per byte),
//             u_regs.mtime_lo_wr / mtime_hi_wr, PSTRB; no SSIP -> setssip_wr,
//             PWDATA[0], PSTRB[0].
// -----------------------------------------------------------------------------
module chilimix_aclint #(
  parameter int N_HART = 1        // harts (1 .. 8)
) (
  input  logic              clk,
  input  logic              rst_n,      // async, active-low
  // APB4 subordinate (registers)
  input  logic              PSEL,
  input  logic              PENABLE,
  input  logic              PWRITE,
  input  logic [15:0]       PADDR,      // byte address inside the ACLINT
  input  logic [31:0]       PWDATA,
  input  logic [3:0]        PSTRB,
  output logic              PREADY,
  output logic [31:0]       PRDATA,
  output logic              PSLVERR,
  // timebase and hart side
  input  logic              tick,       // count mtime up by one this cycle
  output logic [63:0]       mtime,      // for the harts' time CSR
  output logic [N_HART-1:0] mtip,       // machine timer interrupt pending, per hart
  output logic [N_HART-1:0] msip,       // machine software interrupt pending, per hart
  output logic [N_HART-1:0] ssip_set    // set the hart's supervisor software interrupt pending
);

  localparam int MAX_HART = 8;    // harts in the register map

  logic [MAX_HART-1:0]    msip_all;      // msip of every hart in the map (0 past N_HART)
  logic [MAX_HART*32-1:0] mtimecmp_lo;   // mtimecmp bits 31:0 of hart h at [h*32 +: 32]
  logic [MAX_HART*32-1:0] mtimecmp_hi;   // mtimecmp bits 63:32
  logic [N_HART*64-1:0]   mtimecmp;      // mtimecmp of hart h at [h*64 +: 64]
  logic [31:0]            mtime_lo;      // mtime bits 31:0 (read back)
  logic [31:0]            mtime_hi;      // mtime bits 63:32 (read back)
  logic                   mtime_lo_wr;   // APB write to mtime bits 31:0
  logic                   mtime_hi_wr;   // APB write to mtime bits 63:32
  logic [3:0]             hi_strb;       // PSTRB of an mtime_hi write
  logic [3:0]             lo_strb;       // PSTRB of an mtime_lo write
  logic [7:0]             mtime_load;    // load mtime byte b
  logic [63:0]            mtime_load_val;// PWDATA in both words
  logic [MAX_HART-1:0]    setssip_set;   // PWDATA[0] for every setssip word
  logic [MAX_HART-1:0]    setssip_wr;    // setssip[h] written this cycle
  logic [N_HART-1:0]      ssip_set_d;    // setssip write with bit 0 set
  logic [N_HART-1:0]      mtip_d;        // next mtip

  chilimix_aclint_regs #(.N_HART(N_HART)) u_regs (
    .clk               (clk),
    .rst_n             (rst_n),
    .PSEL              (PSEL),
    .PENABLE           (PENABLE),
    .PWRITE            (PWRITE),
    .PADDR             (PADDR),
    .PWDATA            (PWDATA),
    .PSTRB             (PSTRB),
    .PREADY            (PREADY),
    .PRDATA            (PRDATA),
    .PSLVERR           (PSLVERR),
    .msip_pending      (msip_all),
    .mtimecmp_lo_value (mtimecmp_lo),
    .mtimecmp_hi_value (mtimecmp_hi),
    .mtime_lo_value    (mtime_lo),
    .mtime_lo_wr       (mtime_lo_wr),
    .mtime_hi_value    (mtime_hi),
    .mtime_hi_wr       (mtime_hi_wr),
    .setssip_set       (setssip_set),
    .setssip_wr        (setssip_wr)
  );

  assign msip = msip_all[N_HART-1:0];

  // ---- mtime: 64-bit counter, loaded byte by byte from APB writes
  assign hi_strb        = PSTRB & {4{mtime_hi_wr}};
  assign lo_strb        = PSTRB & {4{mtime_lo_wr}};
  assign mtime_load     = {hi_strb, lo_strb};
  assign mtime_load_val = {PWDATA, PWDATA};

  basechili_wide_counter #(.WIDTH(64), .LO_W(32), .WORD_W(8)) u_mtime (
    .clk      (clk),
    .rst_n    (rst_n),
    .inc      (tick),
    .load     (mtime_load),
    .load_val (mtime_load_val),
    .count    (mtime)
  );

  assign mtime_lo = mtime[31:0];
  assign mtime_hi = mtime[63:32];

  // ---- mtip and ssip_set per hart
  for (genvar h = 0; h < N_HART; h++) begin : g_hart
    assign mtimecmp[h*64 +: 64] = {mtimecmp_hi[h*32 +: 32], mtimecmp_lo[h*32 +: 32]};
    assign mtip_d[h]            = mtime >= mtimecmp[h*64 +: 64];
    assign ssip_set_d[h]        = setssip_wr[h] && setssip_set[h] && PSTRB[0];
  end

  basechili_dff #(.WIDTH(2 * N_HART)) u_irq (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({mtip_d, ssip_set_d}),
    .q     ({mtip, ssip_set})
  );

endmodule
