// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S sim :: chilisocs_tb (Verilator top, simulation only)
//
// chilisocs_top with the boot ROM and the program preloaded into its
// memories, a UART receiver on uart_txd, each driven GPIO output looped
// back to its input, a SPI NOR flash on SPI0 and an I2C EEPROM on I2C0
// (models below). sim/run.py builds and runs it.
//
//   +rom=<hex> +sram0=<hex> +sram1=<hex>   $readmemh images (32-bit words)
//   +flash=<hex>     SPI flash contents (32-bit words, 64 KiB, repeated
//                    across the 24-bit address space)
//   +uart_div=<n>    UART0 divisor the program uses (bit = 16 * n cycles)
//   +max_cycles=<n>  stop with TEST TIMEOUT after n cycles (default 2000000)
//   +debugger        run the JTAG debugger session below against the
//                    program (sw/tests/debug.c); it prints "debugger done"
//                    when every step passed (sim/run.py requires it)
//   +sba_stress      system bus traffic and halts from the debugger while
//                    sw/tests/stress.c runs (below); it prints "sba stress
//                    done" at the end (sim/run.py requires it)
//   +rvfi_log=<file> the core's retired instructions (RVFI) to <file>, from
//                    cycle +rvfi_from=<n> (default 0)
//   +rbb_port=<n>    serve the JTAG pins to OpenOCD (remote_bitbang, DPI-C
//                    server sim/tb/rbb.c) on 127.0.0.1:<n>
//
// The program's console lines go to stdout. A line "*** PASS" ends the run
// with TEST PASS, "*** FAIL <code>" with TEST FAIL; both print the cycle
// count since power-on reset; before TEST PASS the testbench prints how many
// cycles core_sleep was high (WFI sleep) and, per phase, how many
// unprivileged (user-mode) transfers the core made: fetches (i_HPROT[1]
// low), data accesses (d_HPROT[1] low) and APB transfers (PPROT[0] low).
// The phase is the last value below 8 written to socctl scratch[0]
// (sw/tests/umode.c marks its steps that way; it starts at 0). A write of
// EXT_RST_REQ to socctl scratch[1] pulls ext_rst_n low for 20 cycles (the
// external reset pin; sw/tests/sysrst.c).
//
// GLS defined (sim/run.py --gls): dut is the ORFS gate-level netlist. The
// memory macros' models (sim/gls/) load the +rom / +sram0 / +sram1 images,
// every flop and latch starts at 1 (so the reset pins' first fall resets
// everything, as the forces below do for RTL), and what needs RTL names is
// left out: the user-transfer counts, EXT_RST_REQ, the RVFI log and two
// debugger checks.
// -----------------------------------------------------------------------------
module chilisocs_tb #(
  parameter int ROM_AW  = 10,
  parameter int SRAM_AW = 14,
  parameter int N_GPIO  = 16,
  parameter int MEM_WAIT = 0,        // chilisocs_top MEM_WAIT: random ROM / SRAM wait states
  parameter int ICACHE_KB = 2,       // chilisocs_top ICACHE_KB: the core's instruction cache (XIP)
  parameter bit RF_LATCH = 1'b1      // chilisocs_top RF_LATCH: 0 builds the register file from flops (FPGA)
);

  logic              clk = 1'b0;
  logic              por_n = 1'b1;
  logic              ext_rst_n = 1'b1;
  logic              test_en = 1'b0;
  logic              uart_rxd = 1'b1;
  logic              uart_txd;
  logic [N_GPIO-1:0] gpio_in;
  logic [N_GPIO-1:0] gpio_out;
  logic [N_GPIO-1:0] gpio_oe;
  logic [N_GPIO-1:0] gpio_pue;
  logic [N_GPIO-1:0] gpio_ds;
  logic [1:0]        clk_div;
  logic              core_sleep;
  logic              jtag_tck = 1'b0;   // JTAG probe (driven by the debugger tasks)
  logic              jtag_trst_n = 1'b1;
  logic              jtag_tms = 1'b1;
  logic              jtag_tdi = 1'b0;
  logic              jtag_tdo;
  logic              jtag_tdo_en;
  logic              spi_sck;
  logic              spi_cs;
  logic [3:0]        spi_dq_o;
  logic [3:0]        spi_dq_oe;
  logic [3:0]        spi_dq_i;
  logic              i2c_scl_i;
  logic              i2c_sda_i;
  logic              i2c_scl_oe;
  logic              i2c_sda_oe;

  always #5 clk = ~clk;
  assign gpio_in = gpio_out & gpio_oe;

`ifdef GLS
  chilisocs_top dut (.*);            // gate-level netlist: no parameters (built with the defaults)
`else
  chilisocs_top #(.ROM_AW(ROM_AW), .SRAM_AW(SRAM_AW), .N_GPIO(N_GPIO), .MEM_WAIT(MEM_WAIT),
                  .ICACHE_KB(ICACHE_KB), .RF_LATCH(RF_LATCH)) dut (.*);
