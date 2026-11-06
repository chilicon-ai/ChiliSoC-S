// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_trap_chk (bound into chillus_trap)
//   - trap and trap_return are never both high           (header Invariants)
//   - mstatus.MPP reads 00 or 11; mepc[0] == 0 (mepc[1:0] == 0 for IALIGN
//     32); data_priv_m == (MPRV ? MPP == M : priv_m)      (header Invariants)
//   - privilege mode (header Privilege mode): it changes only on a trap, MRET,
//     debug entry or dret; a trap outside debug mode -> M, MPP = the old
//     mode; MRET -> mode = MPP, MPP = U (outside an NMI); MRET and WFI with
//     TW in U-mode trap; fetch_priv_m == priv_m
//   - both act only when the instruction leaves the stage: an exception trap
//     or MRET needs in_valid && !stall (bus fault / interrupt / trigger
//     breakpoint excepted); a trigger breakpoint is mcause 3, mtval = pc,
//     with no instruction shown and never with an interrupt
//   - irq_take only for a pending interrupt, with no instruction shown
//     (header Interrupts)
//   - redirect_pc is 4-byte aligned on a trap (mtvec BASE, Direct mode)
//   - a trap is not repeated in the next cycle (header Debug: a repeated
//     trap means the pipeline did not kill the trapping instruction)
//   - mie / mpie update only on trap, MRET or a CSR write; trap outside
//     debug mode -> MIE = 0
//   - at most one of trap, trap_return, dbg_ebreak, dbg_return; a trap in
//     debug mode changes no CSR (mepc, mcause, mtval, MIE / MPIE)
//                                                         (header Invariants)
//   - irq_pending implies irq_wake
//                                                         (header Invariants)
//   - a vectored interrupt goes to BASE + 4 * code, anything else to BASE
//     (header Vectored mode); an NMI sets nmi_mode, its MRET clears it and
//     restores mepc (header NMI)
// -----------------------------------------------------------------------------
module chillus_trap_chk #(
  parameter int XLEN   = 32,
  parameter int IALIGN = 32
) (
  input logic            clk,
  input logic            rst_n,
  input logic            stall,
  input logic            in_valid,
  input logic            mret,
  input logic            bus_fault,
  input logic            irq_pending,
  input logic            irq_take,
  input logic            brk_take,
  input logic [XLEN-1:0] pc,
  input logic [XLEN-1:0] mtval_d,
  input logic [4:0]      mcause_code_d,
  input logic            trap,
  input logic            bus_trap,
  input logic            trap_return,
  input logic [XLEN-1:0] redirect_pc,
  input logic [XLEN-1:0] mstatus_rd,
  input logic [XLEN-1:0] mepc,
  input logic            mie,
  input logic            irq_wake,
  input logic            nmi_mode,
  input logic            debug_mode,
  input logic            dbg_ebreak,
  input logic            dbg_return,
  input logic            mpie,
  input logic [XLEN-1:0] mtval,
  input logic            mcause_int,
  input logic [4:0]      mcause_code,
  input logic            nmi_entry,
  input logic            nmi_exit,
  input logic            mtvec_mode,
  input logic [XLEN-3:0] mtvec_base,
  input logic [4:0]      irq_code,
  input logic [XLEN-1:0] mstack_epc,
  input logic            priv_m,
  input logic            fetch_priv_m,
  input logic            data_priv_m,
  input logic            mpp_m,
  input logic            mprv,
  input logic            tw,
  input logic            wfi,
  input logic            dbg_enter
);

  logic [XLEN-1:0] vec_pc;         // the expected Vectored-mode interrupt target

  assign vec_pc = {mtvec_base, 2'b00} + XLEN'({irq_code, 2'b00});

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(!(trap && trap_return),
       ("chillus_trap: trap and trap_return both high"))
  `CHK(mstatus_rd[12:11] == 2'b11 || mstatus_rd[12:11] == 2'b00,
       ("chillus_trap: mstatus.MPP reads 00 or 11 violated: mstatus=%h", mstatus_rd))
  `CHK(data_priv_m == (mprv ? mpp_m : priv_m),
       ("chillus_trap: data_priv_m=%b, MPRV=%b MPP M=%b mode M=%b", data_priv_m, mprv, mpp_m, priv_m))
  `CHK(fetch_priv_m == priv_m,
       ("chillus_trap: fetch_priv_m != priv_m"))
  `CHK(!$stable(priv_m) |-> $past(trap || trap_return || dbg_enter || dbg_return),
       ("chillus_trap: the mode changed without a trap, MRET, debug entry or dret"))
  `CHK(trap && !debug_mode |=> priv_m && mpp_m == $past(priv_m),
       ("chillus_trap: trap: mode M=%b MPP M=%b (was mode M=%b)", priv_m, mpp_m, $past(priv_m)))
  `CHK(trap_return && !nmi_exit |=> priv_m == $past(mpp_m) && !mpp_m,
       ("chillus_trap: MRET: mode M=%b (MPP was M=%b), MPP M=%b", priv_m, $past(mpp_m), mpp_m))
  `CHK(in_valid && !stall && !priv_m && (mret || (wfi && tw)) |-> trap && !trap_return,
       ("chillus_trap: MRET / WFI (TW) in U-mode did not trap"))
  `CHK(mepc[0] == 1'b0 && (IALIGN == 16 || mepc[1] == 1'b0),
       ("chillus_trap: mepc alignment violated: mepc=%h IALIGN=%0d", mepc, IALIGN))
  `CHK(brk_take |-> !in_valid && !irq_take,
       ("chillus_trap: brk_take with an instruction shown or an interrupt: in_valid=%b irq_take=%b",
        in_valid, irq_take))
  `CHK(brk_take && !bus_trap && !debug_mode |-> mcause_code_d == 5'd3 && mtval_d == pc,
       ("chillus_trap: trigger breakpoint with mcause code %0d / mtval %h (pc %h)", mcause_code_d, mtval_d, pc))
  `CHK(trap && !bus_trap && !irq_take && !brk_take |-> in_valid && !stall,
       ("chillus_trap: exception trap without the instruction leaving the stage: in_valid=%b stall=%b",
        in_valid, stall))
  `CHK(trap_return |-> in_valid && !stall && mret && !bus_fault,
       ("chillus_trap: MRET without the instruction leaving the stage: in_valid=%b stall=%b mret=%b bus_fault=%b",
        in_valid, stall, mret, bus_fault))
  `CHK(bus_trap == bus_fault,
       ("chillus_trap: bus_trap == bus_fault violated"))
  `CHK(irq_take |-> irq_pending && !in_valid,
       ("chillus_trap: irq_take without a pending interrupt / with an instruction: irq_pending=%b in_valid=%b",
        irq_pending, in_valid))
  `CHK(trap |-> redirect_pc[1:0] == 2'b00,
       ("chillus_trap: trap redirect_pc (mtvec BASE) not 4-byte aligned: redirect_pc=%h", redirect_pc))
  `CHK(trap |=> !trap,
       ("chillus_trap: trap in two consecutive cycles (trapping instruction not killed?)"))
  `CHK($onehot0({trap, trap_return, dbg_ebreak, dbg_return}),
       ("chillus_trap: trap / trap_return / dbg_ebreak / dbg_return not exclusive: %b %b %b %b",
        trap, trap_return, dbg_ebreak, dbg_return))
  `CHK(trap && debug_mode |=> $stable(mepc) && $stable(mtval) && $stable(mcause_int) &&
                              $stable(mcause_code) && $stable(mie) && $stable(mpie),
       ("chillus_trap: a trap in debug mode changed a trap CSR"))
  `CHK(trap && !debug_mode |=> !mie,
       ("chillus_trap: mstatus.MIE set after a trap"))
  `CHK(irq_pending |-> irq_wake,
       ("chillus_trap: irq_pending without irq_wake"))
  `CHK(trap && irq_take && !bus_trap && mtvec_mode |-> redirect_pc == vec_pc,
       ("chillus_trap: vectored interrupt redirect_pc=%h, expected %h (code %0d)",
        redirect_pc, vec_pc, irq_code))
  `CHK(trap && !(irq_take && !bus_trap && mtvec_mode) |-> redirect_pc == {mtvec_base, 2'b00},
       ("chillus_trap: trap redirect_pc=%h is not mtvec BASE", redirect_pc))
  `CHK(nmi_entry |=> nmi_mode,
       ("chillus_trap: NMI taken but nmi_mode not set"))
  `CHK(nmi_exit |=> !nmi_mode && mepc == $past(mstack_epc & ~XLEN'(IALIGN / 8 - 1)),
       ("chillus_trap: MRET of the NMI did not clear nmi_mode / restore mepc=%h", mepc))

  `undef CHK

endmodule

bind chillus_trap chillus_trap_chk #(.XLEN(XLEN), .IALIGN(IALIGN)) u_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .stall       (stall),
  .in_valid    (in_valid),
  .mret        (mret),
  .bus_fault   (bus_fault),
  .irq_pending (irq_pending),
  .irq_take    (irq_take),
  .brk_take    (brk_take),
  .pc          (pc),
  .mtval_d     (mtval_d),
  .mcause_code_d (mcause_code_d),
  .trap        (trap),
  .bus_trap    (bus_trap),
  .trap_return (trap_return),
  .redirect_pc (redirect_pc),
  .mstatus_rd  (mstatus_rd),
  .mepc        (mepc),
  .mie         (mie),
  .irq_wake    (irq_wake),
  .nmi_mode    (nmi_mode),
  .debug_mode  (debug_mode),
  .dbg_ebreak  (dbg_ebreak),
  .dbg_return  (dbg_return),
  .mpie        (mpie),
  .mtval       (mtval),
  .mcause_int  (mcause_int),
  .mcause_code (mcause_code),
  .nmi_entry   (nmi_entry),
  .nmi_exit    (nmi_exit),
  .mtvec_mode  (mtvec_mode),
  .mtvec_base  (mtvec_base),
  .irq_code    (irq_code),
  .mstack_epc  (mstack_epc),
  .priv_m      (priv_m),
  .fetch_priv_m (fetch_priv_m),
  .data_priv_m (data_priv_m),
  .mpp_m       (mpp_m),
  .mprv        (mprv),
  .tw          (tw),
  .wfi         (wfi),
  .dbg_enter   (dbg_enter)
);
