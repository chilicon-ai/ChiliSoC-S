// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_ctrl_chk (chillus_ctrl is combinational: bound into
// chillus_core for its clock, connected to u_ctrl's ports / nets)
//   - jump, trap, trap_return and refetch are mutually exclusive
//     (header Invariant)
//   - bus_trap -> trap; irq_take -> trap and irq_pending (the trap unit takes
//     it; ex_valid low)
//   - ex_retire -> ex_act -> ex_valid -> valid_ex (unit valid hierarchy)
//   - redirect_valid -> redirect_pc[0] == 0 (IALIGN 16; chillus_ifu_align
//     relies on it for pc[0] == 0)
//   - wb is stalled only by the LSU response wait and flushed only by a bus
//     error trap (bus_trap)
//   - predict_fire excludes every ex redirect (mispredict, trap, MRET,
//     FENCE.I) and never kills id (header Invariant)
//   - fast_valid -> redirect_valid && fast_pc == redirect_pc (header
//     Invariant)
//   - fast_valid -> fast_cand (header Invariant)
//   - debug mode (header Invariants): dbg_take, trap, trap_return,
//     dbg_ebreak and dbg_return exclusive; dbg_take and irq_take never both;
//     dbg_mask -> !irq_take; state != S_RUN -> !debug_mode; dbg_take ->
//     !ex_valid; dbg_take, irq_take, brk_take at most one; brk_take -> trap
//     and !ex_valid
//   - WFI sleep (header Invariants): fetch_halt -> no instruction in ex;
//     core_sleep -> fetch_halt, wb empty, the IFU idle with no instruction
//     for id, no MSS request presented
//   - sleep clock gate (header Invariant, chillus_core u_cg): !clk_en ->
//     core_sleep; core_sleep && !wake -> !clk_en (asleep, the clock stops);
//     clk_core pulses in exactly the cycles whose enable (clk_en || test_en,
//     settled before the clk edge) was high (counted at each clk falling edge)
//   - boot: before the boot redirect nothing is fetched or executed
//     (!booted_q -> fetch_halt, no fetch request, no instruction for id or
//     ex); boot_redirect -> redirect to boot_addr (bits [1:0] cleared) with
//     no trap
// -----------------------------------------------------------------------------
module chillus_ctrl_chk
  import chillus_dec_pkg::*;
