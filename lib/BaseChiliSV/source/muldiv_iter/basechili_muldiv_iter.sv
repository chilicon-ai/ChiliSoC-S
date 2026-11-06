// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_muldiv_iter
//
// Iterative unsigned multiplier / divider sharing one adder and one set of
// registers: one bit per cycle, WIDTH cycles, for small cores that rarely
// multiply into the high half or divide (e.g. RISC-V MULH* and DIV / REM
// next to a fast low-half MUL). Signs are the caller's (operate on
// magnitudes, negate the result).
//
//   start : load a and b, latch div, begin (also restarts a running op).
//   multiply (div = 0), shift-add, lo starts as b:
//           sum = {1'b0, hi} + (lo[0] ? opnd : 0)
//           {hi, lo} = {sum, lo[WIDTH-1:1]}       (shift right by one)
//           after WIDTH steps {hi, lo} = a * b
//   divide (div = 1), restoring, lo starts as a (the dividend):
//           trial = {hi, lo[WIDTH-1]}             (next dividend bit)
//           ge    = trial >= opnd                 (carry of trial - opnd)
//           hi    = ge ? trial - opnd : trial;  lo = {lo << 1, ge}
//           after WIDTH steps lo = a / b, hi = a % b
//   One WIDTH+1-bit adder serves both: x + y + cin with
//   x = div ? trial : {0, hi}, y = div ? ~{0, opnd} : {0, addend}, cin = div.
//
// Division by zero needs no special case: every trial is >= 0, so quotient
// = all ones and remainder = a (the RISC-V M results for DIVU / REMU).
//
// CLOCK_GATE = 1 stores opnd / hi / lo in basechili_dffe_cg registers (no
// enable mux per bit; idle cycles draw no clock power there).
//
// Timing   : busy is high for the WIDTH cycles after the start edge; the
//            outputs (registers) are valid when busy falls and held until
//            the next start. The step path is opnd / hi / lo -> mux ->
//            WIDTH+1-bit adder -> mux -> hi / lo.
// Invariant: busy == (step_cnt != 0).
//            op_div && opnd != 0 -> hi < opnd after every step.
// Debug    : wrong result -> op_div, opnd, hi / lo and step_cnt per step;
//            divide: ge (sum[WIDTH+1]) is the quotient bit shifted in.
// -----------------------------------------------------------------------------
module basechili_muldiv_iter #(
  parameter  int WIDTH = 32,                       // operand width in bits
  parameter  bit CLOCK_GATE = 1'b0,                // 1: operand / hi / lo are clock-gated registers
  localparam int CNT_W = $clog2(WIDTH + 1)         // step counter width
) (
  input  logic               clk,
  input  logic               rst_n,                // async, active-low
  input  logic               test_en,              // scan / test: open the clock gates (CLOCK_GATE)
  input  logic               start,                // load operands, begin
  input  logic               div,                  // with start: 1 divide, 0 multiply
  input  logic [WIDTH-1:0]   a,                    // multiplicand / dividend
  input  logic [WIDTH-1:0]   b,                    // multiplier / divisor
  output logic               busy,                 // steps remaining
  output logic [2*WIDTH-1:0] product,              // a * b (multiply)
  output logic [WIDTH-1:0]   quotient,             // a / b (divide)
  output logic [WIDTH-1:0]   remainder             // a % b (divide)
);

  localparam logic [CNT_W-1:0] STEPS = CNT_W'(WIDTH);

  logic             op_div;         // the running operation is a divide
  logic [WIDTH-1:0] opnd;           // multiplicand (a) or divisor (b), held
  logic [WIDTH-1:0] opnd_d;
  logic [WIDTH-1:0] hi;             // product high half / partial remainder
  logic [WIDTH-1:0] lo;             // multiplier bits, product low half / dividend bits, quotient
  logic [WIDTH-1:0] hi_d;
  logic [WIDTH-1:0] lo_d;
  logic             step_en;        // start or a step
  logic [WIDTH:0]   trial;          // divide: {hi, next dividend bit}
  logic [WIDTH-1:0] addend;         // multiply: lo[0] ? opnd : 0
  logic [WIDTH:0]   add_x;          // adder operands
  logic [WIDTH:0]   add_y;
  logic [WIDTH+1:0] sum;            // add_x + add_y + op_div; [WIDTH+1] = carry
  logic             ge;             // divide: trial >= opnd (no borrow)
  logic [CNT_W-1:0] step_cnt;       // steps remaining

  assign busy   = (step_cnt != '0);
  assign trial  = {hi, lo[WIDTH-1]};
  assign addend = lo[0] ? opnd : '0;
  assign add_x  = op_div ? trial : {1'b0, hi};
  assign add_y  = op_div ? ~{1'b0, opnd} : {1'b0, addend};
  assign sum    = {1'b0, add_x} + {1'b0, add_y} + {{(WIDTH+1){1'b0}}, op_div};
  assign ge     = sum[WIDTH+1];

  always_comb begin
    if (start) begin
      hi_d = '0;
      lo_d = div ? a : b;
    end else if (op_div) begin
      hi_d = ge ? sum[WIDTH-1:0] : trial[WIDTH-1:0];
      lo_d = {lo[WIDTH-2:0], ge};
    end else begin
      hi_d = sum[WIDTH:1];
      lo_d = {sum[0], lo[WIDTH-1:1]};
    end
  end

  assign opnd_d  = div ? b : a;
  assign step_en = start || busy;

  basechili_dffe #(.WIDTH(1)) u_op_div (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (div),
    .q     (op_div)
  );

  basechili_dffe_cg #(.WIDTH(WIDTH), .GATE(CLOCK_GATE)) u_opnd (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .en      (start),
    .d       (opnd_d),
    .q       (opnd)
  );

  basechili_dffe_cg #(.WIDTH(WIDTH), .GATE(CLOCK_GATE)) u_hi (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .en      (step_en),
    .d       (hi_d),
    .q       (hi)
  );

  basechili_dffe_cg #(.WIDTH(WIDTH), .GATE(CLOCK_GATE)) u_lo (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .en      (step_en),
    .d       (lo_d),
    .q       (lo)
  );

  basechili_updown_counter #(.WIDTH(CNT_W)) u_step_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (start),
    .load_val (STEPS),
    .inc      (1'b0),
    .dec      (busy),
    .count    (step_cnt),
    .count_d  ()
  );

  assign product   = {hi, lo};
  assign quotient  = lo;
  assign remainder = hi;

endmodule
