// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_rvfi
//
// RISC-V Formal Interface (RVFI) retirement trace of the in-order pipeline
// id -> ex -> wb (pipeline-aware). Verification only: it drives no
// pipeline signal, so synthesis removes it when rvfi_* is left unconnected.
// Used to compare the core against a reference model (Spike commit log) and
// by riscv-formal.
//
//   ex  : instruction, pc, next pc, source registers and the MSS request are
//         captured when the instruction leaves ex (leave_ex = ex_act, or
//         brk_take: a trigger breakpoint, reported as a trap entry). This
//         includes an instruction that traps: the decoder kills it in ex, but
//         here it moves on as a trap entry so it is reported in order.
//   wb  : rvfi_valid when wb is not held (a load / store retires in its
//         rvalid cycle); the load word comes from mss_rdata in that cycle;
//         rd from the register file write port (rf_*). A load / store whose
//         access fails (bus_trap: the trap unit traps on it in wb and the
//         decoder kills it) is reported as a trap entry: rvfi_trap = 1, no
//         memory access, pc_wdata = the trap vector.
//
// The ex -> wb register follows the decoder's rule (load when !hold[wb] ||
// kill[wb]; the ex entry when it leaves, else a bubble = 0), with leave_ex
// instead of adv_ex so trap entries advance too.
//
// Fields (RVFI spec, riscv-formal docs/rvfi.md; byte-aligned memory fields)
//   rvfi_order       retirement index, 0 for the first instruction
//   rvfi_pc_wdata    jump target, trap / MRET redirect pc, else pc + 4
//                    (pc + 2 for a 16-bit instruction)
//   rvfi_rs*_addr    0 when the register is not read (decoder rule)
//   rvfi_rd_addr     0 when no register is written; rd_wdata 0 then
//   rvfi_mem_addr    byte address; mask bit 0 / data bits [7:0] are the byte
//                    at mem_addr (bus lanes shifted down by the address offset)
//   rvfi_trap        the instruction trapped: no rd write, no memory access
//   rvfi_intr        first instruction of a trap handler entered by an
//                    interrupt (the interrupted instruction is not reported),
//                    or of the DM code entered by a halt request / step
//   Debug mode: an instruction taken into debug mode by a halt request or
//   step (dbg_take) is not reported, like an interrupted one; an EBREAK
//   entering it is a trap entry; the next report is the DM code at the halt
//   address. pc_wdata of a debug event (entry, exception in debug mode,
//   dret) is the debug unit's redirect pc.
//   rvfi_mode        the privilege mode the instruction ran in (3 M, 0 U;
//                    priv_m in ex, carried next to the entry)
//   rvfi_halt = 0, rvfi_ixl from XLEN
//
// Timing   : rvfi_* are combinational from registers and the rf_* write port;
//            an instruction is reported in the cycle after it leaves ex
//            (later while wb waits for rvalid).
// Invariants
//   rvfi_valid && !rvfi_trap == valid_wb && !kill[wb] (decoder) when wb is
//   not held: the trace and the register write retire together.
//   valid_<s> == 0 -> every field of stage <s> is 0.
// Debug    : instruction missing from the trace -> leave_ex, en_wb, hold /
//            kill; wrong rd value -> u_result (this module only copies rf_*);
//            wrong load data -> off_wb, rmask_wb and mss_rdata in wb.
// -----------------------------------------------------------------------------
module chillus_rvfi
  import chillus_dec_pkg::*;
