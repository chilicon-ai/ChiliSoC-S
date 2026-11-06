// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChillU-S :: chillus_core
//
// ChillU-S RV32I core top (M and U mode): connectivity only (instances and wires, no logic).
// In-order pipeline, one instruction per cycle:
//
//   fetch (u_ifu) -> id (u_rvc, u_rsdec, u_dec, u_rf read) -> ex (u_alu, u_mdu, u_bru,
//   u_lsu request, u_csr, u_trap, u_sb forwarding) -> wb (u_lsu response,
//   u_result write-back, u_rf write)
//
//   u_bp     : static branch prediction in id (BTFN); u_bru flags it in ex
//   u_dbg    : debug mode (Sdext): dcsr / dpc / dscratch, entry, dret (ex)
//   u_trig   : triggers (Sdtrig): execute-address match in id, hit taken in ex
//   u_pmp    : PMP (PMP_REGIONS, 4 by default): data check of the ex access before dmss_req, fetch check of each response word
//   u_icache : instruction cache between u_ifu and imss_* (ICACHE_KB: 0 none, 2 or 4 KiB)
//   u_insample: interrupt / debug_req / fetch_enable input samples (ungated clock)
//   u_cg     : sleep clock gate: clk_core (every unit but u_insample) stops in WFI sleep
//   u_ctrl   : stall / flush vectors, IFU redirect, unit valids, boot, WFI sleep
//   u_mdu    : multiply / divide (M), iterative; holds ex while busy
//   u_sb     : id -> ex operands, forwarding from wb, load-use stall
//   u_result : ex result selection, ex -> wb result, register write
//   u_rvfi   : RVFI retirement trace ex -> wb (verification only)
//
// Interfaces
//   imss_* : instruction fetch (req / gnt, rvalid / rdata / err; chillus_ifu)
//   dmss_* : loads and stores (req / gnt, rvalid / rdata / err; chillus_lsu)
//   boot_addr, hart_id, fetch_enable : boot address (pc and mtvec), mhartid, start of fetch
//   irq_*, mtime : interrupts and timer from the platform (CLINT)
//   debug_req, debug_mode : halt request (enters debug mode, wakes from WFI), debug mode (u_dbg)
//   core_sleep : sleep indication (u_ctrl)
//   imss_priv, dmss_priv : privilege of each fetch / access (1 = M, 0 = U; u_trap), AHB HPROT[1]
//   test_en : scan / test mode, opens the clock gates (u_cg and the register file; tie 0 in functional mode)
//   rvfi_*  : RVFI retirement trace (chillus_rvfi); leave unconnected in the SoC
//
// Clocks
//   clk      : free-running: u_insample (wake inputs) and the sleep clock gate u_cg
//   clk_core : clk gated by u_cg (enable u_ctrl.clk_en = !core_sleep || wake): stops in
//              WFI sleep, runs again from the edge that sees the wake-up (one cycle after
//              the interrupt / debug_req input rises); mcycle does not count while it stops
//
// Debug (instance paths; most signals are also top-level wires here)
//   Instruction flow: op_id / op_ex / op_wb, pc_wb + instr_wb is the
//   retiring instruction (valid_wb), rf_we / rf_rd / rf_wdata its result.
//   Register values: u_rf.u_chk.x10_a0 etc. (sim).  Traps: trap, trap_cause, u_trap.mepc; mode: priv_m.
//   Stalls: stall / hold; flushes: flush / kill; redirects: redirect_*.
//
// Connectivity: every wire and port below is commented 'driver -> loads'
// (instance.port); the source JSON lists every port of every instance.
// -----------------------------------------------------------------------------
module chillus_core
  import chillus_dec_pkg::*;
