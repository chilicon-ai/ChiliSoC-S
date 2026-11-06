// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_ctrl
//
// Pipeline control of id -> ex -> wb (pipeline-aware). Collects the
// stall / flush / redirect sources of the units and drives the decoder's
// stall / flush vectors, the IFU redirect and the per-unit valids, so the
// core top needs no logic. Owns the boot sequence and the WFI sleep state
// machine.
//
//   stall[id]  = load_use (scoreboard)
//   stall[ex]  = md_busy (multiply / divide unit: result not ready) ||
//                lsu_req_stall (LSU: the data request is not granted)
//   stall[wb]  = lsu_rsp_stall (LSU: the access in wb waits for rvalid)
//   flush[id]  = mispredict (branch unit) || trap_return (MRET) || refetch
//                (FENCE.I, WFI) || dbg_return (dret) || boot_redirect: kill
//                younger
//   flush[ex]  = trap || dbg_take || dbg_ebreak: kill the trapping
//                instruction, the one taken into debug mode, or the EBREAK
//                entering it (and, through the decoder, everything younger)
//   flush[wb]  = bus_trap: the load / store in wb got a bus error (rvalid
//                with err); kill it and everything younger
//   redirect   = dbg_redirect || trap || trap_return || mispredict || refetch
//                || predict_fire || boot_redirect
//   redirect_pc = the debug unit's pc (DM halt / exception address, dpc) on
//                a debug event, the trap unit's pc (mtvec / mepc) on trap / MRET
//                and boot (mtvec = boot_addr), the jump
//                target on an unpredicted jump, the next instruction (link)
//                on a branch wrongly predicted taken, FENCE.I or WFI, the
//                predictor's target on predict_fire
//
// Boot (boot_addr / fetch_enable): after reset
// fetch is halted (fetch_halt) until fetch_enable (sampled in
// chillus_insample) is first seen high. That cycle mtvec_init loads mtvec
// from boot_addr (trap unit, Direct mode); the next cycle boot_redirect
// redirects fetch to the trap unit's pc (mtvec) through the trap path, and
// from the cycle after fetch runs. fetch_enable is sticky: dropping it later
// has no effect. Two flops (u_boot): init_q (mtvec loaded), booted_q.
//
// Static branch prediction (BTFN, chillus_bp in id, chillus_bru.predicted in
// ex): an id instruction predicted taken redirects fetch to its target in
// the cycle it advances to ex (predict_fire = predict_taken && !hold[id] &&
// !kill[id]); it is not killed (the IFU's redirect-cycle instruction is the
// branch itself). In ex the branch unit resolves it:
//   jump    && !predicted : redirect to the jump target (mispredict_taken)
//   no_jump &&  predicted : redirect to link, the fall-through (mispredict_not)
//   otherwise             : the front end already fetches the right path
// An ex redirect is older and wins over predict_fire (kill[id]).
//
// FENCE.I (Zifencei): refetch from the next instruction, dropping prefetched
// (possibly stale) instruction words, and invalidates the instruction cache
// (fetch_flush, chillus_icache). Making earlier stores visible to instruction
// fetch beyond that is the MSS's part. A trigger CSR write (trig_refetch)
// refetches the same way, so the next instruction is compared (in id) with
// the new trigger configuration; so does a PMP CSR write (pmp_refetch), so
// the next instruction's words are fetched and checked again.
//
// Trigger hit register (chillus_trig): id_adv (the id instruction moves to
// ex) and ex_load (ex loads) are the decoder's id -> ex rule, so the
// trigger's hit register follows the instruction into ex.
//
// WFI (riscv-privileged.pdf 3.3.3): a WFI leaving ex (ex_retire; not one
// that traps: illegal in U-mode with mstatus.TW) retires like FENCE.I (refetch from the next instruction: younger killed, prefetch
// dropped) and starts the sleep state machine (state, u_state):
//   S_RUN   : normal execution.
//   S_DRAIN : fetch halted (fetch_halt: no new IFU request); waits until the
//             WFI and every older instruction have left wb (a store's
//             response included), the IFU has no fetch outstanding
//             (fetch_idle) and the instruction cache no refill (icache_busy). WFI waits for the core's own requests only
//             (the MSS has no busy inputs).
//   S_SLEEP : core_sleep (a flop bit of state: registered, glitch-free).
//   wake = irq_wake || debug_req returns S_DRAIN / S_SLEEP to S_RUN: fetch
//   resumes at the next instruction. irq_wake (trap unit) is an NMI or an
//   interrupt pending and enabled in mie, whatever mstatus.MIE; with MIE = 1
//   it is then taken on the next instruction when it reaches ex (mepc = WFI
//   + 4; that instruction does not execute first), with MIE = 0 execution
//   continues. A halt request (debug_req) enters debug mode the same way
//   (dpc = WFI + 4). In debug mode or while single-stepping (dbg_mask) WFI
//   is a nop: it refetches but does not drain or sleep. A WFI that reaches
//   ex with an interrupt already taken (irq_take) does not execute (mepc =
//   the WFI); one that retires with wake already high drains for a cycle and
//   resumes. While asleep no instruction is in the pipeline and no MSS
//   request is presented. Waking costs a refetch: the interrupt is not taken
//   straight from S_SLEEP.
// Sleep clock gate: clk_en = !core_sleep || wake enables the core clock gate
// (chillus_core u_cg): in S_SLEEP the clock of every unit but chillus_insample
// stops until wake. wake is combinational from registers that stay valid with
// the clock stopped: the interrupts and debug_req are sampled in
// chillus_insample on the ungated clock, mie and nmi_mode (u_trap) do not
// change while asleep. The gated edge that sees wake also moves S_SLEEP to
// S_RUN. debug_req arrives sampled (one cycle late).
//
// Debug mode (chillus_dbg) uses the trap paths, never the fast redirect:
//   dbg_take = (dbg_pending || trig_dbg) && take_ok
//              debug entry (haltreq / step / action-1 trigger) on the ex
//              instruction, like an interrupt (it does not execute; dpc =
//              its pc); above irq_take
//   brk_take = trig_exc && !dbg_pending && !irq_take && take_ok
//              action-0 trigger (chillus_trig): breakpoint exception on the
//              ex instruction, which does not execute (the trap unit traps)
//   dbg_ebreak (trap unit): EBREAK into debug mode, killed like a trap
//   dbg_return (trap unit): dret, completes like MRET (kill younger)
//   dbg_mask (debug mode or step): no interrupt (NMI included), WFI a nop
//
// Unit valids (ex), built only from older-stage kill (kill[wb]) so that no
// unit sees a combinational path from its own flush:
//   take_ok  = valid_ex && !kill[wb] && !hold[wb] && !lsu_req_wait
//              the ex instruction can be taken (interrupt / debug /
//              breakpoint): not behind an access still waiting for rvalid
//              (so its bus error is taken first), and not while its own data
//              request waits for gnt (a presented request is not withdrawn)
//   irq_take = irq_pending && !dbg_mask && !dbg_pending && take_ok
//              interrupt taken on the ex instruction (it does not execute)
//   ex_valid = valid_ex && !kill[wb] && !irq_take && !dbg_take && !brk_take
//                                               LSU, trap unit, CSR unit, MDU
//              (trap / CSR take hold[ex] as their stall). The data request
//              is gated by kill[wb]: a bus error in wb withdraws the next
//              request in its rvalid cycle (dmss_err -> dmss_req).
//   ex_act   = ex_valid && !hold[ex]            branch unit, FENCE.I: a held
//                                               jump / refetch redirects once
//   ex_retire = ex_act && !trap && !dbg_ebreak  CSR unit (minstret): traps are
//                                               taken in ex (bus faults: the
//                                               CSR unit's unretire), so the
//                                               instruction will retire
//
// Timing   : combinational. fast_pc depends on cond_branch, alt_target and
//            predict_target only (registers through the units' adders).
//            fast_cand: like fast_valid, but without any hold / kill: an id
//            prediction counts without hold[id] / kill[id] (no ex redirect,
//            no compare), an ex branch by its compare alone (cond_flip, not
//            gated by ex_act), so the IFU address does not depend on the data
//            MSS handshake (dmss_gnt / dmss_rvalid through hold).
//            fetch_halt / core_sleep: decoded from the state register; wake
//            reaches it at the next clock edge. clk_en: combinational from
//            the state register and wake (to the clock gate's enable latch).
// Invariant: jump, trap, trap_return and refetch are mutually exclusive
//            (one ex instruction; a misaligned jump traps instead).
//            dbg_take, trap, trap_return, dbg_ebreak and dbg_return are
//            mutually exclusive; dbg_take, irq_take and brk_take at most
//            one.
//            dbg_mask -> !irq_take.
//            predict_fire -> !mispredict && !trap && !trap_return && !refetch.
//            fast_valid -> redirect_valid && fast_pc == redirect_pc.
//            fast_valid -> fast_cand.
//            state != S_RUN -> !valid_ex (nothing enters: fetch halted).
//            !booted_q -> fetch_halt, !valid_ex; boot_redirect at most once.
//            state != S_RUN -> !debug_mode (WFI is a nop in debug mode).
//            core_sleep -> fetch_halt, !valid_wb, fetch_idle.
//            !clk_en -> core_sleep (the clock stops only in S_SLEEP).
// Debug    : a taken loop branch that still costs a refetch: predict_taken in
//            id (u_bp) and predicted in ex (u_bru) must both be high.
//            WFI never sleeps: state stuck in S_DRAIN -> drained terms
//            (valid_wb, fetch_idle); never
//            wakes: irq_wake (u_trap: mie & mip), debug_req, then clk_en
//            and the gate's latch (chillus_core u_cg.en_l).
//            Nothing fetched after reset: u_boot (init_q, booted_q) and the
//            fetch_enable input (u_insample.fetch_enable_q).
//            Halt request not taken: dbg_pending, then dbg_take's terms
//            (valid_ex, kill / hold of wb, lsu_req_wait).
// -----------------------------------------------------------------------------
module chillus_ctrl
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                          // address width
) (
  input  logic                clk,
  input  logic                rst_n,               // async, active-low
  // decoder
  input  logic [N_STAGES-1:0] hold,
  input  logic [N_STAGES-1:0] kill,
  input  logic                valid_ex,
  input  logic                valid_wb,
  output logic [N_STAGES-1:0] stall,
  output logic [N_STAGES-1:0] flush,
  // stall sources
  input  logic                load_use,            // scoreboard
  input  logic                md_busy,             // multiply / divide unit
  input  logic                lsu_req_stall,       // LSU: data request not granted this cycle
  input  logic                lsu_rsp_stall,       // LSU: the access in wb waits for rvalid
  input  logic                lsu_req_wait,        // LSU: a data request waits for gnt (registered)
  // flush / redirect sources
  input  logic                jump,                // branch unit: transfer to jump_target
  input  logic                no_jump,             // branch unit: branch not taken
  input  logic                predicted,           // branch unit: the front end predicted the ex instruction taken
  input  logic [XLEN-1:0]     jump_target,
  input  logic                trap,                // trap unit
  input  logic                bus_trap,            // trap unit: the trap is an older instruction's bus fault
  input  logic                irq_pending,         // trap unit: an enabled interrupt is pending
  input  logic                trap_return,         // trap unit (MRET)
  input  logic [XLEN-1:0]     trap_redirect_pc,    // mtvec on trap, mepc on MRET
  input  logic                fence_i,             // decoder: FENCE.I in ex
  input  logic                wfi,                 // decoder: WFI in ex
  input  logic [XLEN-1:0]     next_pc,             // branch unit link: next instruction
  input  logic                cond_branch,         // branch unit: a conditional branch is in ex (decode)
  input  logic                cond_flip,           // branch unit: its outcome differs from the static prediction (ungated)
  input  logic [XLEN-1:0]     alt_target,          // branch unit: the ex branch's not-followed address
  // debug mode (debug unit; trap unit for the instruction-based events)
  input  logic                dbg_pending,         // debug unit: enter debug mode on the next ex instruction
  input  logic                dbg_mask,            // debug unit: debug mode or step: no interrupt, WFI a nop
  input  logic                dbg_ebreak,          // trap unit: EBREAK enters debug mode (killed, not retired)
  input  logic                dbg_return,          // trap unit: dret
  input  logic                dbg_redirect,        // debug unit: redirect to dbg_redirect_pc
  input  logic [XLEN-1:0]     dbg_redirect_pc,
  output logic                dbg_take,            // enter debug mode on the ex instruction
  // triggers (chillus_trig)
  input  logic                valid_id,            // decoder: instruction in id
  input  logic                trig_exc,            // action-0 trigger hit on the ex instruction
  input  logic                trig_dbg,            // action-1 trigger hit on the ex instruction
  input  logic                trig_refetch,        // a trigger CSR is written
  input  logic                pmp_refetch,         // a PMP CSR is written (fetched words were checked with the old one)
  output logic                brk_take,            // trigger breakpoint taken on the ex instruction
  output logic                id_adv,              // the id instruction moves to ex
  output logic                ex_load,             // ex loads at this edge
  // static branch prediction (id)
  input  logic                predict_taken,       // predictor: id instruction predicted taken
  input  logic [XLEN-1:0]     predict_target,      // predictor: its target
  // IFU redirect
  output logic                redirect_valid,
  output logic [XLEN-1:0]     redirect_pc,
  output logic                fast_valid,          // this redirect may be requested now from fast_pc
  output logic [XLEN-1:0]     fast_pc,             // = redirect_pc when fast_valid; registered sources only
  output logic                fast_cand,           // fast_valid without hold / kill: the IFU presents fast_pc
  // unit valids (ex)
  output logic                ex_valid,
  output logic                ex_act,
  output logic                ex_retire,           // ex instruction leaves ex without a trap
  output logic                predict_fire,        // id instruction predicted taken advances: fetch its target
  // interrupt
  output logic                irq_take,            // take the pending interrupt on the ex instruction
  // WFI sleep
  input  logic                irq_wake,            // trap unit: NMI or mie & mip (whatever MIE)
  input  logic                debug_req,           // debug request (halt request): wakes from WFI
  input  logic                fetch_idle,          // IFU: no fetch outstanding or presented
  input  logic                icache_busy,         // instruction cache: refill on the bus
  output logic                fetch_halt,          // IFU: present no new request
  output logic                fetch_flush,         // instruction cache: FENCE.I leaves ex, invalidate
  // boot
  input  logic                fetch_enable,        // sampled: start fetching (sticky)
  output logic                mtvec_init,          // trap unit: load mtvec from boot_addr
  output logic                boot_redirect,       // redirect fetch to the trap unit's pc (mtvec)
  output logic                core_sleep,          // asleep in WFI: pipeline and MSS ports idle (registered)
  output logic                clk_en               // core clock gate enable: low asleep until wake
);

  typedef enum logic [1:0] {
    S_RUN   = 2'b00,
    S_DRAIN = 2'b01,
    S_SLEEP = 2'b10                                // state_q[1] is core_sleep
  } state_e;

  logic refetch;          // FENCE.I / WFI / trigger CSR write leaves ex: refetch the next instruction
  logic take_ok;          // an instruction in ex can be taken (interrupt / debug / breakpoint)
  logic mispredict_taken; // ex jump the front end did not follow: fetch jump_target
  logic mispredict_not;   // ex branch predicted taken but not taken: fetch next_pc
  logic mispredict;       // either: kill id, redirect
  logic fast_ex;          // ex conditional branch mispredicted: fast to alt_target
  logic fast_id;          // id prediction, no conditional branch in ex: fast to predict_target
  logic wfi_go;           // WFI leaves ex: refetch and drain
  logic wake;             // WFI wake-up: irq_wake or debug_req
  logic drained;          // WFI and older instructions gone, fetch idle
  logic [1:0] state_q;
  logic [1:0] state_d;
  state_e     state;      // enum view of state_q
  state_e     state_nx;
  logic       init_q;     // boot: mtvec loaded from boot_addr
  logic       booted_q;   // boot: redirected to boot_addr, fetch may run
  logic [1:0] boot_d;     // {init, booted} next
  logic [1:0] boot_q;

  always_comb begin
    stall            = '0;
    stall[STAGE_ID]  = load_use;
    stall[STAGE_EX]  = md_busy || lsu_req_stall;
    stall[STAGE_WB]  = lsu_rsp_stall;
  end

  // An interrupt is taken on the instruction in ex, which then does not
  // execute: no unit sees it (ex_valid low), the trap unit traps (mepc =
  // pc_ex). Not while wb is held (an older load / store waiting for rvalid),
  // so an older instruction's bus fault is always taken first, and not while
  // the ex instruction's own data request waits for gnt. Independent of md_busy,
  // so a multiply / divide in progress is abandoned (re-executed after MRET).
  // A debug entry (haltreq / step) is taken the same way, before an
  // interrupt; interrupts are masked in debug mode and while stepping.
  // A trigger hit (before) is taken the same way: action 1 as a debug entry,
  // action 0 as a breakpoint exception below an interrupt.
  assign take_ok   = valid_ex && !kill[STAGE_WB] && !hold[STAGE_WB] && !lsu_req_wait;
  assign dbg_take  = (dbg_pending || trig_dbg) && take_ok;
  assign irq_take  = irq_pending && !dbg_mask && !dbg_pending && !trig_dbg && take_ok;
  assign brk_take  = trig_exc && !dbg_pending && !irq_take && take_ok;
  assign ex_valid  = valid_ex && !kill[STAGE_WB] && !irq_take && !dbg_take && !brk_take;
  assign ex_act    = ex_valid && !hold[STAGE_EX];
  assign ex_retire = ex_act && !trap && !dbg_ebreak;
  assign wfi_go    = ex_act && wfi && !dbg_mask && !trap;
  assign refetch   = ex_act && !trap && (fence_i || wfi || trig_refetch || pmp_refetch);
  assign fetch_flush = ex_act && !trap && fence_i;
  assign id_adv    = valid_id && !hold[STAGE_ID] && !kill[STAGE_ID];
  assign ex_load   = !hold[STAGE_EX] || kill[STAGE_EX];

  assign mispredict_taken = jump && !predicted;
  assign mispredict_not   = no_jump && predicted;
  assign mispredict       = mispredict_taken || mispredict_not;
  assign predict_fire     = predict_taken && !hold[STAGE_ID] && !kill[STAGE_ID];

  always_comb begin
    flush            = '0;
    flush[STAGE_ID]  = mispredict || trap_return || refetch || dbg_return || boot_redirect;
    flush[STAGE_EX]  = trap || dbg_take || dbg_ebreak;
    flush[STAGE_WB]  = bus_trap;
  end

  assign redirect_valid = dbg_redirect || trap || trap_return || mispredict || refetch ||
                          predict_fire || boot_redirect;
  assign redirect_pc    = dbg_redirect                          ? dbg_redirect_pc  :
                          (trap || trap_return || boot_redirect) ? trap_redirect_pc :
                          mispredict_taken                      ? jump_target      :
                          (mispredict_not || refetch)           ? next_pc          :
                                                                  predict_target;

  // Fast redirect (chillus_ifu_fetch requests fast_pc in the redirect cycle):
  // only sources whose address comes from registers through an adder, so
  // the MSS request address never waits for forwarding or the comparator.
  // fast_pc is selected by cond_branch (decode), not by the outcome: with a
  // conditional branch in ex only its misprediction is fast (to
  // alt_target = redirect_pc of mispredict_taken / mispredict_not); without
  // one, an id prediction is (predict_target). JALR, traps, MRET, FENCE.I,
  // debug events and JAL (always predicted) take the registered path.
  assign fast_ex    = cond_branch && mispredict;
  assign fast_id    = !cond_branch && predict_fire;
  assign fast_valid = fast_ex || fast_id;
  assign fast_pc    = cond_branch ? alt_target : predict_target;
  // fast_cand: fast_valid without any hold / kill, so the IFU's address
  // select does not wait for the ex redirect on an id prediction, nor for
  // hold[ex] (the data MSS handshake) on an ex branch. A cycle with fast_cand
  // but no fast_valid (the prediction or branch is held or killed) presents
  // no request. An ex branch still selects by its compare (cond_flip):
  // suppressing the sequential fetch for every conditional branch in ex costs
  // CoreMark performance.
  assign fast_cand  = cond_flip || (!cond_branch && predict_taken);

  // ---------------------------------------------------------------------------
  // Boot: mtvec from boot_addr, then one redirect to it, then fetch
  // ---------------------------------------------------------------------------
  assign mtvec_init    = fetch_enable && !init_q;
  assign boot_redirect = init_q && !booted_q;
  assign boot_d        = {init_q || fetch_enable, init_q};

  basechili_dff #(.WIDTH(2)) u_boot (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (boot_d),
    .q     (boot_q)
  );

  assign {init_q, booted_q} = boot_q;

  // ---------------------------------------------------------------------------
  // WFI sleep state machine
  // ---------------------------------------------------------------------------
  // WFI raises no exception, so ex_act is its retirement (a bus fault of an
  // older access kills it through kill[wb], an interrupt through irq_take).
  assign wake    = irq_wake || debug_req;
  assign drained = !valid_wb && fetch_idle && !icache_busy;
  assign state   = state_e'(state_q);

  always_comb begin
    state_nx = state;
    case (state)
      S_RUN:   if (wfi_go)  state_nx = S_DRAIN;
      S_DRAIN: if (wake)    state_nx = S_RUN;
               else if (drained) state_nx = S_SLEEP;
      S_SLEEP: if (wake)    state_nx = S_RUN;
      default:              state_nx = S_RUN;
    endcase
  end
  assign state_d = state_nx;

  basechili_dff #(.WIDTH(2)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign fetch_halt = (state != S_RUN) || !booted_q;
  assign core_sleep = state_q[1];
  assign clk_en     = !core_sleep || wake;

endmodule
