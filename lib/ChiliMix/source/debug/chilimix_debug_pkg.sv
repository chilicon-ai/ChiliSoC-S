// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_debug_pkg
//
// Debug module memory map, instruction encoders and the debug ROM of
// the execution-based debug module (chilimix_debug_dm; RISC-V debug spec 1.0
// Appendix A.2, the riscv-dbg scheme): the hart runs the ROM's park loop in
// debug mode and does the halt / resume / command handshake by loads and
// stores to the DM's memory. The ROM runs unchanged on RV32 and RV64 harts
// (word stores, byte loads, x0-relative addresses); RV64 abstract commands
// add ld / sd (aarsize 3).
//
// DM base address: 0x0000_0000 (as in ChiliSoC-S; SiFive
// puts its debug module there too). The ROM and the abstract commands
// address the DM as offset(x0), which needs the DM in the low 2 KiB / the
// ROM below 4 KiB of the address space:
//   + the ROM and commands are short, need one scratch register (dscratch0)
//     and restore cleanly after an exception in debug mode;
//   - address 0 cannot hold RAM / ROM (no "null pointer = valid memory"),
//     and the hart's halt / exception addresses are 0x800 / 0x808 (chillu
//     DM_HALT_ADDR / DM_EXCEPTION_ADDR set by the integration).
// A SoC that needs the DM elsewhere needs a position-
// independent ROM and commands: auipc for the base, a second scratch
// register (dscratch1) and saving it around CSR commands and exceptions.
//
// Memory map (byte offsets in the 4 KiB DM region; hart side):
//   0x100 HALTED     W  the hart is in the park loop (written every loop)
//   0x104 GOING      W  the hart took the go flag (starts the command)
//   0x108 RESUMING   W  the hart took the resume flag (about to dret)
//   0x10C EXCEPTION  W  an exception in debug mode (during a command)
//   0x33C CMD        R  CMD_WORDS words: the abstract command, then (no
//                       postexec) ebreak, or (postexec) nops into the
//                       program buffer
//   0x35C PROGBUF    R  PROGBUF_SIZE words, then IMPEBREAK (ebreak)
//   0x380 DATA       RW DATA_COUNT words (data0 ..), shadowed in dataN
//   0x400 FLAGS      R  byte 0: bit 0 go, bit 1 resume (hart 0)
//   0x800 ROM        R  ROM_WORDS words: 0x800 halt entry, 0x808 exception
// -----------------------------------------------------------------------------
package chilimix_debug_pkg;

  // ---- memory map
  localparam int          PROGBUF_SIZE = 8;               // program buffer words
  localparam int          DATA_COUNT   = 2;               // data registers
  localparam int          CMD_WORDS    = 8;               // abstract command words
  localparam int          ROM_WORDS    = 22;              // debug ROM words
  localparam logic [11:0] A_HALTED     = 12'h100;
  localparam logic [11:0] A_GOING      = 12'h104;
  localparam logic [11:0] A_RESUMING   = 12'h108;
  localparam logic [11:0] A_EXCEPTION  = 12'h10C;
  localparam logic [11:0] A_CMD        = 12'h33C;
  localparam logic [11:0] A_PROGBUF    = 12'h35C;
  localparam logic [11:0] A_IMPEBREAK  = 12'h37C;
  localparam logic [11:0] A_DATA       = 12'h380;
  localparam logic [11:0] A_FLAGS      = 12'h400;
  localparam logic [11:0] A_ROM        = 12'h800;         // halt address
  localparam logic [11:0] A_CMD_END     = 12'h35C;        // A_CMD + 4 * CMD_WORDS
  localparam logic [11:0] A_PROGBUF_END = 12'h37C;        // A_PROGBUF + 4 * PROGBUF_SIZE
  localparam logic [11:0] A_DATA_END    = 12'h388;        // A_DATA + 4 * DATA_COUNT
  localparam logic [11:0] A_ROM_END     = 12'h858;        // A_ROM + 4 * ROM_WORDS
  localparam logic [11:0] A_EXC_ENTRY  = 12'h808;         // exception address

  // ---- registers and CSRs used by the ROM and the commands
  localparam logic [4:0]  X_ZERO = 5'd0;
  localparam logic [4:0]  X_S0   = 5'd8;
  localparam logic [11:0] CSR_DSCRATCH0 = 12'h7B2;

  // ---- RV32I encoders
  function automatic logic [31:0] i_type(logic [11:0] imm, logic [4:0] rs1, logic [2:0] f3,
                                         logic [4:0] rd, logic [6:0] op);
    return {imm, rs1, f3, rd, op};
  endfunction

  function automatic logic [31:0] rv_lw(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return i_type(imm, rs1, 3'b010, rd, 7'b0000011);
  endfunction

  function automatic logic [31:0] rv_lbu(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return i_type(imm, rs1, 3'b100, rd, 7'b0000011);
  endfunction

  function automatic logic [31:0] rv_sw(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);
    return {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] rv_ld(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);    // RV64
    return i_type(imm, rs1, 3'b011, rd, 7'b0000011);
  endfunction

  function automatic logic [31:0] rv_sd(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);   // RV64
    return {imm[11:5], rs2, rs1, 3'b011, imm[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] rv_andi(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return i_type(imm, rs1, 3'b111, rd, 7'b0010011);
  endfunction

  function automatic logic [31:0] rv_csrw(logic [11:0] csr, logic [4:0] rs1);   // csrrw x0
    return i_type(csr, rs1, 3'b001, X_ZERO, 7'b1110011);
  endfunction

  function automatic logic [31:0] rv_csrr(logic [4:0] rd, logic [11:0] csr);    // csrrs rd, csr, x0
    return i_type(csr, X_ZERO, 3'b010, rd, 7'b1110011);
  endfunction

  function automatic logic [31:0] rv_bne(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] off);
    return {off[12], off[10:5], rs2, rs1, 3'b001, off[4:1], off[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] rv_jal(logic [4:0] rd, logic [20:0] off);
    return {off[20], off[10:1], off[11], off[19:12], rd, 7'b1101111};
  endfunction

  function automatic logic [31:0] rv_jalr(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
    return i_type(imm, rs1, 3'b000, rd, 7'b1100111);
  endfunction

  localparam logic [31:0] RV_NOP    = 32'h0000_0013;   // addi x0, x0, 0
  localparam logic [31:0] RV_FENCE  = 32'h0FF0_000F;   // fence iorw, iorw
  localparam logic [31:0] RV_EBREAK = 32'h0010_0073;
  localparam logic [31:0] RV_DRET   = 32'h7B20_0073;

  // ---- fixed abstract command words (CSR commands keep s0 in dscratch0)
  localparam logic [31:0] CMD_SAVE_S0    = rv_csrw(CSR_DSCRATCH0, X_S0);    // csrw dscratch0, s0
  localparam logic [31:0] CMD_RESTORE_S0 = rv_csrr(X_S0, CSR_DSCRATCH0);    // csrr s0, dscratch0
  localparam logic [31:0] CMD_LOAD_S0    = rv_lw(X_S0, X_ZERO, A_DATA);     // lw s0, DATA0(x0)
  localparam logic [31:0] CMD_STORE_S0   = rv_sw(X_S0, X_ZERO, A_DATA);     // sw s0, DATA0(x0)
  localparam logic [31:0] CMD_LOAD64_S0  = rv_ld(X_S0, X_ZERO, A_DATA);     // ld s0, DATA0(x0) (aarsize 3)
  localparam logic [31:0] CMD_STORE64_S0 = rv_sd(X_S0, X_ZERO, A_DATA);     // sd s0, DATA0(x0) (aarsize 3)

  // ---- debug ROM (at A_ROM; s0 is saved in dscratch0 while the ROM runs)
  //  0x800  jal  x0, entry           halt entry (debug_req, ebreak in debug mode)
  //  0x804  nop
  //  0x808  jal  x0, exception       exception in debug mode
  //  0x80C entry:
  //         fence                    the hart's stores reach the DM first
  //         csrw dscratch0, s0
  //  0x814 loop:
  //         sw   x0, HALTED(x0)
  //         lbu  s0, FLAGS(x0)
  //         andi s0, s0, 1
  //         bne  s0, x0, going
  //         lbu  s0, FLAGS(x0)
  //         andi s0, s0, 2
  //         bne  s0, x0, resume
  //         jal  x0, loop
  //  0x834 resume:
  //         sw   x0, RESUMING(x0)
  //         csrr s0, dscratch0
  //         dret
  //  0x840 going:
  //         csrr s0, dscratch0       every GPR holds the program's value
  //         sw   x0, GOING(x0)
  //         jalr x0, CMD(x0)
  //  0x84C exception:
  //         sw   x0, EXCEPTION(x0)
  //         csrr s0, dscratch0       a CSR command saved s0 there
  //         ebreak                   back to the park loop
  function automatic logic [ROM_WORDS*32-1:0] rom_image();
    logic [ROM_WORDS*32-1:0] img;
    img[0*32 +: 32]  = rv_jal(X_ZERO, 21'h00C);                 // 0x800 -> 0x80C
    img[1*32 +: 32]  = RV_NOP;                                  // 0x804
    img[2*32 +: 32]  = rv_jal(X_ZERO, 21'h044);                 // 0x808 -> 0x84C
    img[3*32 +: 32]  = RV_FENCE;                                // 0x80C
    img[4*32 +: 32]  = rv_csrw(CSR_DSCRATCH0, X_S0);            // 0x810
    img[5*32 +: 32]  = rv_sw(X_ZERO, X_ZERO, A_HALTED);         // 0x814 loop
    img[6*32 +: 32]  = rv_lbu(X_S0, X_ZERO, A_FLAGS);           // 0x818
    img[7*32 +: 32]  = rv_andi(X_S0, X_S0, 12'd1);              // 0x81C
    img[8*32 +: 32]  = rv_bne(X_S0, X_ZERO, 13'h020);           // 0x820 -> 0x840
    img[9*32 +: 32]  = rv_lbu(X_S0, X_ZERO, A_FLAGS);           // 0x824
    img[10*32 +: 32] = rv_andi(X_S0, X_S0, 12'd2);              // 0x828
    img[11*32 +: 32] = rv_bne(X_S0, X_ZERO, 13'h008);           // 0x82C -> 0x834
    img[12*32 +: 32] = rv_jal(X_ZERO, 21'h1F_FFE4);             // 0x830 -> 0x814 (-0x1C)
    img[13*32 +: 32] = rv_sw(X_ZERO, X_ZERO, A_RESUMING);       // 0x834 resume
    img[14*32 +: 32] = rv_csrr(X_S0, CSR_DSCRATCH0);            // 0x838
    img[15*32 +: 32] = RV_DRET;                                 // 0x83C
    img[16*32 +: 32] = rv_csrr(X_S0, CSR_DSCRATCH0);            // 0x840 going
    img[17*32 +: 32] = rv_sw(X_ZERO, X_ZERO, A_GOING);          // 0x844
    img[18*32 +: 32] = rv_jalr(X_ZERO, X_ZERO, A_CMD);          // 0x848
    img[19*32 +: 32] = rv_sw(X_ZERO, X_ZERO, A_EXCEPTION);      // 0x84C exception
    img[20*32 +: 32] = rv_csrr(X_S0, CSR_DSCRATCH0);            // 0x850
    img[21*32 +: 32] = RV_EBREAK;                               // 0x854
    return img;
  endfunction

  localparam logic [ROM_WORDS*32-1:0] ROM = rom_image();

endpackage