(
  input logic                clk,
  input logic                rst_n,
  input logic [N_STAGES-1:0] stall,
  input logic [N_STAGES-1:0] flush,
  input logic                valid_ex,
  input logic                jump,
  input logic                trap,
  input logic                bus_trap,
  input logic                irq_pending,
  input logic                trap_return,
  input logic                refetch,
  input logic                mispredict,
  input logic                predict_fire,
  input logic                redirect_valid,
  input logic [XLEN-1:0]     redirect_pc,
  input logic                fast_valid,
  input logic [XLEN-1:0]     fast_pc,
  input logic                fast_cand,
  input logic                ex_valid,
  input logic                ex_act,
  input logic                ex_retire,
  input logic                irq_take,
  input logic                fetch_halt,
  input logic                core_sleep,
  input logic                fetch_idle,
  input logic                valid_wb,
  input logic                lsu_rsp_stall,
  input logic                ifu_valid,
  input logic                imss_req,
  input logic                dmss_req,
  input logic                dbg_take,
  input logic                booted,
  input logic                boot_redirect,
  input logic [XLEN-1:0]     boot_addr,
  input logic                brk_take,
  input logic                dbg_ebreak,
  input logic                dbg_return,
  input logic                dbg_mask,
  input logic                debug_mode,
  input logic                running,         // u_ctrl.state == S_RUN
  input logic                clk_en,
  input logic                wake,
  input logic                test_en,
  input logic                clk_core         // gated clock (u_cg.gclk)
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK($onehot0({jump, trap, trap_return, refetch}),
       ("chillus_ctrl: jump / trap / trap_return / refetch mutually exclusive violated: jump=%b trap=%b trap_return=%b refetch=%b",
        jump, trap, trap_return, refetch))
  `CHK(bus_trap |-> trap,
       ("chillus_ctrl: bus_trap -> trap violated"))
  `CHK(irq_take |-> trap && irq_pending && !ex_valid,
       ("chillus_ctrl: irq_take -> trap && irq_pending && !ex_valid violated: trap=%b irq_pending=%b ex_valid=%b",
        trap, irq_pending, ex_valid))
  `CHK(ex_retire |-> ex_act,
       ("chillus_ctrl: ex_retire -> ex_act violated"))
  `CHK(ex_act |-> ex_valid,
       ("chillus_ctrl: ex_act -> ex_valid violated"))
  `CHK(ex_valid |-> valid_ex,
       ("chillus_ctrl: ex_valid -> valid_ex violated"))
  `CHK(redirect_valid |-> redirect_pc[0] == 1'b0,
       ("chillus_ctrl: redirect_pc[0] == 0 violated: redirect_pc=%h jump=%b trap=%b trap_return=%b refetch=%b",
        redirect_pc, jump, trap, trap_return, refetch))
  `CHK(stall[STAGE_WB] == lsu_rsp_stall && flush[STAGE_WB] == bus_trap,
       ("chillus_ctrl: wb stall / flush not from the LSU wait / bus_trap: stall=%b flush=%b lsu_rsp_stall=%b bus_trap=%b",
        stall, flush, lsu_rsp_stall, bus_trap))

  `CHK(predict_fire |-> !mispredict && !trap && !trap_return && !refetch && !flush[STAGE_ID],
       ("chillus_ctrl: predict_fire with an ex redirect / id flush: mispredict=%b trap=%b trap_return=%b refetch=%b flush=%b",
        mispredict, trap, trap_return, refetch, flush))

  `CHK(fast_valid |-> redirect_valid && fast_pc == redirect_pc,
       ("chillus_ctrl: fast redirect address mismatch: redirect_valid=%b fast_pc=%h redirect_pc=%h mispredict=%b predict_fire=%b",
        redirect_valid, fast_pc, redirect_pc, mispredict, predict_fire))
  `CHK(fast_valid |-> fast_cand,
       ("chillus_ctrl: fast_valid -> fast_cand violated: mispredict=%b predict_fire=%b", mispredict, predict_fire))

  `CHK($onehot0({dbg_take, trap, trap_return, dbg_ebreak, dbg_return}),
       ("chillus_ctrl: dbg_take / trap / trap_return / dbg_ebreak / dbg_return not exclusive: %b %b %b %b %b",
        dbg_take, trap, trap_return, dbg_ebreak, dbg_return))
  `CHK($onehot0({dbg_take, irq_take, brk_take}),
       ("chillus_ctrl: dbg_take / irq_take / brk_take not exclusive: %b %b %b", dbg_take, irq_take, brk_take))
  `CHK(brk_take |-> trap && !ex_valid,
       ("chillus_ctrl: brk_take without trap or with ex_valid: trap=%b ex_valid=%b", trap, ex_valid))
  `CHK(dbg_mask |-> !irq_take,
       ("chillus_ctrl: interrupt taken in debug mode / while stepping"))
  `CHK(dbg_take |-> !ex_valid,
       ("chillus_ctrl: dbg_take with ex_valid (the instruction would execute)"))
  `CHK(!running |-> !debug_mode,
       ("chillus_ctrl: WFI sleep state in debug mode"))

  `CHK(fetch_halt |-> !valid_ex,
       ("chillus_ctrl: instruction in ex while fetch is halted (WFI)"))
  `CHK(core_sleep |-> fetch_halt && !valid_wb && fetch_idle && !ifu_valid && !imss_req && !dmss_req,
       ("chillus_ctrl: core_sleep with work in progress: fetch_halt=%b valid_wb=%b fetch_idle=%b ifu_valid=%b imss_req=%b dmss_req=%b",
        fetch_halt, valid_wb, fetch_idle, ifu_valid, imss_req, dmss_req))

  `CHK(!booted |-> fetch_halt && !imss_req && !ifu_valid && !valid_ex,
       ("chillus_ctrl: activity before boot: fetch_halt=%b imss_req=%b ifu_valid=%b valid_ex=%b",
        fetch_halt, imss_req, ifu_valid, valid_ex))
  `CHK(boot_redirect |-> redirect_valid && redirect_pc == {boot_addr[XLEN-1:2], 2'b00} && !trap,
       ("chillus_ctrl: boot redirect to %h (boot_addr %h, redirect_valid=%b trap=%b)",
        redirect_pc, boot_addr, redirect_valid, trap))

  `CHK(!clk_en |-> core_sleep,
       ("chillus_ctrl: core clock gated outside S_SLEEP: running=%b", running))
  `CHK(core_sleep && !wake |-> !clk_en,
       ("chillus_ctrl: asleep without wake-up but the core clock runs: clk_en=%b", clk_en))

  // clk_core pulses: one per clk cycle whose enable was high before the edge
  int unsigned gcnt;       // clk_core rising edges
  int unsigned gcnt_seen;  // gcnt at the previous clk falling edge
  logic        en_q;       // clk_en || test_en just before the last clk rising edge

  always @(posedge clk_core) gcnt <= gcnt + 1;
  always @(posedge clk) en_q <= clk_en || test_en;
  always @(negedge clk) begin
    if (rst_n && (gcnt - gcnt_seen) != 32'(en_q))
      $error("chillus_ctrl: clk_core had %0d edges in a cycle with enable %b (sleep clock gate u_cg)",
             gcnt - gcnt_seen, en_q);
    gcnt_seen <= gcnt;
  end

  `undef CHK

endmodule

bind chillus_core chillus_ctrl_chk u_ctrl_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .stall          (u_ctrl.stall),
  .flush          (u_ctrl.flush),
  .valid_ex       (u_ctrl.valid_ex),
  .jump           (u_ctrl.jump),
  .trap           (u_ctrl.trap),
  .bus_trap       (u_ctrl.bus_trap),
  .irq_pending    (u_ctrl.irq_pending),
  .trap_return    (u_ctrl.trap_return),
  .refetch        (u_ctrl.refetch),
  .mispredict     (u_ctrl.mispredict),
  .predict_fire   (u_ctrl.predict_fire),
  .redirect_valid (u_ctrl.redirect_valid),
  .redirect_pc    (u_ctrl.redirect_pc),
  .fast_valid     (u_ctrl.fast_valid),
  .fast_pc        (u_ctrl.fast_pc),
  .fast_cand      (u_ctrl.fast_cand),
  .ex_valid       (u_ctrl.ex_valid),
  .ex_act         (u_ctrl.ex_act),
  .ex_retire      (u_ctrl.ex_retire),
  .irq_take       (u_ctrl.irq_take),
  .fetch_halt     (u_ctrl.fetch_halt),
  .core_sleep     (u_ctrl.core_sleep),
  .fetch_idle     (u_ctrl.fetch_idle),
  .valid_wb       (u_ctrl.valid_wb),
  .lsu_rsp_stall  (u_ctrl.lsu_rsp_stall),
  .ifu_valid      (ifu_valid),
  .imss_req       (imss_req),
  .dmss_req       (dmss_req),
  .dbg_take       (u_ctrl.dbg_take),
  .booted         (u_ctrl.booted_q),
  .boot_redirect  (u_ctrl.boot_redirect),
  .boot_addr      (boot_addr),
  .brk_take       (u_ctrl.brk_take),
  .dbg_ebreak     (u_ctrl.dbg_ebreak),
  .dbg_return     (u_ctrl.dbg_return),
  .dbg_mask       (u_ctrl.dbg_mask),
  .debug_mode     (u_dbg.debug_mode),
  .running        (u_ctrl.state == u_ctrl.S_RUN),
  .clk_en         (clk_en),
  .wake           (u_ctrl.wake),
  .test_en        (test_en),
  .clk_core       (clk_core)
);
