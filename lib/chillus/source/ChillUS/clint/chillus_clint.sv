// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_clint
//
// Core-local interruptor for one hart (SiFive CLINT layout = RISC-V ACLINT
// MSWI at offset 0x0000 + MTIMER at offset 0x4000; riscv-privileged.pdf
// 3.2.1 Machine Timer Registers). Platform peripheral, mapped by the
// testbench (base 0x0200_0000, as Spike); ChiliSoC-S uses ChiliMix's
// chilimix_aclint instead.
//
// Register map (byte offsets, 32-bit registers, little-endian)
//   0x0000  msip           bit 0 R/W (MSIP), bits 31:1 read 0
//   0x4000  mtimecmp[31:0]
//   0x4004  mtimecmp[63:32]
//   0xBFF8  mtime[31:0]
//   0xBFFC  mtime[63:32]
//   any other offset: reads 0, writes ignored (no error).
// Only req_addr[15:2] is decoded (word access); req_addr[1:0] is ignored.
// Writes honor req_strb per byte lane: written word = (old & ~mask) |
// (req_wdata & mask), mask = byte lanes of req_strb.
//
// mtime: 64-bit counter, +1 at every clock edge where tick = 1 (tie tick to 1
// for one increment per clock). A software write to mtime (either half, any
// strobes) replaces the whole 64-bit increment at that edge, as the core's
// mcycle: the written half takes the merged write word and the other half
// holds its value (no increment, no carry). So a read after the write
// returns exactly the written value, whatever tick was.
// Reset: mtime = 0, msip = 0, mtimecmp = all ones (no timer interrupt).
//
// irq_timer (MTIP) = mtime >= mtimecmp (64-bit unsigned compare),
// irq_software (MSIP) = msip[0]. Both are level, held until software changes
// mtimecmp / mtime / msip.
//
// Updating mtimecmp from a 32-bit hart without a spurious interrupt (the
// standard sequence, riscv-privileged.pdf 3.2.1) is supported, since each
// write takes effect at its own edge:
//   sw  -1,   0x4004  # mtimecmp hi = all ones: compare cannot be true
//   sw  lo,   0x4000  # new low word
//   sw  hi,   0x4004  # new high word
//
// Register port (same protocol as the core's data MSS port; no stall output,
// every request is taken): a request is taken at a clock edge with req_valid.
// A write updates its register at that edge. A read samples the addressed
// register's value before that edge (mtime before that edge's increment)
// into ack_rdata, which holds it until the next read.
//
// Timing
//   ack_rdata   : registered, valid after the edge that takes the read.
//   mtime       : registered (u_mtime.count).
//   irq_software: registered (msip), changes at the edge that takes the write.
//   irq_timer   : combinational compare of registers only (mtime, mtimecmp),
//                 so it reflects a mtimecmp / mtime write or a tick in the
//                 cycle right after that edge (0 cycles after the registers).
//
// Invariants
//   irq_timer == (mtime >= mtimecmp) every cycle.
//   mtime changes only by +1 (tick, no write) or by a write to 0xBFF8 / 0xBFFC.
//
// Debug
//   Timer interrupt missing / spurious: compare mtime with mtimecmp
//   (u_mtimecmp_lo.q, u_mtimecmp_hi.q); check that tick is toggling.
//   Write lost: sel_* decode of req_addr, wmask (from req_strb), wword.
//   Wrong read data: rword (selected register) at the read edge, rd_en.
// -----------------------------------------------------------------------------
module chillus_clint #(
  parameter  int XLEN   = 32,                     // register port width (32 only)
  localparam int N_LANE = XLEN / 8                // byte lanes on the register port
) (
  input  logic              clk,
  input  logic              rst_n,                // async, active-low
  input  logic              tick,                 // mtime increments on edges where tick = 1

  // register port: a request is taken at every edge with req_valid
  input  logic              req_valid,
  input  logic              req_write,            // 1 = write, 0 = read
  input  logic [15:0]       req_addr,             // byte offset within the CLINT (word aligned)
  input  logic [N_LANE-1:0] req_strb,             // byte enables (writes)
  input  logic [XLEN-1:0]   req_wdata,
  output logic [XLEN-1:0]   ack_rdata,            // read word, held until the next read

  // to the hart
  output logic [63:0]       mtime,                // time / timeh CSRs
  output logic              irq_timer,            // MTIP: mtime >= mtimecmp (unsigned)
  output logic              irq_software          // MSIP: msip[0]
);

  // word offsets (byte offset >> 2)
  localparam logic [13:0] W_MSIP        = 14'(16'h0000 >> 2);
  localparam logic [13:0] W_MTIMECMP_LO = 14'(16'h4000 >> 2);
  localparam logic [13:0] W_MTIMECMP_HI = 14'(16'h4004 >> 2);
  localparam logic [13:0] W_MTIME_LO    = 14'(16'hBFF8 >> 2);
  localparam logic [13:0] W_MTIME_HI    = 14'(16'hBFFC >> 2);

  logic [13:0]     waddr;          // word offset: req_addr[15:2]
  logic            sel_msip;       // req_addr names msip
  logic            sel_cmp_lo;     // req_addr names mtimecmp[31:0]
  logic            sel_cmp_hi;     // req_addr names mtimecmp[63:32]
  logic            sel_time_lo;    // req_addr names mtime[31:0]
  logic            sel_time_hi;    // req_addr names mtime[63:32]
  logic [XLEN-1:0] rword;          // addressed register's current value (0 if unmapped)
  logic [XLEN-1:0] wmask;          // bit mask of the written byte lanes
  logic [XLEN-1:0] wword;          // rword with the written byte lanes replaced
  logic            wr;             // a write is taken at this edge
  logic            rd_en;          // a read is taken at this edge: ack_rdata loads rword

  logic            msip;           // MSIP bit
  logic            msip_en;
  logic [63:0]     mtimecmp;       // {u_mtimecmp_hi.q, u_mtimecmp_lo.q}
  logic            mtimecmp_lo_en;
  logic            mtimecmp_hi_en;
  logic            mtime_ld;       // write of either mtime half: replaces the increment
  logic [63:0]     mtime_ld_val;   // mtime with the written half replaced by wword

  // ---------------------------------------------------------------------------
  // Decode and read mux
  // ---------------------------------------------------------------------------
  assign waddr       = req_addr[15:2];
  assign sel_msip    = (waddr == W_MSIP);
  assign sel_cmp_lo  = (waddr == W_MTIMECMP_LO);
  assign sel_cmp_hi  = (waddr == W_MTIMECMP_HI);
  assign sel_time_lo = (waddr == W_MTIME_LO);
  assign sel_time_hi = (waddr == W_MTIME_HI);

  always_comb begin
    if (sel_msip)         rword = XLEN'(msip);
    else if (sel_cmp_lo)  rword = XLEN'(mtimecmp[31:0]);
    else if (sel_cmp_hi)  rword = XLEN'(mtimecmp[63:32]);
    else if (sel_time_lo) rword = XLEN'(mtime[31:0]);
    else if (sel_time_hi) rword = XLEN'(mtime[63:32]);
    else                  rword = '0;
  end

  // byte-lane write merge into the addressed register's current value
  always_comb begin
    for (int i = 0; i < N_LANE; i++) begin
      wmask[8*i +: 8] = {8{req_strb[i]}};
    end
  end

  assign wword = (rword & ~wmask) | (req_wdata & wmask);
  assign wr    = req_valid && req_write;
  assign rd_en = req_valid && !req_write;

  // ---------------------------------------------------------------------------
  // Read data: sampled at the edge that takes the read
  // ---------------------------------------------------------------------------
  basechili_dffe #(.WIDTH(XLEN)) u_ack_rdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rd_en),
    .d     (rword),
    .q     (ack_rdata)
  );

  // ---------------------------------------------------------------------------
  // msip
  // ---------------------------------------------------------------------------
  assign msip_en = wr && sel_msip;

  basechili_dffe #(.WIDTH(1)) u_msip (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (msip_en),
    .d     (wword[0]),
    .q     (msip)
  );

  assign irq_software = msip;

  // ---------------------------------------------------------------------------
  // mtimecmp: reset to all ones
  // ---------------------------------------------------------------------------
  assign mtimecmp_lo_en = wr && sel_cmp_lo;
  assign mtimecmp_hi_en = wr && sel_cmp_hi;

  basechili_dffe #(.WIDTH(32), .RESET_VAL('1)) u_mtimecmp_lo (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mtimecmp_lo_en),
    .d     (wword[31:0]),
    .q     (mtimecmp[31:0])
  );

  basechili_dffe #(.WIDTH(32), .RESET_VAL('1)) u_mtimecmp_hi (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mtimecmp_hi_en),
    .d     (wword[31:0]),
    .q     (mtimecmp[63:32])
  );

  // ---------------------------------------------------------------------------
  // mtime: +1 per tick; a write of either half replaces the increment
  // ---------------------------------------------------------------------------
  assign mtime_ld     = wr && (sel_time_lo || sel_time_hi);
  assign mtime_ld_val = sel_time_hi ? {wword[31:0], mtime[31:0]} :
                                      {mtime[63:32], wword[31:0]};

  basechili_updown_counter #(.WIDTH(64)) u_mtime (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (mtime_ld),
    .load_val (mtime_ld_val),
    .inc      (tick),
    .dec      (1'b0),
    .count    (mtime),
    .count_d  ()
  );

  assign irq_timer = (mtime >= mtimecmp);

endmodule
