// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_csr
//
// Executes the Zicsr instructions (riscv-unprivileged.pdf, Chapter 6) for an
// M / U-mode core. Stage-agnostic; it must work in the same stage as
// chillus_trap (first top: ex), whose CSRs it reaches through the trap_csr_*
// port. The debug unit (chillus_dbg), the trigger unit (chillus_trig) and
// the PMP (chillus_pmp) sit on the same address / write bus (trap_csr_addr
// / we / wdata) and answer on their *_csr_rdata / *_csr_hit.
//
//   src     = csr_uimm ? imm (zero-extended uimm) : rs1_data
//   CSRRW[I] new = src         CSRRS[I] new = old | src   CSRRC[I] new = old & ~src
//   rdata   = old CSR value (written to rd by the write-back)
//
// Write suppression (Table 7): CSRRS / CSRRC with rs1 = x0 (the register
// number) and CSRRSI / CSRRCI with uimm = 0 do not write, and so raise no
// illegal-instruction exception on a read-only CSR. CSRRW[I] with rd = x0
// would not read; no CSR here has read side effects, so it is read anyway.
//
// Privilege (riscv-privileged.pdf 2.1, 3.1.11): in U-mode (priv_m = 0) a
// CSR whose address bits [9:8] are not 00 is illegal, and so are cycle /
// time / instret[h] unless their mcounteren bit (CY / TM / IR) is set. The
// debug CSRs need debug mode (M-mode) anyway.
//
// CSRs
//   chillus_trap : mstatus 0x300, mie 0x304, mtvec 0x305, mepc 0x341,
//                 mcause 0x342, mtval 0x343, mip 0x344
//   chillus_dbg : dcsr 0x7B0, dpc 0x7B1, dscratch0 0x7B2, dscratch1 0x7B3,
//                 in debug mode only (dbg_csr_hit low outside: illegal)
//   chillus_trig: tselect 0x7A0, tdata1..3 0x7A1..0x7A3, tinfo 0x7A4,
//                 tcontrol 0x7A5 (none with NUM_TRIGGERS = 0: illegal)
//   here        : mscratch 0x340 (read / write)
//                 counters (Zicntr, riscv-privileged.pdf 3.1.10 / 3.1.12):
//                   mcycle 0xB00, minstret 0xB02, mcycleh 0xB80, minstreth 0xB82
//                   (read / write; ...h only for XLEN 32), read-only shadows
//                   cycle 0xC00, instret 0xC02, cycleh 0xC80, instreth 0xC82
//                 mcountinhibit 0x320: CY [0], IR [2] (read / write), others 0
//                 time 0xC01, timeh 0xC81 (XLEN 32): read-only copy of the
//                 platform's mtime (CLINT) on the mtime input
//                 misa 0x301: MXL (XLEN) and MISA_EXT (generated from the
//                 decoder's extensions: I, M, C); read-only, writes ignored
//                 mstatush 0x310: read 0, writes ignored
//                 mcounteren 0x306: CY [0], TM [1], IR [2] (read / write),
//                 others 0 (no hpmcounters)
//                 menvcfg 0x30A, menvcfgh 0x31A (XLEN 32): read 0, writes
//                 ignored (FIOM may read 0 without S-mode, as Spike)
//                 hardware performance monitor (no counters):
//                   mhpmcounter3..31 0xB03-0xB1F, mhpmcounter3h..31h
//                   0xB83-0xB9F (XLEN 32), mhpmevent3..31 0x323-0x33F
//                 PMP CSRs beyond chillus_pmp's entries (riscv-privileged
//                 3.7.1: all PMP CSRs exist, fields WARL / read-only zero;
//                 chillus_pmp answers pmpcfg0 and its pmpaddr first):
//                   pmpcfg0..15 0x3A0-0x3AF (odd ones XLEN 32 only),
//                   pmpaddr0..63 0x3B0-0x3EF
//                 all of these: read 0, writes ignored
//                 mvendorid 0xF11, marchid 0xF12, mimpid 0xF13, mconfigptr
//                 0xF15: read-only 0
//                 mhartid 0xF14: read-only, the hart_id input
//   illegal     : any other address, a write to a read-only address
//                 (csr_addr[11:10] == 11), or a U-mode access above
//                 (priv_fail). The write is then not performed.
//                 Not implemented, so illegal: hpmcounter3..31[h] (no Zihpm),
//                 mcontext / mscontext, custom CSRs 0x7C0 / 0x7C1;
//                 the debug CSRs outside debug mode; the trigger CSRs with
//                 NUM_TRIGGERS = 0.
//
// Writes happen only when the instruction leaves the stage (in_valid &&
// !stall), so a held instruction writes once.
//
// Counters: 64 bits, reset to 0. mcycle counts every clock cycle, minstret
// every retire pulse (an instruction leaves the stage without a trap; traps
// are taken in this stage, so all older instructions are counted when a CSR
// instruction reads minstret here). The one exception, a load / store that
// gets a bus error after leaving this stage, is taken back by an unretire
// pulse (decrement) in the cycle of its trap. A CSR write of a counter (or its
// upper half) replaces that cycle's increment, so the next instruction reads
// the written value (riscv-privileged.pdf 3.1.10, as Spike).
// mcountinhibit.CY / IR stop mcycle / minstret; count_stop (dcsr.stopcount
// in debug mode) stops both.
// minstret counts one cycle late (timing: retire comes from the trap
// decision): the retire / unretire pulses are registered (retire_q /
// unretire_q) and applied at the next edge; a read in between, and the base
// of a partial (minstreth) write, use minstret_now = the counter with the
// pending pulse applied, so software sees no difference.
//
// Timing   : combinational except mscratch, the counters and mcountinhibit
//            (updated at the clock edge).
// Invariants
//   minstret_now == retired instructions (rvfi_valid && !rvfi_trap) plus the
//   non-trapping ones in later stages, since the last minstret write and
//   while mcountinhibit.IR and count_stop are clear (ir_stop low).
//   retire_q && unretire_q never both set.
//   !priv_m && is_csr && csr_addr[9:8] != 0 -> illegal.
// Debug    : old / src / new_value show the read-modify-write; do_write is
//            low for the suppressed cases above; an unexpected illegal CSR
//            access in U-mode -> priv_fail (csr_addr[9:8], mcounteren). Counters: u_mcycle.count,
//            u_minstret.count (retire_q pulses once per instruction, one
//            cycle after it left the stage).
// -----------------------------------------------------------------------------
module chillus_csr
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                        // register width
) (
  input  logic            clk,
  input  logic            rst_n,                 // async, active-low
  input  logic            stall,                 // this stage holds its instruction: no write

  // instruction in this stage
  input  logic            in_valid,              // real instruction; 0 when killed or a bubble
  input  logic            retire,                // an instruction leaves the stage without a trap (minstret)
  input  logic            unretire,              // an older, already counted instruction traps (bus fault)
  input  logic [63:0]     mtime,                 // platform timer (time / timeh)
  input  logic [XLEN-1:0] hart_id,               // mhartid (static after reset)
  input  logic            count_stop,            // debug unit: dcsr.stopcount in debug mode
  input  logic            priv_m,                // trap unit: the mode is M (0: U)
  input  csr_op_e         csr_op,
  input  logic            csr_uimm,              // source is imm (uimm) instead of rs1_data
  input  logic [11:0]     csr_addr,
  input  logic [4:0]      rs1,                   // rs1 register number (write suppression)
  input  logic [XLEN-1:0] rs1_data,              // after forwarding
  input  logic [XLEN-1:0] imm,                   // zero-extended uimm for CSRR*I

  // result
  output logic [XLEN-1:0] rdata,                 // old CSR value
  output logic            illegal,               // illegal-instruction exception

  // CSRs of chillus_trap
  output logic [11:0]     trap_csr_addr,
  output logic            trap_csr_we,
  output logic [XLEN-1:0] trap_csr_wdata,
  input  logic [XLEN-1:0] trap_csr_rdata,
  input  logic            trap_csr_hit,
  // CSRs of chillus_dbg (on the trap_csr_addr / we / wdata bus)
  input  logic [XLEN-1:0] dbg_csr_rdata,
  input  logic            dbg_csr_hit,
  // CSRs of chillus_trig (on the trap_csr_addr / we / wdata bus)
  input  logic [XLEN-1:0] trig_csr_rdata,
  input  logic            trig_csr_hit,
  // CSRs of chillus_pmp (on the trap_csr_addr / we / wdata bus)
  input  logic [XLEN-1:0] pmp_csr_rdata,
  input  logic            pmp_csr_hit
);

  localparam logic [11:0] CSR_MISA       = 12'h301;
  localparam logic [11:0] CSR_MSTATUSH   = 12'h310;
  localparam logic [11:0] CSR_MCOUNTEREN = 12'h306;
  localparam logic [11:0] CSR_MENVCFG    = 12'h30A;
  localparam logic [11:0] CSR_MENVCFGH   = 12'h31A;
  localparam logic [11:0] CSR_MSCRATCH   = 12'h340;
  localparam logic [11:0] CSR_MVENDORID  = 12'hF11;
  localparam logic [11:0] CSR_MARCHID    = 12'hF12;
  localparam logic [11:0] CSR_MIMPID     = 12'hF13;
  localparam logic [11:0] CSR_MHARTID    = 12'hF14;
  localparam logic [11:0] CSR_MCONFIGPTR = 12'hF15;
  localparam logic [11:0] CSR_MCOUNTINHIBIT = 12'h320;
  localparam logic [11:0] CSR_MCYCLE     = 12'hB00;
  localparam logic [11:0] CSR_MINSTRET   = 12'hB02;
  localparam logic [11:0] CSR_MCYCLEH    = 12'hB80;
  localparam logic [11:0] CSR_MINSTRETH  = 12'hB82;
  localparam logic [11:0] CSR_CYCLE      = 12'hC00;
  localparam logic [11:0] CSR_INSTRET    = 12'hC02;
  localparam logic [11:0] CSR_CYCLEH     = 12'hC80;
  localparam logic [11:0] CSR_INSTRETH   = 12'hC82;
  localparam logic [11:0] CSR_TIME       = 12'hC01;
  localparam logic [11:0] CSR_TIMEH      = 12'hC81;
  localparam logic [11:0] CSR_MHPMCOUNTER3   = 12'hB03;
  localparam logic [11:0] CSR_MHPMCOUNTER31  = 12'hB1F;
  localparam logic [11:0] CSR_MHPMCOUNTER3H  = 12'hB83;
  localparam logic [11:0] CSR_MHPMCOUNTER31H = 12'hB9F;
  localparam logic [11:0] CSR_MHPMEVENT3     = 12'h323;
  localparam logic [11:0] CSR_MHPMEVENT31    = 12'h33F;
  localparam logic [11:0] CSR_PMPCFG0        = 12'h3A0;
  localparam logic [11:0] CSR_PMPCFG15       = 12'h3AF;
  localparam logic [11:0] CSR_PMPADDR0       = 12'h3B0;
  localparam logic [11:0] CSR_PMPADDR63      = 12'h3EF;

  localparam bit          RV32    = (XLEN == 32);           // counter upper halves are separate CSRs (...h)
  localparam logic [1:0]  MXL     = (XLEN == 64) ? 2'd2 : 2'd1;   // misa MXL: 1 = 32 bits, 2 = 64 bits
  localparam int          MISA_U  = 20;                     // misa bit of U-mode
  localparam logic [63:0] LO_MASK = 64'({XLEN{1'b1}});      // counter bits written through mcycle / minstret

  logic            is_csr;          // a CSR instruction is presented
  logic [XLEN-1:0] src;             // rs1_data or uimm
  logic            src_is_zero_reg; // rs1 = x0, or uimm = 0
  logic            writes;          // the instruction writes the CSR (Table 7)
  logic            read_only;       // csr_addr[11:10] == 11
  logic            zero_csr;        // CSR that reads 0 (writes ignored or read-only)
  logic            sel_mhartid;     // mhartid: reads the hart_id input
  logic            hpm_csr;         // mhpmcounter3..31[h] / mhpmevent3..31: read 0
  logic            pmp_csr;         // pmpcfg* / pmpaddr*: read 0 (no PMP entries)
  logic            sel_misa;
  logic            sel_counteren;   // mcounteren
  logic [2:0]      counteren;       // mcounteren {IR, TM, CY}
  logic            counteren_en;
  logic [XLEN-1:0] counteren_rd;    // mcounteren as read
  logic            user_cnt;        // cycle / time / instret[h]
  logic            cnt_ok;          // its mcounteren bit is set
  logic            priv_fail;       // U-mode access to an M CSR or a disabled counter
  logic [XLEN-1:0] misa;            // misa value (read-only)
  logic            exists;          // csr_addr names an implemented CSR
  logic [XLEN-1:0] old;             // current CSR value
  logic [XLEN-1:0] new_value;       // value to write
  logic            do_write;        // write performed this cycle
  logic [XLEN-1:0] mscratch;
  logic            mscratch_en;

  // counters
  logic            sel_cycle;       // mcycle or cycle
  logic            sel_cycleh;      // mcycleh or cycleh (XLEN 32)
  logic            sel_instret;     // minstret or instret
  logic            sel_instreth;    // minstreth or instreth (XLEN 32)
  logic            sel_inhibit;     // mcountinhibit
  logic            sel_time;        // time
  logic            sel_timeh;       // timeh (XLEN 32)
  logic            cnt_csr;         // csr_addr names a counter CSR
  logic [63:0]     wdata64;         // new_value zero-extended to the counter width
  logic [63:0]     mcycle;
  logic [63:0]     mcycle_ld_val;
  logic            mcycle_ld;       // CSR write of mcycle / mcycleh
  logic            mcycle_inc;
  logic            ir_stop;         // minstret stopped: mcountinhibit.IR or count_stop
  logic [63:0]     minstret;
  logic [63:0]     minstret_ld_val;
  logic            minstret_ld;     // CSR write of minstret / minstreth
  logic            minstret_inc;
  logic            minstret_dec;    // bus-faulting instruction counted at retire
  logic            retire_q;        // pending minstret increment (instruction of the previous cycle)
  logic            retire_d;
  logic            unretire_q;      // pending minstret decrement
  logic            unretire_d;
  logic [63:0]     minstret_now;    // minstret with the pending pulse applied (reads)
  logic [1:0]      inhibit;         // mcountinhibit {IR, CY}
  logic [1:0]      inhibit_d;
  logic            inhibit_en;
  logic [XLEN-1:0] inhibit_rd;      // mcountinhibit as read

  // ---------------------------------------------------------------------------
  // Decode
  // ---------------------------------------------------------------------------
  assign is_csr          = in_valid && (csr_op != CSR_OP_NONE);
  assign src             = csr_uimm ? imm : rs1_data;
  assign src_is_zero_reg = csr_uimm ? (imm == '0) : (rs1 == '0);
  assign writes          = (csr_op == CSR_OP_RW) || !src_is_zero_reg;
  assign read_only       = csr_addr[11:10] == 2'b11;

  assign hpm_csr  = ((csr_addr >= CSR_MHPMCOUNTER3)  && (csr_addr <= CSR_MHPMCOUNTER31))  ||
                    (RV32 && (csr_addr >= CSR_MHPMCOUNTER3H) && (csr_addr <= CSR_MHPMCOUNTER31H)) ||
                    ((csr_addr >= CSR_MHPMEVENT3)    && (csr_addr <= CSR_MHPMEVENT31));
  assign pmp_csr  = ((csr_addr >= CSR_PMPCFG0)  && (csr_addr <= CSR_PMPCFG15) && (RV32 || !csr_addr[0])) ||
                    ((csr_addr >= CSR_PMPADDR0) && (csr_addr <= CSR_PMPADDR63));
  assign zero_csr = (csr_addr == CSR_MSTATUSH)  || (csr_addr == CSR_MVENDORID) ||
                    (csr_addr == CSR_MENVCFG)   || (RV32 && (csr_addr == CSR_MENVCFGH)) ||
                    (csr_addr == CSR_MARCHID)   || (csr_addr == CSR_MIMPID)    ||
                    (csr_addr == CSR_MCONFIGPTR) ||
                    hpm_csr || pmp_csr;
  assign sel_misa = (csr_addr == CSR_MISA);
  assign sel_counteren = (csr_addr == CSR_MCOUNTEREN);
  assign sel_mhartid = (csr_addr == CSR_MHARTID);

  always_comb begin
    misa              = '0;
    misa[XLEN-1:XLEN-2] = MXL;
    misa[25:0]        = MISA_EXT;
    misa[MISA_U]      = 1'b1;
  end
  assign sel_cycle    = (csr_addr == CSR_MCYCLE)   || (csr_addr == CSR_CYCLE);
  assign sel_cycleh   = RV32 && ((csr_addr == CSR_MCYCLEH)   || (csr_addr == CSR_CYCLEH));
  assign sel_instret  = (csr_addr == CSR_MINSTRET) || (csr_addr == CSR_INSTRET);
  assign sel_instreth = RV32 && ((csr_addr == CSR_MINSTRETH) || (csr_addr == CSR_INSTRETH));
  assign sel_inhibit  = csr_addr == CSR_MCOUNTINHIBIT;
  assign sel_time     = (csr_addr == CSR_TIME);
  assign sel_timeh    = RV32 && (csr_addr == CSR_TIMEH);
  assign cnt_csr      = sel_cycle || sel_cycleh || sel_instret || sel_instreth || sel_inhibit ||
                        sel_time || sel_timeh;

  assign exists   = trap_csr_hit || dbg_csr_hit || trig_csr_hit || pmp_csr_hit || zero_csr || sel_misa || sel_mhartid || (csr_addr == CSR_MSCRATCH) || cnt_csr ||
                    sel_counteren;

  // U-mode: user-level CSRs only, counters as mcounteren allows (cycle,
  // time, instret: csr_addr[1:0] = 0, 1, 2; the others do not exist)
  assign user_cnt  = csr_addr[11:8] == 4'hC;
  assign cnt_ok    = (csr_addr[1:0] != 2'b11) && counteren[csr_addr[1:0]];
  assign priv_fail = !priv_m && ((csr_addr[9:8] != 2'b00) || (user_cnt && !cnt_ok));

  assign illegal  = is_csr && (!exists || (read_only && writes) || priv_fail);

  // ---------------------------------------------------------------------------
  // Read-modify-write
  // ---------------------------------------------------------------------------
  always_comb begin
    if (trap_csr_hit)                     old = trap_csr_rdata;
    else if (dbg_csr_hit)                 old = dbg_csr_rdata;
    else if (trig_csr_hit)                old = trig_csr_rdata;
    else if (pmp_csr_hit)                 old = pmp_csr_rdata;
    else if (csr_addr == CSR_MSCRATCH)    old = mscratch;
    else if (sel_misa)                    old = misa;
    else if (sel_cycle)                   old = mcycle[XLEN-1:0];
    else if (sel_cycleh)                  old = XLEN'(mcycle[63:32]);
    else if (sel_instret)                 old = minstret_now[XLEN-1:0];
    else if (sel_instreth)                old = XLEN'(minstret_now[63:32]);
    else if (sel_time)                    old = mtime[XLEN-1:0];
    else if (sel_timeh)                   old = XLEN'(mtime[63:32]);
    else if (sel_inhibit)                 old = inhibit_rd;
    else if (sel_mhartid)                 old = hart_id;
    else if (sel_counteren)               old = counteren_rd;
    else                                  old = '0;
  end

  always_comb begin
    case (csr_op)
      CSR_OP_RW:   new_value = src;
      CSR_OP_RS:   new_value = old | src;
      CSR_OP_RC:   new_value = old & ~src;
      CSR_OP_NONE: new_value = old;
      default:     new_value = old;
    endcase
  end

  assign rdata    = is_csr ? old : '0;
  assign do_write = is_csr && !stall && writes && !illegal;

  assign trap_csr_addr  = csr_addr;
  assign trap_csr_we    = do_write;
  assign trap_csr_wdata = new_value;

  // ---------------------------------------------------------------------------
  // mscratch
  // ---------------------------------------------------------------------------
  assign mscratch_en = do_write && (csr_addr == CSR_MSCRATCH);

  basechili_dffe #(.WIDTH(XLEN)) u_mscratch (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mscratch_en),
    .d     (new_value),
    .q     (mscratch)
  );

  // ---------------------------------------------------------------------------
  // mcounteren: CY [0], TM [1], IR [2]
  // ---------------------------------------------------------------------------
  assign counteren_en = do_write && sel_counteren;
  assign counteren_rd = XLEN'(counteren);

  basechili_dffe #(.WIDTH(3)) u_mcounteren (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (counteren_en),
    .d     (new_value[2:0]),
    .q     (counteren)
  );

  // ---------------------------------------------------------------------------
  // Counters: a write (low or high half) replaces the increment
  // ---------------------------------------------------------------------------
  assign wdata64 = 64'(new_value);

  assign mcycle_ld     = do_write && ((csr_addr == CSR_MCYCLE) || sel_cycleh);
  assign mcycle_ld_val = sel_cycleh ? {wdata64[31:0], mcycle[31:0]} :
                                        (mcycle & ~LO_MASK) | (wdata64 & LO_MASK);
  assign mcycle_inc    = !inhibit[0] && !count_stop;

  basechili_updown_counter #(.WIDTH(64)) u_mcycle (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (mcycle_ld),
    .load_val (mcycle_ld_val),
    .inc      (mcycle_inc),
    .dec      (1'b0),
    .count    (mcycle),
    .count_d  ()
  );

  assign minstret_ld     = do_write && ((csr_addr == CSR_MINSTRET) || sel_instreth);
  assign minstret_ld_val = sel_instreth ? {wdata64[31:0], minstret_now[31:0]} :
                                            (minstret_now & ~LO_MASK) | (wdata64 & LO_MASK);
  // a writing instruction does not count itself (its write replaces it)
  assign ir_stop         = inhibit[1] || count_stop;
  assign retire_d        = retire && !ir_stop && !minstret_ld;
  assign unretire_d      = unretire && !ir_stop;
  assign minstret_inc    = retire_q;
  assign minstret_dec    = unretire_q;
  assign minstret_now    = retire_q   ? (minstret + 64'd1) :
                           unretire_q ? (minstret - 64'd1) :
                                        minstret;

  basechili_dff #(.WIDTH(1)) u_retire_q (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (retire_d),
    .q     (retire_q)
  );

  basechili_dff #(.WIDTH(1)) u_unretire_q (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (unretire_d),
    .q     (unretire_q)
  );

  basechili_updown_counter #(.WIDTH(64)) u_minstret (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (minstret_ld),
    .load_val (minstret_ld_val),
    .inc      (minstret_inc),
    .dec      (minstret_dec),
    .count    (minstret),
    .count_d  ()
  );

  // mcountinhibit: CY [0], IR [2]; TM [1] and the hpm bits read 0
  assign inhibit_en = do_write && sel_inhibit;
  assign inhibit_d  = {new_value[2], new_value[0]};

  always_comb begin
    inhibit_rd    = '0;
    inhibit_rd[0] = inhibit[0];
    inhibit_rd[2] = inhibit[1];
  end

  basechili_dffe #(.WIDTH(2)) u_mcountinhibit (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (inhibit_en),
    .d     (inhibit_d),
    .q     (inhibit)
  );

endmodule