#(
  parameter bit              RF_LATCH          = 1'b1,           // register file storage: latches (basechili_latch_array); 0: flops (basechili_reg_array)
  parameter bit              DEBUG             = 1'b1,           // Sdext debug mode (chillus_dbg); 0: none (debug_req only wakes from WFI, dret illegal)
  parameter logic [XLEN-1:0] DM_HALT_ADDR      = 32'h1A11_0800,  // Debug Module halt address (riscv-dbg HaltAddress at the DM base)
  parameter logic [XLEN-1:0] DM_EXCEPTION_ADDR = 32'h1A11_0808,  // Debug Module exception address (riscv-dbg ExceptionAddress at the DM base)
  parameter int              NUM_TRIGGERS      = 0,              // Sdtrig execute-address triggers (chillus_trig); 0: none (trigger CSRs illegal)
  parameter int              PMP_REGIONS       = 4,              // PMP entries (chillus_pmp, Smpmp, grain 4 bytes), 0..4; 0: no PMP (the PMP CSRs read 0, U-mode reaches all memory)
  parameter int              ICACHE_KB         = 0,              // instruction cache (chillus_icache) in KiB: 0 (none, the IFU drives imss_* directly), 2 or 4; 2-way, 16-byte lines
  parameter logic [XLEN-1:0] ICACHE_BASE       = 32'h0000_0000,  // instruction cache: fetches with (addr & ICACHE_MASK) == ICACHE_BASE are cacheable
  parameter logic [XLEN-1:0] ICACHE_MASK       = 32'h0000_0000   // instruction cache: cacheable region mask (0: every address); fetches in debug mode are never cached
) (
  // clock and reset
  input  logic              clk,                       // free-running clock (gated inside by u_cg in
                                                       //   WFI sleep); (top input) -> u_insample.clk,
                                                       //   u_cg.clk
  input  logic              rst_n,                     // async, active-low; (top input) ->
                                                       //   u_insample.rst_n, u_ifu.rst_n,
                                                       //   u_icache.rst_n, u_dec.rst_n, u_ctrl.rst_n,
                                                       //   u_rf.rst_n, u_sb.rst_n, u_lsu.rst_n,
                                                       //   u_csr.rst_n, u_trap.rst_n, u_dbg.rst_n,
                                                       //   u_trig.rst_n, u_pmp.rst_n, u_mdu.rst_n,
                                                       //   u_result.rst_n, u_rvfi.rst_n
  input  logic              test_en,                   // scan / test mode: opens the core clock
                                                       //   gates (sleep gate u_cg, latch register
                                                       //   file); tie 0 in functional mode; (top
                                                       //   input) -> u_cg.test_en, u_ifu.test_en,
                                                       //   u_rf.test_en, u_mdu.test_en

  // boot
  input  logic [XLEN-1:0]   boot_addr,                 // first instruction and reset mtvec (Direct);
                                                       //   bits [1:0] ignored; static while the core
                                                       //   runs; (top input) -> u_trap.boot_addr
  input  logic [XLEN-1:0]   hart_id,                   // mhartid; static while the core runs; (top
                                                       //   input) -> u_csr.hart_id
  input  logic              fetch_enable,              // start fetching at boot_addr when first seen
                                                       //   high after reset (sticky, sampled); tie 1
                                                       //   to boot at once; (top input) ->
                                                       //   u_insample.fetch_enable

  // instruction fetch MSS port
  output logic              imss_req,                  // fetch request; stays high with the same
                                                       //   address until imss_gnt, except that a
                                                       //   redirect may withdraw a request not yet
                                                       //   granted; u_icache.m_req -> (top output)
  input  logic              imss_gnt,                  // the request is taken this cycle; (top
                                                       //   input) -> u_icache.m_gnt
  output logic [XLEN-1:0]   imss_addr,                 // word address (bits [1:0] = 0);
                                                       //   u_icache.m_addr -> (top output)
  output logic              imss_priv,                 // privileged fetch (M-mode; 0: U-mode): AHB
                                                       //   HPROT[1]; registered, valid with imss_req;
                                                       //   u_icache.m_priv -> (top output)
  input  logic              imss_rvalid,               // response of the oldest granted request (in
                                                       //   order, earliest the cycle after its grant);
                                                       //   always taken; (top input) ->
                                                       //   u_icache.m_rvalid
  input  logic [31:0]       imss_rdata,                // (top input) -> u_icache.m_rdata
  input  logic              imss_err,                  // with imss_rvalid: the fetch failed
                                                       //   (instruction access fault when the word is
                                                       //   used); (top input) -> u_icache.m_err

  // data MSS port
  output logic              dmss_req,                  // load / store request; stays high with the
                                                       //   same request until dmss_gnt; at most one
                                                       //   access outstanding; u_lsu.mss_req ->
                                                       //   u_rvfi.mss_req, (top output)
  input  logic              dmss_gnt,                  // the request is taken this cycle; (top
                                                       //   input) -> u_lsu.mss_gnt
  output logic              dmss_we,                   // store (else load); u_lsu.mss_we ->
                                                       //   u_rvfi.mss_we, (top output)
  output logic [XLEN/8-1:0] dmss_be,                   // byte enables of the access; u_lsu.mss_be ->
                                                       //   u_rvfi.mss_be, (top output)
  output logic [XLEN-1:0]   dmss_addr,                 // word address (bits [1:0] = 0);
                                                       //   u_lsu.mss_addr -> (top output)
  output logic [XLEN-1:0]   dmss_wdata,                // store data, replicated into every byte
                                                       //   lane; u_lsu.mss_wdata -> u_rvfi.mss_wdata,
                                                       //   (top output)
  output logic              dmss_priv,                 // privileged access (M-mode, or mstatus.MPRV
                                                       //   with MPP = M; 0: U-mode): AHB HPROT[1];
                                                       //   registered, valid with dmss_req;
                                                       //   u_trap.data_priv_m -> u_pmp.data_priv_m,
                                                       //   (top output)
  input  logic              dmss_rvalid,               // response of the granted access (earliest
                                                       //   the cycle after its grant); always taken;
                                                       //   (top input) -> u_lsu.mss_rvalid
  input  logic [XLEN-1:0]   dmss_rdata,                // load word, all lanes (with dmss_rvalid);
                                                       //   (top input) -> u_lsu.mss_rdata,
                                                       //   u_rvfi.mss_rdata
  input  logic              dmss_err,                  // with dmss_rvalid: the access failed (bus
                                                       //   error) and had no effect; (top input) ->
                                                       //   u_lsu.mss_err

  // interrupts and timer (CLINT / platform)
  input  logic              irq_software,              // machine software interrupt (msip); (top
                                                       //   input) -> u_insample.irq_software
  input  logic              irq_timer,                 // machine timer interrupt (mtime >=
                                                       //   mtimecmp); (top input) ->
                                                       //   u_insample.irq_timer
  input  logic              irq_external,              // machine external interrupt (PLIC); (top
                                                       //   input) -> u_insample.irq_external
  input  logic [14:0]       irq_fast,                  // local interrupts, level, mip[16 + i]
                                                       //   (mcause 16 + i); tie 0 if unused; (top
                                                       //   input) -> u_insample.irq_fast
  input  logic              irq_nmi,                   // non-maskable interrupt, level (mcause 31);
                                                       //   tie 0 if unused; (top
                                                       //   input) -> u_insample.irq_nmi
  input  logic [63:0]       mtime,                     // platform timer, read by the time / timeh
                                                       //   CSRs; (top input) -> u_csr.mtime

  // debug and sleep
  input  logic              debug_req,                 // halt request, level (Debug Module): enter
                                                       //   debug mode; also wakes the core from WFI;
                                                       //   tie 0 if unused; (top input) ->
                                                       //   u_insample.debug_req
  output logic              core_sleep,                // the core sleeps in WFI: pipeline empty, no
                                                       //   MSS request outstanding (registered);
                                                       //   u_ctrl.core_sleep -> (top output)
  output logic              debug_mode,                // the hart is in debug mode (registered),
                                                       //   e.g. to freeze a watchdog; u_dbg.debug_mode
                                                       //   -> u_icache.debug_mode, u_trap.debug_mode,
                                                       //   u_trig.debug_mode, u_pmp.debug_mode, (top
                                                       //   output)

  // RVFI retirement trace (verification; leave unconnected in the SoC)
  output logic              rvfi_valid,                // one instruction retires (or traps) this
                                                       //   cycle; u_rvfi.rvfi_valid -> (top output)
  output logic [63:0]       rvfi_order,                // u_rvfi.rvfi_order -> (top output)
  output logic [31:0]       rvfi_insn,                 // u_rvfi.rvfi_insn -> (top output)
  output logic              rvfi_trap,                 // u_rvfi.rvfi_trap -> (top output)
  output logic              rvfi_halt,                 // u_rvfi.rvfi_halt -> (top output)
  output logic              rvfi_intr,                 // u_rvfi.rvfi_intr -> (top output)
  output logic [1:0]        rvfi_mode,                 // u_rvfi.rvfi_mode -> (top output)
  output logic [1:0]        rvfi_ixl,                  // u_rvfi.rvfi_ixl -> (top output)
  output logic [4:0]        rvfi_rs1_addr,             // u_rvfi.rvfi_rs1_addr -> (top output)
  output logic [4:0]        rvfi_rs2_addr,             // u_rvfi.rvfi_rs2_addr -> (top output)
  output logic [XLEN-1:0]   rvfi_rs1_rdata,            // u_rvfi.rvfi_rs1_rdata -> (top output)
  output logic [XLEN-1:0]   rvfi_rs2_rdata,            // u_rvfi.rvfi_rs2_rdata -> (top output)
  output logic [4:0]        rvfi_rd_addr,              // u_rvfi.rvfi_rd_addr -> (top output)
  output logic [XLEN-1:0]   rvfi_rd_wdata,             // u_rvfi.rvfi_rd_wdata -> (top output)
  output logic [XLEN-1:0]   rvfi_pc_rdata,             // u_rvfi.rvfi_pc_rdata -> (top output)
  output logic [XLEN-1:0]   rvfi_pc_wdata,             // u_rvfi.rvfi_pc_wdata -> (top output)
  output logic [XLEN-1:0]   rvfi_mem_addr,             // u_rvfi.rvfi_mem_addr -> (top output)
  output logic [XLEN/8-1:0] rvfi_mem_rmask,            // u_rvfi.rvfi_mem_rmask -> (top output)
  output logic [XLEN/8-1:0] rvfi_mem_wmask,            // u_rvfi.rvfi_mem_wmask -> (top output)
  output logic [XLEN-1:0]   rvfi_mem_rdata,            // u_rvfi.rvfi_mem_rdata -> (top output)
  output logic [XLEN-1:0]   rvfi_mem_wdata             // u_rvfi.rvfi_mem_wdata -> (top output)
);

  // clock
  logic                clk_core;            // core clock: clk gated in WFI sleep (u_cg); every unit
                                            //   but u_insample; u_cg.gclk -> u_ifu.clk, u_icache.clk,
                                            //   u_dec.clk, u_ctrl.clk, u_rf.clk, u_sb.clk, u_lsu.clk,
                                            //   u_csr.clk, u_trap.clk, u_dbg.clk, u_trig.clk,
                                            //   u_pmp.clk, u_mdu.clk, u_result.clk, u_rvfi.clk
  logic                clk_en;              // core clock enable: awake or wake-up pending
                                            //   (!core_sleep || wake); u_ctrl.clk_en -> u_cg.en

  // fetch -> id
  logic                ifu_valid;           // u_ifu.dec_valid -> u_rsdec.valid, u_dec.ifu_valid
  logic                ifu_accept;          // u_dec.ifu_accept -> u_ifu.dec_accept
  logic [31:0]         ifu_instr;           // u_ifu.dec_instr -> u_rvc.instr_in, u_rsdec.instr,
                                            //   u_dec.ifu_raw, u_bp.instr
  logic [31:0]         rvc_instr;           // 32-bit form (16-bit instructions expanded);
                                            //   u_rvc.instr_out -> u_dec.ifu_instr
  logic                rvc_illegal;         // invalid 16-bit instruction (rvc_instr = 0, decodes as
                                            //   illegal); u_rvc.illegal -> (no loads)
  logic [XLEN-1:0]     ifu_pc;              // u_ifu.dec_pc -> u_dec.ifu_pc, u_bp.pc, u_trig.pc
  logic                ifu_is32;            // u_ifu.dec_is32 -> u_rvc.is32, u_rsdec.is32,
                                            //   u_dec.ifu_is32, u_bp.is32
  logic                ifu_fault;           // u_ifu.dec_fault -> u_rsdec.fault, u_dec.ifu_fault
  logic                ifu_fault_hi;        // only the 2nd halfword faulted (pc + 2);
                                            //   u_ifu.dec_fault_hi -> u_dec.ifu_fault_hi
  logic                redirect_valid;      // u_ctrl.redirect_valid -> u_ifu.redirect_valid
  logic [XLEN-1:0]     redirect_pc;         // u_ctrl.redirect_pc -> u_ifu.redirect_pc
  logic                fast_valid;          // this redirect is requested from fast_pc in the
                                            //   redirect cycle; u_ctrl.fast_valid -> u_ifu.fast_valid
  logic [XLEN-1:0]     fast_pc;             // fast redirect address (= redirect_pc when fast_valid);
                                            //   u_ctrl.fast_pc -> u_ifu.fast_pc
  logic                fast_cand;           // fast_valid without hold / kill of the id prediction:
                                            //   the IFU presents fast_pc; u_ctrl.fast_cand ->
                                            //   u_ifu.fast_cand

  // pipeline control
  logic [N_STAGES-1:0] stall;               // u_ctrl.stall -> u_dec.stall
  logic [N_STAGES-1:0] flush;               // u_ctrl.flush -> u_dec.flush
  logic [N_STAGES-1:0] hold;                // u_dec.hold -> u_ctrl.hold, u_sb.hold, u_csr.stall
                                            //   ([STAGE_EX]), u_trap.stall ([STAGE_EX]), u_mdu.stall
                                            //   ([STAGE_EX]), u_result.hold, u_rvfi.hold
  logic [N_STAGES-1:0] kill;                // u_dec.kill -> u_ctrl.kill, u_sb.kill, u_result.kill,
                                            //   u_rvfi.kill
  logic                ex_valid;            // u_ctrl.ex_valid -> u_lsu.in_valid, u_csr.in_valid,
                                            //   u_trap.in_valid, u_mdu.in_valid
  logic                ex_act;              // u_ctrl.ex_act -> u_bru.in_valid, u_dbg.act,
                                            //   u_rvfi.ex_act
  logic                ex_retire;           // u_ctrl.ex_retire -> u_csr.retire

  // decoder: id
  logic                valid_id;            // u_dec.valid_id -> u_bp.in_valid, u_ctrl.valid_id,
                                            //   u_sb.valid_id
  op_e                 op_id;               // u_dec.op_id -> (no loads)
  logic [XLEN-1:0]     imm_id;              // u_dec.imm_id -> (no loads)
  branch_op_e          branch_op_id;        // u_dec.branch_op_id -> u_bp.branch_op
  jump_op_e            jump_op_id;          // u_dec.jump_op_id -> u_bp.jump_op
  logic                predict_taken;       // u_bp: id instruction predicted taken (BTFN);
                                            //   u_bp.taken -> u_ctrl.predict_taken
  logic [XLEN-1:0]     predict_target;      // u_bp: its target, pc + imm; u_bp.target ->
                                            //   u_ctrl.predict_target

  // pipeline control
  logic                predict_fire;        // u_ctrl: predicted-taken instruction advances, fetch
                                            //   redirected to predict_target; u_ctrl.predict_fire ->
                                            //   (no loads)

  // decoder: id
  logic [4:0]          rs1_id;              // u_rsdec (early, from the raw encoding); u_rsdec.rs1 ->
                                            //   u_rf.rs1_addr, u_sb.rs1_id
  logic [4:0]          rs2_id;              // u_rsdec.rs2 -> u_rf.rs2_addr, u_sb.rs2_id
  logic [4:0]          dec_rs1_id;          // decoder's copy (equal to rs1_id for legal
                                            //   instructions); u_dec.rs1_id -> u_sb.dec_rs1_id
  logic [4:0]          dec_rs2_id;          // u_dec.rs2_id -> u_sb.dec_rs2_id

  // decoder: ex
  logic                valid_ex;            // u_dec.valid_ex -> u_ctrl.valid_ex, u_result.valid_ex
  op_e                 op_ex;               // u_dec.op_ex -> (no loads)
  logic                illegal_ex;          // u_dec.illegal_ex -> u_trap.illegal
  logic                fault_ex;            // u_dec.fault_ex -> u_trap.fetch_fault
  logic                fault_hi_ex;         // u_dec.fault_hi_ex -> u_trap.fetch_fault_hi
  logic [XLEN-1:0]     pc_ex;               // u_dec.pc_ex -> u_alu.pc, u_bru.pc, u_trap.pc,
                                            //   u_dbg.pc, u_rvfi.pc
  logic [31:0]         instr_ex;            // u_dec.instr_ex -> u_trap.instr, u_rvfi.instr
  logic                is32_ex;             // u_dec.is32_ex -> u_bru.is32
  logic [XLEN-1:0]     imm_ex;              // u_dec.imm_ex -> u_alu.imm, u_bru.imm, u_csr.imm
  logic [4:0]          rd_ex;               // u_dec.rd_ex -> u_sb.rd_ex, u_bru.rd
  logic [4:0]          rs1_ex;              // u_dec.rs1_ex -> u_bru.rs1, u_csr.rs1, u_rvfi.rs1
  logic [4:0]          rs2_ex;              // u_dec.rs2_ex -> u_rvfi.rs2
  logic [11:0]         csr_ex;              // u_dec.csr_ex -> u_csr.csr_addr
  alu_op_e             alu_op_ex;           // u_dec.alu_op_ex -> u_alu.alu_op
  alu_src1_e           alu_src1_ex;         // u_dec.alu_src1_ex -> u_alu.alu_src1
  alu_src2_e           alu_src2_ex;         // u_dec.alu_src2_ex -> u_alu.alu_src2
  branch_op_e          branch_op_ex;        // u_dec.branch_op_ex -> u_bru.branch_op
  jump_op_e            jump_op_ex;          // u_dec.jump_op_ex -> u_bru.jump_op
  mem_op_e             mem_op_ex;           // u_dec.mem_op_ex -> u_sb.mem_op_ex, u_lsu.mem_op,
                                            //   u_trap.mem_op
  mem_size_e           mem_size_ex;         // u_dec.mem_size_ex -> u_lsu.mem_size
  logic                mem_unsigned_ex;     // u_dec.mem_unsigned_ex -> u_lsu.mem_unsigned
  wb_src_e             wb_src_ex;           // u_dec.wb_src_ex -> u_result.wb_src_ex
  csr_op_e             csr_op_ex;           // u_dec.csr_op_ex -> u_csr.csr_op
  logic                csr_uimm_ex;         // u_dec.csr_uimm_ex -> u_csr.csr_uimm
  logic                fence_i_ex;          // u_dec.fence_i_ex -> u_ctrl.fence_i
  logic                wfi_ex;              // u_dec.wfi_ex -> u_ctrl.wfi, u_trap.wfi
  logic                ecall_ex;            // u_dec.ecall_ex -> u_trap.ecall
  logic                ebreak_ex;           // u_dec.ebreak_ex -> u_trap.ebreak
  logic                mret_ex;             // u_dec.mret_ex -> u_trap.mret
  logic                dret_ex;             // u_dec.dret_ex -> u_trap.dret
  md_op_e              md_op_ex;            // u_dec.md_op_ex -> u_mdu.md_op

  // decoder: wb
  logic                valid_wb;            // u_dec.valid_wb -> u_ctrl.valid_wb, u_result.valid_wb
  op_e                 op_wb;               // u_dec.op_wb -> (no loads)
  logic                illegal_wb;          // u_dec.illegal_wb -> (no loads)
  logic                fault_wb;            // u_dec.fault_wb -> (no loads)
  logic [XLEN-1:0]     pc_wb;               // u_dec.pc_wb -> u_trap.bus_fault_pc
  logic [31:0]         instr_wb;            // u_dec.instr_wb -> (no loads)
  logic [4:0]          rd_wb;               // u_dec.rd_wb -> u_result.rd_wb
  mem_op_e             mem_op_wb;           // u_dec.mem_op_wb -> (no loads)
  wb_src_e             wb_src_wb;           // u_dec.wb_src_wb -> u_result.wb_src_wb

  // register file / scoreboard
  logic [XLEN-1:0]     rf_rs1_data;         // u_rf.rs1_data -> u_sb.rf_rs1_data
  logic [XLEN-1:0]     rf_rs2_data;         // u_rf.rs2_data -> u_sb.rf_rs2_data
  logic                rf_we;               // u_result.rf_we -> u_rf.rd_we, u_rvfi.rf_we
  logic [4:0]          rf_rd;               // u_result.rf_rd -> u_rf.rd_addr, u_rvfi.rf_rd
  logic [XLEN-1:0]     rf_wdata;            // u_result.rf_wdata -> u_rf.rd_data, u_rvfi.rf_wdata
  logic [XLEN-1:0]     rs1_data;            // ex operands, hazards resolved; u_sb.rs1_data ->
                                            //   u_alu.rs1_data, u_bru.rs1_data, u_csr.rs1_data,
                                            //   u_mdu.rs1_data, u_rvfi.rs1_data
  logic [XLEN-1:0]     rs2_data;            // u_sb.rs2_data -> u_alu.rs2_data, u_lsu.rs2_data,
                                            //   u_mdu.rs2_data, u_rvfi.rs2_data
  logic                load_use;            // u_sb.load_use -> u_ctrl.load_use

  // ex units
  logic [XLEN-1:0]     alu_result;          // u_alu.result -> u_lsu.addr, u_trap.mem_addr,
                                            //   u_pmp.data_addr, u_result.alu_result, u_rvfi.mem_addr
  logic                alu_cmp_eq;          // u_alu: rs1 == rs2 (branch compare); u_alu.cmp_eq ->
                                            //   u_bru.cmp_eq
  logic                alu_cmp_lt;          // u_alu: rs1 < rs2, signed or unsigned (branch compare);
                                            //   u_alu.cmp_lt -> u_bru.cmp_lt
  logic                jump;                // u_bru.jump -> u_ctrl.jump, u_rvfi.jump
  logic                no_jump;             // u_bru.no_jump -> u_ctrl.no_jump
  logic                predicted;           // u_bru: the front end predicted the ex instruction
                                            //   taken; u_bru.predicted -> u_ctrl.predicted
  logic                target_misaligned;   // u_bru.target_misaligned -> u_trap.target_misaligned
  logic [XLEN-1:0]     jump_target;         // u_bru.target -> u_ctrl.jump_target, u_trap.target,
                                            //   u_rvfi.jump_target
  logic [XLEN-1:0]     link;                // u_bru.link -> u_ctrl.next_pc, u_result.link,
                                            //   u_rvfi.next_pc
  logic [XLEN-1:0]     alt_target;          // ex conditional branch: the address the front end did
                                            //   not follow; u_bru.alt_target -> u_ctrl.alt_target
  logic                cond_branch;         // a conditional branch is in ex (decode);
                                            //   u_bru.cond_branch -> u_ctrl.cond_branch
  logic                cond_flip;           // u_bru: the ex conditional branch's outcome differs
                                            //   from its static prediction (ungated); u_bru.cond_flip
                                            //   -> u_ctrl.cond_flip
  logic                ras_push;            // u_bru.ras_push -> (no loads)
  logic                ras_pop;             // u_bru.ras_pop -> (no loads)
  logic                mem_misaligned;      // u_lsu.misaligned -> u_trap.mem_misaligned
  logic                load_valid;          // u_lsu.load_valid -> (no loads)
  logic                lsu_req_stall;       // u_lsu: the ex data request is not granted this cycle:
                                            //   hold ex; u_lsu.req_stall -> u_ctrl.lsu_req_stall
  logic                lsu_rsp_stall;       // u_lsu: the wb access waits for dmss_rvalid: hold wb;
                                            //   u_lsu.rsp_stall -> u_ctrl.lsu_rsp_stall
  logic                lsu_req_wait;        // u_lsu: a data request waits for dmss_gnt (registered):
                                            //   no interrupt / debug entry on it; u_lsu.req_wait ->
                                            //   u_ctrl.lsu_req_wait
  logic [XLEN-1:0]     load_data;           // u_lsu.load_data -> u_result.load_data
  logic                access_fault;        // u_lsu.access_fault -> u_trap.bus_fault
  logic                access_fault_store;  // u_lsu.access_fault_store -> u_trap.bus_fault_store
  logic [XLEN-1:0]     access_fault_addr;   // u_lsu.access_fault_addr -> u_trap.bus_fault_addr
  logic [XLEN-1:0]     csr_rdata;           // u_csr.rdata -> u_result.csr_rdata
  logic                md_busy;             // u_mdu.busy -> u_ctrl.md_busy
  logic [XLEN-1:0]     md_result;           // u_mdu.result -> u_result.md_result
  logic                md_late;             // late MUL in ex: result produced in wb
                                            //   (md_late_result); u_mdu.late -> u_sb.late_ex,
                                            //   u_result.md_late
  logic [XLEN-1:0]     md_late_result;      // product of the late MUL now in wb; u_mdu.late_result
                                            //   -> u_result.md_late_result
  logic                csr_illegal;         // u_csr.illegal -> u_trap.csr_illegal
  logic [11:0]         trap_csr_addr;       // u_csr.trap_csr_addr -> u_trap.csr_addr,
                                            //   u_dbg.csr_addr, u_trig.csr_addr, u_pmp.csr_addr
  logic                trap_csr_we;         // u_csr.trap_csr_we -> u_trap.csr_we, u_dbg.csr_we,
                                            //   u_trig.csr_we, u_pmp.csr_we
  logic [XLEN-1:0]     trap_csr_wdata;      // u_csr.trap_csr_wdata -> u_trap.csr_wdata,
                                            //   u_dbg.csr_wdata, u_trig.csr_wdata, u_pmp.csr_wdata
  logic [XLEN-1:0]     trap_csr_rdata;      // u_trap.csr_rdata -> u_csr.trap_csr_rdata
  logic                trap_csr_hit;        // u_trap.csr_hit -> u_csr.trap_csr_hit
  logic                trap;                // u_trap.trap -> u_ctrl.trap, u_dbg.trap, u_rvfi.trap
  logic                bus_trap;            // u_trap.bus_trap -> u_ctrl.bus_trap, u_csr.unretire,
                                            //   u_rvfi.bus_trap
  logic                irq_pending;         // u_trap.irq_pending -> u_ctrl.irq_pending
  logic                irq_wake;            // WFI wake-up: an interrupt pending and enabled in mie,
                                            //   or an NMI (regardless of mstatus.MIE); u_trap.irq_wake
                                            //   -> u_ctrl.irq_wake

  // pipeline control
  logic                irq_take;            // u_ctrl.irq_take -> u_trap.irq_take, u_rvfi.irq_take
  logic                fetch_halt;          // u_ctrl: WFI drain / sleep, the IFU presents no new
                                            //   request; u_ctrl.fetch_halt -> u_ifu.halt
  logic                fetch_idle;          // u_ifu: no fetch outstanding or presented; u_ifu.idle
                                            //   -> u_ctrl.fetch_idle

  // ex units
  logic [3:0]          trap_cause;          // u_trap.trap_cause -> (no loads)
  logic                trap_return;         // u_trap.trap_return -> u_ctrl.trap_return, u_trig.mret,
                                            //   u_rvfi.trap_return
  logic [XLEN-1:0]     trap_redirect_pc;    // u_trap.redirect_pc -> u_ctrl.trap_redirect_pc,
                                            //   u_rvfi.trap_redirect_pc
  logic                dbg_ebreak;          // u_trap: EBREAK enters (re-enters) debug mode, no
                                            //   exception; u_trap.dbg_ebreak -> u_ctrl.dbg_ebreak,
                                            //   u_dbg.dbg_ebreak, u_rvfi.dbg_ebreak
  logic                dbg_return;          // u_trap: dret executes; u_trap.dbg_return ->
                                            //   u_ctrl.dbg_return, u_dbg.dbg_return
  logic                nmi_pending;         // u_trap: NMI pending and not blocked (dcsr.nmip);
                                            //   u_trap.nmi_pending -> u_dbg.nmi_pending
  logic [XLEN-1:0]     dbg_csr_rdata;       // u_dbg.csr_rdata -> u_csr.dbg_csr_rdata
  logic                dbg_csr_hit;         // u_dbg.csr_hit -> u_csr.dbg_csr_hit

  // debug
  logic                dbg_pending;         // u_dbg: enter debug mode on the next ex instruction
                                            //   (haltreq / step); u_dbg.dbg_pending ->
                                            //   u_ctrl.dbg_pending
  logic                dbg_take;            // u_ctrl: debug entry taken on the ex instruction (it
                                            //   does not execute); u_ctrl.dbg_take -> u_dbg.dbg_take,
                                            //   u_trig.dbg_take, u_rvfi.dbg_take
  logic                dbg_mask;            // u_dbg: debug mode or step: interrupts masked, WFI a
                                            //   nop; u_dbg.dbg_mask -> u_ctrl.dbg_mask
  logic                dbg_enter;           // debug mode is entered now (u_trap: mode = M);
                                            //   u_dbg.dbg_enter -> u_trap.dbg_enter
  logic                dcsr_prv_m;          // dcsr.prv is M: the mode after dret; u_dbg.dcsr_prv_m
                                            //   -> u_trap.dcsr_prv_m
  logic                priv_m;              // the privilege mode is M (0: U), u_trap; u_trap.priv_m
                                            //   -> u_csr.priv_m, u_dbg.priv_m, u_trig.priv_m,
                                            //   u_pmp.fetch_priv_m, u_rvfi.priv_m
  logic                ebreak_dm;           // u_dbg: EBREAK goes to the Debug Module (dcsr.ebreakm
                                            //   or debug mode); u_dbg.ebreak_dm -> u_trap.ebreak_dm
  logic                count_stop;          // u_dbg: dcsr.stopcount in debug mode: counters stop;
                                            //   u_dbg.count_stop -> u_csr.count_stop
  logic                dbg_redirect;        // u_dbg: debug event redirects fetch; u_dbg.dbg_redirect
                                            //   -> u_ctrl.dbg_redirect, u_rvfi.dbg_redirect
  logic [XLEN-1:0]     dbg_redirect_pc;     // DM halt / exception address, or dpc on dret;
                                            //   u_dbg.dbg_redirect_pc -> u_ctrl.dbg_redirect_pc,
                                            //   u_rvfi.dbg_redirect_pc
  logic                trap_m;              // u_trap: a trap into M-mode is taken (tcontrol mte /
                                            //   mpte); u_trap.trap_m -> u_trig.trap_m
  logic                trig_exc;            // u_trig: action-0 trigger hit on the ex instruction;
                                            //   u_trig.trig_exc -> u_ctrl.trig_exc
  logic                trig_dbg;            // u_trig: action-1 trigger hit on the ex instruction;
                                            //   u_trig.trig_dbg -> u_ctrl.trig_dbg, u_dbg.trig_dbg
  logic                brk_take;            // u_ctrl: trigger breakpoint taken on the ex instruction
                                            //   (it does not execute); u_ctrl.brk_take ->
                                            //   u_trap.brk_take, u_dbg.brk_take, u_trig.brk_take,
                                            //   u_rvfi.brk_take
  logic                trig_refetch;        // u_trig: a trigger CSR is written: refetch;
                                            //   u_trig.refetch -> u_ctrl.trig_refetch
  logic [XLEN-1:0]     trig_csr_rdata;      // u_trig.csr_rdata -> u_csr.trig_csr_rdata
  logic                trig_csr_hit;        // u_trig.csr_hit -> u_csr.trig_csr_hit
  logic                id_adv;              // u_ctrl: the id instruction moves to ex (trigger hit
                                            //   register); u_ctrl.id_adv -> u_trig.adv
  logic                ex_load;             // u_ctrl: ex loads at this edge (trigger hit register);
                                            //   u_ctrl.ex_load -> u_trig.load

  // results
  logic [XLEN-1:0]     result_wb;           // u_result.result_wb -> u_sb.result_wb

  // sampled inputs
  logic                irq_software_q;      // irq_software sampled (u_insample, one cycle late);
                                            //   u_insample.irq_software_q -> u_trap.irq_software
  logic                irq_timer_q;         // irq_timer sampled (u_insample, one cycle late);
                                            //   u_insample.irq_timer_q -> u_trap.irq_timer
  logic                irq_external_q;      // irq_external sampled (u_insample, one cycle late);
                                            //   u_insample.irq_external_q -> u_trap.irq_external
  logic [14:0]         irq_fast_q;          // irq_fast sampled (u_insample, one cycle late);
                                            //   u_insample.irq_fast_q -> u_trap.irq_fast
  logic                irq_nmi_q;           // irq_nmi sampled (u_insample, one cycle late);
                                            //   u_insample.irq_nmi_q -> u_trap.irq_nmi
  logic                debug_req_q;         // debug_req sampled (u_insample, one cycle late);
                                            //   u_insample.debug_req_q -> u_ctrl.debug_req,
                                            //   u_dbg.halt_req
  logic                fetch_enable_q;      // fetch_enable sampled (u_insample, one cycle late);
                                            //   u_insample.fetch_enable_q -> u_ctrl.fetch_enable

  // boot
  logic                mtvec_init;          // u_ctrl: load mtvec from boot_addr (u_trap);
                                            //   u_ctrl.mtvec_init -> u_trap.mtvec_init
  logic                boot_redirect;       // u_ctrl: redirect fetch to mtvec (boot_addr);
                                            //   u_ctrl.boot_redirect -> u_trap.boot_redirect

  // ex units
  logic                pmp_deny_load;       // u_pmp: a load at alu_result is not allowed -> u_lsu;
                                            //   u_pmp.data_deny_load -> u_lsu.pmp_deny_load
  logic                pmp_deny_store;      // u_pmp: a store at alu_result is not allowed -> u_lsu;
                                            //   u_pmp.data_deny_store -> u_lsu.pmp_deny_store

  // fetch
  logic [XLEN-1:0]     ifu_rsp_addr;        // u_ifu: address of the arriving fetch word -> u_pmp;
                                            //   u_ifu.rsp_addr -> u_pmp.fetch_addr
  logic                ifu_rsp_deny;        // u_pmp: the arriving fetch word may not be executed ->
                                            //   u_ifu; u_pmp.fetch_deny -> u_ifu.rsp_deny

  // ex units
  logic [XLEN-1:0]     pmp_csr_rdata;       // u_pmp: CSR read data -> u_csr; u_pmp.csr_rdata ->
                                            //   u_csr.pmp_csr_rdata
  logic                pmp_csr_hit;         // u_pmp: pmpcfg0 / pmpaddr0..3 addressed -> u_csr;
                                            //   u_pmp.csr_hit -> u_csr.pmp_csr_hit
  logic                pmp_refetch;         // u_pmp: a PMP CSR is written: refetch; u_pmp.refetch ->
                                            //   u_ctrl.pmp_refetch

  // fetch
  logic                ifu_mss_req;         // u_ifu: fetch request -> u_icache; u_ifu.mss_req ->
                                            //   u_icache.c_req
  logic                ifu_mss_gnt;         // u_icache: fetch request taken -> u_ifu; u_icache.c_gnt
                                            //   -> u_ifu.mss_gnt
  logic [XLEN-1:0]     ifu_mss_addr;        // u_ifu: fetch address -> u_icache; u_ifu.mss_addr ->
                                            //   u_icache.c_addr
  logic                ifu_mss_rvalid;      // u_icache: fetch response -> u_ifu; u_icache.c_rvalid
                                            //   -> u_ifu.mss_rvalid
  logic [31:0]         ifu_mss_rdata;       // u_icache: fetched word -> u_ifu; u_icache.c_rdata ->
                                            //   u_ifu.mss_rdata
  logic                ifu_mss_err;         // u_icache: fetch failed -> u_ifu; u_icache.c_err ->
                                            //   u_ifu.mss_err
  logic                ifu_priv;            // u_trap: privilege of the fetch -> u_icache;
                                            //   u_trap.fetch_priv_m -> u_icache.c_priv
  logic                fetch_flush;         // u_ctrl: FENCE.I leaves ex -> u_icache (invalidate);
                                            //   u_ctrl.fetch_flush -> u_icache.flush
  logic                icache_busy;         // u_icache: refill on the bus -> u_ctrl (WFI drain);
                                            //   u_icache.busy -> u_ctrl.icache_busy

  // ===========================================================================
  // u_insample : input sample registers: interrupts, debug_req, fetch_enable (ungated clock: wake inputs)
  // ===========================================================================
  chillus_insample #(
    .NF (15)
  ) u_insample (
    .clk            (clk),
    .rst_n          (rst_n),
    .irq_software   (irq_software),
    .irq_timer      (irq_timer),
    .irq_external   (irq_external),
    .irq_fast       (irq_fast),
    .irq_nmi        (irq_nmi),
    .debug_req      (debug_req),
    .fetch_enable   (fetch_enable),
    .irq_software_q (irq_software_q),
    .irq_timer_q    (irq_timer_q),
    .irq_external_q (irq_external_q),
    .irq_fast_q     (irq_fast_q),
    .irq_nmi_q      (irq_nmi_q),
    .debug_req_q    (debug_req_q),
    .fetch_enable_q (fetch_enable_q)
  );

  // ===========================================================================
  // u_cg : sleep clock gate: stops clk_core while the core sleeps in WFI
  // ===========================================================================
  basechili_clock_gate u_cg (
    .clk     (clk),
    .en      (clk_en),
    .test_en (test_en),
    .gclk    (clk_core)
  );

  // ===========================================================================
  // u_ifu : instruction fetch: prefetch buffer, 16/32-bit instruction alignment
  // ===========================================================================
  chillus_ifu #(
    .ADDR_W (XLEN),
    .DEPTH  (4),
    .MAX_OS (2)
  ) u_ifu (
    .clk            (clk_core),
    .rst_n          (rst_n),
    .test_en        (test_en),
    .redirect_valid (redirect_valid),
    .redirect_pc    (redirect_pc),
    .fast_valid     (fast_valid),
    .fast_cand      (fast_cand),
    .fast_pc        (fast_pc),
    .halt           (fetch_halt),
    .idle           (fetch_idle),
    .mss_req        (ifu_mss_req),
    .mss_gnt        (ifu_mss_gnt),
    .mss_addr       (ifu_mss_addr),
    .mss_rvalid     (ifu_mss_rvalid),
    .mss_rdata      (ifu_mss_rdata),
    .mss_err        (ifu_mss_err),
    .rsp_addr       (ifu_rsp_addr),
    .rsp_deny       (ifu_rsp_deny),
    .dec_valid      (ifu_valid),
    .dec_accept     (ifu_accept),
    .dec_instr      (ifu_instr),
    .dec_pc         (ifu_pc),
    .dec_is32       (ifu_is32),
    .dec_fault      (ifu_fault),
    .dec_fault_hi   (ifu_fault_hi)
  );

  // ===========================================================================
  // u_icache : instruction cache between u_ifu and imss_* (ICACHE_KB, 0: wires)
  // ===========================================================================
  chillus_icache #(
    .ADDR_W     (XLEN),
    .SIZE_KB    (ICACHE_KB),
    .CACHE_BASE (ICACHE_BASE),
    .CACHE_MASK (ICACHE_MASK)
  ) u_icache (
    .clk        (clk_core),
    .rst_n      (rst_n),
    .flush      (fetch_flush),
    .debug_mode (debug_mode),
    .busy       (icache_busy),
    .c_req      (ifu_mss_req),
    .c_gnt      (ifu_mss_gnt),
    .c_addr     (ifu_mss_addr),
    .c_priv     (ifu_priv),
    .c_rvalid   (ifu_mss_rvalid),
    .c_rdata    (ifu_mss_rdata),
    .c_err      (ifu_mss_err),
    .m_req      (imss_req),
    .m_gnt      (imss_gnt),
    .m_addr     (imss_addr),
    .m_priv     (imss_priv),
    .m_rvalid   (imss_rvalid),
    .m_rdata    (imss_rdata),
    .m_err      (imss_err)
  );

  // ===========================================================================
  // u_rvc : RV32C expander: 16-bit instructions to their 32-bit form (id)
  // ===========================================================================
  chillus_rvc u_rvc (
    .instr_in  (ifu_instr),
    .is32      (ifu_is32),
    .instr_out (rvc_instr),
    .illegal   (rvc_illegal)
  );

  // ===========================================================================
  // u_rsdec : source-register numbers from the raw encoding, in parallel with u_rvc / u_dec (id)
  // ===========================================================================
  chillus_rsdec u_rsdec (
    .valid (ifu_valid),
    .fault (ifu_fault),
    .instr (ifu_instr),
    .is32  (ifu_is32),
    .rs1   (rs1_id),
    .rs2   (rs2_id)
  );

  // ===========================================================================
  // u_dec : decoder (id) and decode-information pipeline; stall / flush -> hold / kill
  // ===========================================================================
  chillus_dec u_dec (
    .clk             (clk_core),
    .rst_n           (rst_n),
    .ifu_valid       (ifu_valid),
    .ifu_accept      (ifu_accept),
    .ifu_instr       (rvc_instr),
    .ifu_raw         (ifu_instr),
    .ifu_pc          (ifu_pc),
    .ifu_is32        (ifu_is32),
    .ifu_fault       (ifu_fault),
    .ifu_fault_hi    (ifu_fault_hi),
    .stall           (stall),
    .flush           (flush),
    .hold            (hold),
    .kill            (kill),
    .valid_id        (valid_id),
    .op_id           (op_id),
    .imm_id          (imm_id),
    .rs1_id          (dec_rs1_id),
    .rs2_id          (dec_rs2_id),
    .branch_op_id    (branch_op_id),
    .jump_op_id      (jump_op_id),
    .valid_ex        (valid_ex),
    .op_ex           (op_ex),
    .illegal_ex      (illegal_ex),
    .fault_ex        (fault_ex),
    .fault_hi_ex     (fault_hi_ex),
    .pc_ex           (pc_ex),
    .instr_ex        (instr_ex),
    .is32_ex         (is32_ex),
    .imm_ex          (imm_ex),
    .rd_ex           (rd_ex),
    .rs1_ex          (rs1_ex),
    .rs2_ex          (rs2_ex),
    .csr_ex          (csr_ex),
    .alu_op_ex       (alu_op_ex),
    .alu_src1_ex     (alu_src1_ex),
    .alu_src2_ex     (alu_src2_ex),
    .branch_op_ex    (branch_op_ex),
    .jump_op_ex      (jump_op_ex),
    .mem_op_ex       (mem_op_ex),
    .mem_size_ex     (mem_size_ex),
    .mem_unsigned_ex (mem_unsigned_ex),
    .wb_src_ex       (wb_src_ex),
    .csr_op_ex       (csr_op_ex),
    .csr_uimm_ex     (csr_uimm_ex),
    .fence_i_ex      (fence_i_ex),
    .ecall_ex        (ecall_ex),
    .ebreak_ex       (ebreak_ex),
    .mret_ex         (mret_ex),
    .dret_ex         (dret_ex),
    .wfi_ex          (wfi_ex),
    .md_op_ex        (md_op_ex),
    .valid_wb        (valid_wb),
    .op_wb           (op_wb),
    .illegal_wb      (illegal_wb),
    .fault_wb        (fault_wb),
    .pc_wb           (pc_wb),
    .instr_wb        (instr_wb),
    .rd_wb           (rd_wb),
    .mem_op_wb       (mem_op_wb),
    .wb_src_wb       (wb_src_wb)
  );

  // ===========================================================================
  // u_bp : static branch predictor (id): short backward branches and JAL taken, the rest not
  // ===========================================================================
  chillus_bp #(
    .XLEN (XLEN)
  ) u_bp (
    .in_valid  (valid_id),
    .branch_op (branch_op_id),
    .jump_op   (jump_op_id),
    .pc        (ifu_pc),
    .instr     (ifu_instr),
    .is32      (ifu_is32),
    .taken     (predict_taken),
    .target    (predict_target)
  );

  // ===========================================================================
  // u_ctrl : pipeline control: stall / flush vectors, IFU redirect, unit valids
  // ===========================================================================
  chillus_ctrl #(
    .XLEN (XLEN)
  ) u_ctrl (
    .clk              (clk_core),
    .rst_n            (rst_n),
    .hold             (hold),
    .kill             (kill),
    .valid_ex         (valid_ex),
    .valid_wb         (valid_wb),
    .stall            (stall),
    .flush            (flush),
    .load_use         (load_use),
    .md_busy          (md_busy),
    .lsu_req_stall    (lsu_req_stall),
    .lsu_rsp_stall    (lsu_rsp_stall),
    .lsu_req_wait     (lsu_req_wait),
    .jump             (jump),
    .no_jump          (no_jump),
    .predicted        (predicted),
    .jump_target      (jump_target),
    .trap             (trap),
    .bus_trap         (bus_trap),
    .irq_pending      (irq_pending),
    .trap_return      (trap_return),
    .trap_redirect_pc (trap_redirect_pc),
    .fence_i          (fence_i_ex),
    .wfi              (wfi_ex),
    .next_pc          (link),
    .cond_branch      (cond_branch),
    .cond_flip        (cond_flip),
    .alt_target       (alt_target),
    .dbg_pending      (dbg_pending),
    .dbg_mask         (dbg_mask),
    .dbg_ebreak       (dbg_ebreak),
    .dbg_return       (dbg_return),
    .dbg_redirect     (dbg_redirect),
    .dbg_redirect_pc  (dbg_redirect_pc),
    .dbg_take         (dbg_take),
    .valid_id         (valid_id),
    .trig_exc         (trig_exc),
    .trig_dbg         (trig_dbg),
    .trig_refetch     (trig_refetch),
    .pmp_refetch      (pmp_refetch),
    .brk_take         (brk_take),
    .id_adv           (id_adv),
    .ex_load          (ex_load),
    .predict_taken    (predict_taken),
    .predict_target   (predict_target),
    .redirect_valid   (redirect_valid),
    .redirect_pc      (redirect_pc),
    .fast_valid       (fast_valid),
    .fast_pc          (fast_pc),
    .fast_cand        (fast_cand),
    .ex_valid         (ex_valid),
    .ex_act           (ex_act),
    .ex_retire        (ex_retire),
    .predict_fire     (predict_fire),
    .irq_take         (irq_take),
    .irq_wake         (irq_wake),
    .debug_req        (debug_req_q),
    .fetch_idle       (fetch_idle),
    .icache_busy      (icache_busy),
    .fetch_halt       (fetch_halt),
    .fetch_flush      (fetch_flush),
    .fetch_enable     (fetch_enable_q),
    .mtvec_init       (mtvec_init),
    .boot_redirect    (boot_redirect),
    .core_sleep       (core_sleep),
    .clk_en           (clk_en)
  );

  // ===========================================================================
  // u_rf : integer register file, read in id, written from wb
  // ===========================================================================
  chillus_rf #(
    .XLEN  (XLEN),
    .LATCH (RF_LATCH)
  ) u_rf (
    .clk      (clk_core),
    .rst_n    (rst_n),
    .test_en  (test_en),
    .rs1_addr (rs1_id),
    .rs1_data (rf_rs1_data),
    .rs2_addr (rs2_id),
    .rs2_data (rf_rs2_data),
    .rd_we    (rf_we),
    .rd_addr  (rf_rd),
    .rd_data  (rf_wdata)
  );

  // ===========================================================================
  // u_sb : scoreboard: id -> ex operands, forwarding from wb, load-use stall
  // ===========================================================================
  chillus_scoreboard #(
    .XLEN (XLEN)
  ) u_sb (
    .clk         (clk_core),
    .rst_n       (rst_n),
    .hold        (hold),
    .kill        (kill),
    .valid_id    (valid_id),
    .rs1_id      (rs1_id),
    .rs2_id      (rs2_id),
    .dec_rs1_id  (dec_rs1_id),
    .dec_rs2_id  (dec_rs2_id),
    .rf_rs1_data (rf_rs1_data),
    .rf_rs2_data (rf_rs2_data),
    .rd_ex       (rd_ex),
    .mem_op_ex   (mem_op_ex),
    .late_ex     (md_late),
    .result_wb   (result_wb),
    .rs1_data    (rs1_data),
    .rs2_data    (rs2_data),
    .load_use    (load_use)
  );

  // ===========================================================================
  // u_alu : ALU (ex)
  // ===========================================================================
  chillus_alu #(
    .XLEN (XLEN)
  ) u_alu (
    .alu_op   (alu_op_ex),
    .alu_src1 (alu_src1_ex),
    .alu_src2 (alu_src2_ex),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data),
    .pc       (pc_ex),
    .imm      (imm_ex),
    .result   (alu_result),
    .cmp_eq   (alu_cmp_eq),
    .cmp_lt   (alu_cmp_lt)
  );

  // ===========================================================================
  // u_bru : branch unit (ex): jumps, branches, link address
  // ===========================================================================
  chillus_bru #(
    .XLEN   (XLEN),
    .IALIGN (16)
  ) u_bru (
    .in_valid          (ex_act),
    .branch_op         (branch_op_ex),
    .jump_op           (jump_op_ex),
    .is32              (is32_ex),
    .rd                (rd_ex),
    .rs1               (rs1_ex),
    .pc                (pc_ex),
    .rs1_data          (rs1_data),
    .cmp_eq            (alu_cmp_eq),
    .cmp_lt            (alu_cmp_lt),
    .imm               (imm_ex),
    .jump              (jump),
    .no_jump           (no_jump),
    .target_misaligned (target_misaligned),
    .target            (jump_target),
    .link              (link),
    .alt_target        (alt_target),
    .cond_branch       (cond_branch),
    .cond_flip         (cond_flip),
    .ras_push          (ras_push),
    .ras_pop           (ras_pop),
    .predicted         (predicted)
  );

  // ===========================================================================
  // u_lsu : load / store unit: request (ex, address from the ALU), response (wb)
  // ===========================================================================
  chillus_lsu #(
    .XLEN (XLEN)
  ) u_lsu (
    .clk                (clk_core),
    .rst_n              (rst_n),
    .in_valid           (ex_valid),
    .mem_op             (mem_op_ex),
    .mem_size           (mem_size_ex),
    .mem_unsigned       (mem_unsigned_ex),
    .addr               (alu_result),
    .rs2_data           (rs2_data),
    .misaligned         (mem_misaligned),
    .pmp_deny_load      (pmp_deny_load),
    .pmp_deny_store     (pmp_deny_store),
    .req_stall          (lsu_req_stall),
    .req_wait           (lsu_req_wait),
    .mss_req            (dmss_req),
    .mss_gnt            (dmss_gnt),
    .mss_we             (dmss_we),
    .mss_addr           (dmss_addr),
    .mss_be             (dmss_be),
    .mss_wdata          (dmss_wdata),
    .mss_rvalid         (dmss_rvalid),
    .mss_rdata          (dmss_rdata),
    .mss_err            (dmss_err),
    .rsp_stall          (lsu_rsp_stall),
    .access_fault       (access_fault),
    .access_fault_store (access_fault_store),
    .access_fault_addr  (access_fault_addr),
    .load_valid         (load_valid),
    .load_data          (load_data)
  );

  // ===========================================================================
  // u_csr : Zicsr execution (ex)
  // ===========================================================================
  chillus_csr #(
    .XLEN (XLEN)
  ) u_csr (
    .clk            (clk_core),
    .rst_n          (rst_n),
    .stall          (hold[STAGE_EX]),
    .in_valid       (ex_valid),
    .retire         (ex_retire),
    .unretire       (bus_trap),
    .mtime          (mtime),
    .hart_id        (hart_id),
    .count_stop     (count_stop),
    .priv_m         (priv_m),
    .csr_op         (csr_op_ex),
    .csr_uimm       (csr_uimm_ex),
    .csr_addr       (csr_ex),
    .rs1            (rs1_ex),
    .rs1_data       (rs1_data),
    .imm            (imm_ex),
    .rdata          (csr_rdata),
    .illegal        (csr_illegal),
    .trap_csr_addr  (trap_csr_addr),
    .trap_csr_we    (trap_csr_we),
    .trap_csr_wdata (trap_csr_wdata),
    .trap_csr_rdata (trap_csr_rdata),
    .trap_csr_hit   (trap_csr_hit),
    .dbg_csr_rdata  (dbg_csr_rdata),
    .dbg_csr_hit    (dbg_csr_hit),
    .trig_csr_rdata (trig_csr_rdata),
    .trig_csr_hit   (trig_csr_hit),
    .pmp_csr_rdata  (pmp_csr_rdata),
    .pmp_csr_hit    (pmp_csr_hit)
  );

  // ===========================================================================
  // u_trap : machine-mode trap unit (ex): exceptions, interrupts, trap CSRs, MRET
  // ===========================================================================
  chillus_trap #(
    .XLEN   (XLEN),
    .IALIGN (16)
  ) u_trap (
    .clk               (clk_core),
    .rst_n             (rst_n),
    .stall             (hold[STAGE_EX]),
    .in_valid          (ex_valid),
    .pc                (pc_ex),
    .instr             (instr_ex),
    .fetch_fault       (fault_ex),
    .fetch_fault_hi    (fault_hi_ex),
    .illegal           (illegal_ex),
    .csr_illegal       (csr_illegal),
    .target_misaligned (target_misaligned),
    .target            (jump_target),
    .ecall             (ecall_ex),
    .ebreak            (ebreak_ex),
    .mem_misaligned    (mem_misaligned),
    .mem_op            (mem_op_ex),
    .mem_addr          (alu_result),
    .mret              (mret_ex),
    .dret              (dret_ex),
    .wfi               (wfi_ex),
    .priv_m            (priv_m),
    .fetch_priv_m      (ifu_priv),
    .data_priv_m       (dmss_priv),
    .debug_mode        (debug_mode),
    .ebreak_dm         (ebreak_dm),
    .dbg_ebreak        (dbg_ebreak),
    .dbg_return        (dbg_return),
    .nmi_pending       (nmi_pending),
    .trap_m            (trap_m),
    .dbg_enter         (dbg_enter),
    .dcsr_prv_m        (dcsr_prv_m),
    .bus_fault         (access_fault),
    .bus_fault_store   (access_fault_store),
    .bus_fault_addr    (access_fault_addr),
    .bus_fault_pc      (pc_wb),
    .irq_software      (irq_software_q),
    .irq_timer         (irq_timer_q),
    .irq_external      (irq_external_q),
    .irq_fast          (irq_fast_q),
    .irq_nmi           (irq_nmi_q),
    .irq_pending       (irq_pending),
    .irq_wake          (irq_wake),
    .irq_take          (irq_take),
    .brk_take          (brk_take),
    .trap              (trap),
    .bus_trap          (bus_trap),
    .trap_cause        (trap_cause),
    .trap_return       (trap_return),
    .redirect_pc       (trap_redirect_pc),
    .boot_addr         (boot_addr),
    .mtvec_init        (mtvec_init),
    .boot_redirect     (boot_redirect),
    .csr_addr          (trap_csr_addr),
    .csr_we            (trap_csr_we),
    .csr_wdata         (trap_csr_wdata),
    .csr_rdata         (trap_csr_rdata),
    .csr_hit           (trap_csr_hit)
  );

  // ===========================================================================
  // u_dbg : debug mode (Sdext, ex): dcsr / dpc / dscratch, entry, dret
  // ===========================================================================
  chillus_dbg #(
    .XLEN              (XLEN),
    .IALIGN            (16),
    .DEBUG             (DEBUG),
    .DM_HALT_ADDR      (DM_HALT_ADDR),
    .DM_EXCEPTION_ADDR (DM_EXCEPTION_ADDR)
  ) u_dbg (
    .clk             (clk_core),
    .rst_n           (rst_n),
    .act             (ex_act),
    .pc              (pc_ex),
    .trap            (trap),
    .dbg_ebreak      (dbg_ebreak),
    .dbg_return      (dbg_return),
    .priv_m          (priv_m),
    .halt_req        (debug_req_q),
    .nmi_pending     (nmi_pending),
    .dbg_pending     (dbg_pending),
    .dbg_take        (dbg_take),
    .trig_dbg        (trig_dbg),
    .brk_take        (brk_take),
    .debug_mode      (debug_mode),
    .dbg_mask        (dbg_mask),
    .ebreak_dm       (ebreak_dm),
    .count_stop      (count_stop),
    .dbg_enter       (dbg_enter),
    .dcsr_prv_m      (dcsr_prv_m),
    .dbg_redirect    (dbg_redirect),
    .dbg_redirect_pc (dbg_redirect_pc),
    .csr_addr        (trap_csr_addr),
    .csr_we          (trap_csr_we),
    .csr_wdata       (trap_csr_wdata),
    .csr_rdata       (dbg_csr_rdata),
    .csr_hit         (dbg_csr_hit)
  );

  // ===========================================================================
  // u_trig : trigger module (Sdtrig): execute-address triggers, compare in id, hit into ex
  // ===========================================================================
  chillus_trig #(
    .XLEN         (XLEN),
    .NUM_TRIGGERS (NUM_TRIGGERS),
    .DEBUG        (DEBUG)
  ) u_trig (
    .clk        (clk_core),
    .rst_n      (rst_n),
    .pc         (ifu_pc),
    .adv        (id_adv),
    .load       (ex_load),
    .trig_exc   (trig_exc),
    .trig_dbg   (trig_dbg),
    .brk_take   (brk_take),
    .dbg_take   (dbg_take),
    .debug_mode (debug_mode),
    .priv_m     (priv_m),
    .trap_m     (trap_m),
    .mret       (trap_return),
    .csr_addr   (trap_csr_addr),
    .csr_we     (trap_csr_we),
    .csr_wdata  (trap_csr_wdata),
    .csr_rdata  (trig_csr_rdata),
    .csr_hit    (trig_csr_hit),
    .refetch    (trig_refetch)
  );

  // ===========================================================================
  // u_pmp : physical memory protection (PMP_REGIONS entries, 0: none): data check on the LSU request (ex), fetch check on the IFU response
  // ===========================================================================
  chillus_pmp #(
    .XLEN      (XLEN),
    .N_REGIONS (PMP_REGIONS)
  ) u_pmp (
    .clk             (clk_core),
    .rst_n           (rst_n),
    .debug_mode      (debug_mode),
    .data_addr       (alu_result),
    .data_priv_m     (dmss_priv),
    .data_deny_load  (pmp_deny_load),
    .data_deny_store (pmp_deny_store),
    .fetch_addr      (ifu_rsp_addr),
    .fetch_priv_m    (priv_m),
    .fetch_deny      (ifu_rsp_deny),
    .csr_addr        (trap_csr_addr),
    .csr_we          (trap_csr_we),
    .csr_wdata       (trap_csr_wdata),
    .csr_rdata       (pmp_csr_rdata),
    .csr_hit         (pmp_csr_hit),
    .refetch         (pmp_refetch)
  );

  // ===========================================================================
  // u_mdu : multiply / divide unit (ex): MUL pipelined into wb (late), MULH* / divide iterative, holding ex
  // ===========================================================================
  chillus_mdu #(
    .XLEN (XLEN)
  ) u_mdu (
    .clk         (clk_core),
    .rst_n       (rst_n),
    .test_en     (test_en),
    .stall       (hold[STAGE_EX]),
    .in_valid    (ex_valid),
    .md_op       (md_op_ex),
    .rs1_data    (rs1_data),
    .rs2_data    (rs2_data),
    .busy        (md_busy),
    .result      (md_result),
    .late        (md_late),
    .late_result (md_late_result)
  );

  // ===========================================================================
  // u_result : result register ex -> wb and register write-back
  // ===========================================================================
  chillus_result #(
    .XLEN (XLEN)
  ) u_result (
    .clk            (clk_core),
    .rst_n          (rst_n),
    .hold           (hold),
    .kill           (kill),
    .valid_ex       (valid_ex),
    .wb_src_ex      (wb_src_ex),
    .alu_result     (alu_result),
    .link           (link),
    .csr_rdata      (csr_rdata),
    .md_result      (md_result),
    .md_late        (md_late),
    .md_late_result (md_late_result),
    .valid_wb       (valid_wb),
    .wb_src_wb      (wb_src_wb),
    .rd_wb          (rd_wb),
    .load_data      (load_data),
    .result_wb      (result_wb),
    .rf_we          (rf_we),
    .rf_rd          (rf_rd),
    .rf_wdata       (rf_wdata)
  );

  // ===========================================================================
  // u_rvfi : RVFI retirement trace (verification only, no pipeline loads)
  // ===========================================================================
  chillus_rvfi #(
    .XLEN (XLEN)
  ) u_rvfi (
    .clk              (clk_core),
    .rst_n            (rst_n),
    .hold             (hold),
    .kill             (kill),
    .ex_act           (ex_act),
    .pc               (pc_ex),
    .instr            (instr_ex),
    .priv_m           (priv_m),
    .rs1              (rs1_ex),
    .rs2              (rs2_ex),
    .rs1_data         (rs1_data),
    .rs2_data         (rs2_data),
    .jump             (jump),
    .jump_target      (jump_target),
    .trap             (trap),
    .trap_return      (trap_return),
    .trap_redirect_pc (trap_redirect_pc),
    .dbg_ebreak       (dbg_ebreak),
    .dbg_redirect     (dbg_redirect),
    .dbg_redirect_pc  (dbg_redirect_pc),
    .bus_trap         (bus_trap),
    .irq_take         (irq_take),
    .dbg_take         (dbg_take),
    .brk_take         (brk_take),
    .next_pc          (link),
    .mss_req          (dmss_req),
    .mss_we           (dmss_we),
    .mem_addr         (alu_result),
    .mss_be           (dmss_be),
    .mss_wdata        (dmss_wdata),
    .mss_rdata        (dmss_rdata),
    .rf_we            (rf_we),
    .rf_rd            (rf_rd),
    .rf_wdata         (rf_wdata),
    .rvfi_valid       (rvfi_valid),
    .rvfi_order       (rvfi_order),
    .rvfi_insn        (rvfi_insn),
    .rvfi_trap        (rvfi_trap),
    .rvfi_halt        (rvfi_halt),
    .rvfi_intr        (rvfi_intr),
    .rvfi_mode        (rvfi_mode),
    .rvfi_ixl         (rvfi_ixl),
    .rvfi_rs1_addr    (rvfi_rs1_addr),
    .rvfi_rs2_addr    (rvfi_rs2_addr),
    .rvfi_rs1_rdata   (rvfi_rs1_rdata),
    .rvfi_rs2_rdata   (rvfi_rs2_rdata),
    .rvfi_rd_addr     (rvfi_rd_addr),
    .rvfi_rd_wdata    (rvfi_rd_wdata),
    .rvfi_pc_rdata    (rvfi_pc_rdata),
    .rvfi_pc_wdata    (rvfi_pc_wdata),
    .rvfi_mem_addr    (rvfi_mem_addr),
    .rvfi_mem_rmask   (rvfi_mem_rmask),
    .rvfi_mem_wmask   (rvfi_mem_wmask),
    .rvfi_mem_rdata   (rvfi_mem_rdata),
    .rvfi_mem_wdata   (rvfi_mem_wdata)
  );

endmodule
