// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// ChillU-S target macros for the RISC-V architectural tests (riscv-arch-test
// 3.x, RISCOF). Used by both plugins (chillus and the Sail reference) so the
// DUT and reference ELFs are built identically.
//
//   boot      : nothing; ChillU-S starts at RESET_PC = 0x8000_0000, where
//               link.ld puts rvtest_entry_point (.text.init first).
//   halt      : store 1 to tohost: chillus_tb (+tohost) ends the run as PASS,
//               Sail stops on its HTIF tohost write.
//   signature : [begin_signature, end_signature), 4-byte aligned; read by
//               Sail from memory, and by the chillus plugin from the ELF image
//               plus the stores in the RVFI trace.
//   interrupts: msip at the CLINT base 0x0200_0000, mtimecmp at 0x0200_4000
//               (chillus_clint); no external interrupt source.
#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#define ALIGNMENT 2

#define RVMODEL_DATA_SECTION \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 8; .global tohost; tohost: .dword 0;                     \
        .align 8; .global fromhost; fromhost: .dword 0;                 \
        .popsection;                                                    \
        .align 8; .global begin_regstate; begin_regstate:               \
        .word 128;                                                      \
        .align 8; .global end_regstate; end_regstate:                   \
        .word 4;

#define RVMODEL_HALT            ;\
  li x1, 1                      ;\
1:                              ;\
  sw x1, tohost, t2             ;\
  j 1b                          ;

#define RVMODEL_BOOT

#define RVMODEL_DATA_BEGIN      ;\
  RVMODEL_DATA_SECTION          ;\
  .align ALIGNMENT              ;\
  .global begin_signature       ;\
begin_signature:

#define RVMODEL_DATA_END        ;\
  .align ALIGNMENT              ;\
  .global end_signature         ;\
end_signature:

#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

// PMP: 4 entries (pmpcfg0, pmpaddr0..3), grain 4 bytes (G = 0)
#define RVMODEL_NUM_PMPS        4
#define RVMODEL_PMP_GRAIN       0

#define RVMODEL_CLINT_BASE      0x02000000
#define RVMODEL_MSIP            (RVMODEL_CLINT_BASE + 0x0000)
#define RVMODEL_MTIMECMP        (RVMODEL_CLINT_BASE + 0x4000)

#define RVMODEL_SET_MSW_INT     ;\
  li t1, 1                      ;\
  li t2, RVMODEL_MSIP           ;\
  sw t1, 0(t2)                  ;

#define RVMODEL_CLEAR_MSW_INT   ;\
  li t2, RVMODEL_MSIP           ;\
  sw x0, 0(t2)                  ;

#define RVMODEL_CLEAR_MTIMER_INT ;\
  li t1, -1                     ;\
  li t2, RVMODEL_MTIMECMP       ;\
  sw t1, 4(t2)                  ;\
  sw t1, 0(t2)                  ;

#define RVMODEL_CLEAR_MEXT_INT

#endif // _COMPLIANCE_MODEL_H
