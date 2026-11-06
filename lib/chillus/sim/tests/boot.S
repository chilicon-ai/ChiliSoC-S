/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S boot test: the boot inputs. The testbench drives hart_id =
# 0xa5 (+hart_id) and holds fetch_enable low for 60 cycles after reset, then
# pulses it for one cycle (+fetch_delay): the core must start at boot_addr
# (the testbench's BASE = _start) and keep running after fetch_enable drops
# (it is sticky). Covered: mtvec = boot_addr in Direct mode before software
# writes it, mhartid = hart_id, and fetch held until fetch_enable (mcycle
# counts from reset, so the first instruction sees mcycle >= 60).
# Stand-alone (no riscv-tests env): the env spins on a non-zero mhartid.
# run.py: no-spike; plusarg +hart_id=a5; plusarg +fetch_delay=60

  .section .text.init, "ax", @progbits
  .option norvc
  .globl _start
_start:
  csrr t2, mcycle               # first: cycles since reset

  li gp, 2                      # mtvec = boot_addr, Direct
  csrr t0, mtvec
  la t1, _start
  bne t0, t1, fail

  li gp, 3                      # mhartid = hart_id
  csrr t0, mhartid
  li t1, 0xa5
  bne t0, t1, fail

  li gp, 4                      # fetch waited for fetch_enable
  li t1, 60
  bltu t2, t1, fail

  li gp, 5                      # still running long after the pulse
  li t0, 200
1:
  addi t0, t0, -1
  bnez t0, 1b

pass:
  li t0, 1
  la t1, tohost
  sw t0, 0(t1)
2:
  j 2b

fail:
  slli gp, gp, 1
  ori gp, gp, 1
  la t1, tohost
  sw gp, 0(t1)
3:
  j 3b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
