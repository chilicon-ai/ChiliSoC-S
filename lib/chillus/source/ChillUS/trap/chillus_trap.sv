// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_trap
//
// Machine-mode trap unit (riscv-privileged.pdf, Chapter 3; ECALL / EBREAK
// per riscv-unprivileged.pdf Chapter 2.8). Stage-agnostic: it acts on the
// instruction presented on its inputs, in the stage where all of that
// instruction's exceptions are known (first top: ex). Owns the privilege
// mode: M and U (no S-mode, so every trap goes to M).
//
// Privilege mode (priv_m: 1 = M, 0 = U; reset M, so the hart boots in M):
//   trap (not in debug mode)  MPP = the mode trapped from, mode = M
//   MRET                      mode = MPP, MPP = U; MPRV = 0 when MPP was U
//   debug entry (dbg_enter)   mode = M (chillus_dbg saves the old one in
//                             dcsr.prv)
//   dret (dbg_return)         mode = dcsr.prv (dcsr_prv_m); MPRV = 0 when U
// In U-mode MRET, and WFI with mstatus.TW = 1, are illegal; ECALL raises
// mcause 8; M-level interrupts are enabled whatever mstatus.MIE (which only
// masks them in M-mode). CSR privilege (csr_addr[9:8], mcounteren) is
// checked by chillus_csr.
// Data privilege (data_priv_m): the mode of loads and stores, MPP while
// mstatus.MPRV = 1 (in debug mode too: dcsr.mprven = 1), else the mode.
// priv_m and data_priv_m are flops: the MSS ports' HPROT[1] (privileged)
// comes straight from them. Both follow the instruction in this stage: a
// change (trap, MRET, dret, a mstatus write) takes effect at the edge where
// that instruction leaves, and every change of the mode kills the younger
// instructions (redirect), so nothing fetched under the old mode executes.
//
// Exceptions, highest priority first (Table 17), with mcause / mtval:
//   1  instruction access fault   fetch_fault        mtval = pc, or pc + 2 with
//                                                      fetch_fault_hi (only the
//                                                      second halfword faulted)
//   2  illegal instruction        illegal,           mtval = instruction bits
//                                 csr_illegal,
//                                 dret && !debug_mode,
//                                 U-mode: mret, wfi && TW
//   0  instruction addr misaligned target_misaligned mtval = jump target
//   8 / 11 environment call       ecall              mtval = 0; 8 from U, 11 from M
//   3  breakpoint                 ebreak             mtval = pc (spec: pc or 0; as Spike);
//                                                      not with ebreak_dm (below)
//   4  load address misaligned    mem_misaligned     mtval = effective address
//   6  store address misaligned   mem_misaligned     mtval = effective address
//
// Trigger breakpoint (brk_take, Sdtrig chillus_trig: an action-0 execute
// trigger, timing "before"): the pipeline takes it on the instruction at pc
// like an interrupt (the instruction does not execute; this unit sees no
// instruction): mcause = 3, mepc = mtval = pc. Above every exception of the
// instruction (riscv-debug-specification Table 13), below an interrupt.
//
// Bus fault of an older instruction (bus_fault: the MSS answered a load /
// store with an error after that instruction left this stage; first top:
// it is in WB): takes priority over the instruction presented here, which
// the pipeline kills (it is younger). bus_trap = 1, mepc = bus_fault_pc,
//   5  load access fault          mtval = bus_fault_addr
//   7  store access fault         mtval = bus_fault_addr
//
// Interrupts (riscv-privileged.pdf 3.1.9, 3.1.14): mip.MEIP / MTIP / MSIP
// [11] / [7] / [3] = irq_external / irq_timer / irq_software (read-only);
// mie.MEIE / MTIE / MSIE enable them. The 15 local ("fast")
// interrupts irq_fast[i] are mip[16 + i] (read-only), enabled by mie[16 + i].
// irq_pending = NMI pending || ((mstatus.MIE || U-mode) && !nmi_mode &&
// (mie & mip) != 0).
// The pipeline decides when to take it (irq_take: it then shows this unit
// no instruction) and this unit traps with mcause = {1, code}, highest
// priority first: 31 NMI, 16 .. 30 fast (irq_fast[0] first), 11 machine
// external, 3 software, 7 timer; mepc = pc (the instruction that did not
// execute), mtval = 0. All sources are level-sensitive: software clears an
// interrupt at its source.
// irq_wake = NMI pending || (mie & mip) != 0, regardless of mstatus.MIE: the
// WFI wake-up condition (riscv-privileged.pdf 3.3.3). It depends only on the
// irq_* inputs and registers; the core samples irq_* in chillus_insample on
// the ungated clock, so it is valid while the core clock is gated.
//
// NMI: irq_nmi is taken regardless of
// mstatus.MIE and mie, as interrupt code 31. Taking it saves mepc, mcause
// and mstatus.MPIE / MPP in a one-entry stack (u_mstack_*) and sets nmi_mode,
// which blocks further NMIs and all other interrupts; the MRET that ends
// the handler (nmi_mode set) restores them, so the interrupted handler
// state survives. The NMI handler must not raise exceptions (they would
// overwrite mepc, and their MRET would end nmi_mode).
//
// Vectored mode: mtvec.MODE [0] is writable (bit 1 reads 0, as Spike: a
// write of 3 is 1), and in Vectored mode an interrupt (NMI included) goes to
// BASE + 4 * code; exceptions go to BASE.
//
// Taking a trap (trap = 1): mepc = pc of the trapping instruction (not the
// next one: ECALL / EBREAK do not retire), mcause = {0, code}, mtval as
// above, mstatus.MPIE = MIE, MIE = 0, MPP = the mode; redirect_pc = mtvec BASE
// (BASE + 4 * code for an interrupt in Vectored mode).
// The pipeline must kill the trapping instruction (no side effects, no rd
// write) and all younger ones, and redirect fetch to redirect_pc.
//
// MRET (trap_return = 1): MIE = MPIE, MPIE = 1, mode = MPP, MPP = U
// (in nmi_mode: MPIE / MPP from the stack); redirect_pc = mepc.
// MRET completes; the pipeline kills only younger instructions.
//
// Boot (chillus_ctrl): mtvec_init loads mtvec = {boot_addr BASE, Direct}
// (reset value 0 until then); boot_redirect selects redirect_pc = mtvec BASE
// without a trap, so fetch starts at boot_addr (bits [1:0] ignored).
//
// Debug mode (Sdext, chillus_dbg): an EBREAK with ebreak_dm (dcsr.ebreakm
// or debug mode) raises no exception but dbg_ebreak (enter / re-enter debug
// mode; the pipeline kills it like a trap and does not retire it). dret in
// debug mode executes (dbg_return); outside it is illegal. In debug mode an
// exception still traps (the pipeline kills and chillus_dbg redirects to the
// DM's exception address) but updates no CSR (no mepc / mcause / mtval /
// mstatus change); interrupts are masked by the pipeline (irq_take low).
// nmi_pending (dcsr.nmip) is the NMI pending and not blocked.
//
// Both act only when the instruction leaves the stage (in_valid && !stall),
// so each takes effect exactly once even if the stage is held.
//
// CSRs owned here, written through the CSR port by the CSR instructions. The
// CSR unit must work in the same stage as this unit, so a same-cycle csr_we
// belongs to the instruction presented here: when that instruction traps
// (e.g. an illegal CSR access), its CSR write is dropped.
//
//   0x300 mstatus  MIE [3], MPIE [7], MPP [12:11] (WARL: 11 = M, every other
//                  value is U, as Spike), MPRV [17], TW [21]; others 0
//                  (MPP resets to U, as Spike)
//   0x304 mie      MEIE [11], MTIE [7], MSIE [3], fast [30:16]; others 0
//   0x305 mtvec    BASE [XLEN-1:2]; MODE [0] (0 Direct, 1 Vectored), [1] = 0;
//                  boot_addr, Direct after boot
//   0x341 mepc     low bit(s) always 0 (IALIGN)
//   0x342 mcause   Interrupt [XLEN-1], Exception Code [4:0] (WLRL)
//   0x343 mtval
//   0x344 mip      MEIP [11], MTIP [7], MSIP [3], fast [30:16] from the
//                  irq_* inputs (read-only, writes ignored)
//
// Timing   : trap, trap_cause, trap_return, redirect_pc and csr_rdata are
//            combinational; the CSRs update at the clock edge.
// Invariants
//   trap and trap_return are never both high.
//   At most one of trap, trap_return, dbg_ebreak, dbg_return.
//   debug_mode && trap -> no CSR update (mepc, mcause, mtval, mstatus).
//   mstatus.MPP reads 00 or 11; mepc[0] == 0.
//   data_priv_m == (mstatus.MPRV ? MPP == M : priv_m).
//   irq_pending implies irq_wake.
// Debug    : cause (enum) / tval show the selected exception; exc_* show
//            every raised source. A trap repeated every cycle means the
//            pipeline did not kill the trapping instruction. Interrupts:
//            irq_code (taken code), irq_en3 / irq_en_fast (pending and
//            enabled), nmi_pend / nmi_mode; vector: trap_pc_vec. Mode:
//            priv_m, mpp_m, mprv, data_priv_m; an unexpected illegal
//            instruction in U-mode -> priv_illegal (or chillus_csr).
// -----------------------------------------------------------------------------
module chillus_trap
  import chillus_dec_pkg::*;