`endif

  longint unsigned cycles = 0;       // clk cycles since por_n went high
  longint unsigned max_cycles = 2000000;
  int              uart_div = 1;

  initial begin
    string f;
`ifndef GLS
    if ($value$plusargs("rom=%s", f))   $readmemh(f, dut.u_rom.mem);
    if ($value$plusargs("sram0=%s", f)) $readmemh(f, dut.u_sram0.mem);
    if ($value$plusargs("sram1=%s", f)) $readmemh(f, dut.u_sram1.mem);
`endif
    if ($value$plusargs("flash=%s", f)) $readmemh(f, flash_mem);
    void'($value$plusargs("uart_div=%d", uart_div));
    void'($value$plusargs("max_cycles=%d", max_cycles));
    // the simulator starts every flop at 0, so the reset outputs of socctl
    // (flop outputs) would never fall: pulse them high once so every
    // asynchronous reset fires when por_n falls
`ifndef GLS
    force dut.u_socctl.rst_n = 1'b1;
    force dut.u_socctl.u_rst.srst_n = 1'b1;
    force dut.rst_dom_n = '1;
    force dut.rst_dbg_n = 1'b1;
`endif
    #1 por_n = 1'b0;
`ifndef GLS
    release dut.u_socctl.rst_n;
    release dut.u_socctl.u_rst.srst_n;
    release dut.rst_dom_n;
    release dut.rst_dbg_n;
