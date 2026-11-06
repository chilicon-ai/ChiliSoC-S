// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_debug_dm -- the debug module driven over the DMI,
// with an RV32 or RV64 (XLEN) hart model that really executes the DM's ROM,
// abstract command words and program buffer through the memory port, and a
// system bus of SB_DATA_W data and SB_ADDR_W address bits.
//
// Hart model: RV32I / RV64I subset (addi, andi, lw, lbu, sw, ld, sd as two
// word accesses, bne, jal, jalr, fence, csrrw / csrrs, ebreak, dret) plus
// debug mode as chillus_dbg: debug_req
// enters at 0x800 (dpc = pc), ebreak in debug mode re-enters 0x800, an
// exception in debug mode goes to 0x808, dret returns to dpc. CSRs: dcsr,
// dpc, dscratch0 / 1, mscratch, misa (RO), mhartid (RO); any other is an
// exception. Outside debug mode it runs addi x5, x5, 1; jal x0, -4 from
// its own memory. 0 .. 3 idle cycles between instructions.
//
// Checked:
//   - the ROM read through the memory port against GNU as output;
//   - dmstatus / abstractcs / hartinfo fields; halt, resume (resumeack, the
//     hart continues at dpc), halt-on-reset, ndmreset / ndmresetpending,
//     havereset / ackhavereset, dmactive = 0 resetting the DM;
//   - access-register commands (GPRs x0 .. x31, CSRs; aarsize 2, and 3 with
//     XLEN 64: data1 holds the high word; a 32-bit write to a 64-bit register
//     sign-extends, as lw) and program buffer execution: after each command
//     every hart register equals the model's expectation (only the written
//     register changes; s0 survives every command, also after an exception),
//     read data in data0 / data1;
//   - cmderr: 1 busy (data / progbuf / command / abstractcs access while the
//     DUT is busy, taken from dut.busy at that access), 2 unsupported, 3
//     exception, 4 not halted; command writes ignored while cmderr != 0;
//   - abstractauto as OpenOCD uses it: reads of data0 with autoexecdata run
//     the last command again after returning data0 (block reads through the
//     program buffer), writes of data0 run it with the new data, writes of
//     a progbuf word with autoexecprogbuf run it; abstractauto reads back;
//     an autoexec access while not halted gives cmderr 4;
//   - system bus access at every size the bus has (64-bit with SB_DATA_W 64)
//     and byte offset, through sbaddress1 / sbdata1 where they exist, bus
//     errors, alignment and size errors, autoincrement blocks, sbbusyerror.
`include "tb_common.svh"
module chilimix_debug_dm_tb #(
  parameter int XLEN      = 32,
  parameter int SB_ADDR_W = 32,
  parameter int SB_DATA_W = 32
);
  import chilimix_debug_pkg::*;

  localparam int         SB_LANES = SB_DATA_W / 8;
  localparam int         SB_LO    = $clog2(SB_LANES);
  localparam bit         SB_A64   = SB_ADDR_W > 32;
  localparam bit         SB_D64   = SB_DATA_W == 64;
  localparam logic [2:0] SB_MAX   = SB_D64 ? 3'd3 : 3'd2;
  typedef logic [XLEN-1:0]      xw_t;    // a hart register
  typedef logic [SB_ADDR_W-1:0] sba_t;   // a system bus address
  typedef logic [SB_DATA_W-1:0] sbd_t;   // a system bus word

  localparam int          N_RAND   = 1500;
  localparam xw_t         RESET_PC = xw_t'(32'h8000_0000);
  localparam logic [31:0] GOLDEN_ROM [ROM_WORDS] = '{
    32'h00c0006f, 32'h00000013, 32'h0440006f, 32'h0ff0000f, 32'h7b241073, 32'h10002023,
    32'h40004403, 32'h00147413, 32'h02041063, 32'h40004403, 32'h00247413, 32'h00041463,
    32'hfe5ff06f, 32'h10002423, 32'h7b202473, 32'h7b200073, 32'h7b202473, 32'h10002223,
    32'h33c00067, 32'h10002623, 32'h7b202473, 32'h00100073};

  `TB_CLOCK_RESET

  logic        dmi_req_valid, dmi_req_accept, dmi_rsp_valid, dmi_rsp_accept;
  logic [6:0]  dmi_req_addr;
  logic [31:0] dmi_req_data, dmi_rsp_data;
  logic [1:0]  dmi_req_op, dmi_rsp_op;
  logic        debug_req, hart_unavail, ndmreset;
  logic        mem_req, mem_we;
  logic [9:0]  mem_addr;
  logic [31:0] mem_wdata, mem_rdata;
  logic [3:0]  mem_be;
  logic        sb_req_valid, sb_req_accept, sb_req_write, sb_ack_valid, sb_ack_accept, sb_ack_error;
  sba_t        sb_req_addr;
  sbd_t        sb_req_wdata, sb_ack_rdata;
  logic [2:0]  sb_req_size;

  chilimix_debug_dm #(.XLEN(XLEN), .SB_ADDR_W(SB_ADDR_W), .SB_DATA_W(SB_DATA_W)) dut (.*);

  function automatic xw_t sext32(logic [31:0] v);
    return xw_t'(signed'(v));
  endfunction

  // ---- hart reset: the testbench's, or ndmreset (delayed, as a reset tree)
  logic       tb_hart_rst = 1'b0;
  logic [3:0] ndm_dly = '0;
  always @(posedge clk) ndm_dly <= {ndm_dly[2:0], ndmreset};
  assign hart_unavail = tb_hart_rst || (|ndm_dly);

  // ---- hart model
  xw_t         x [32];
  xw_t         pc, dpc, dcsr, dscratch0, dscratch1, mscratch;
  bit          dmode;
  bit          port_busy;          // the testbench uses the memory port (ROM check)
  int          n_exc_dm;           // exceptions taken in debug mode

  // a hart reset seen since the instruction started: the hart abandons it
  bit rst_seen = 1'b0;
  always @(posedge clk) if (hart_unavail) rst_seen <= 1'b1;

  task automatic dm_access(input bit we, input xw_t a, input logic [31:0] wdata,
                           input logic [3:0] be, output logic [31:0] rdata);
    if (rst_seen) begin rdata = '0; return; end            // in / after reset: no access
    mem_req = 1; mem_we = we; mem_addr = a[11:2]; mem_wdata = wdata; mem_be = be;
    @(negedge clk);
    mem_req = 0; mem_we = 0;
    rdata = mem_rdata;
    @(negedge clk);
  endtask

  // CSR access: returns 0 when the CSR does not exist / is read-only on a write
  function automatic bit csr_ok(logic [11:0] a, bit wr);
    case (a)
      12'h7B0, 12'h7B1, 12'h7B2, 12'h7B3: return dmode;
      12'h340: return 1;
      12'h301, 12'hF14: return !wr;
      default: return 0;
    endcase
  endfunction

  function automatic xw_t csr_rd(logic [11:0] a);
    case (a)
      12'h7B0: return dcsr;
      12'h7B1: return dpc;
      12'h7B2: return dscratch0;
      12'h7B3: return dscratch1;
      12'h340: return mscratch;
      12'h301: return (XLEN == 64) ? xw_t'(64'h8000_0000_0000_0100) : xw_t'(32'h4000_0100);   // RV32I / RV64I
      default: return '0;              // mhartid
    endcase
  endfunction

  task automatic csr_wr(logic [11:0] a, xw_t v);
    case (a)
      12'h7B0: dcsr = v;
      12'h7B1: dpc = v;
      12'h7B2: dscratch0 = v;
      12'h7B3: dscratch1 = v;
      12'h340: mscratch = v;
      default: ;
    endcase
  endtask

  task automatic hart_step();
    logic [31:0] ins, v, vh;
    xw_t         a, rd_v, imm_i, imm_s, imm_b, imm_j, npc;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  f3;
    bit          exc;
    if (!dmode && debug_req) begin                         // halt request
      dpc = pc; dmode = 1; dcsr[8:6] = 3'd3; pc = 'h800;
    end
    if (dmode) dm_access(0, pc, '0, '0, ins);
    else begin
      ins = (pc == RESET_PC) ? 32'h00128293 : 32'hffdff06f;  // addi x5,x5,1 ; jal x0,-4
      @(negedge clk);
    end
    if (rst_seen) return;                                  // reset during the fetch
    rd = ins[11:7]; rs1 = ins[19:15]; rs2 = ins[24:20]; f3 = ins[14:12];
    imm_i = sext32({{20{ins[31]}}, ins[31:20]});
    imm_s = sext32({{20{ins[31]}}, ins[31:25], ins[11:7]});
    imm_b = sext32({{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0});
    imm_j = sext32({{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0});
    npc = pc + 4; exc = 0; rd_v = '0;
    case (ins[6:0])
      7'h13: if (f3 == 3'd0) rd_v = x[rs1] + imm_i; else if (f3 == 3'd7) rd_v = x[rs1] & imm_i; else exc = 1;
      7'h03: begin
        a = x[rs1] + imm_i;
        if (a >= 'h1000 || !dmode || !(f3 == 3'd2 || f3 == 3'd4 || (f3 == 3'd3 && XLEN == 64))) exc = 1;
        else if (f3 == 3'd3) begin                          // ld: two word accesses
          dm_access(0, a, '0, '0, v);
          dm_access(0, a + 4, '0, '0, vh);
          rd_v = xw_t'({vh, v});
        end else begin
          dm_access(0, a, '0, '0, v);
          rd_v = (f3 == 3'd2) ? sext32(v) : xw_t'(v >> (8 * a[1:0]) & 32'hFF);
        end
      end
      7'h23: begin
        a = x[rs1] + imm_s;
        if (a >= 'h1000 || !dmode || !(f3 == 3'd2 || (f3 == 3'd3 && XLEN == 64))) exc = 1;
        else begin
          dm_access(1, a, x[rs2][31:0], 4'hF, v);
          if (f3 == 3'd3) dm_access(1, a + 4, 32'(64'(x[rs2]) >> 32), 4'hF, v);   // sd: high word
        end
        rd = 5'd0;
      end
      7'h63: begin if (f3 != 3'd1) exc = 1; else if (x[rs1] != x[rs2]) npc = pc + imm_b; rd = 5'd0; end
      7'h6F: begin rd_v = pc + 4; npc = pc + imm_j; end
      7'h67: begin rd_v = pc + 4; npc = (x[rs1] + imm_i) & ~xw_t'(1); end
      7'h0F: rd = 5'd0;                                     // fence
      7'h73: begin
        if (f3 == 3'd0 && ins[31:20] == 12'h001 && dmode) begin npc = 'h800; rd = 5'd0; end        // ebreak
        else if (f3 == 3'd0 && ins[31:20] == 12'h7B2 && dmode) begin npc = dpc; dmode = 0; rd = 5'd0; end  // dret
        else if (f3 == 3'd1 || f3 == 3'd2) begin
          if (!csr_ok(ins[31:20], f3 == 3'd1 || rs1 != 5'd0)) exc = 1;
          else begin
            rd_v = csr_rd(ins[31:20]);
            if (f3 == 3'd1) csr_wr(ins[31:20], x[rs1]);
            else if (rs1 != 5'd0) csr_wr(ins[31:20], rd_v | x[rs1]);
          end
        end else exc = 1;
      end
      default: exc = 1;
    endcase
    if (rst_seen) return;                                  // reset during a load / store
    if (exc) begin
      `CHECK(dmode, "hart model: exception outside debug mode")
      n_exc_dm++;
      pc = 'h808;
    end else begin
      if (rd != 5'd0) x[rd] = rd_v;
      pc = npc;
    end
    repeat ($urandom % 4) @(negedge clk);
  endtask

  initial begin
    mem_req = 0; mem_we = 0; mem_addr = '0; mem_wdata = '0; mem_be = '0;
    for (int i = 0; i < 32; i++) x[i] = xw_t'({32'(i * 32'h0202_0202), 32'(i * 32'h0101_0101)});
    x[0] = '0;
    pc = RESET_PC; dpc = '0; dcsr = xw_t'(32'h4000_0003); dscratch0 = '0; dscratch1 = '0; mscratch = '0;
    dmode = 0; port_busy = 1; n_exc_dm = 0;
    wait (rst_n);
    forever begin
      @(negedge clk);
      if (port_busy) continue;
      if (hart_unavail || rst_seen) begin
        pc = RESET_PC; dmode = 0;
        wait (!hart_unavail);
        @(negedge clk);
        rst_seen = 1'b0;
        continue;
      end
      hart_step();
    end
  end

  // ---- DMI driver
  bit was_sb_busy;                             // dut.sb_busy at the last DMI access
  task automatic dmi(input logic [1:0] op, input logic [6:0] a, input logic [31:0] d,
                     output logic [31:0] r, output bit was_busy);
    dmi_req_valid = 1; dmi_req_op = op; dmi_req_addr = a; dmi_req_data = d;
    #1;
    while (!dmi_req_accept) begin @(negedge clk); #1; end
    was_busy = dut.busy;                       // oracle: busy when the access takes effect
    was_sb_busy = dut.sb_busy;
    @(negedge clk);
    dmi_req_valid = 0;
    while (!dmi_rsp_valid) @(negedge clk);
    r = dmi_rsp_data;
    dmi_rsp_accept = 1;
    @(negedge clk);
    dmi_rsp_accept = 0;
  endtask

  logic [31:0] r;
  bit          wb;

  task automatic wr(input logic [6:0] a, input logic [31:0] d);
    dmi(2'd2, a, d, r, wb);
  endtask

  task automatic rd(input logic [6:0] a, output logic [31:0] v);
    dmi(2'd1, a, '0, v, wb);
  endtask

  // ---- expectations
  xw_t         exp_x [32];
  logic [2:0]  exp_err;
  int          n_cmd, n_err [8], n_resume, n_halt;

  // the program's registers: parked in the ROM loop (after HALTED), s0 is
  // the ROM's scratch and the program's s0 is in dscratch0
  function automatic xw_t arch_x(int i);
    return (i == 8 && dmode) ? dscratch0 : x[i];
  endfunction

  task automatic snapshot();
    for (int i = 0; i < 32; i++) exp_x[i] = arch_x(i);
  endtask

  task automatic check_regs(input string what);
    for (int i = 0; i < 32; i++)
      if (arch_x(i) !== exp_x[i]) begin
        $error("CHECK failed: %s: x%0d = %h, expected %h", what, i, arch_x(i), exp_x[i]);
      end
  endtask

  task automatic wait_idle();
    logic [31:0] v;
    do rd(7'h16, v); while (v[12]);
  endtask

  // run a command, wait for it, check cmderr and clear it
  task automatic run_cmd(input logic [31:0] c, input logic [2:0] expect_err);
    logic [31:0] v;
    wr(7'h17, c);
    wait_idle();
    rd(7'h16, v);
    if (v[10:8] != expect_err) $error("CHECK failed: cmderr %0d, expected %0d (command %h)", v[10:8], expect_err, c);
    n_err[v[10:8]]++;
    n_cmd++;
    if (v[10:8] != 3'd0) wr(7'h16, 32'h0000_0700);
  endtask

  function automatic logic [31:0] acc(bit transfer, bit write, bit postexec, logic [15:0] regno,
                                      logic [2:0] size = 3'd2);
    return {8'd0, 1'b0, size, 1'b0, postexec, transfer, write, regno};
  endfunction

  // a random access size: 2, or 3 on RV64
  function automatic logic [2:0] rnd_size();
    return (XLEN == 64 && $urandom % 2 == 0) ? 3'd3 : 3'd2;
  endfunction

  // the register value after a write of val with an access of size
  function automatic xw_t written(xw_t val, logic [2:0] size);
    return (size == 3'd3) ? val : sext32(val[31:0]);
  endfunction

  // data0 / data1 as a register value read with an access of size
  task automatic rd_data(input logic [2:0] size, output xw_t v);
    logic [31:0] lo, hi;
    rd(7'h04, lo);
    hi = '0;
    if (size == 3'd3) rd(7'h05, hi);
    v = xw_t'({hi, lo});
  endtask

  task automatic wr_data(input logic [2:0] size, input xw_t v);
    wr(7'h04, v[31:0]);
    if (size == 3'd3) wr(7'h05, 32'(64'(v) >> 32));
  endtask

  // the low bits a read of size returns
  function automatic xw_t of_size(xw_t v, logic [2:0] size);
    return (size == 3'd3) ? v : xw_t'(v[31:0]);
  endfunction

  task automatic halt();
    logic [31:0] v;
    wr(7'h10, 32'h8000_0001);
    do rd(7'h11, v); while (!v[9]);
    wr(7'h10, 32'h0000_0001);
    `CHECK(dmode, "halted: the hart is in debug mode")
    snapshot();
    n_halt++;
  endtask

  task automatic resume();
    logic [31:0] v, pc0;
    pc0 = dpc;
    wr(7'h10, 32'h4000_0001);
    do rd(7'h11, v); while (!v[17]);
    `CHECK(!v[9] && v[11], "resumed: running, not halted")
    repeat (16) @(negedge clk);                    // RESUMING comes two instructions before dret
    `CHECK(!dmode, "resumed: the hart left debug mode")
    n_resume++;
  endtask

  // GPR / CSR commands with the model's expectations
  int n_cmd64;                                    // aarsize 3 commands

  task automatic cmd_gpr_write(input int n, input xw_t val, input logic [2:0] size = 3'd2);
    wr_data(size, val);
    run_cmd(acc(1, 1, 0, 16'h1000 + 16'(n), size), 3'd0);
    if (n != 0) exp_x[n] = written(val, size);
    if (size == 3'd3) n_cmd64++;
    check_regs("GPR write");
  endtask

  task automatic cmd_gpr_read(input int n, input logic [2:0] size = 3'd2);
    xw_t v;
    run_cmd(acc(1, 0, 0, 16'h1000 + 16'(n), size), 3'd0);
    rd_data(size, v);
    `CHECK(v == of_size(exp_x[n], size), "GPR read data")
    if (size == 3'd3) n_cmd64++;
    check_regs("GPR read");
  endtask

  task automatic cmd_csr(input logic [11:0] csr, input bit write, input xw_t val, input bit legal,
                         input logic [2:0] size = 3'd2);
    xw_t v;
    if (write) wr_data(size, val);
    run_cmd(acc(1, write, 0, 16'(csr), size), legal ? 3'd0 : 3'd3);
    if (legal && !write) begin
      rd_data(size, v);
      `CHECK(v == of_size(csr_rd(csr), size), "CSR read data")
    end
    if (legal && write) `CHECK(csr_rd(csr) == written(val, size), "CSR written")
    if (size == 3'd3) n_cmd64++;
    check_regs("CSR command (s0 kept)");
  endtask

  // program buffer: addi x6, x6, k (postexec only), or an illegal instruction
  task automatic cmd_progbuf(input bit illegal);
    logic [11:0] k;
    k = 12'($urandom % 100);
    wr(7'h20, illegal ? 32'hFFFF_FFFF : {k, 5'd6, 3'd0, 5'd6, 7'h13});
    for (int i = 1; i < PROGBUF_SIZE; i++) wr(7'h20 + 7'(i), RV_NOP);
    run_cmd(acc(0, 0, 1, 16'h0), illegal ? 3'd3 : 3'd0);
    if (!illegal) exp_x[6] = exp_x[6] + xw_t'(k);
    check_regs("program buffer");
  endtask

  // abstractauto: x6 += 1 per run of "read x6, then the program buffer"
  // (OpenOCD's block read), x7 = data0 per run of "write x7, then the
  // program buffer" (block write), and a progbuf write as the trigger
  task automatic cmd_autoexec();
    logic [31:0] v;
    xw_t         base;
    int          n;
    wr(7'h20, {12'd1, 5'd6, 3'd0, 5'd6, 7'h13});          // addi x6, x6, 1
    for (int i = 1; i < PROGBUF_SIZE; i++) wr(7'h20 + 7'(i), RV_NOP);
    wr(7'h18, 32'h0080_0003);
    rd(7'h18, v);
    `CHECK(v == 32'h0080_0003, "abstractauto reads back")
    base = exp_x[6];
    run_cmd(acc(1, 0, 1, 16'h1006), 3'd0);                  // data0 = x6, then x6 += 1
    n = 4 + $urandom % 8;
    for (int i = 0; i < n; i++) begin
      rd(7'h04, v);                                          // returns, then runs again
      `CHECK(v == 32'(base + xw_t'(i)), "autoexec read: data0 of the previous run")
      wait_idle();
    end
    wr(7'h18, 32'h0);
    rd(7'h04, v);
    `CHECK(v == 32'(base + xw_t'(n)), "autoexec read: last run")
    exp_x[6] = base + xw_t'(n) + 1;
    check_regs("autoexec block read");
    wr(7'h18, 32'h0000_0001);
    run_cmd(acc(1, 1, 1, 16'h1007), 3'd0);                  // x7 = data0, then x6 += 1
    for (int i = 0; i < 3; i++) begin
      v = $urandom;
      wr(7'h04, v);                                          // runs with the new data0
      wait_idle();
      `CHECK(x[7] == sext32(v), "autoexec write: x7 = data0")
    end
    exp_x[7] = sext32(v);
    exp_x[6] = exp_x[6] + 4;
    wr(7'h18, 32'h0080_0000);
    wr(7'h27, RV_NOP);                                       // progbuf7: runs again
    wait_idle();
    exp_x[6] = exp_x[6] + 1;
    wr(7'h18, 32'h0);
    check_regs("autoexec block write and progbuf trigger");
    rd(7'h16, v);
    `CHECK(v[10:8] == 3'd0, "autoexec: no cmderr")
    n_cmd += n + 4;
  endtask

  // ---- system bus model: random accept / response delays, ERROR where
  // address bits 31:28 are 0xF; every access is checked against the expected queue
  typedef struct { sba_t addr; logic write; logic [2:0] size; sbd_t wdata; } sb_acc_t;
  sbd_t        sysmem [sba_t];     // by bus word address (addr >> SB_LO)
  sb_acc_t     sb_exp [$];
  int          sb_wait, n_sb_acc, n_sb64, n_sb_hi;
  bit          sb_pending, sb_cur_err;
  sbd_t        sb_cur_rdata;

  function automatic bit sb_err_addr(sba_t a);
    return a[31:28] == 4'hF;
  endfunction

  function automatic sbd_t lane_mask(logic [2:0] size, sba_t a);
    sbd_t m;
    m = (size >= 3'(SB_LO)) ? '1 : sbd_t'((64'd1 << (8 << size)) - 1);
    return m << (8 * int'(a[SB_LO-1:0] & ~((SB_LO)'((1 << size) - 1))));
  endfunction

  function automatic sbd_t sysmem_rd(sba_t a);
    sba_t w;
    w = a >> SB_LO;
    return sysmem.exists(w) ? sysmem[w] : sbd_t'({32'(w) ^ 32'h5A5A_0000, 32'(w)});
  endfunction

  initial begin
    sb_req_accept = 0; sb_ack_valid = 0; sb_ack_error = 0; sb_ack_rdata = '0;
    sb_pending = 0; n_sb_acc = 0; n_sb64 = 0; n_sb_hi = 0;
    forever begin
      @(negedge clk);
      if (sb_ack_valid) begin sb_ack_valid = 0; sb_pending = 0; end   // sb_ack_accept is always 1
      if (sb_pending) begin
        if (sb_wait == 0) begin
          sb_ack_valid = 1; sb_ack_error = sb_cur_err; sb_ack_rdata = sb_cur_rdata;
        end else sb_wait--;
      end
      sb_req_accept = !sb_pending && ($urandom % 3 != 0);
    end
  end

  always @(posedge clk) if (rst_n && sb_req_valid && sb_req_accept) begin
    sb_acc_t e;
    sbd_t    m;
    `CHECK(sb_exp.size() > 0, "system bus access the model did not expect")
    if (sb_exp.size() > 0) begin
      e = sb_exp.pop_front();
      m = lane_mask(e.size, e.addr);
      `CHECK(sb_req_addr == e.addr && sb_req_write == e.write && sb_req_size == e.size
             && (!e.write || (sb_req_wdata & m) == (e.wdata & m)), "system bus access contents")
    end
    `CHECK(sb_ack_accept, "sb_ack_accept")
    n_sb_acc++;
    if (sb_req_size == 3'd3) n_sb64++;
    if (SB_A64 && (64'(sb_req_addr) >> 32) != 0) n_sb_hi++;
    sb_pending <= 1;
    sb_wait <= $urandom % 4;
    sb_cur_err <= sb_err_addr(sb_req_addr);
    sb_cur_rdata <= sysmem_rd(sb_req_addr);
    if (sb_req_write && !sb_err_addr(sb_req_addr)) begin
      m = lane_mask(sb_req_size, sb_req_addr);
      sysmem[sb_req_addr >> SB_LO] = (sysmem_rd(sb_req_addr) & ~m) | (sb_req_wdata & m);
    end
  end

  // ---- SBA through the DMI
  int n_sb_err [8];

  task automatic sb_wait_idle(output logic [31:0] cs);
    do rd(7'h38, cs); while (cs[21]);
  endtask

  function automatic sb_acc_t sb_mk(sba_t a, logic w, logic [2:0] size, logic [63:0] d);
    sb_acc_t e;
    e.addr = a; e.write = w; e.size = size;
    case (size)
      3'd0:    e.wdata = {SB_LANES{d[7:0]}};
      3'd1:    e.wdata = {(SB_LANES / 2){d[15:0]}};
      3'd2:    e.wdata = {(SB_LANES / 4){d[31:0]}};
      default: e.wdata = sbd_t'(d);
    endcase
    return e;
  endfunction

  function automatic logic [2:0] sb_err_of(sba_t a, logic [2:0] size);
    if (size > SB_MAX) return 3'd4;
    if ((size == 3'd1 && a[0]) || (size == 3'd2 && a[1:0] != 2'b00) || (size == 3'd3 && a[2:0] != 3'b000)) return 3'd3;
    return sb_err_addr(a) ? 3'd2 : 3'd0;
  endfunction

  // a random system bus address: low or anywhere, with high bits on a wide address
  function automatic sba_t sb_rnd_addr(bit anywhere);
    sba_t a;
    a = anywhere ? sba_t'({$urandom, $urandom}) : sba_t'(32'h4000 + 32'($urandom % 256));
    if (SB_A64 && !anywhere && $urandom % 2 == 0) a = a | sba_t'(64'(1 + $urandom % 4) << 32);
    return a;
  endfunction

  task automatic wr_sbaddr(input sba_t a);
    if (SB_A64) wr(7'h3A, 32'(64'(a) >> 32));
    wr(7'h39, a[31:0]);
  endtask

  // one access: sbaccess = size; a write, or a read on the sbaddress0 write
  task automatic sb_access(input bit write, input sba_t a, input logic [2:0] size, input logic [63:0] d);
    logic [31:0] cs, v, vh;
    logic [63:0] exp, got;
    sbd_t        old_word;
    logic [2:0]  e;
    e = sb_err_of(a, size);
    old_word = sysmem_rd(a);
    wr(7'h38, {11'd0, !write, size, 1'b0, 1'b0, 15'd0});          // sbreadonaddr for reads
    if (e == 3'd0 || e == 3'd2) sb_exp.push_back(sb_mk(a, write, size, d));
    if (write) begin
      wr_sbaddr(a);
      if (SB_D64) wr(7'h3D, d[63:32]);
      wr(7'h3C, d[31:0]);
    end else wr_sbaddr(a);
    sb_wait_idle(cs);
    if (cs[14:12] != e) $error("CHECK failed: sberror %0d, expected %0d (addr %h size %0d)", cs[14:12], e, a, size);
    n_sb_err[cs[14:12]]++;
    if (e == 3'd0) begin
      exp = 64'(sysmem_rd(a) >> (8 * int'(a[SB_LO-1:0])));
      exp = (size == 3'd0) ? exp & 64'hFF : (size == 3'd1) ? exp & 64'hFFFF : (size == 3'd2) ? exp & 64'hFFFF_FFFF : exp;
      if (!write) begin
        rd(7'h3C, v);
        vh = '0;
        if (SB_D64) rd(7'h3D, vh);
        got = {vh, v};
        `CHECK(got == exp, "SBA read data")
      end else
        `CHECK(((sysmem_rd(a) ^ old_word) & ~lane_mask(size, a)) == 0, "SBA write touched only its bytes")
    end
    if (cs[14:12] != 3'd0) wr(7'h38, 32'h0000_7000);              // clear sberror
  endtask

  // a block with sbautoincrement: n writes, then n reads with sbreadondata
  task automatic sb_block(input sba_t a, input int n);
    logic [31:0] cs, v, d [];
    d = new[n];
    wr(7'h38, {11'd0, 1'b0, 3'd2, 1'b1, 1'b0, 15'd0});            // autoincrement
    wr_sbaddr(a);
    for (int i = 0; i < n; i++) begin
      d[i] = $urandom;
      sb_exp.push_back(sb_mk(a + sba_t'(4 * i), 1, 3'd2, 64'(d[i])));
      wr(7'h3C, d[i]);
      sb_wait_idle(cs);
    end
    rd(7'h39, v);
    `CHECK(v == 32'(a + sba_t'(4 * n)), "sbaddress0 after autoincrement")
    wr(7'h38, {11'd0, 1'b1, 3'd2, 1'b1, 1'b1, 15'd0});            // readonaddr, autoincrement, readondata
    sb_exp.push_back(sb_mk(a, 0, 3'd2, '0));
    wr_sbaddr(a);
    for (int i = 0; i < n; i++) begin
      sb_wait_idle(cs);
      if (i < n - 1) sb_exp.push_back(sb_mk(a + sba_t'(4 * (i + 1)), 0, 3'd2, '0));
      else wr(7'h38, {11'd0, 1'b0, 3'd2, 1'b1, 1'b0, 15'd0});     // last: no further read
      rd(7'h3C, v);
      `CHECK(v == d[i], "SBA block read")
    end
    `CHECK(cs[14:12] == 3'd0 && !cs[22], "SBA block: no error")
  endtask

  // sbaddress0 / sbdata0 access while sbbusy: sbbusyerror, then nothing starts
  task automatic sb_busy_probe();
    logic [31:0] cs, v;
    bit was;
    wr(7'h38, {11'd0, 1'b1, 3'd2, 1'b0, 1'b0, 15'd0});
    if (SB_A64) wr(7'h3A, 32'h0);
    sb_exp.push_back(sb_mk(sba_t'(32'h100), 0, 3'd2, '0));
    wr(7'h39, 32'h100);                                             // starts a read
    wr(7'h38, {11'd0, 1'b0, 3'($urandom % 3), 1'b0, 1'b0, 15'd0}); // no read on the probe; new sbaccess
    dmi(2'd2, 7'h39, 32'h200, v, was);                              // while busy?
    was = was_sb_busy;
    sb_wait_idle(cs);
    if (!cs[22] && cs[14:12] == 3'd0) begin
      rd(7'h3C, v);
      `CHECK(v == 32'(sysmem_rd(sba_t'(32'h100)) >> (8 * (32'h100 % SB_LANES))),
             "an sbcs write in flight does not change the access (32-bit read)")
    end
    `CHECK(cs[22] == was, "sbbusyerror exactly when sbaddress0 was written while busy")
    rd(7'h39, v);
    `CHECK(v == (was ? 32'h100 : 32'h200), "sbaddress0 write ignored only while busy")
    if (cs[22]) begin
      wr(7'h3C, 32'h1);                                             // blocked: no access
      repeat (6) @(negedge clk);
      wr(7'h38, 32'h0040_0000);                                     // clear sbbusyerror
      n_sb_err[1]++;
    end
  endtask

  // ---- main
  logic [31:0] v, c;
  int          k;

  initial begin
    dmi_req_valid = 0; dmi_req_addr = '0; dmi_req_data = '0; dmi_req_op = '0; dmi_rsp_accept = 0;
    n_cmd = 0; n_resume = 0; n_halt = 0; n_cmd64 = 0;
    for (int i = 0; i < 8; i++) begin n_err[i] = 0; n_sb_err[i] = 0; end
    tb_reset();
    // ---- the ROM through the memory port, against the assembler
    @(negedge clk);
    for (int i = 0; i < ROM_WORDS; i++) begin
      dm_access(0, 32'h800 + 32'(4 * i), '0, '0, v);
      `CHECK(v == GOLDEN_ROM[i], "debug ROM word against GNU as")
    end
    port_busy = 0;
    // ---- activate, status
    rd(7'h11, v);
    `CHECK(v[3:0] == 4'd3 && v[7] && v[22] && v[5], "dmstatus version / authenticated / impebreak / hasresethaltreq")
    wr(7'h10, 32'h0000_0001);
    rd(7'h10, v);
    `CHECK(v == 32'h1, "dmcontrol: dmactive")
    rd(7'h11, v);
    `CHECK(v[11] && v[10] && !v[9] && v[19], "dmstatus: running, havereset")
    wr(7'h10, 32'h1000_0001);                                   // ackhavereset
    rd(7'h11, v);
    `CHECK(!v[19] && !v[18], "ackhavereset")
    rd(7'h12, v);
    `CHECK(v == {8'd0, 4'd0, 3'd0, 1'b1, 4'd2, 12'h380}, "hartinfo")
    rd(7'h16, v);
    `CHECK(v[28:24] == 5'd8 && v[3:0] == 4'd2 && !v[12] && v[10:8] == 3'd0, "abstractcs")
    rd(7'h38, v);
    `CHECK(v[31:29] == 3'd1 && v[11:5] == 7'(SB_ADDR_W) && v[4:0] == {1'b0, SB_D64, 3'b111},
           "sbcs: sbversion, sbasize, sbaccess sizes")
    // ---- not halted: cmderr 4
    run_cmd(acc(1, 0, 0, 16'h1005), 3'd4);
    // ---- halt, commands
    halt();
    rd(7'h40, v);
    `CHECK(v == 32'h1, "haltsum0")
    for (int n = 0; n < 32; n++) cmd_gpr_write(n, xw_t'({$urandom, $urandom}), rnd_size());
    for (int n = 0; n < 32; n++) cmd_gpr_read(n, rnd_size());
    cmd_csr(12'h340, 1, xw_t'(64'hFEDC_BA98_A5A5_1234), 1, rnd_size());
    cmd_csr(12'h340, 0, '0, 1, rnd_size());
    cmd_csr(12'hF14, 0, '0, 1);
    cmd_csr(12'h7C0, 0, '0, 0);                                 // no such CSR: exception
    cmd_csr(12'hF14, 1, 32'h1, 0);                              // read-only: exception
    cmd_gpr_read(8);                                            // s0 after the exceptions
    cmd_progbuf(0);
    cmd_progbuf(1);
    cmd_autoexec();
    // ---- unsupported
    run_cmd(32'h0100_0000, 3'd2);                               // quick access
    run_cmd(32'h0200_0000, 3'd2);                               // access memory
    run_cmd({8'd0, 1'b0, (XLEN == 64) ? 3'd4 : 3'd3, 1'b0, 3'b010, 16'h1001}, 3'd2);  // aarsize above XLEN
    run_cmd({8'd0, 1'b0, 3'd1, 1'b0, 3'b010, 16'h1001}, 3'd2);  // aarsize 1
    run_cmd({8'd0, 1'b0, 3'd2, 1'b1, 3'b010, 16'h1001}, 3'd2);  // aarpostincrement
    run_cmd(acc(1, 0, 0, 16'h1020), 3'd2);                      // FPR
    // ---- cmderr blocks commands until cleared
    wr(7'h17, 32'h0200_0000);
    wr(7'h04, 32'h1234_5678);
    wr(7'h17, acc(1, 1, 0, 16'h1007));                          // ignored
    wait_idle();
    rd(7'h16, v);
    `CHECK(v[10:8] == 3'd2, "cmderr kept")
    check_regs("command ignored while cmderr is set");
    wr(7'h16, 32'h0000_0700);
    // ---- resume, running, halt again
    wr(7'h18, 32'h0000_0001);
    resume();
    rd(7'h04, v);                                               // autoexec while running: cmderr 4
    rd(7'h16, v);
    `CHECK(v[10:8] == 3'd4, "autoexec while running: cmderr 4")
    wr(7'h16, 32'h0000_0700);
    wr(7'h18, 32'h0);
    repeat (40) @(negedge clk);
    halt();
    `CHECK(dpc == RESET_PC || dpc == RESET_PC + xw_t'(4), "dpc in the running program")
    // ---- halt-on-reset and ndmreset
    wr(7'h10, 32'h0000_0009);                                   // setresethaltreq
    resume();
    wr(7'h10, 32'h0000_0003);                                   // ndmreset
    `CHECK(ndmreset, "ndmreset output")
    repeat (8) @(negedge clk);
    rd(7'h11, v);
    `CHECK(v[24] && v[12], "ndmresetpending, unavail")
    wr(7'h10, 32'h0000_0001);
    do rd(7'h11, v); while (!v[9]);
    `CHECK(!v[24] && v[19], "halted after reset: ndmresetpending clear, havereset")
    `CHECK(dpc == RESET_PC, "halt-on-reset: dpc is the reset vector")
    snapshot();
    wr(7'h10, 32'h1000_0005);                                   // ackhavereset, clrresethaltreq
    // ---- dmactive = 0 resets the DM
    wr(7'h20, 32'hDEAD_BEEF);
    wr(7'h10, 32'h0000_0000);
    wr(7'h10, 32'h0000_0001);
    rd(7'h20, v);
    `CHECK(v == 32'h0, "dmactive = 0 cleared progbuf")
    // ---- system bus access
    for (int sz = 0; sz <= int'(SB_MAX); sz++)
      for (int off = 0; off < SB_LANES; off++) begin
        sb_access(1, sba_t'(32'h1000 + 32'(off)), 3'(sz), {$urandom, $urandom});
        sb_access(0, sba_t'(32'h1000 + 32'(off)), 3'(sz), '0);
      end
    if (SB_A64) begin                                                // above 4 GiB
      sb_access(1, sba_t'(64'h1_0000_1000), SB_MAX, {$urandom, $urandom});
      sb_access(0, sba_t'(64'h1_0000_1000), SB_MAX, '0);
    end
    sb_access(0, sba_t'(32'hF000_0010), 3'd2, '0);                  // bus error: sberror 2
    sb_access(1, sba_t'(32'h2000), SB_MAX + 3'd1, 64'h1);          // too wide: sberror 4
    sb_block(sba_t'(32'h3000), 8);
    sb_busy_probe();
    // ---- random
    for (int it = 0; it < N_RAND; it++) begin
      if ($urandom % 4 == 0) begin
        case ($urandom % 8)
          0:       sb_block(sb_rnd_addr(0) & ~sba_t'(3), 1 + $urandom % 6);
          1:       sb_busy_probe();
          2:       if ($urandom % 3 != 0) sb_access($urandom % 2, sba_t'(32'hF000_0000 + 32'(4 * ($urandom % 64))), 3'd2, {$urandom, $urandom});
                   else sb_access($urandom % 2, sb_rnd_addr(0), SB_MAX + 3'd1, {$urandom, $urandom});   // bus error / too wide
          3, 4:    sb_access($urandom % 2, sb_rnd_addr(1), 3'($urandom % (int'(SB_MAX) + 1)), {$urandom, $urandom});
          5:       sb_access($urandom % 2, sb_rnd_addr(0) & ~sba_t'(7), SB_MAX, {$urandom, $urandom});   // widest, aligned
          default: sb_access($urandom % 2, sb_rnd_addr(0), 3'($urandom % (int'(SB_MAX) + 1)), {$urandom, $urandom});
        endcase
      end
      rd(7'h11, v);
      if (!v[9]) begin
        if ($urandom % 2 == 0) run_cmd(acc(1, 0, 0, 16'h1001), 3'd4);
        else halt();
        continue;
      end
      case ($urandom % 12)
        0, 1, 2: cmd_gpr_write($urandom % 32, xw_t'({$urandom, $urandom}), rnd_size());
        3, 4:    cmd_gpr_read($urandom % 32, rnd_size());
        5:       cmd_csr(($urandom % 2) ? 12'h340 : 12'h7B3, $urandom % 2, xw_t'({$urandom, $urandom}), 1, rnd_size());
        6:       cmd_csr(12'h7C0 + 12'($urandom % 16), 0, '0, 0);
        7:       cmd_progbuf($urandom % 4 == 0);
        8: begin                                                // access while busy
          wr(7'h04, $urandom);
          run_cmd_busy_probe();
        end
        9:  resume();
        10: begin
          if ($urandom % 2 == 0) run_cmd(32'h0100_0000 + 32'($urandom % 2), 3'd2);
          else begin                                            // data1 and abstractauto
            c = $urandom;
            wr(7'h05, c);
            rd(7'h05, v);
            `CHECK(v == c, "data1 read back")
            wr(7'h18, 32'hFFFF_FFFF);
            rd(7'h18, v);
            `CHECK(v == 32'h00FF_0003, "abstractauto: only the autoexec bits")
            wr(7'h18, 32'h0);
          end
        end
        default: begin                                          // hart reset while halted
          if ($urandom % 3 == 0) begin                          // ... during a command: cmderr 4
            wr(7'h10, 32'h0000_0009);
            wr(7'h17, acc(1, 0, 0, 16'h1003));
            tb_hart_rst = 1; repeat (5) @(negedge clk); tb_hart_rst = 0;
            do rd(7'h11, v); while (!v[9]);
            rd(7'h16, v);
            `CHECK(!v[12] && v[10:8] == ((dut.cmderr == 3'd4) ? 3'd4 : 3'd0), "hart reset during a command")
            n_err[v[10:8]]++;
            if (v[10:8] != 3'd0) wr(7'h16, 32'h0000_0700);
            snapshot();
            wr(7'h10, 32'h1000_0005);
          end else if ($urandom % 4 == 0) begin
            wr(7'h10, 32'h0000_0009);
            tb_hart_rst = 1; repeat (5) @(negedge clk); tb_hart_rst = 0;
            do rd(7'h11, v); while (!v[9]);
            `CHECK(dpc == RESET_PC, "halt-on-reset after a hart reset")
            snapshot();
            wr(7'h10, 32'h1000_0005);
          end
        end
      endcase
    end
    $display("commands %0d, cmderr 0/1/2/3/4: %0d/%0d/%0d/%0d/%0d, halts %0d, resumes %0d, debug-mode exceptions %0d",
             n_cmd, n_err[0], n_err[1], n_err[2], n_err[3], n_err[4], n_halt, n_resume, n_exc_dm);
    `CHECK(n_err[1] > 10 && n_err[2] > 20 && n_err[3] > 20 && n_err[4] > 10, "few errors of some kind")
    `CHECK(n_cmd > 600, "few commands")
    `CHECK(XLEN == 32 || n_cmd64 > 100, "few 64-bit commands")
    $display("system bus accesses %0d (%0d 64-bit, %0d above 4 GiB), sberror 0/busy/2/3/4: %0d/%0d/%0d/%0d/%0d",
             n_sb_acc, n_sb64, n_sb_hi, n_sb_err[0], n_sb_err[1], n_sb_err[2], n_sb_err[3], n_sb_err[4]);
    `CHECK((!SB_D64 || n_sb64 > 20) && (!SB_A64 || n_sb_hi > 20), "few 64-bit / high-address system bus accesses")
    `CHECK(sb_exp.size() == 0, "expected system bus accesses never came")
    `CHECK(n_sb_acc > 300 && n_sb_err[2] > 10 && n_sb_err[3] > 10 && n_sb_err[4] > 5 && n_sb_err[1] > 5,
           "few system bus accesses / errors of some kind")
    tb_pass();
  end

  // a GPR read with a data0 / progbuf access right after it: cmderr 1 exactly
  // when the DUT was still busy at that access
  task automatic run_cmd_busy_probe();
    logic [31:0] v;
    bit          was;
    int          n;
    n = $urandom % 32;
    wr(7'h17, acc(1, 0, 0, 16'h1000 + 16'(n)));
    case ($urandom % 4)
      0: dmi(2'd2, 7'h04, $urandom, v, was);
      2: dmi(2'd2, 7'h18, 32'h1, v, was);
      1: dmi(2'd1, 7'h21, '0, v, was);
      default: dmi(2'd2, 7'h17, acc(1, 0, 0, 16'h1001), v, was);
    endcase
    wait_idle();
    rd(7'h16, v);
    if (v[10:8] != (was ? 3'd1 : 3'd0)) $error("CHECK failed: busy probe cmderr %0d, busy was %0d", v[10:8], was);
    n_err[v[10:8]]++;
    n_cmd++;
    if (v[10:8] != 3'd0) wr(7'h16, 32'h0000_0700);
    check_regs("busy probe");
    // the data0 write while idle changed data0 only, the second command read x1
  endtask
endmodule