#(
  parameter int              XLEN        = 32,     // register width
  parameter int              IALIGN      = 32      // 32 without C, 16 with C
) (
  input  logic            clk,
  input  logic            rst_n,                   // async, active-low
  input  logic            stall,                   // this stage holds its instruction: no action

  // instruction in this stage
  input  logic            in_valid,                // real instruction; 0 when killed or a bubble
  input  logic [XLEN-1:0] pc,
  input  logic [31:0]     instr,                   // raw bits (mtval of an illegal instruction)
  // exception sources of this instruction
  input  logic            fetch_fault,             // decoder fault: IFU fetch error
  input  logic            fetch_fault_hi,          // with fetch_fault: only the second halfword (pc + 2) faulted
  input  logic            illegal,                 // decoder illegal
  input  logic            csr_illegal,             // CSR unit: access to a missing / read-only CSR
  input  logic            target_misaligned,       // branch unit
  input  logic [XLEN-1:0] target,                  // branch unit jump target
  input  logic            ecall,                   // decoder indication
  input  logic            ebreak,                  // decoder indication
  input  logic            mem_misaligned,          // LSU misaligned
  input  mem_op_e         mem_op,                  // load vs store for mem_misaligned
  input  logic [XLEN-1:0] mem_addr,                // LSU effective address
  input  logic            mret,                    // decoder indication
  input  logic            dret,                    // decoder indication
  input  logic            wfi,                     // decoder indication (illegal in U-mode with TW)

  // privilege mode
  output logic            priv_m,                  // the mode is M (0: U); registered
  output logic            fetch_priv_m,            // = priv_m: fetches are M-mode accesses (imss HPROT[1])
  output logic            data_priv_m,             // loads / stores are M-mode accesses (MPRV); registered

  // debug mode (chillus_dbg)
  input  logic            debug_mode,              // exceptions update no CSR; dret legal
  input  logic            ebreak_dm,               // EBREAK enters debug mode instead of trapping
  output logic            dbg_ebreak,              // EBREAK to debug mode executes (no trap)
  output logic            dbg_return,              // dret executes
  output logic            nmi_pending,             // NMI pending and not blocked (dcsr.nmip)
  output logic            trap_m,                  // a trap into M-mode is taken (not in debug mode): tcontrol
  input  logic            dbg_enter,               // debug unit: debug mode is entered now (mode = M)
  input  logic            dcsr_prv_m,              // debug unit: dcsr.prv is M (mode after dret)

  // bus fault of an older instruction (LSU access fault)
  input  logic            bus_fault,               // trap on it now (independent of stall / in_valid)
  input  logic            bus_fault_store,         // store (else load) access fault
  input  logic [XLEN-1:0] bus_fault_addr,          // access address (mtval)
  input  logic [XLEN-1:0] bus_fault_pc,            // its pc (mepc)

  // interrupts
  input  logic            irq_software,            // mip.MSIP
  input  logic            irq_timer,               // mip.MTIP
  input  logic            irq_external,            // mip.MEIP
  input  logic [14:0]     irq_fast,                // local interrupts: mip[16 + i]
  input  logic            irq_nmi,                 // non-maskable interrupt (code 31)
  output logic            irq_pending,             // take an interrupt: NMI, or MIE && mie & mip
  output logic            irq_wake,                // WFI wake-up: NMI or mie & mip, regardless of MIE
  input  logic            irq_take,                // pipeline: take it now, on the instruction at pc
  input  logic            brk_take,                // pipeline: trigger breakpoint on the instruction at pc

  // trap / return
  output logic            trap,                    // take a trap now: kill this and younger, redirect
  output logic            bus_trap,                // the trap is bus_fault: also kill the older instruction
  output logic [3:0]      trap_cause,              // exception code (mcause[3:0]) of the trap
  output logic            trap_return,             // MRET executes: kill younger, redirect
  output logic [XLEN-1:0] redirect_pc,             // mtvec BASE on trap and boot, mepc on MRET
  // boot (chillus_ctrl)
  input  logic [XLEN-1:0] boot_addr,               // mtvec BASE at boot
  input  logic            mtvec_init,              // load mtvec from boot_addr
  input  logic            boot_redirect,           // redirect_pc = mtvec BASE (no trap)

  // CSR port (CSR instructions)
  input  logic [11:0]     csr_addr,
  input  logic            csr_we,                  // write csr_wdata to csr_addr at the clock edge
  input  logic [XLEN-1:0] csr_wdata,
  output logic [XLEN-1:0] csr_rdata,               // 0 when !csr_hit
  output logic            csr_hit                  // csr_addr is a CSR of this unit
);

  // Exception codes (mcause, Interrupt = 0), Table 16
  typedef enum logic [3:0] {
    EXC_INSTR_MISALIGNED  = 4'd0,
    EXC_INSTR_FAULT       = 4'd1,
    EXC_ILLEGAL           = 4'd2,
    EXC_BREAKPOINT        = 4'd3,
    EXC_LOAD_MISALIGNED   = 4'd4,
    EXC_LOAD_FAULT        = 4'd5,
    EXC_STORE_MISALIGNED  = 4'd6,
    EXC_STORE_FAULT       = 4'd7,
    EXC_ECALL_U           = 4'd8,
    EXC_ECALL_M           = 4'd11
  } exc_e;

  // Interrupt codes (mcause, Interrupt = 1)
  localparam logic [3:0] IRQ_SOFTWARE = 4'd3;
  localparam logic [3:0] IRQ_TIMER    = 4'd7;
  localparam logic [3:0] IRQ_EXTERNAL = 4'd11;
  localparam logic [4:0] IRQ_NMI      = 5'd31;
  localparam int         IRQ_FAST0    = 16;        // code of irq_fast[0]

  localparam int NF = 15;                          // local interrupts
  localparam int CW = 5;                           // mcause exception code width

  localparam logic [11:0] CSR_MSTATUS = 12'h300;
  localparam logic [11:0] CSR_MIE     = 12'h304;
  localparam logic [11:0] CSR_MTVEC   = 12'h305;
  localparam logic [11:0] CSR_MIP     = 12'h344;
  localparam logic [11:0] CSR_MEPC    = 12'h341;
  localparam logic [11:0] CSR_MCAUSE  = 12'h342;
  localparam logic [11:0] CSR_MTVAL   = 12'h343;

  localparam logic [XLEN-1:0] EPC_MASK = ~XLEN'(IALIGN / 8 - 1);   // clears mepc[0] (and [1] for IALIGN 32)

  // exception selection
  logic            act;            // the instruction leaves the stage this cycle
  logic            exc_instr_fault;
  logic [XLEN-1:0] fetch_tval;     // instruction access fault mtval: its faulting portion
  logic            exc_illegal;
  logic            exc_instr_misaligned;
  logic            exc_ecall;
  logic            exc_breakpoint;
  logic            exc_load_misaligned;
  logic            exc_store_misaligned;
  logic            exc_any;        // some exception is raised
  exc_e            cause;          // highest-priority exception of this instruction
  logic [XLEN-1:0] tval;           // its trap value
  logic            exc_trap;       // this instruction traps
  logic            dret_illegal;   // dret outside debug mode
  logic            priv_illegal;   // U-mode: mret, or wfi with mstatus.TW
  exc_e            ecall_code;     // environment call from U or M
  logic            csr_upd;        // the trap updates the trap CSRs (not in debug mode)
  exc_e            trap_code;      // cause of the trap taken (bus fault or this instruction)
  logic [XLEN-1:0] trap_tval;
  logic [XLEN-1:0] trap_pc;        // mepc of the trap taken
  logic [4:0]      irq_code;       // highest-priority pending enabled interrupt (or NMI)
  logic [4:0]      trap_code_w;    // mcause code of the trap taken, 5 bits
  logic [XLEN-1:0] trap_pc_base;   // mtvec BASE
  logic [XLEN-1:0] trap_pc_vec;    // BASE + 4 * irq_code (Vectored mode)
  logic            trap_vec;       // this trap is vectored: an interrupt with mtvec.MODE = 1
  logic [NF-1:0]   irq_en_fast;    // fast interrupts pending and enabled in mie
  logic            irq_any_en;     // some interrupt pending and enabled in mie
  logic            nmi_pend;       // NMI pending and not blocked (not in nmi_mode)
  logic            nmi_mode;       // in the NMI handler (NMI taken, its MRET not yet)
  logic            nmi_entry;      // the NMI is taken this cycle
  logic            nmi_exit;       // MRET in nmi_mode: restore the stack
  logic [XLEN-1:0] mstack_epc;     // mepc saved by the NMI
  logic            mstack_int;     // mcause.Interrupt saved by the NMI
  logic [CW-1:0]   mstack_code;    // mcause code saved by the NMI
  logic            mstack_mpie;    // mstatus.MPIE saved by the NMI
  logic            mstack_mpp;     // mstatus.MPP (M) saved by the NMI
  logic            mtvec_mode;     // mtvec.MODE [0]: 1 = Vectored
  logic [2:0]      mip3;           // mip {MEIP, MTIP, MSIP}
  logic [2:0]      mie3;           // mie {MEIE, MTIE, MSIE}
  logic [2:0]      mie3_d;
  logic            mie3_en;
  logic [2:0]      irq_en3;        // mie3 & mip3
  logic [NF-1:0]   mie_fast;       // mie[30:16]
  logic [NF-1:0]   mie_fast_d;
  logic            mie_fast_en;
  logic            nmi_mode_d;
  logic            nmi_mode_en;

  // CSR state
  logic            mie;            // mstatus.MIE
  logic            mie_d;
  logic            mpie;           // mstatus.MPIE
  logic            mpie_d;
  logic            mstatus_en;
  logic            priv_m_d;
  logic            mpp_m;          // mstatus.MPP is M (0: U)
  logic            mpp_m_d;
  logic            mprv;           // mstatus.MPRV
  logic            mprv_d;
  logic            tw;             // mstatus.TW
  logic            tw_d;
  logic            data_priv_m_d;
  logic [XLEN-3:0] mtvec_base;     // mtvec.BASE (address bits XLEN-1:2)
  logic [XLEN-3:0] mtvec_base_d;
  logic            mtvec_en;
  logic            mtvec_mode_d;
  logic [XLEN-1:0] mepc;
  logic [XLEN-1:0] mepc_d;
  logic            mepc_en;
  logic            mcause_int;     // mcause.Interrupt
  logic            mcause_int_d;
  logic [CW-1:0]   mcause_code;    // mcause.Exception Code
  logic [CW-1:0]   mcause_code_d;
  logic            mcause_en;
  logic [XLEN-1:0] mtval;
  logic [XLEN-1:0] mtval_d;
  logic            mtval_en;

  // CSR port
  logic            csr_wr;         // csr_we of a non-trapping instruction
  logic            wr_mstatus;
  logic            wr_mtvec;
  logic            wr_mepc;
  logic            wr_mcause;
  logic            wr_mtval;
  logic            wr_mie;
  logic [XLEN-1:0] mie_rd;         // mie as read
  logic [XLEN-1:0] mip_rd;         // mip as read
  logic [XLEN-1:0] mstatus_rd;     // mstatus as read
  logic [XLEN-1:0] mtvec_rd;       // mtvec as read
  logic [XLEN-1:0] mcause_rd;      // mcause as read

  // ===========================================================================
  // Exception selection
  // ===========================================================================
  assign act = in_valid && !stall;

  assign exc_instr_fault      = fetch_fault;
  assign fetch_tval           = fetch_fault_hi ? pc + unsigned'(XLEN'(2)) : pc;
  assign dret_illegal         = dret && !debug_mode;
  assign priv_illegal         = !priv_m && (mret || (wfi && tw));
  assign exc_illegal          = illegal || csr_illegal || dret_illegal || priv_illegal;
  assign ecall_code           = priv_m ? EXC_ECALL_M : EXC_ECALL_U;
  assign exc_instr_misaligned = target_misaligned;
  assign exc_ecall            = ecall;
  assign exc_breakpoint       = ebreak && !ebreak_dm;
  assign exc_load_misaligned  = mem_misaligned && (mem_op == MEM_OP_LOAD);
  assign exc_store_misaligned = mem_misaligned && (mem_op == MEM_OP_STORE);

  assign exc_any = exc_instr_fault || exc_illegal || exc_instr_misaligned || exc_ecall ||
                   exc_breakpoint || exc_load_misaligned || exc_store_misaligned;

  // Lowest priority first: a later assignment overrides, so the highest
  // priority source (Table 17) is applied last.
  always_comb begin
    cause = EXC_INSTR_MISALIGNED;
    tval  = '0;
    if (exc_store_misaligned) begin cause = EXC_STORE_MISALIGNED; tval = mem_addr;      end
    if (exc_load_misaligned)  begin cause = EXC_LOAD_MISALIGNED;  tval = mem_addr;      end
    if (exc_breakpoint)       begin cause = EXC_BREAKPOINT;       tval = pc;            end
    if (exc_ecall)            begin cause = ecall_code;           tval = '0;            end
    if (exc_instr_misaligned) begin cause = EXC_INSTR_MISALIGNED; tval = target;        end
    if (exc_illegal)          begin cause = EXC_ILLEGAL;          tval = XLEN'(instr);  end
    if (exc_instr_fault)      begin cause = EXC_INSTR_FAULT;      tval = fetch_tval;    end
  end

  // ===========================================================================
  // Interrupts
  // ===========================================================================
  assign mip3        = {irq_external, irq_timer, irq_software};
  assign irq_en3     = mie3 & mip3;
  assign irq_any_en  = (irq_en3 != '0) || (irq_en_fast != '0);
  assign irq_pending = nmi_pend || ((mie || !priv_m) && !nmi_mode && irq_any_en);
  assign irq_wake    = nmi_pend || irq_any_en;

  // Lowest priority first: a later assignment overrides.
  always_comb begin
    irq_code = 5'(IRQ_TIMER);
    if (irq_en3[0]) irq_code = 5'(IRQ_SOFTWARE);
    if (irq_en3[2]) irq_code = 5'(IRQ_EXTERNAL);
    for (int i = NF - 1; i >= 0; i--) begin
      if (irq_en_fast[i]) irq_code = 5'(unsigned'(IRQ_FAST0 + i));
    end
    if (nmi_pend) irq_code = IRQ_NMI;
  end

  assign irq_en_fast = mie_fast & irq_fast;

  // NMI: one-entry stack of mepc / mcause / MPIE
  assign nmi_pend    = irq_nmi && !nmi_mode;
  assign nmi_entry   = irq_take && !bus_trap && nmi_pend;
  assign nmi_exit    = trap_return && nmi_mode;
  assign nmi_mode_en = nmi_entry || nmi_exit;
  assign nmi_mode_d  = nmi_entry;

  basechili_dffe #(.WIDTH(1)) u_nmi_mode (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_mode_en),
    .d     (nmi_mode_d),
    .q     (nmi_mode)
  );

  basechili_dffe #(.WIDTH(XLEN)) u_mstack_epc (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_entry),
    .d     (mepc),
    .q     (mstack_epc)
  );

  basechili_dffe #(.WIDTH(1)) u_mstack_int (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_entry),
    .d     (mcause_int),
    .q     (mstack_int)
  );

  basechili_dffe #(.WIDTH(CW)) u_mstack_code (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_entry),
    .d     (mcause_code),
    .q     (mstack_code)
  );

  basechili_dffe #(.WIDTH(1)) u_mstack_mpie (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_entry),
    .d     (mpie),
    .q     (mstack_mpie)
  );

  basechili_dffe #(.WIDTH(1)) u_mstack_mpp (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (nmi_entry),
    .d     (mpp_m),
    .q     (mstack_mpp)
  );

  // ===========================================================================
  // Trap taken: bus fault (older) / interrupt / exception of this instruction
  // ===========================================================================
  assign exc_trap    = act && exc_any;
  assign bus_trap    = bus_fault;
  assign trap        = exc_trap || bus_trap || irq_take || brk_take;
  assign trap_code   = bus_trap ? (bus_fault_store ? EXC_STORE_FAULT : EXC_LOAD_FAULT) :
                       brk_take ? EXC_BREAKPOINT : cause;
  assign trap_code_w = (irq_take && !bus_trap) ? irq_code : {1'b0, trap_code};
  assign trap_tval   = bus_trap ? bus_fault_addr : irq_take ? '0 : brk_take ? pc : tval;
  assign trap_pc     = bus_trap ? bus_fault_pc   : pc;
  assign trap_cause  = trap_code_w[3:0];
  assign trap_return = act && mret && !exc_any && !bus_trap;
  assign dbg_ebreak  = act && ebreak && ebreak_dm && !exc_any && !bus_trap;
  assign dbg_return  = act && dret && !exc_any && !bus_trap;
  assign nmi_pending = nmi_pend;
  assign csr_upd     = trap && !debug_mode;
  assign trap_m      = csr_upd;

  // Trap vector: BASE + 4 * code (irq_code from registers and the irq_*
  // inputs, so the adder runs in parallel with the trap decision).
  assign trap_pc_base = {mtvec_base, 2'b00};
  assign trap_pc_vec  = trap_pc_base + XLEN'({irq_code, 2'b00});
  assign trap_vec     = mtvec_mode && irq_take && !bus_trap;
  assign redirect_pc  = !(trap || boot_redirect) ? mepc        :
                        trap_vec                 ? trap_pc_vec : trap_pc_base;

  // ===========================================================================
  // CSR port
  // ===========================================================================
  assign csr_wr     = csr_we && !trap;                // a trapping instruction writes no CSR
  assign wr_mstatus = csr_wr && (csr_addr == CSR_MSTATUS);
  assign wr_mtvec   = csr_wr && (csr_addr == CSR_MTVEC);
  assign wr_mepc    = csr_wr && (csr_addr == CSR_MEPC);
  assign wr_mcause  = csr_wr && (csr_addr == CSR_MCAUSE);
  assign wr_mtval   = csr_wr && (csr_addr == CSR_MTVAL);
  assign wr_mie     = csr_wr && (csr_addr == CSR_MIE);

  always_comb begin
    mstatus_rd        = '0;
    mstatus_rd[3]     = mie;
    mstatus_rd[7]     = mpie;
    mstatus_rd[12:11] = {mpp_m, mpp_m};                // MPP: 11 M, 00 U
    mstatus_rd[17]    = mprv;
    mstatus_rd[21]    = tw;
  end

  assign mtvec_rd = {mtvec_base, 1'b0, mtvec_mode};    // MODE: 0 Direct, 1 Vectored

  always_comb begin
    mie_rd     = '0;
    mie_rd[3]  = mie3[0];
    mie_rd[7]  = mie3[1];
    mie_rd[11] = mie3[2];
    mip_rd     = '0;
    mip_rd[3]  = mip3[0];
    mip_rd[7]  = mip3[1];
    mip_rd[11] = mip3[2];
    mie_rd[IRQ_FAST0 +: NF] = mie_fast;
    mip_rd[IRQ_FAST0 +: NF] = irq_fast;
  end

  always_comb begin
    mcause_rd         = '0;
    mcause_rd[XLEN-1] = mcause_int;
    mcause_rd[CW-1:0] = mcause_code;
  end

  always_comb begin
    case (csr_addr)
      CSR_MSTATUS: csr_rdata = mstatus_rd;
      CSR_MTVEC:   csr_rdata = mtvec_rd;
      CSR_MEPC:    csr_rdata = mepc;
      CSR_MCAUSE:  csr_rdata = mcause_rd;
      CSR_MTVAL:   csr_rdata = mtval;
      CSR_MIE:     csr_rdata = mie_rd;
      CSR_MIP:     csr_rdata = mip_rd;
      default:     csr_rdata = '0;
    endcase
  end

  assign csr_hit = (csr_addr == CSR_MSTATUS) || (csr_addr == CSR_MTVEC) ||
                   (csr_addr == CSR_MEPC) || (csr_addr == CSR_MCAUSE) ||
                   (csr_addr == CSR_MTVAL) || (csr_addr == CSR_MIE) ||
                   (csr_addr == CSR_MIP);

  // ===========================================================================
  // CSR registers
  // ===========================================================================
  // mstatus.MIE / MPIE: trap pushes, MRET pops the interrupt-enable stack
  assign mstatus_en = csr_upd || trap_return || wr_mstatus;
  assign mie_d      = csr_upd     ? 1'b0 :
                      trap_return ? mpie :
                                    csr_wdata[3];
  assign mpie_d     = csr_upd     ? mie  :
                      nmi_exit    ? mstack_mpie :
                      trap_return ? 1'b1 :
                                    csr_wdata[7];

  basechili_dffe #(.WIDTH(1)) u_mie (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mstatus_en),
    .d     (mie_d),
    .q     (mie)
  );

  basechili_dffe #(.WIDTH(1)) u_mpie (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mstatus_en),
    .d     (mpie_d),
    .q     (mpie)
  );

  // Privilege mode and mstatus.MPP / MPRV / TW. Lowest priority first: the
  // events are exclusive (a CSR write comes from a non-trapping CSR
  // instruction, debug entry executes no instruction).
  always_comb begin
    priv_m_d = priv_m;
    mpp_m_d  = mpp_m;
    mprv_d   = mprv;
    tw_d     = tw;
    if (wr_mstatus) begin
      mpp_m_d = csr_wdata[12:11] == 2'b11;             // WARL: 01 / 10 are U
      mprv_d  = csr_wdata[17];
      tw_d    = csr_wdata[21];
    end
    if (dbg_return) begin
      priv_m_d = dcsr_prv_m;
      if (!dcsr_prv_m) mprv_d = 1'b0;
    end
    if (dbg_enter) priv_m_d = 1'b1;
    if (trap_return) begin
      priv_m_d = mpp_m;
      mpp_m_d  = nmi_exit && mstack_mpp;
      if (!mpp_m) mprv_d = 1'b0;
    end
    if (csr_upd) begin
      priv_m_d = 1'b1;
      mpp_m_d  = priv_m;
    end
  end

  assign data_priv_m_d = mprv_d ? mpp_m_d : priv_m_d;
  assign fetch_priv_m  = priv_m;

  basechili_dff #(.WIDTH(1), .RESET_VAL(1'b1)) u_priv_m (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (priv_m_d),
    .q     (priv_m)
  );

  basechili_dff #(.WIDTH(1)) u_mpp_m (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (mpp_m_d),
    .q     (mpp_m)
  );

  basechili_dff #(.WIDTH(1)) u_mprv (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (mprv_d),
    .q     (mprv)
  );

  basechili_dff #(.WIDTH(1)) u_tw (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (tw_d),
    .q     (tw)
  );

  basechili_dff #(.WIDTH(1), .RESET_VAL(1'b1)) u_data_priv_m (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (data_priv_m_d),
    .q     (data_priv_m)
  );

  // mtvec.BASE
  assign mtvec_en     = wr_mtvec || mtvec_init;
  assign mtvec_base_d = mtvec_init ? boot_addr[XLEN-1:2] : csr_wdata[XLEN-1:2];

  basechili_dffe #(.WIDTH(XLEN-2)) u_mtvec_base (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mtvec_en),
    .d     (mtvec_base_d),
    .q     (mtvec_base)
  );

  // mtvec.MODE [0] (bit 1 reads 0: a write of 2 is Direct, 3 Vectored, as Spike)
  assign mtvec_mode_d = !mtvec_init && csr_wdata[0];

  basechili_dffe #(.WIDTH(1)) u_mtvec_mode (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mtvec_en),
    .d     (mtvec_mode_d),
    .q     (mtvec_mode)
  );

  // mepc: address of the trapping instruction (restored by the NMI's MRET)
  assign mepc_en = csr_upd || wr_mepc || nmi_exit;
  assign mepc_d  = (csr_upd  ? trap_pc :
                    nmi_exit ? mstack_epc : csr_wdata) & EPC_MASK;

  basechili_dffe #(.WIDTH(XLEN)) u_mepc (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mepc_en),
    .d     (mepc_d),
    .q     (mepc)
  );

  // mcause
  assign mcause_en     = csr_upd || wr_mcause || nmi_exit;
  assign mcause_int_d  = csr_upd  ? (irq_take && !bus_trap) :
                         nmi_exit ? mstack_int : csr_wdata[XLEN-1];
  assign mcause_code_d = csr_upd  ? trap_code_w[CW-1:0] :
                         nmi_exit ? mstack_code : csr_wdata[CW-1:0];

  basechili_dffe #(.WIDTH(1)) u_mcause_int (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mcause_en),
    .d     (mcause_int_d),
    .q     (mcause_int)
  );

  basechili_dffe #(.WIDTH(CW)) u_mcause_code (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mcause_en),
    .d     (mcause_code_d),
    .q     (mcause_code)
  );

  // mie: MEIE [11], MTIE [7], MSIE [3], fast [30:16]; mip is read-only
  // (writes ignored)
  assign mie3_en = wr_mie;
  assign mie3_d  = {csr_wdata[11], csr_wdata[7], csr_wdata[3]};

  basechili_dffe #(.WIDTH(3)) u_mie3 (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mie3_en),
    .d     (mie3_d),
    .q     (mie3)
  );

  assign mie_fast_en = wr_mie;
  assign mie_fast_d  = csr_wdata[IRQ_FAST0 +: NF];

  basechili_dffe #(.WIDTH(NF)) u_mie_fast (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mie_fast_en),
    .d     (mie_fast_d),
    .q     (mie_fast)
  );

  // mtval
  assign mtval_en = csr_upd || wr_mtval;
  assign mtval_d  = csr_upd ? trap_tval : csr_wdata;

  basechili_dffe #(.WIDTH(XLEN)) u_mtval (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mtval_en),
    .d     (mtval_d),
    .q     (mtval)
  );

endmodule