`endif
    repeat (5) @(posedge clk);
    @(negedge clk);
    por_n = 1'b1;
  end

  localparam logic [31:0] SCRATCH0    = 32'h1000_001C;   // socctl scratch[0] / [1]: mailbox
  localparam logic [31:0] SCRATCH1    = 32'h1000_0020;
  localparam logic [31:0] EXT_RST_REQ = 32'hE7E7_0001;
  longint unsigned sleep_cycles = 0; // clk cycles with core_sleep high
  int unsigned phase = 0;            // last scratch[0] value below 8
  int unsigned user_i[8], user_d[8], user_apb[8];   // unprivileged transfers per phase

  initial
    for (int p = 0; p < 8; p++) begin
      user_i[p] = 0;
      user_d[p] = 0;
      user_apb[p] = 0;
    end

`ifndef GLS
  always @(posedge clk) begin
    if (dut.i_HTRANS == 2'b10 && dut.i_HREADY && !dut.i_HPROT[1])
      user_i[phase] <= user_i[phase] + 1;
    if (dut.d_HTRANS == 2'b10 && dut.d_HREADY && !dut.d_HPROT[1])
      user_d[phase] <= user_d[phase] + 1;
    if (dut.PSEL && dut.PENABLE && dut.PREADY && !dut.u_apb.PPROT[0])
      user_apb[phase] <= user_apb[phase] + 1;
    if (dut.PSEL && dut.PENABLE && dut.PREADY && dut.PWRITE && dut.PADDR == SCRATCH0 && dut.PWDATA < 8)
      phase <= dut.PWDATA;
  end

  int ext_rst_cnt = 0;                // cycles left of the requested ext_rst_n pulse

  always @(posedge clk)
    if (dut.PSEL && dut.PENABLE && dut.PREADY && dut.PWRITE && dut.PADDR == SCRATCH1 && dut.PWDATA == EXT_RST_REQ) begin
      ext_rst_n = 1'b0;
      ext_rst_cnt = 20;
    end else if (ext_rst_cnt > 0) begin
      ext_rst_cnt = ext_rst_cnt - 1;
      if (ext_rst_cnt == 0) ext_rst_n = 1'b1;
    end
`endif

  always @(posedge clk) begin
    if (por_n)
      cycles <= cycles + 1;
    if (core_sleep)
      sleep_cycles <= sleep_cycles + 1;
    if (cycles >= max_cycles) begin
      $display("\nTEST TIMEOUT after %0d cycles", cycles);
      $finish;
    end
  end

  // ---- JTAG debugger: OpenOCD-style DMI accesses (a nop scan returns each
  // result; busy means dmireset and a retry with more Run-Test/Idle cycles)
  localparam int          TCK_H       = 13;        // tck half period (clk period 10)
  localparam logic [31:0] PWM0_COUNT  = 32'h1001_5008;
  localparam logic [31:0] MAGIC       = 32'hD0B6_0001;
  localparam logic [6:0]  DMCONTROL   = 7'h10, DMSTATUS = 7'h11, ABSTRACTCS = 7'h16,
                          COMMAND     = 7'h17, DATA0    = 7'h04, SBCS       = 7'h38,
                          SBADDRESS0  = 7'h39, SBDATA0  = 7'h3C;
  localparam logic [15:0] R_DCSR = 16'h07B0, R_DPC = 16'h07B1, R_TSELECT = 16'h07A0,
                          R_TDATA1 = 16'h07A1, R_TDATA2 = 16'h07A2, R_SP = 16'h1002;

  logic [63:0] jtag_sh;              // last DR scan out
  int          jtag_idle = 1;        // Run-Test/Idle cycles after an update
  int          dbg_checks = 0;
  logic [15:0] code_hi = 16'h8000;   // the program's code: SRAM0, or the flash window (+xip)
  initial if ($test$plusargs("xip")) code_hi = 16'h2000;

  task automatic dbg_check(input bit ok, input string what);
    if (!ok) $error("debugger: %s", what);
    dbg_checks++;
  endtask

  task automatic jtag_step(input logic t, input logic d);
    jtag_tms = t; jtag_tdi = d;
    #(TCK_H);
    jtag_tck = 1'b1;
    #(TCK_H);
    jtag_tck = 1'b0;
  endtask

  task automatic jtag_ir(input logic [4:0] v);
    jtag_step(1, 0); jtag_step(1, 0); jtag_step(0, 0); jtag_step(0, 0);
    for (int i = 0; i < 5; i++) jtag_step(i == 4, v[i]);
    jtag_step(1, 0); jtag_step(0, 0);
  endtask

  task automatic jtag_dr(input int n, input logic [63:0] v);
    jtag_step(1, 0); jtag_step(0, 0); jtag_step(0, 0);
    jtag_sh = '0;
    for (int i = 0; i < n; i++) begin
      #1 jtag_sh[i] = jtag_tdo;
      jtag_step(i == n - 1, v[i]);
    end
    jtag_step(1, 0);
    for (int i = 0; i <= jtag_idle; i++) jtag_step(0, 0);
  endtask

  task automatic dmi(input logic [1:0] op, input logic [6:0] a, input logic [31:0] d, output logic [31:0] r);
    forever begin
      jtag_ir(5'h11);
      jtag_dr(41, {23'd0, a, d, op});
      jtag_dr(41, '0);
      if (jtag_sh[1:0] == 2'd0) begin r = jtag_sh[33:2]; return; end
      dbg_check(jtag_sh[1:0] == 2'd3, "DMI result is ok or busy");
      jtag_idle += 2;
      jtag_ir(5'h10);
      jtag_dr(32, 64'h0001_0000);    // dmireset
    end
  endtask

  task automatic dmi_wr(input logic [6:0] a, input logic [31:0] d);
    logic [31:0] r;
    dmi(2'd2, a, d, r);
  endtask

  task automatic dmi_rd(input logic [6:0] a, output logic [31:0] r);
    dmi(2'd1, a, '0, r);
  endtask

  // system bus access, 32 bits
  task automatic sb_rd(input logic [31:0] a, output logic [31:0] v);
    logic [31:0] cs;
    dmi_wr(SBCS, 32'h0014_0000);     // sbaccess 32, sbreadonaddr
    dmi_wr(SBADDRESS0, a);
    do dmi_rd(SBCS, cs); while (cs[21]);
    dbg_check(cs[14:12] == 3'd0 && !cs[22], $sformatf("SBA read of %h: sberror %0d", a, cs[14:12]));
    dmi_rd(SBDATA0, v);
  endtask

  task automatic sb_wr(input logic [31:0] a, input logic [31:0] v);
    logic [31:0] cs;
    dmi_wr(SBCS, 32'h0004_0000);     // sbaccess 32
    dmi_wr(SBADDRESS0, a);
    dmi_wr(SBDATA0, v);
    do dmi_rd(SBCS, cs); while (cs[21]);
    dbg_check(cs[14:12] == 3'd0 && !cs[22], $sformatf("SBA write of %h: sberror %0d", a, cs[14:12]));
  endtask

  // system bus read that must fail (no subordinate): sberror 2 (bus error), cleared again
  task automatic sb_rd_err(input logic [31:0] a);
    logic [31:0] cs;
    dmi_wr(SBCS, 32'h0014_0000);
    dmi_wr(SBADDRESS0, a);
    do dmi_rd(SBCS, cs); while (cs[21]);
    dbg_check(cs[14:12] == 3'd2, $sformatf("SBA read of %h: sberror %0d, expected 2", a, cs[14:12]));
    dmi_wr(SBCS, 32'h0000_7000);     // sberror is write-1-to-clear
    dmi_rd(SBCS, cs);
    dbg_check(cs[14:12] == 3'd0, "sberror cleared");
  endtask

  // one word of every region over the system bus, while the program keeps
  // the D bus and the DMA busy (sw/tests/debug.c); SRAM0's last word is
  // written, read back and restored; an unclaimed address gives a bus error
  task automatic sb_sweep();
    localparam int N = 13;
    logic [31:0] a[N] = '{chilisocs_pkg::DM_BASE + 32'h800, chilisocs_pkg::ROM_BASE, chilisocs_pkg::XIP_BASE,
                          chilisocs_pkg::SRAM0_BASE, chilisocs_pkg::SRAM1_BASE, chilisocs_pkg::CLINT_BASE,
                          chilisocs_pkg::PLIC_BASE + 32'h4, chilisocs_pkg::GPIO_BASE,
                          chilisocs_pkg::UART0_BASE + 32'h1C, chilisocs_pkg::TIMER_BASE + 32'h8,
                          chilisocs_pkg::SPI0_BASE, chilisocs_pkg::I2C0_BASE, chilisocs_pkg::DMA_BASE + 32'h8};
    logic [31:0] v, orig;
    localparam logic [31:0] TOP0 = chilisocs_pkg::SRAM0_BASE + (32'd4 << SRAM_AW) - 32'd4;
    for (int i = 0; i < N; i++) sb_rd(a[i], v);
    sb_rd(TOP0, orig);
    sb_wr(TOP0, 32'h5BA0_0D0E);
    sb_rd(TOP0, v);
    dbg_check(v == 32'h5BA0_0D0E, $sformatf("SBA write of SRAM0 read back %h", v));
    sb_wr(TOP0, orig);
    sb_rd_err(32'h4000_0000);
  endtask

  // abstract command: access register regno (GPR 0x1000 + n, or a CSR)
  task automatic reg_access(input logic [15:0] regno, input bit write, input logic [31:0] wv, output logic [31:0] rv);
    logic [31:0] cs;
    if (write) dmi_wr(DATA0, wv);
    dmi_wr(COMMAND, {8'd0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, write, regno});
    do dmi_rd(ABSTRACTCS, cs); while (cs[12]);
    dbg_check(cs[10:8] == 3'd0, $sformatf("abstract command on %h: cmderr %0d", regno, cs[10:8]));
    if (cs[10:8] != 3'd0) dmi_wr(ABSTRACTCS, 32'h0000_0700);
    if (!write) dmi_rd(DATA0, rv);
  endtask

  task automatic reg_rd(input logic [15:0] regno, output logic [31:0] v);
    reg_access(regno, 1'b0, '0, v);
  endtask

  task automatic reg_wr(input logic [15:0] regno, input logic [31:0] v);
    logic [31:0] r;
    reg_access(regno, 1'b1, v, r);
  endtask

  task automatic wait_halted();
    logic [31:0] st;
    int n = 0;
    do begin dmi_rd(DMSTATUS, st); n++; end while (!st[9] && n < 400);
    dbg_check(st[9], "hart halted (dmstatus.allhalted)");
  endtask

  task automatic resume();
    logic [31:0] st;
    dmi_wr(DMCONTROL, 32'h4000_0001);
    do dmi_rd(DMSTATUS, st); while (!st[17]);
    dmi_wr(DMCONTROL, 32'h0000_0001);
  endtask

  initial if ($test$plusargs("debugger")) begin
    logic [31:0] v, tgt, dpc, c1, c2;
    @(posedge por_n);
    repeat (40) @(posedge clk);
    for (int i = 0; i < 6; i++) jtag_step(1, 0);   // Test-Logic-Reset
    jtag_step(0, 0);
    jtag_dr(32, '0);
    dbg_check(jtag_sh[31:0] == chilisocs_pkg::JTAG_IDCODE, $sformatf("IDCODE %h", jtag_sh[31:0]));
    $display("\ndebugger: IDCODE %h at cycle %0d", jtag_sh[31:0], cycles);
    jtag_ir(5'h10);
    jtag_dr(32, '0);
    dbg_check(jtag_sh[3:0] == 4'd1 && jtag_sh[9:4] == 6'd7, "dtmcs: version 1, abits 7");
    dmi_wr(DMCONTROL, 32'h0000_0001);              // dmactive
    dmi_rd(DMSTATUS, v);
    dbg_check(v[3:0] == 4'd3 && v[11], "dmstatus: version 3, running");
    // the program announces itself in scratch[1]: read over the system bus
    do sb_rd(SCRATCH1, v); while (v != 32'd1);
    $display("\ndebugger: program ready at cycle %0d", cycles);
    sb_rd(SCRATCH0, tgt);
    sb_rd(PWM0_COUNT, c1);
    sb_rd(PWM0_COUNT, c2);
    dbg_check(c2 != c1, "PWM 0 counts while the hart runs");
    for (int r = 0; r < 3; r++) sb_sweep();
    $display("\ndebugger: system bus sweep done at cycle %0d", cycles);
    // halt request
    dmi_wr(DMCONTROL, 32'h8000_0001);
    wait_halted();
    dmi_wr(DMCONTROL, 32'h0000_0001);
`ifndef GLS
    dbg_check(dut.cpu_debug_mode, "core in debug mode");
`endif
    reg_rd(R_DCSR, v);
    dbg_check(v[8:6] == 3'd3 && v[31:28] == 4'd4, $sformatf("dcsr after haltreq %h: cause 3, xdebugver 4", v));
    reg_rd(R_DPC, dpc);
    dbg_check(dpc[31:16] == code_hi, $sformatf("dpc %h in the code (%h....)", dpc, code_hi));
    reg_rd(R_SP, v);
    dbg_check(v[31:16] == 16'h8001 || v == 32'h8002_0000, $sformatf("sp %h in SRAM1", v));
    sb_rd(PWM0_COUNT, c1);
    repeat (300) @(posedge clk);
    sb_rd(PWM0_COUNT, c2);
    dbg_check(c2 == c1, $sformatf("PWM 0 frozen in debug mode (%0d, %0d)", c1, c2));
    // hardware breakpoint (trigger 0) on the program's target function
    reg_wr(R_TSELECT, 32'd0);
    reg_wr(R_TDATA2, tgt);
    reg_wr(R_TDATA1, 32'h6800_1044);               // mcontrol6, dmode, action 1, m, execute
    reg_rd(R_TDATA1, v);
    dbg_check(v[31:28] == 4'd6 && v[27] && v[15:12] == 4'd1, $sformatf("tdata1 %h", v));
    sb_wr(SCRATCH0, MAGIC);
    sb_wr(SCRATCH1, 32'd2);
    resume();                                      // resumeack: the hart left debug mode
    wait_halted();
    reg_rd(R_DCSR, v);
    dbg_check(v[8:6] == 3'd2, $sformatf("dcsr after the breakpoint %h: cause 2 (trigger)", v));
    reg_rd(R_DPC, dpc);
    dbg_check(dpc == tgt, $sformatf("dpc %h at the breakpoint %h", dpc, tgt));
    reg_wr(R_TDATA1, 32'h0);                       // disable the trigger
    // single step
    reg_wr(R_DCSR, v | 32'h4);
    resume();
    wait_halted();
    reg_rd(R_DCSR, v);
    dbg_check(v[8:6] == 3'd4, $sformatf("dcsr after a step %h: cause 4", v));
    reg_rd(R_DPC, dpc);
    dbg_check(dpc == tgt + 2 || dpc == tgt + 4, $sformatf("dpc %h one instruction after %h", dpc, tgt));
    reg_wr(R_DCSR, v & ~32'h4);
    resume();
    // the program finishes its first boot: system reset from the debugger
    do sb_rd(SCRATCH1, v); while (v != 32'd3);
    dmi_wr(DMCONTROL, 32'h0000_0003);              // ndmreset
    repeat (20) @(posedge clk);
`ifndef GLS
    dbg_check(!dut.rst_cpu_n && !dut.rst_bus_n, "ndmreset holds the system in reset");
`endif
    dmi_wr(DMCONTROL, 32'h0000_0001);
    dmi_rd(DMSTATUS, v);
    dbg_check(v[19], "dmstatus.allhavereset after ndmreset");
    dmi_wr(DMCONTROL, 32'h1000_0001);              // ackhavereset
    dmi_rd(DMSTATUS, v);
    dbg_check(!v[19], "havereset acknowledged");
    do sb_rd(SCRATCH1, v); while (v != 32'd3);       // second boot is up
    sb_wr(SCRATCH1, 32'd4);                          // release it
    $display("\ndebugger done: %0d checks at cycle %0d", dbg_checks, cycles);
  end

  // ---- debugger traffic during sw/tests/stress.c (+sba_stress): until the
  // program says it is done (scratch[1] = 3), bursts of system bus writes and
  // reads (sbautoincrement, sbreadondata) of its own buffer DBG_BUF, checked;
  // reads of a random region; every fourth burst a halt, a look at dpc and
  // sp, and a resume. Then the final pattern into DBG_BUF (the program checks
  // it) and scratch[1] = 4. Random choices follow +verilator+seed.
  localparam logic [31:0] DBG_BUF   = chilisocs_pkg::SRAM1_BASE + 32'hA000;
  localparam int          DBG_WORDS = 64;

  task automatic sb_burst_wr(input logic [31:0] a, input logic [31:0] d[DBG_WORDS], input int n);
    logic [31:0] cs;
    dmi_wr(SBCS, 32'h0005_0000);     // sbaccess 32, sbautoincrement
    dmi_wr(SBADDRESS0, a);
    for (int i = 0; i < n; i++) dmi_wr(SBDATA0, d[i]);
    do dmi_rd(SBCS, cs); while (cs[21]);
    dbg_check(cs[14:12] == 3'd0 && !cs[22], $sformatf("SBA burst write of %h: sberror %0d busyerror %0d", a,
              cs[14:12], cs[22]));
  endtask

  task automatic sb_burst_rd(input logic [31:0] a, output logic [31:0] d[DBG_WORDS], input int n);
    logic [31:0] cs;
    dmi_wr(SBCS, 32'h0015_8000);     // sbaccess 32, sbreadonaddr, sbautoincrement, sbreadondata
    dmi_wr(SBADDRESS0, a);
    for (int i = 0; i < n; i++) begin
      if (i == n - 1) dmi_wr(SBCS, 32'h0005_0000);   // last word: no read after it
      dmi_rd(SBDATA0, d[i]);
    end
    do dmi_rd(SBCS, cs); while (cs[21]);
    dbg_check(cs[14:12] == 3'd0 && !cs[22], $sformatf("SBA burst read of %h: sberror %0d busyerror %0d", a,
              cs[14:12], cs[22]));
  endtask

  initial if ($test$plusargs("sba_stress")) begin
    logic [31:0] v, wr[DBG_WORDS], rd[DBG_WORDS];
    int bursts = 0, halts = 0, n, off;
    logic [31:0] regions[6] = '{chilisocs_pkg::ROM_BASE, chilisocs_pkg::SRAM0_BASE, chilisocs_pkg::SRAM1_BASE,
                                chilisocs_pkg::CLINT_BASE + 32'hBFF8, chilisocs_pkg::PLIC_BASE + 32'h4,
                                chilisocs_pkg::DMA_BASE + 32'h108};
    @(posedge por_n);
    repeat (40) @(posedge clk);
    for (int i = 0; i < 6; i++) jtag_step(1, 0);   // Test-Logic-Reset
    jtag_step(0, 0);
    dmi_wr(DMCONTROL, 32'h0000_0001);              // dmactive
    do sb_rd(SCRATCH1, v); while (v != 32'd1);
    $display("\nsba stress: program running at cycle %0d", cycles);
    forever begin
      sb_rd(SCRATCH1, v);
      if (v == 32'd3) break;
      n   = 1 + int'($urandom_range(DBG_WORDS - 1));
      off = int'($urandom_range(DBG_WORDS - n));
      for (int i = 0; i < n; i++) wr[i] = $urandom;
      sb_burst_wr(DBG_BUF + 32'(4 * off), wr, n);
      sb_rd(regions[$urandom_range(5)], v);
      sb_burst_rd(DBG_BUF + 32'(4 * off), rd, n);
      for (int i = 0; i < n; i++)
        dbg_check(rd[i] == wr[i], $sformatf("SBA burst word %0d at %h: %h, wrote %h", i, DBG_BUF + 32'(4 * (off + i)),
                                           rd[i], wr[i]));
      bursts++;
      if (bursts % 4 == 0) begin
        dmi_wr(DMCONTROL, 32'h8000_0001);          // halt request
        wait_halted();
        dmi_wr(DMCONTROL, 32'h0000_0001);
        reg_rd(R_DPC, v);
        dbg_check(v[31:16] == code_hi, $sformatf("dpc %h in the code (%h....)", v, code_hi));
        $display("sba stress: halt %0d at cycle %0d, dpc %h", halts, cycles, v);
        reg_rd(R_SP, v);
        dbg_check(v[31:16] == 16'h8001 || v == 32'h8002_0000, $sformatf("sp %h in SRAM1", v));
        repeat ($urandom_range(200)) @(posedge clk);
        resume();
        halts++;
      end
    end
    for (int i = 0; i < DBG_WORDS; i++) wr[i] = 32'hD1B0_0000 ^ (32'h9E37_79B9 * 32'(i));
    sb_burst_wr(DBG_BUF, wr, DBG_WORDS);
    sb_burst_rd(DBG_BUF, rd, DBG_WORDS);
    for (int i = 0; i < DBG_WORDS; i++) dbg_check(rd[i] == wr[i], $sformatf("SBA final word %0d: %h", i, rd[i]));
    sb_wr(SCRATCH1, 32'd4);
    $display("\nsba stress done: %0d bursts, %0d halts, %0d checks at cycle %0d", bursts, halts, dbg_checks, cycles);
  end

  // ---- retired-instruction log (+rvfi_log=<file>): the core's RVFI trace,
  // one line per instruction from cycle +rvfi_from=<n> on (for a failing
  // program: which instruction produced the wrong value)
  int    rvfi_fd   = 0;
  longint unsigned rvfi_from = 0;
  string rvfi_file;

  initial
    if ($value$plusargs("rvfi_log=%s", rvfi_file)) begin
      void'($value$plusargs("rvfi_from=%d", rvfi_from));
      rvfi_fd = $fopen(rvfi_file, "w");
    end

`ifndef GLS
  always @(posedge clk)
    if (rvfi_fd != 0 && cycles >= rvfi_from && dut.u_cpu.rvfi_valid)
      $fdisplay(rvfi_fd, "%0d %0d m%0d pc %h insn %h%s%s%s x%0d=%h mem %h r%h w%h %h",
                cycles, dut.u_cpu.rvfi_order, dut.u_cpu.rvfi_mode, dut.u_cpu.rvfi_pc_rdata, dut.u_cpu.rvfi_insn,
                dut.u_cpu.rvfi_trap ? " TRAP" : "", dut.u_cpu.rvfi_intr ? " INTR" : "",
                dut.u_cpu.rvfi_halt ? " HALT" : "", dut.u_cpu.rvfi_rd_addr, dut.u_cpu.rvfi_rd_wdata,
                dut.u_cpu.rvfi_mem_addr, dut.u_cpu.rvfi_mem_rmask, dut.u_cpu.rvfi_mem_wmask,
                dut.u_cpu.rvfi_mem_wmask != 0 ? dut.u_cpu.rvfi_mem_wdata : dut.u_cpu.rvfi_mem_rdata);
`endif

  // ---- OpenOCD over remote_bitbang (+rbb_port=<n>, sim/tb/rbb.c): every
  // RBB_DIV clk cycles one JTAG pin change from OpenOCD (tck half period at
  // least RBB_DIV clk periods); srst drives ext_rst_n
  localparam int RBB_DIV = 2;
  import "DPI-C" function int rbb_open(input int port);
  import "DPI-C" function int rbb_step(input int tdo);
  int rbb_port = 0;
  int rbb_cnt  = 0;
  int rbb_pins;

  initial
    if ($value$plusargs("rbb_port=%d", rbb_port) && rbb_open(rbb_port) != 0) begin
      $display("TEST FAIL rbb: cannot listen on port %0d", rbb_port);
      $finish;
    end

  always @(posedge clk)
    if (rbb_port != 0) begin
      rbb_cnt = rbb_cnt + 1;
      if (rbb_cnt == RBB_DIV) begin
        rbb_cnt     = 0;
        rbb_pins    = rbb_step({31'd0, jtag_tdo});
        jtag_tck    = rbb_pins[0];
        jtag_tms    = rbb_pins[1];
        jtag_tdi    = rbb_pins[2];
        jtag_trst_n = !rbb_pins[3];
        ext_rst_n   = !rbb_pins[4];
      end
    end

  // ---- SPI NOR flash (mode 0, one chip select): samples on rising sck,
  // drives on falling sck. Instructions (command and address on dq0):
  //   0x03 read, 0x0B fast read (8 dummy cycles), 0x3B dual output and
  //   0x6B quad output fast read (8 dummy cycles), all with 3 address bytes;
  //   0x9F JEDEC ID (EF 40 18), 0x05 status (0: never busy); 0x66 / 0x99
  //   (reset) and 0xAB (wake up) are accepted without data. Any other
  //   command is an error. Data on dq1 (single), dq1..0 (dual), dq3..0
  //   (quad), MSB first.
  logic [31:0] flash_mem [16384];
  logic        fl_sck_q = 1'b0;
  logic        fl_cs_q = 1'b1;
  int          fl_rises;             // rising sck edges since cs fell
  logic [7:0]  fl_cmd;
  logic [23:0] fl_addr;
  logic [3:0]  fl_out = '0;          // bits the flash drives
  int          flash_insts = 0;      // instructions per command code
  int          flash_reads = 0;      // read instructions (03 / 0B / 3B / 6B)

  initial
    for (int i = 0; i < 16384; i++) flash_mem[i] = '0;

  assign spi_dq_i = fl_out;

  function automatic logic [7:0] flash_byte(input logic [23:0] a);
    return flash_mem[a[15:2]][8 * a[1:0] +: 8];
  endfunction

  always @(negedge clk) begin
    int w, s_data, j, grp;
    logic [7:0] b;
    if (!spi_cs && fl_cs_q) begin fl_rises = 0; fl_cmd = '0; fl_addr = '0; fl_out = '0; end
    if (spi_cs && !fl_cs_q) fl_out = '0;
    if (!spi_cs) begin
      w      = (fl_cmd == 8'h6B) ? 4 : (fl_cmd == 8'h3B) ? 2 : 1;
      s_data = (fl_cmd == 8'h03) ? 32 : (fl_cmd == 8'h9F || fl_cmd == 8'h05) ? 8 : 40;
      if (spi_sck && !fl_sck_q) begin                // rising: sample
        if (fl_rises < 8)
          fl_cmd = {fl_cmd[6:0], spi_dq_o[0]};
        else if (fl_rises < 32 && fl_cmd != 8'h9F && fl_cmd != 8'h05)
          fl_addr = {fl_addr[22:0], spi_dq_o[0]};
        fl_rises++;
        if (fl_rises == 8) begin
          flash_insts++;
          if (fl_cmd inside {8'h03, 8'h0B, 8'h3B, 8'h6B}) flash_reads++;
          else if (!(fl_cmd inside {8'h9F, 8'h05, 8'h66, 8'h99, 8'hAB}))
            $error("SPI flash: unknown command %02x", fl_cmd);
        end
      end
      if (!spi_sck && fl_sck_q && fl_rises >= s_data && fl_rises >= 8
          && !(fl_cmd inside {8'h66, 8'h99, 8'hAB})) begin  // falling: next data bits
        w      = (fl_cmd == 8'h6B) ? 4 : (fl_cmd == 8'h3B) ? 2 : 1;
        s_data = (fl_cmd == 8'h03) ? 32 : (fl_cmd == 8'h9F || fl_cmd == 8'h05) ? 8 : 40;
        j      = fl_rises - s_data;
        grp    = j % (8 / w);
        case (fl_cmd)
          8'h9F:   b = (j / 8 % 3 == 0) ? 8'hEF : (j / 8 % 3 == 1) ? 8'h40 : 8'h18;
          8'h05:   b = 8'h00;
          default: b = flash_byte(fl_addr + 24'(j / (8 / w)));
        endcase
        if (w == 4)      fl_out = (grp == 0) ? b[7:4] : b[3:0];
        else if (w == 2) fl_out = {2'd0, b[7 - 2 * grp -: 2]};
        else             fl_out = {2'd0, b[7 - grp], 1'b0};
      end
    end
    fl_sck_q = spi_sck;
    fl_cs_q  = spi_cs;
  end

  // ---- I2C EEPROM at address 0x50 (256 bytes, 8-bit pointer that
  // increments per byte, 24C02 style): a write sends the pointer then data
  // bytes, a read returns bytes from the pointer. It stretches scl for 12
  // cycles after every fifth falling scl edge.
  localparam logic [6:0] EEPROM_ADDR = 7'h50;
  typedef enum int {T_IDLE, T_RX, T_TX} i2c_tst_e;
  logic [7:0] ee_mem [256];
  logic [7:0] ee_ptr, ee_rx, ee_tx;
  i2c_tst_e   ee_st = T_IDLE;
  int         ee_bit;                // bits clocked in this byte (8: the ack clock)
  logic       ee_first;              // the next received byte is the address
  logic       ee_got_ptr;            // the pointer byte arrived in this write
  logic       ee_acking;             // driving our ACK
  logic       ee_m_ack;              // the master's ack bit after a byte we sent
  logic       ee_scl_q = 1'b1, ee_sda_q = 1'b1;
  logic       ee_scl_low = 1'b0, ee_sda_low = 1'b0;
  int         ee_stretch = 0, ee_falls = 0;
  int         ee_starts = 0, ee_stops = 0, ee_stretches = 0;

  assign i2c_scl_i = !(i2c_scl_oe || ee_scl_low);
  assign i2c_sda_i = !(i2c_sda_oe || ee_sda_low);

  initial
    for (int i = 0; i < 256; i++) ee_mem[i] = 8'(i * 7 + 1);

  always @(negedge clk) begin
    if (ee_stretch > 0) begin
      ee_stretch--;
      if (ee_stretch == 0) ee_scl_low = 1'b0;
    end
    if (i2c_scl_i && ee_scl_q && i2c_sda_i != ee_sda_q) begin        // START / STOP
      ee_sda_low = 1'b0; ee_acking = 1'b0;
      if (!i2c_sda_i) begin ee_st = T_RX; ee_bit = 0; ee_first = 1'b1; ee_got_ptr = 1'b0; ee_starts++; end
      else begin ee_st = T_IDLE; ee_stops++; end
    end else if (i2c_scl_i && !ee_scl_q) begin                         // rise: sample
      if (ee_st == T_RX && ee_bit < 8) begin
        ee_rx = {ee_rx[6:0], i2c_sda_i}; ee_bit++;
      end else if (ee_st == T_TX) begin
        if (ee_bit == 8) ee_m_ack = i2c_sda_i;
        ee_bit++;
      end
    end else if (!i2c_scl_i && ee_scl_q) begin                         // fall: drive
      ee_falls++;
      if (ee_falls % 5 == 0) begin ee_stretch = 12; ee_scl_low = 1'b1; ee_stretches++; end
      if (ee_st == T_RX) begin
        if (ee_bit == 8 && !ee_acking) begin
          if (ee_first && ee_rx[7:1] != EEPROM_ADDR) ee_st = T_IDLE; // not us: NACK
          else begin ee_sda_low = 1'b1; ee_acking = 1'b1; end
        end else if (ee_acking) begin
          ee_sda_low = 1'b0; ee_acking = 1'b0; ee_bit = 0;
          if (ee_first) begin
            ee_first = 1'b0;
            if (ee_rx[0]) begin ee_st = T_TX; ee_tx = ee_mem[ee_ptr]; ee_sda_low = !ee_tx[7]; end
          end else if (!ee_got_ptr) begin
            ee_ptr = ee_rx; ee_got_ptr = 1'b1;
          end else begin
            ee_mem[ee_ptr] = ee_rx; ee_ptr++;
          end
        end
      end else if (ee_st == T_TX) begin
        if (ee_bit < 8) ee_sda_low = !ee_tx[7 - ee_bit];
        else if (ee_bit == 8) ee_sda_low = 1'b0;                     // the master's ack clock
        else begin
          ee_ptr++;
          if (!ee_m_ack) begin ee_tx = ee_mem[ee_ptr]; ee_bit = 0; ee_sda_low = !ee_tx[7]; end
          else begin ee_sda_low = 1'b0; ee_st = T_IDLE; end          // NACK: wait for STOP
        end
      end
    end
    ee_scl_q = i2c_scl_i; ee_sda_q = i2c_sda_i;
  end

  // ---- UART receiver: 8N1, sampled mid-bit
  string line = "";
  initial begin
    logic [7:0] ch;
`ifdef GLS
    @(posedge por_n);
`else
    @(posedge dut.rst_bus_n);
`endif
    forever begin
      @(negedge uart_txd);
      repeat (8 * uart_div) @(posedge clk);
      if (uart_txd)
        continue;                    // glitch, not a start bit
      for (int i = 0; i < 8; i++) begin
        repeat (16 * uart_div) @(posedge clk);
        ch[i] = uart_txd;
      end
      repeat (16 * uart_div) @(posedge clk);
      if (!uart_txd)
        $error("UART framing error after 0x%02x", ch);
      $write("%c", ch);
      if (ch == 8'h0a) begin
        $fflush;
        if (line.substr(0, 7) == "*** PASS") begin
          $display("core_sleep cycles %0d", sleep_cycles);
          $display("flash instructions %0d reads %0d; eeprom starts %0d stops %0d stretches %0d",
                   flash_insts, flash_reads, ee_starts, ee_stops, ee_stretches);
          for (int p = 0; p < 8; p++)
            $display("user phase %0d i %0d d %0d apb %0d", p, user_i[p], user_d[p], user_apb[p]);
          $display("TEST PASS cycles %0d", cycles);
          $finish;
        end else if (line.len() >= 8 && line.substr(0, 7) == "*** FAIL") begin
          $display("TEST FAIL cycles %0d", cycles);
          $finish;
        end
        line = "";
      end else begin
        line = $sformatf("%s%c", line, ch);
      end
    end
  end

endmodule