#(
  parameter  int XLEN   = 32,                      // register width
  localparam int N_LANE = XLEN / 8,                // byte lanes on the data bus
  localparam int OFF_W  = $clog2(N_LANE)           // byte offset bits within a bus word
) (
  input  logic                clk,
  input  logic                rst_n,               // async, active-low
  // pipeline control (decoder, ctrl)
  input  logic [N_STAGES-1:0] hold,
  input  logic [N_STAGES-1:0] kill,
  input  logic                ex_act,              // the ex instruction leaves ex at this edge
  // ex: instruction
  input  logic [XLEN-1:0]     pc,
  input  logic [31:0]         instr,
  input  logic                priv_m,              // trap unit: the mode is M (0: U)
  input  logic [4:0]          rs1,
  input  logic [4:0]          rs2,
  input  logic [XLEN-1:0]     rs1_data,            // after forwarding
  input  logic [XLEN-1:0]     rs2_data,            // after forwarding
  // ex: next pc
  input  logic                jump,                // branch unit
  input  logic [XLEN-1:0]     jump_target,
  input  logic                trap,                // trap unit
  input  logic                trap_return,         // trap unit (MRET)
  input  logic [XLEN-1:0]     trap_redirect_pc,    // mtvec on trap, mepc on MRET
  input  logic                dbg_ebreak,          // trap unit: EBREAK enters debug mode (not retired)
  input  logic                dbg_redirect,        // debug unit: debug event redirects fetch
  input  logic [XLEN-1:0]     dbg_redirect_pc,     // DM halt / exception address, dpc
  input  logic                bus_trap,            // trap unit: the wb load / store got a bus error
  input  logic                irq_take,            // an interrupt is taken (ex instruction not executed)
  input  logic                dbg_take,            // debug entry is taken (ex instruction not executed)
  input  logic                brk_take,            // trigger breakpoint taken (ex instruction reported as a trap)
  input  logic [XLEN-1:0]     next_pc,             // branch unit link: pc + 4 (pc + 2 if 16-bit)
  // ex: data MSS request, wb: response
  input  logic                mss_req,
  input  logic                mss_we,
  input  logic [XLEN-1:0]     mem_addr,            // byte address of the access (ALU result)
  input  logic [N_LANE-1:0]   mss_be,
  input  logic [XLEN-1:0]     mss_wdata,           // store data in every lane
  input  logic [XLEN-1:0]     mss_rdata,           // whole bus word (rvalid cycle)
  // wb: register file write port (chillus_result)
  input  logic                rf_we,
  input  logic [4:0]          rf_rd,
  input  logic [XLEN-1:0]     rf_wdata,
  // RVFI
  output logic                rvfi_valid,
  output logic [63:0]         rvfi_order,
  output logic [31:0]         rvfi_insn,
  output logic                rvfi_trap,
  output logic                rvfi_halt,
  output logic                rvfi_intr,
  output logic [1:0]          rvfi_mode,
  output logic [1:0]          rvfi_ixl,
  output logic [4:0]          rvfi_rs1_addr,
  output logic [4:0]          rvfi_rs2_addr,
  output logic [XLEN-1:0]     rvfi_rs1_rdata,
  output logic [XLEN-1:0]     rvfi_rs2_rdata,
  output logic [4:0]          rvfi_rd_addr,
  output logic [XLEN-1:0]     rvfi_rd_wdata,
  output logic [XLEN-1:0]     rvfi_pc_rdata,
  output logic [XLEN-1:0]     rvfi_pc_wdata,
  output logic [XLEN-1:0]     rvfi_mem_addr,
  output logic [N_LANE-1:0]   rvfi_mem_rmask,
  output logic [N_LANE-1:0]   rvfi_mem_wmask,
  output logic [XLEN-1:0]     rvfi_mem_rdata,
  output logic [XLEN-1:0]     rvfi_mem_wdata
);

  // per-instruction entry carried ex -> wb, packed as
  // {valid, trap, insn, pc_rdata, pc_wdata, rs1_addr, rs2_addr, rs1_rdata,
  //  rs2_rdata, mem_addr, rmask, wmask, wdata}
  localparam int ENTRY_W = 1 + 1 + 32 + 4*XLEN + 5 + 5 + XLEN + 2*N_LANE + XLEN;
  localparam int MEMF_W  = XLEN + 2*N_LANE + XLEN;          // {mem_addr, rmask, wmask, wdata}
  localparam int RS_W    = 5 + 5 + 2*XLEN;                  // {rs1, rs2, rs1_rdata, rs2_rdata}
  localparam int ID_W    = 32 + XLEN;                       // {insn, pc_rdata}

  // ex
  logic                ld_ex;           // the ex instruction is a taken load request
  logic                st_ex;           // the ex instruction is a taken store request
  logic [OFF_W-1:0]    off_ex;          // byte offset of the access in the bus word
  logic [N_LANE-1:0]   rmask_ex;
  logic [N_LANE-1:0]   wmask_ex;
  logic [XLEN-1:0]     wdata_ex;
  logic [XLEN-1:0]     maddr_ex;        // access byte address, 0 when no access
  logic [XLEN-1:0]     pc_wdata_ex;     // next pc of the ex instruction
  logic                trap_ex;         // the ex instruction is reported as a trap
  logic                leave_ex;        // the ex instruction is reported (ex_act or brk_take)
  logic [XLEN-1:0]     vec_pc;          // trap vector / debug redirect of a trap entry
  logic [XLEN-1:0]     rs1_rdata_ex;
  logic [XLEN-1:0]     rs2_rdata_ex;
  logic [ENTRY_W-1:0]  entry_ex;

  // ex -> wb
  logic                en_wb;
  logic [ENTRY_W-1:0]  entry_wb_d;
  logic [ENTRY_W-1:0]  entry_wb;       // the wb instruction's entry
  logic [OFF_W-1:0]    off_wb_d;
  logic [OFF_W-1:0]    off_wb;         // byte offset of the load in the bus word
  logic [ENTRY_W-1:0]  entry_fault;    // entry_wb as a bus-fault trap entry
  logic [ENTRY_W-1:0]  entry_rep;      // entry reported this cycle
  logic                valid_wb;
  logic [N_LANE-1:0]   rmask_wb;
  logic [XLEN-1:0]     rbits_wb;       // rmask_wb as a bit mask
  logic                retire;         // rvfi_valid: one report per instruction
  logic                order_clr;      // order counter never clears
  logic                intr_pend;      // an interrupt / debug entry was taken: flag the next instruction leaving ex
  logic                intr_pend_d;
  logic                intr_wb_d;
  logic                mode_m_wb_d;
  logic                mode_m_wb;      // the wb instruction ran in M-mode

  // ---------------------------------------------------------------------------
  // ex: capture
  // ---------------------------------------------------------------------------
  // A request is granted at the edge where the instruction leaves ex (the LSU
  // holds ex until gnt). A trapping instruction makes no request.
  assign trap_ex  = trap || dbg_ebreak;
  assign ld_ex    = mss_req && !mss_we && !trap_ex;
  assign st_ex    = mss_req &&  mss_we && !trap_ex;
  assign off_ex   = mem_addr[OFF_W-1:0];
  assign maddr_ex = (ld_ex || st_ex) ? mem_addr : '0;
  assign rmask_ex = ld_ex ? (mss_be >> off_ex) : '0;
  assign wmask_ex = st_ex ? (mss_be >> off_ex) : '0;

  // mss_wdata holds the store data in every lane, so lane 0 upward is the
  // data at mem_addr.
  always_comb begin
    wdata_ex = '0;
    for (int b = 0; b < N_LANE; b++) begin
      if (wmask_ex[b]) wdata_ex[b*8 +: 8] = mss_wdata[b*8 +: 8];
    end
  end

  assign vec_pc       = dbg_redirect ? dbg_redirect_pc : trap_redirect_pc;
  assign pc_wdata_ex  = (dbg_redirect || trap || trap_return) ? vec_pc      :
                        jump                                  ? jump_target :
                                                                next_pc;
  assign rs1_rdata_ex = (rs1 == '0) ? '0 : rs1_data;
  assign rs2_rdata_ex = (rs2 == '0) ? '0 : rs2_data;

  assign entry_ex = {1'b1, trap_ex, instr, pc, pc_wdata_ex, rs1, rs2, rs1_rdata_ex,
                     rs2_rdata_ex, maddr_ex, rmask_ex, wmask_ex, wdata_ex};

  // ---------------------------------------------------------------------------
  // ex -> wb
  // ---------------------------------------------------------------------------
  assign en_wb      = !hold[STAGE_WB] || kill[STAGE_WB];
  assign leave_ex   = ex_act || brk_take;
  assign entry_wb_d = leave_ex ? entry_ex : '0;
  assign off_wb_d   = leave_ex ? off_ex : '0;

  basechili_dffe #(.WIDTH(ENTRY_W)) u_entry_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (entry_wb_d),
    .q     (entry_wb)
  );

  basechili_dffe #(.WIDTH(OFF_W)) u_off_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (off_wb_d),
    .q     (off_wb)
  );

  // ---------------------------------------------------------------------------
  // wb: report (a bus fault turns the entry into a trap entry)
  // ---------------------------------------------------------------------------
  assign valid_wb    = entry_wb[ENTRY_W-1];
  assign entry_fault = {2'b11, entry_wb[ENTRY_W-3 -: ID_W], vec_pc,
                        entry_wb[MEMF_W +: RS_W], MEMF_W'(0)};
  assign entry_rep   = bus_trap ? entry_fault : entry_wb;

  assign {rvfi_trap, rvfi_insn, rvfi_pc_rdata, rvfi_pc_wdata,
          rvfi_rs1_addr, rvfi_rs2_addr, rvfi_rs1_rdata, rvfi_rs2_rdata,
          rvfi_mem_addr, rvfi_mem_rmask, rvfi_mem_wmask,
          rvfi_mem_wdata} = entry_rep[ENTRY_W-2:0];

  // load word: the addressed bytes shifted down to bit 0
  assign rmask_wb = rvfi_mem_rmask;
  always_comb begin
    rbits_wb = '0;
    for (int b = 0; b < N_LANE; b++) begin
      rbits_wb[b*8 +: 8] = {8{rmask_wb[b]}};
    end
  end
  assign rvfi_mem_rdata = (mss_rdata >> {off_wb, 3'b000}) & rbits_wb;

  assign retire        = valid_wb && !hold[STAGE_WB] && (!kill[STAGE_WB] || bus_trap);
  assign rvfi_valid    = retire;
  assign rvfi_rd_addr  = (rf_we && !rvfi_trap) ? rf_rd : '0;
  assign rvfi_rd_wdata = (rvfi_rd_addr == '0) ? '0 : rf_wdata;

  assign rvfi_halt = 1'b0;
  assign rvfi_mode = {mode_m_wb, mode_m_wb};
  assign rvfi_ixl  = (XLEN == 64) ? 2'd2 : 2'd1;

  assign order_clr = 1'b0;

  // ---------------------------------------------------------------------------
  // rvfi_intr: carried next to the entry, same enable
  // ---------------------------------------------------------------------------
  assign intr_pend_d = irq_take || dbg_take || (intr_pend && !leave_ex);
  assign intr_wb_d   = leave_ex ? intr_pend : 1'b0;

  basechili_dff #(.WIDTH(1)) u_intr_pend (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (intr_pend_d),
    .q     (intr_pend)
  );

  basechili_dffe #(.WIDTH(1)) u_intr_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (intr_wb_d),
    .q     (rvfi_intr)
  );

  // rvfi_mode: the ex instruction's mode, carried next to the entry
  assign mode_m_wb_d = leave_ex ? priv_m : 1'b1;

  basechili_dffe #(.WIDTH(1), .RESET_VAL(1'b1)) u_mode_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (mode_m_wb_d),
    .q     (mode_m_wb)
  );

  basechili_counter #(.WIDTH(64)) u_order_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (order_clr),
    .en    (retire),
    .count (rvfi_order)
  );

endmodule
