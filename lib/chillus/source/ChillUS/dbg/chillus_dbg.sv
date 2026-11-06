// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_dbg
//
// Debug mode of the hart (Sdext, riscv-debug-specification.pdf Chapter 4),
// for an execution-based Debug Module (riscv-dbg, spec Appendix A.2): the DM
// ROM's park loop does the halt / resume handshake in software, so the core
// has only debug_req, the DM's halt and exception addresses, and dret.
// Stage-agnostic: it acts on the instruction presented on its inputs, in the
// stage of chillus_trap (first top: ex). With DEBUG = 0 it holds no flops,
// never requests entry and reports no CSR.
//
// Entry into debug mode (debug_mode = 1, dpc = pc, dcsr.cause set, fetch
// redirected to DM_HALT_ADDR), Table 8 priority, highest first:
//   3 haltreq  halt_req (sampled debug_req) \ the pipeline takes them on the
//   2 trigger  trig_dbg (action-1 trigger)   | ex instruction (dbg_take),
//   4 step     step_done                    / which does not execute:
//                                             dpc = that instruction
//   1 ebreak   an EBREAK with dcsr.ebreakm (M-mode) / dcsr.ebreaku (U-mode)
//              (dbg_ebreak from chillus_trap, which then raises no
//              breakpoint exception): dpc = the EBREAK
// On entry dcsr.prv saves the mode (priv_m) and the hart runs in M
// (dbg_enter: chillus_trap sets the mode); dret returns to dcsr.prv
// (dcsr_prv_m to chillus_trap).
// haltreq, trigger and step come in through dbg_take (cause 3 when halt_req
// is set, else 2 with trig_dbg, else 4); an EBREAK executes only when
// dbg_take did not take it.
// Single step (dcsr.step): after dret, step_done is set when the next
// instruction leaves ex (retired or trapped, also by a trigger breakpoint:
// brk_take), so the following instruction
// in ex (branch target, trap handler, ...) is taken with cause 4 before it
// executes. A fetch fault there is not raised (the faulting entry is taken
// instead). dbg_mask (debug_mode || step) masks interrupts (NMI included;
// stepie = 0) and makes WFI a nop.
//
// In debug mode:
//   EBREAK (dbg_ebreak)         re-enters DM_HALT_ADDR, no dcsr / dpc change
//   exception (trap)            DM_EXCEPTION_ADDR; chillus_trap updates no CSR
//   dret (dbg_return)           pc = dpc, debug_mode = 0
//   halt_req / step             ignored (dbg_pending low)
// Outside debug mode dret is an illegal instruction (chillus_trap) and the
// debug CSRs do not exist (csr_hit low: chillus_csr reports them illegal).
//
// CSRs (only in debug mode)
//   0x7B0 dcsr      debugver [31:28] = 4, ebreakm [15], ebreaku [12],
//                   stopcount [10] (R/W), cause [8:6] (set on entry),
//                   mprven [4] = 1 (MPRV applies in debug mode), nmip [3]
//                   (NMI pending), step [2] (R/W), prv [1:0] (set on entry;
//                   WARL: 3 = M, every other value is U); stepie, stoptime
//                   and the other fields 0
//   0x7B1 dpc       low bit(s) 0 (IALIGN)
//   0x7B2 dscratch0
//   0x7B3 dscratch1
// stopcount: count_stop = stopcount && debug_mode stops mcycle / minstret
// (chillus_csr).
//
// Timing   : dbg_pending, dbg_mask, debug_mode, ebreak_dm and count_stop come
//            from registers; dbg_redirect / dbg_redirect_pc and csr_rdata are
//            combinational; the state updates at the clock edge.
// Invariants
//   dpc[0] == 0.
//   debug_mode -> dcsr.cause is 1 .. 4.
//   debug_mode -> !dbg_pending.
//   At most one of entry, reenter, exc, dret per cycle.
// Debug    : no entry -> dbg_pending (halt_req, step_done, debug_mode) and
//            u_ctrl.dbg_take (valid_ex, hold / kill of mem); wrong resume pc
//            -> dpc, dbg_return; step runs on -> step_done, dcsr_step.
// -----------------------------------------------------------------------------
module chillus_dbg #(
  parameter int              XLEN              = 32,    // register width
  parameter int              IALIGN            = 32,    // 32 without C, 16 with C
  parameter bit              DEBUG             = 1'b1,  // Sdext present (0: no debug mode)
  parameter logic [XLEN-1:0] DM_HALT_ADDR      = '0,    // DM halt / ebreak entry address
  parameter logic [XLEN-1:0] DM_EXCEPTION_ADDR = '0     // DM address for an exception in debug mode
) (
  input  logic            clk,
  input  logic            rst_n,                   // async, active-low

  // instruction in this stage
  input  logic            act,                     // the instruction leaves the stage (retires or traps)
  input  logic [XLEN-1:0] pc,
  input  logic            trap,                    // trap unit: exception / bus fault taken now
  input  logic            dbg_ebreak,              // trap unit: EBREAK enters (re-enters) debug mode
  input  logic            dbg_return,              // trap unit: dret executes
  input  logic            priv_m,                  // trap unit: the mode is M (0: U)

  // entry request
  input  logic            halt_req,                // sampled debug_req (level)
  input  logic            nmi_pending,             // trap unit: NMI pending (dcsr.nmip)
  output logic            dbg_pending,             // enter debug mode on the next instruction
  input  logic            dbg_take,                // pipeline: entry taken now, on the instruction at pc
  input  logic            trig_dbg,                // trigger: action-1 hit on that instruction (cause 2)
  input  logic            brk_take,                // pipeline: trigger breakpoint taken (a step's trap)

  // state
  output logic            debug_mode,              // registered
  output logic            dbg_mask,                // debug_mode || dcsr.step: no interrupt, WFI is a nop
  output logic            ebreak_dm,               // EBREAK goes to the DM (ebreakm or debug mode)
  output logic            count_stop,              // dcsr.stopcount in debug mode: counters stop
  output logic            dbg_enter,               // debug mode is entered now (the mode becomes M)
  output logic            dcsr_prv_m,              // dcsr.prv is M: the mode after dret

  // redirect
  output logic            dbg_redirect,            // redirect fetch to dbg_redirect_pc
  output logic [XLEN-1:0] dbg_redirect_pc,         // DM_HALT_ADDR, DM_EXCEPTION_ADDR or dpc

  // CSR port (CSR instructions)
  input  logic [11:0]     csr_addr,
  input  logic            csr_we,                  // write csr_wdata to csr_addr at the clock edge
  input  logic [XLEN-1:0] csr_wdata,
  output logic [XLEN-1:0] csr_rdata,               // 0 when !csr_hit
  output logic            csr_hit                  // csr_addr is a debug CSR and debug_mode is set
);

  localparam logic [11:0] CSR_DCSR      = 12'h7B0;
  localparam logic [11:0] CSR_DPC       = 12'h7B1;
  localparam logic [11:0] CSR_DSCRATCH0 = 12'h7B2;
  localparam logic [11:0] CSR_DSCRATCH1 = 12'h7B3;

  localparam logic [2:0] CAUSE_EBREAK  = 3'd1;
  localparam logic [2:0] CAUSE_TRIGGER = 3'd2;
  localparam logic [2:0] CAUSE_HALTREQ = 3'd3;
  localparam logic [2:0] CAUSE_STEP    = 3'd4;

  localparam logic [XLEN-1:0] EPC_MASK = ~XLEN'(IALIGN / 8 - 1);   // clears dpc[0] (and [1] for IALIGN 32)

  logic            entry;          // enter debug mode now
  logic            reenter;        // EBREAK in debug mode: back to the halt address
  logic            exc;            // exception in debug mode
  logic            step_done;      // the stepped instruction left the stage
  logic            dcsr_ebreakm;
  logic            dcsr_ebreaku;
  logic            dcsr_stopcount;
  logic            dcsr_step;
  logic [2:0]      dcsr_cause;
  logic [XLEN-1:0] dpc;
  logic [XLEN-1:0] dcsr_rd;        // dcsr as read

  if (DEBUG) begin : g_dbg
    logic            csr_wr;           // csr_we of a non-trapping instruction
    logic            wr_dcsr;
    logic            wr_dpc;
    logic            wr_dscratch0;
    logic            wr_dscratch1;
    logic            debug_mode_d;
    logic            debug_mode_en;
    logic            step_done_d;
    logic [3:0]      dcsr_wr4;         // {ebreakm, ebreaku, stopcount, step} written
    logic [3:0]      dcsr_q4;          // {ebreakm, ebreaku, stopcount, step}
    logic            prv_en;           // dcsr.prv: entry or dcsr write
    logic            prv_d;
    logic [2:0]      cause_d;
    logic [XLEN-1:0] dpc_d;
    logic            dpc_en;
    logic [XLEN-1:0] dscratch0;
    logic [XLEN-1:0] dscratch1;

    assign entry   = dbg_take || (dbg_ebreak && !debug_mode);
    assign reenter = dbg_ebreak && debug_mode;
    assign exc     = trap && debug_mode;

    assign dbg_pending = !debug_mode && (halt_req || step_done);
    assign dbg_mask    = debug_mode || dcsr_step;
    assign ebreak_dm   = debug_mode || (priv_m ? dcsr_ebreakm : dcsr_ebreaku);
    assign dbg_enter   = entry;
    assign count_stop  = debug_mode && dcsr_stopcount;

    assign dbg_redirect    = entry || reenter || exc || dbg_return;
    assign dbg_redirect_pc = dbg_return ? dpc :
                             exc        ? DM_EXCEPTION_ADDR : DM_HALT_ADDR;

    // debug mode
    assign debug_mode_en = entry || dbg_return;
    assign debug_mode_d  = entry;

    basechili_dffe #(.WIDTH(1)) u_debug_mode (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (debug_mode_en),
      .d     (debug_mode_d),
      .q     (debug_mode)
    );

    // step: the instruction after dret left the stage (cleared on entry)
    assign step_done_d = !entry && (step_done || ((act || brk_take) && dcsr_step && !debug_mode));

    basechili_dff #(.WIDTH(1)) u_step_done (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (step_done_d),
      .q     (step_done)
    );

    // CSR port
    assign csr_hit      = debug_mode && (csr_addr[11:2] == CSR_DCSR[11:2]);
    assign csr_wr       = csr_we && csr_hit && !trap;
    assign wr_dcsr      = csr_wr && (csr_addr == CSR_DCSR);
    assign wr_dpc       = csr_wr && (csr_addr == CSR_DPC);
    assign wr_dscratch0 = csr_wr && (csr_addr == CSR_DSCRATCH0);
    assign wr_dscratch1 = csr_wr && (csr_addr == CSR_DSCRATCH1);

    always_comb begin
      case (csr_addr)
        CSR_DCSR:      csr_rdata = dcsr_rd;
        CSR_DPC:       csr_rdata = dpc;
        CSR_DSCRATCH0: csr_rdata = dscratch0;
        CSR_DSCRATCH1: csr_rdata = dscratch1;
        default:       csr_rdata = '0;
      endcase
    end

    // dcsr: ebreakm [15], ebreaku [12], stopcount [10], step [2] writable
    assign dcsr_wr4 = {csr_wdata[15], csr_wdata[12], csr_wdata[10], csr_wdata[2]};

    basechili_dffe #(.WIDTH(4)) u_dcsr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (wr_dcsr),
      .d     (dcsr_wr4),
      .q     (dcsr_q4)
    );

    assign {dcsr_ebreakm, dcsr_ebreaku, dcsr_stopcount, dcsr_step} = dcsr_q4;

    // dcsr.prv (M or U): the mode at entry, or written by the debugger
    assign prv_en = entry || wr_dcsr;
    assign prv_d  = entry ? priv_m : (csr_wdata[1:0] == 2'b11);

    basechili_dffe #(.WIDTH(1), .RESET_VAL(1'b1)) u_prv (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (prv_en),
      .d     (prv_d),
      .q     (dcsr_prv_m)
    );

    // dcsr.cause: Table 8 (haltreq, trigger, step; an EBREAK is only seen
    // when dbg_take did not take its instruction)
    assign cause_d = !dbg_take ? CAUSE_EBREAK  :
                     halt_req  ? CAUSE_HALTREQ :
                     trig_dbg  ? CAUSE_TRIGGER : CAUSE_STEP;

    basechili_dffe #(.WIDTH(3)) u_cause (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (entry),
      .d     (cause_d),
      .q     (dcsr_cause)
    );

    // dpc: the instruction not executed (dbg_take) or the EBREAK
    assign dpc_en = entry || wr_dpc;
    assign dpc_d  = (entry ? pc : csr_wdata) & EPC_MASK;

    basechili_dffe #(.WIDTH(XLEN)) u_dpc (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (dpc_en),
      .d     (dpc_d),
      .q     (dpc)
    );

    basechili_dffe #(.WIDTH(XLEN)) u_dscratch0 (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (wr_dscratch0),
      .d     (csr_wdata),
      .q     (dscratch0)
    );

    basechili_dffe #(.WIDTH(XLEN)) u_dscratch1 (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (wr_dscratch1),
      .d     (csr_wdata),
      .q     (dscratch1)
    );
  end else begin : g_nodbg
    assign entry           = 1'b0;
    assign reenter         = 1'b0;
    assign exc             = 1'b0;
    assign step_done       = 1'b0;
    assign debug_mode      = 1'b0;
    assign dbg_pending     = 1'b0;
    assign dbg_mask        = 1'b0;
    assign ebreak_dm       = 1'b0;
    assign count_stop      = 1'b0;
    assign dbg_redirect    = 1'b0;
    assign dbg_redirect_pc = '0;
    assign dcsr_ebreakm    = 1'b0;
    assign dcsr_ebreaku    = 1'b0;
    assign dbg_enter       = 1'b0;
    assign dcsr_prv_m      = 1'b1;
    assign dcsr_stopcount  = 1'b0;
    assign dcsr_step       = 1'b0;
    assign dcsr_cause      = '0;
    assign dpc             = '0;
    assign csr_hit         = 1'b0;
    assign csr_rdata       = '0;
  end

  always_comb begin
    dcsr_rd        = '0;
    dcsr_rd[31:28] = 4'd4;                // debugver: Sdext 1.0
    dcsr_rd[15]    = dcsr_ebreakm;
    dcsr_rd[12]    = dcsr_ebreaku;
    dcsr_rd[10]    = dcsr_stopcount;
    dcsr_rd[8:6]   = dcsr_cause;
    dcsr_rd[4]     = 1'b1;                // mprven: MPRV applies in debug mode
    dcsr_rd[3]     = nmi_pending;
    dcsr_rd[2]     = dcsr_step;
    dcsr_rd[1:0]   = {dcsr_prv_m, dcsr_prv_m};   // prv: 11 M, 00 U
  end

endmodule
