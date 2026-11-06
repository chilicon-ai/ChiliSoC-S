// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// Testbench :: chilimix_plic_regs -- random APB4 transfers against a register model
//
// Checked every cycle: field outputs equal the model (reset values, rw bits
// with PSTRB, w1c set by _set inputs and cleared by writing 1, set winning),
// PREADY high, PRDATA of a read, PSLVERR exactly where no block word exists,
// read / write pulses one-hot on the accessed register in ACCESS.
`include "tb_common.svh"
module chilimix_plic_regs_tb #(
  parameter int N_CTX = 1  // contexts present (1 .. 16)
);
  localparam int AW = 22, DW = 32, NL = 4, NREG = 129, NBLK = 4;
  localparam int N_CYC = 20000;

  `TB_CLOCK_RESET

  logic PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [AW-1:0] PADDR;
  logic [DW-1:0] PWDATA, PRDATA;
  logic [NL-1:0] PSTRB;
  logic [188:0] priority_value;
  logic [30:0] pending0_src;
  logic [31:0] pending1_src;
  logic [495:0] enable0_src;
  logic [511:0] enable1_src;
  logic [47:0] threshold_value;
  logic [95:0] claim_id;
  logic [15:0] claim_rd;
  logic [15:0] claim_wr;

  chilimix_plic_regs #(.N_CTX(N_CTX)) dut (.*);

  // register table (absolute byte offsets) and blocks
  localparam logic [AW-1:0] OFFS [NREG] = '{22'h4, 22'h8, 22'hc, 22'h10, 22'h14, 22'h18, 22'h1c, 22'h20, 22'h24, 22'h28, 22'h2c, 22'h30, 22'h34, 22'h38, 22'h3c, 22'h40, 22'h44, 22'h48, 22'h4c, 22'h50, 22'h54, 22'h58, 22'h5c, 22'h60, 22'h64, 22'h68, 22'h6c, 22'h70, 22'h74, 22'h78, 22'h7c, 22'h80, 22'h84, 22'h88, 22'h8c, 22'h90, 22'h94, 22'h98, 22'h9c, 22'ha0, 22'ha4, 22'ha8, 22'hac, 22'hb0, 22'hb4, 22'hb8, 22'hbc, 22'hc0, 22'hc4, 22'hc8, 22'hcc, 22'hd0, 22'hd4, 22'hd8, 22'hdc, 22'he0, 22'he4, 22'he8, 22'hec, 22'hf0, 22'hf4, 22'hf8, 22'hfc, 22'h1000, 22'h1004, 22'h2000, 22'h2004, 22'h2080, 22'h2084, 22'h2100, 22'h2104, 22'h2180, 22'h2184, 22'h2200, 22'h2204, 22'h2280, 22'h2284, 22'h2300, 22'h2304, 22'h2380, 22'h2384, 22'h2400, 22'h2404, 22'h2480, 22'h2484, 22'h2500, 22'h2504, 22'h2580, 22'h2584, 22'h2600, 22'h2604, 22'h2680, 22'h2684, 22'h2700, 22'h2704, 22'h2780, 22'h2784, 22'h200000, 22'h200004, 22'h201000, 22'h201004, 22'h202000, 22'h202004, 22'h203000, 22'h203004, 22'h204000, 22'h204004, 22'h205000, 22'h205004, 22'h206000, 22'h206004, 22'h207000, 22'h207004, 22'h208000, 22'h208004, 22'h209000, 22'h209004, 22'h20a000, 22'h20a004, 22'h20b000, 22'h20b004, 22'h20c000, 22'h20c004, 22'h20d000, 22'h20d004, 22'h20e000, 22'h20e004, 22'h20f000, 22'h20f004};
  localparam logic [DW-1:0] RW   [NREG] = '{32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h7, 32'h0, 32'h0, (N_CTX > 0) ? 32'hfffffffe : 32'h0, (N_CTX > 0) ? 32'hffffffff : 32'h0, (N_CTX > 1) ? 32'hfffffffe : 32'h0, (N_CTX > 1) ? 32'hffffffff : 32'h0, (N_CTX > 2) ? 32'hfffffffe : 32'h0, (N_CTX > 2) ? 32'hffffffff : 32'h0, (N_CTX > 3) ? 32'hfffffffe : 32'h0, (N_CTX > 3) ? 32'hffffffff : 32'h0, (N_CTX > 4) ? 32'hfffffffe : 32'h0, (N_CTX > 4) ? 32'hffffffff : 32'h0, (N_CTX > 5) ? 32'hfffffffe : 32'h0, (N_CTX > 5) ? 32'hffffffff : 32'h0, (N_CTX > 6) ? 32'hfffffffe : 32'h0, (N_CTX > 6) ? 32'hffffffff : 32'h0, (N_CTX > 7) ? 32'hfffffffe : 32'h0, (N_CTX > 7) ? 32'hffffffff : 32'h0, (N_CTX > 8) ? 32'hfffffffe : 32'h0, (N_CTX > 8) ? 32'hffffffff : 32'h0, (N_CTX > 9) ? 32'hfffffffe : 32'h0, (N_CTX > 9) ? 32'hffffffff : 32'h0, (N_CTX > 10) ? 32'hfffffffe : 32'h0, (N_CTX > 10) ? 32'hffffffff : 32'h0, (N_CTX > 11) ? 32'hfffffffe : 32'h0, (N_CTX > 11) ? 32'hffffffff : 32'h0, (N_CTX > 12) ? 32'hfffffffe : 32'h0, (N_CTX > 12) ? 32'hffffffff : 32'h0, (N_CTX > 13) ? 32'hfffffffe : 32'h0, (N_CTX > 13) ? 32'hffffffff : 32'h0, (N_CTX > 14) ? 32'hfffffffe : 32'h0, (N_CTX > 14) ? 32'hffffffff : 32'h0, (N_CTX > 15) ? 32'hfffffffe : 32'h0, (N_CTX > 15) ? 32'hffffffff : 32'h0, (N_CTX > 0) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 1) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 2) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 3) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 4) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 5) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 6) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 7) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 8) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 9) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 10) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 11) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 12) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 13) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 14) ? 32'h7 : 32'h0, 32'h0, (N_CTX > 15) ? 32'h7 : 32'h0, 32'h0};
  localparam logic [DW-1:0] W1C  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hfffffffe, 32'hffffffff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, (N_CTX > 0) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 1) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 2) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 3) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 4) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 5) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 6) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 7) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 8) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 9) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 10) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 11) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 12) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 13) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 14) ? 32'h3f : 32'h0, 32'h0, (N_CTX > 15) ? 32'h3f : 32'h0};
  localparam logic [DW-1:0] RST  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] WO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam int DIR [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};  // 0 both, 1 reads only, 2 writes only
  localparam int BANK_IDX [NREG] = '{-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};  // register holding the bank field, or -1
  localparam logic [DW-1:0] BANK_MASK [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] BANK_VAL  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam bit HAS_RD [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, (N_CTX > 0) ? 1 : 0, 0, (N_CTX > 1) ? 1 : 0, 0, (N_CTX > 2) ? 1 : 0, 0, (N_CTX > 3) ? 1 : 0, 0, (N_CTX > 4) ? 1 : 0, 0, (N_CTX > 5) ? 1 : 0, 0, (N_CTX > 6) ? 1 : 0, 0, (N_CTX > 7) ? 1 : 0, 0, (N_CTX > 8) ? 1 : 0, 0, (N_CTX > 9) ? 1 : 0, 0, (N_CTX > 10) ? 1 : 0, 0, (N_CTX > 11) ? 1 : 0, 0, (N_CTX > 12) ? 1 : 0, 0, (N_CTX > 13) ? 1 : 0, 0, (N_CTX > 14) ? 1 : 0, 0, (N_CTX > 15) ? 1 : 0};
  localparam bit HAS_WR [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, (N_CTX > 0) ? 1 : 0, 0, (N_CTX > 1) ? 1 : 0, 0, (N_CTX > 2) ? 1 : 0, 0, (N_CTX > 3) ? 1 : 0, 0, (N_CTX > 4) ? 1 : 0, 0, (N_CTX > 5) ? 1 : 0, 0, (N_CTX > 6) ? 1 : 0, 0, (N_CTX > 7) ? 1 : 0, 0, (N_CTX > 8) ? 1 : 0, 0, (N_CTX > 9) ? 1 : 0, 0, (N_CTX > 10) ? 1 : 0, 0, (N_CTX > 11) ? 1 : 0, 0, (N_CTX > 12) ? 1 : 0, 0, (N_CTX > 13) ? 1 : 0, 0, (N_CTX > 14) ? 1 : 0, 0, (N_CTX > 15) ? 1 : 0};
  localparam int BLK_BASE  [NBLK] = '{0, 4096, 8192, 2097152};
  localparam int BLK_SIZE  [NBLK] = '{256, 8, 2048, 65536};
  localparam int BLK_WORDS [NBLK] = '{64, 2, 482, 15362};
  // driven by the testbench on every element, present or not
  localparam logic [DW-1:0] RO_DRV  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hfffffffe, 32'hffffffff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f, 32'h0, 32'h3f};
  localparam logic [DW-1:0] W1C_DRV [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};

  logic [DW-1:0] model  [NREG];   // expected rw / w1c bits
  logic [DW-1:0] ro_val [NREG];   // read-only values driven this cycle
  logic [DW-1:0] set_rq [NREG];   // w1c set requests this cycle

  // drive the read-only values and w1c set requests of this cycle
  task automatic drive_hw();
    pending0_src = ro_val[63][31:1];
    pending1_src = ro_val[64][31:0];
    claim_id = {ro_val[128][5:0], ro_val[126][5:0], ro_val[124][5:0], ro_val[122][5:0], ro_val[120][5:0], ro_val[118][5:0], ro_val[116][5:0], ro_val[114][5:0], ro_val[112][5:0], ro_val[110][5:0], ro_val[108][5:0], ro_val[106][5:0], ro_val[104][5:0], ro_val[102][5:0], ro_val[100][5:0], ro_val[98][5:0]};
  endtask

  // stored bits of register i as seen on the field outputs
  function automatic logic [DW-1:0] q_of(int i);
    case (i)
      0: return (DW'(priority_value[2:0]) << 0);
      1: return (DW'(priority_value[5:3]) << 0);
      2: return (DW'(priority_value[8:6]) << 0);
      3: return (DW'(priority_value[11:9]) << 0);
      4: return (DW'(priority_value[14:12]) << 0);
      5: return (DW'(priority_value[17:15]) << 0);
      6: return (DW'(priority_value[20:18]) << 0);
      7: return (DW'(priority_value[23:21]) << 0);
      8: return (DW'(priority_value[26:24]) << 0);
      9: return (DW'(priority_value[29:27]) << 0);
      10: return (DW'(priority_value[32:30]) << 0);
      11: return (DW'(priority_value[35:33]) << 0);
      12: return (DW'(priority_value[38:36]) << 0);
      13: return (DW'(priority_value[41:39]) << 0);
      14: return (DW'(priority_value[44:42]) << 0);
      15: return (DW'(priority_value[47:45]) << 0);
      16: return (DW'(priority_value[50:48]) << 0);
      17: return (DW'(priority_value[53:51]) << 0);
      18: return (DW'(priority_value[56:54]) << 0);
      19: return (DW'(priority_value[59:57]) << 0);
      20: return (DW'(priority_value[62:60]) << 0);
      21: return (DW'(priority_value[65:63]) << 0);
      22: return (DW'(priority_value[68:66]) << 0);
      23: return (DW'(priority_value[71:69]) << 0);
      24: return (DW'(priority_value[74:72]) << 0);
      25: return (DW'(priority_value[77:75]) << 0);
      26: return (DW'(priority_value[80:78]) << 0);
      27: return (DW'(priority_value[83:81]) << 0);
      28: return (DW'(priority_value[86:84]) << 0);
      29: return (DW'(priority_value[89:87]) << 0);
      30: return (DW'(priority_value[92:90]) << 0);
      31: return (DW'(priority_value[95:93]) << 0);
      32: return (DW'(priority_value[98:96]) << 0);
      33: return (DW'(priority_value[101:99]) << 0);
      34: return (DW'(priority_value[104:102]) << 0);
      35: return (DW'(priority_value[107:105]) << 0);
      36: return (DW'(priority_value[110:108]) << 0);
      37: return (DW'(priority_value[113:111]) << 0);
      38: return (DW'(priority_value[116:114]) << 0);
      39: return (DW'(priority_value[119:117]) << 0);
      40: return (DW'(priority_value[122:120]) << 0);
      41: return (DW'(priority_value[125:123]) << 0);
      42: return (DW'(priority_value[128:126]) << 0);
      43: return (DW'(priority_value[131:129]) << 0);
      44: return (DW'(priority_value[134:132]) << 0);
      45: return (DW'(priority_value[137:135]) << 0);
      46: return (DW'(priority_value[140:138]) << 0);
      47: return (DW'(priority_value[143:141]) << 0);
      48: return (DW'(priority_value[146:144]) << 0);
      49: return (DW'(priority_value[149:147]) << 0);
      50: return (DW'(priority_value[152:150]) << 0);
      51: return (DW'(priority_value[155:153]) << 0);
      52: return (DW'(priority_value[158:156]) << 0);
      53: return (DW'(priority_value[161:159]) << 0);
      54: return (DW'(priority_value[164:162]) << 0);
      55: return (DW'(priority_value[167:165]) << 0);
      56: return (DW'(priority_value[170:168]) << 0);
      57: return (DW'(priority_value[173:171]) << 0);
      58: return (DW'(priority_value[176:174]) << 0);
      59: return (DW'(priority_value[179:177]) << 0);
      60: return (DW'(priority_value[182:180]) << 0);
      61: return (DW'(priority_value[185:183]) << 0);
      62: return (DW'(priority_value[188:186]) << 0);
      63: return '0;
      64: return '0;
      65: return (DW'(enable0_src[30:0]) << 1);
      66: return (DW'(enable1_src[31:0]) << 0);
      67: return (DW'(enable0_src[61:31]) << 1);
      68: return (DW'(enable1_src[63:32]) << 0);
      69: return (DW'(enable0_src[92:62]) << 1);
      70: return (DW'(enable1_src[95:64]) << 0);
      71: return (DW'(enable0_src[123:93]) << 1);
      72: return (DW'(enable1_src[127:96]) << 0);
      73: return (DW'(enable0_src[154:124]) << 1);
      74: return (DW'(enable1_src[159:128]) << 0);
      75: return (DW'(enable0_src[185:155]) << 1);
      76: return (DW'(enable1_src[191:160]) << 0);
      77: return (DW'(enable0_src[216:186]) << 1);
      78: return (DW'(enable1_src[223:192]) << 0);
      79: return (DW'(enable0_src[247:217]) << 1);
      80: return (DW'(enable1_src[255:224]) << 0);
      81: return (DW'(enable0_src[278:248]) << 1);
      82: return (DW'(enable1_src[287:256]) << 0);
      83: return (DW'(enable0_src[309:279]) << 1);
      84: return (DW'(enable1_src[319:288]) << 0);
      85: return (DW'(enable0_src[340:310]) << 1);
      86: return (DW'(enable1_src[351:320]) << 0);
      87: return (DW'(enable0_src[371:341]) << 1);
      88: return (DW'(enable1_src[383:352]) << 0);
      89: return (DW'(enable0_src[402:372]) << 1);
      90: return (DW'(enable1_src[415:384]) << 0);
      91: return (DW'(enable0_src[433:403]) << 1);
      92: return (DW'(enable1_src[447:416]) << 0);
      93: return (DW'(enable0_src[464:434]) << 1);
      94: return (DW'(enable1_src[479:448]) << 0);
      95: return (DW'(enable0_src[495:465]) << 1);
      96: return (DW'(enable1_src[511:480]) << 0);
      97: return (DW'(threshold_value[2:0]) << 0);
      98: return '0;
      99: return (DW'(threshold_value[5:3]) << 0);
      100: return '0;
      101: return (DW'(threshold_value[8:6]) << 0);
      102: return '0;
      103: return (DW'(threshold_value[11:9]) << 0);
      104: return '0;
      105: return (DW'(threshold_value[14:12]) << 0);
      106: return '0;
      107: return (DW'(threshold_value[17:15]) << 0);
      108: return '0;
      109: return (DW'(threshold_value[20:18]) << 0);
      110: return '0;
      111: return (DW'(threshold_value[23:21]) << 0);
      112: return '0;
      113: return (DW'(threshold_value[26:24]) << 0);
      114: return '0;
      115: return (DW'(threshold_value[29:27]) << 0);
      116: return '0;
      117: return (DW'(threshold_value[32:30]) << 0);
      118: return '0;
      119: return (DW'(threshold_value[35:33]) << 0);
      120: return '0;
      121: return (DW'(threshold_value[38:36]) << 0);
      122: return '0;
      123: return (DW'(threshold_value[41:39]) << 0);
      124: return '0;
      125: return (DW'(threshold_value[44:42]) << 0);
      126: return '0;
      127: return (DW'(threshold_value[47:45]) << 0);
      128: return '0;
      default: return '0;
    endcase
  endfunction

  // write-only field outputs of register i (PWDATA bits) in place
  function automatic logic [DW-1:0] wo_of(int i);
    case (i)
      default: return '0;
    endcase
  endfunction

  function automatic logic pulse_of(int i, bit wr);
    case (i)
      0: return wr ? 1'b0 : 1'b0;
      1: return wr ? 1'b0 : 1'b0;
      2: return wr ? 1'b0 : 1'b0;
      3: return wr ? 1'b0 : 1'b0;
      4: return wr ? 1'b0 : 1'b0;
      5: return wr ? 1'b0 : 1'b0;
      6: return wr ? 1'b0 : 1'b0;
      7: return wr ? 1'b0 : 1'b0;
      8: return wr ? 1'b0 : 1'b0;
      9: return wr ? 1'b0 : 1'b0;
      10: return wr ? 1'b0 : 1'b0;
      11: return wr ? 1'b0 : 1'b0;
      12: return wr ? 1'b0 : 1'b0;
      13: return wr ? 1'b0 : 1'b0;
      14: return wr ? 1'b0 : 1'b0;
      15: return wr ? 1'b0 : 1'b0;
      16: return wr ? 1'b0 : 1'b0;
      17: return wr ? 1'b0 : 1'b0;
      18: return wr ? 1'b0 : 1'b0;
      19: return wr ? 1'b0 : 1'b0;
      20: return wr ? 1'b0 : 1'b0;
      21: return wr ? 1'b0 : 1'b0;
      22: return wr ? 1'b0 : 1'b0;
      23: return wr ? 1'b0 : 1'b0;
      24: return wr ? 1'b0 : 1'b0;
      25: return wr ? 1'b0 : 1'b0;
      26: return wr ? 1'b0 : 1'b0;
      27: return wr ? 1'b0 : 1'b0;
      28: return wr ? 1'b0 : 1'b0;
      29: return wr ? 1'b0 : 1'b0;
      30: return wr ? 1'b0 : 1'b0;
      31: return wr ? 1'b0 : 1'b0;
      32: return wr ? 1'b0 : 1'b0;
      33: return wr ? 1'b0 : 1'b0;
      34: return wr ? 1'b0 : 1'b0;
      35: return wr ? 1'b0 : 1'b0;
      36: return wr ? 1'b0 : 1'b0;
      37: return wr ? 1'b0 : 1'b0;
      38: return wr ? 1'b0 : 1'b0;
      39: return wr ? 1'b0 : 1'b0;
      40: return wr ? 1'b0 : 1'b0;
      41: return wr ? 1'b0 : 1'b0;
      42: return wr ? 1'b0 : 1'b0;
      43: return wr ? 1'b0 : 1'b0;
      44: return wr ? 1'b0 : 1'b0;
      45: return wr ? 1'b0 : 1'b0;
      46: return wr ? 1'b0 : 1'b0;
      47: return wr ? 1'b0 : 1'b0;
      48: return wr ? 1'b0 : 1'b0;
      49: return wr ? 1'b0 : 1'b0;
      50: return wr ? 1'b0 : 1'b0;
      51: return wr ? 1'b0 : 1'b0;
      52: return wr ? 1'b0 : 1'b0;
      53: return wr ? 1'b0 : 1'b0;
      54: return wr ? 1'b0 : 1'b0;
      55: return wr ? 1'b0 : 1'b0;
      56: return wr ? 1'b0 : 1'b0;
      57: return wr ? 1'b0 : 1'b0;
      58: return wr ? 1'b0 : 1'b0;
      59: return wr ? 1'b0 : 1'b0;
      60: return wr ? 1'b0 : 1'b0;
      61: return wr ? 1'b0 : 1'b0;
      62: return wr ? 1'b0 : 1'b0;
      63: return wr ? 1'b0 : 1'b0;
      64: return wr ? 1'b0 : 1'b0;
      65: return wr ? 1'b0 : 1'b0;
      66: return wr ? 1'b0 : 1'b0;
      67: return wr ? 1'b0 : 1'b0;
      68: return wr ? 1'b0 : 1'b0;
      69: return wr ? 1'b0 : 1'b0;
      70: return wr ? 1'b0 : 1'b0;
      71: return wr ? 1'b0 : 1'b0;
      72: return wr ? 1'b0 : 1'b0;
      73: return wr ? 1'b0 : 1'b0;
      74: return wr ? 1'b0 : 1'b0;
      75: return wr ? 1'b0 : 1'b0;
      76: return wr ? 1'b0 : 1'b0;
      77: return wr ? 1'b0 : 1'b0;
      78: return wr ? 1'b0 : 1'b0;
      79: return wr ? 1'b0 : 1'b0;
      80: return wr ? 1'b0 : 1'b0;
      81: return wr ? 1'b0 : 1'b0;
      82: return wr ? 1'b0 : 1'b0;
      83: return wr ? 1'b0 : 1'b0;
      84: return wr ? 1'b0 : 1'b0;
      85: return wr ? 1'b0 : 1'b0;
      86: return wr ? 1'b0 : 1'b0;
      87: return wr ? 1'b0 : 1'b0;
      88: return wr ? 1'b0 : 1'b0;
      89: return wr ? 1'b0 : 1'b0;
      90: return wr ? 1'b0 : 1'b0;
      91: return wr ? 1'b0 : 1'b0;
      92: return wr ? 1'b0 : 1'b0;
      93: return wr ? 1'b0 : 1'b0;
      94: return wr ? 1'b0 : 1'b0;
      95: return wr ? 1'b0 : 1'b0;
      96: return wr ? 1'b0 : 1'b0;
      97: return wr ? 1'b0 : 1'b0;
      98: return wr ? claim_wr[0] : claim_rd[0];
      99: return wr ? 1'b0 : 1'b0;
      100: return wr ? claim_wr[1] : claim_rd[1];
      101: return wr ? 1'b0 : 1'b0;
      102: return wr ? claim_wr[2] : claim_rd[2];
      103: return wr ? 1'b0 : 1'b0;
      104: return wr ? claim_wr[3] : claim_rd[3];
      105: return wr ? 1'b0 : 1'b0;
      106: return wr ? claim_wr[4] : claim_rd[4];
      107: return wr ? 1'b0 : 1'b0;
      108: return wr ? claim_wr[5] : claim_rd[5];
      109: return wr ? 1'b0 : 1'b0;
      110: return wr ? claim_wr[6] : claim_rd[6];
      111: return wr ? 1'b0 : 1'b0;
      112: return wr ? claim_wr[7] : claim_rd[7];
      113: return wr ? 1'b0 : 1'b0;
      114: return wr ? claim_wr[8] : claim_rd[8];
      115: return wr ? 1'b0 : 1'b0;
      116: return wr ? claim_wr[9] : claim_rd[9];
      117: return wr ? 1'b0 : 1'b0;
      118: return wr ? claim_wr[10] : claim_rd[10];
      119: return wr ? 1'b0 : 1'b0;
      120: return wr ? claim_wr[11] : claim_rd[11];
      121: return wr ? 1'b0 : 1'b0;
      122: return wr ? claim_wr[12] : claim_rd[12];
      123: return wr ? 1'b0 : 1'b0;
      124: return wr ? claim_wr[13] : claim_rd[13];
      125: return wr ? 1'b0 : 1'b0;
      126: return wr ? claim_wr[14] : claim_rd[14];
      127: return wr ? 1'b0 : 1'b0;
      128: return wr ? claim_wr[15] : claim_rd[15];
      default: return 1'b0;
    endcase
  endfunction

  // register an access selects at addr, or -1; err: no block word there
  function automatic int reg_at(logic [AW-1:0] addr, bit wr, output bit err);
    int word;
    word = int'(addr) & ~(NL - 1);
    err = 1'b1;
    for (int b = 0; b < NBLK; b++)
      if (word >= BLK_BASE[b] && word < BLK_BASE[b] + BLK_SIZE[b])
        err = (word - BLK_BASE[b]) / NL >= BLK_WORDS[b];
    for (int i = 0; i < NREG; i++)
      if (int'(OFFS[i]) == word && DIR[i] != (wr ? 1 : 2)
          && (BANK_IDX[i] < 0 || (model[BANK_IDX[i]] & BANK_MASK[i]) == BANK_VAL[i])) return i;
    return -1;
  endfunction

  function automatic logic [DW-1:0] rnd_dw();
    logic [DW-1:0] d;
    for (int k = 0; k < DW; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  function automatic logic [DW-1:0] strb_mask(logic [NL-1:0] s);
    logic [DW-1:0] mk;
    for (int k = 0; k < NL; k++) mk[k*8 +: 8] = {8{s[k]}};
    return mk;
  endfunction

  int cyc, ri, phase;   // phase 0 idle, 1 SETUP, 2 ACCESS
  bit err;
  logic [DW-1:0] exp_rd;

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    for (int i = 0; i < NREG; i++) begin ro_val[i] = '0; set_rq[i] = '0; model[i] = RST[i]; end
    drive_hw();
    tb_reset();
    for (int i = 0; i < NREG; i++) `CHECK(q_of(i) == RST[i], "reset value")
    phase = 0;
    for (cyc = 0; cyc < N_CYC; cyc++) begin
      // drive after the falling edge
      for (int i = 0; i < NREG; i++) begin
        ro_val[i] = rnd_dw() & RO_DRV[i];
        set_rq[i] = ($urandom % 8 == 0) ? rnd_dw() & W1C_DRV[i] : '0;
      end
      drive_hw();
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 2;
        PADDR = ($urandom % 5 != 0) ? OFFS[$urandom % NREG] | AW'($urandom % NL) : AW'($urandom);
        PWDATA = rnd_dw();
        PSTRB = ($urandom % 2) ? '1 : NL'($urandom);
        if (!PWRITE) PSTRB = '0;
      end else begin
        PWRITE = $urandom % 2; PADDR = AW'($urandom); PWDATA = rnd_dw(); PSTRB = NL'($urandom);
      end
      #1;
      // combinational checks before the rising edge
      ri = reg_at(PADDR, PWRITE, err);
      `CHECK(PREADY, "PREADY high")
      for (int i = 0; i < NREG; i++) `CHECK(wo_of(i) == (PWDATA & WO[i]), "write-only field outputs")
      for (int i = 0; i < NREG; i++) begin
        `CHECK(pulse_of(i, 1'b1) == (HAS_WR[i] && phase == 2 && PWRITE && ri == i), "write pulse")
        `CHECK(pulse_of(i, 1'b0) == (HAS_RD[i] && phase == 2 && !PWRITE && ri == i), "read pulse")
      end
      if (phase == 2) begin
        `CHECK(PSLVERR == err, "PSLVERR")
        if (!PWRITE && !err) begin
          exp_rd = (ri >= 0) ? (model[ri] | (ro_val[ri] & RO[ri])) : '0;
          `CHECK(PRDATA == exp_rd, "read data")
        end
      end
      @(posedge clk);
      // model update at the edge: a write, then w1c sets (set wins)
      if (phase == 2 && PWRITE && ri >= 0) begin
        model[ri] = (model[ri] & ~(RW[ri] & strb_mask(PSTRB))) | (PWDATA & RW[ri] & strb_mask(PSTRB));
        model[ri] = model[ri] & ~(PWDATA & W1C[ri] & strb_mask(PSTRB));
      end
      for (int i = 0; i < NREG; i++) model[i] |= set_rq[i] & W1C[i];
      @(negedge clk);
      for (int i = 0; i < NREG; i++) `CHECK(q_of(i) == model[i], "field outputs")
    end
    tb_pass();
  end
endmodule
