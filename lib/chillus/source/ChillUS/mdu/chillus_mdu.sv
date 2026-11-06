// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_mdu
//
// Multiply / divide unit for the M extension (riscv-unprivileged.pdf,
// Chapter 13). Stage-agnostic: it works on the instruction presented on its
// inputs (first top: ex) and asks the pipeline to hold that stage (busy)
// until the result is ready.
//
// MUL on BaseChiliSV basechili_mul_lo (low half only, about half the
// array, one cycle); MULH, MULHSU, MULHU on the shared iterative unit u_iter
// (below): CoreMark's timed code uses MUL only.
// Late MUL: a MUL does not hold the stage. Its operands enter
// basechili_mul_lo when it leaves (in_valid && !stall), and its product
// (late_result) is valid in the next stage in the following cycle (the
// multiplier's stage registers are the stage boundary). late flags such a
// MUL: the pipeline takes late_result one stage later and treats it like a
// load (a consumer right behind it waits one cycle).
// Signs: MULH both signed; MULHSU rs1 signed; MULHU and MUL unsigned (the
// low half does not depend on the signs).
// Iterative operations (divide, MULH*) share BaseChiliSV
// basechili_muldiv_iter (u_iter: one adder, one bit per cycle, XLEN steps)
// on operand magnitudes, and one negator on the registered result:
//   quotient = sign(rs1) ^ sign(rs2) and rs2 != 0 ? -q : q
//   remainder= sign(rs1) ? -r : r                 (sign of the dividend)
//   MULH*    = sign(rs1) ^ sign(rs2) ? high half of -(|rs1| * |rs2|) : high
//              half; -P's high half = ~P_hi + (P_lo == 0)
// The special cases follow without extra logic: x / 0 gives q = all ones
// (basechili_muldiv_iter), so DIV = -1, DIVU = 2^XLEN - 1, REM[U] = rs1; the
// overflow -2^(XLEN-1) / -1 gives q = 2^(XLEN-1), not negated =
// -2^(XLEN-1), r = 0; a zero product is never negated (rs2 = 0) or negates
// to 0.
//
//   S_IDLE : an M instruction is presented (in_valid, md_op != NONE):
//            MUL -> stays in S_IDLE (late, no busy; see above)
//            divide or MULH* -> start u_iter on |rs1|, |rs2|      -> S_CALC
//   S_CALC : wait for u_iter; in its first idle cycle apply the sign and
//            register the result                              -> S_DONE
//   S_DONE : result valid, busy low; the instruction leaves the stage
//            (in_valid && !stall)                             -> S_IDLE
//   Any state: in_valid low (the instruction was killed)      -> S_IDLE
//
// A killed divide / MULH* leaves u_iter running; the next start restarts
// it.
//
// Timing   : busy is combinational from in_valid, md_op and the state (not
//            from stall). MUL: never busy; late_result is combinational
//            from u_mul's stage registers, valid the cycle after it left
//            (until the next MUL leaves). Divide and MULH*: busy XLEN + 2
//            cycles, result from a register (u_iter_result).
// Invariants
//   state != S_IDLE -> the stage held an M instruction in the previous
//   cycle (in_valid was high); in a kill cycle (an older bus fault, or an
//   interrupt taken on it) in_valid is already low and the state returns to
//   S_IDLE at the next edge.
//   late -> state == S_IDLE and !busy.
// Debug    : state (enum) and op_q show the operation; MUL: u_mul's stage
//            (late_result); divide / MULH*: u_iter.step_cnt, hi / lo; wrong
//            sign -> neg_res_q / rem_neg_q.
// -----------------------------------------------------------------------------
module chillus_mdu
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                        // register width (32: basechili_mul_lo is 32 x 32)
) (
  input  logic            clk,
  input  logic            rst_n,                 // async, active-low
  input  logic            test_en,               // scan / test: library clock gates (none built: CLOCK_GATE 0)
  input  logic            stall,                 // this stage holds its instruction
  // instruction in this stage
  input  logic            in_valid,              // real instruction; 0 when killed or a bubble
  input  md_op_e          md_op,
  input  logic [XLEN-1:0] rs1_data,              // after forwarding
  input  logic [XLEN-1:0] rs2_data,              // after forwarding
  // to the pipeline
  output logic            busy,                  // hold the stage: result not ready
  output logic [XLEN-1:0] result,                // valid when !busy for an M instruction other than MUL
  output logic            late,                  // MUL presented: its result is late_result, one stage later
  output logic [XLEN-1:0] late_result            // product of the last MUL that left the stage
);

  typedef enum logic [1:0] {
    S_IDLE = 2'd0,
    S_CALC = 2'd1,
    S_DONE = 2'd2
  } state_e;

  localparam int OP_W = $bits(md_op_e);

  // decode of the presented operation
  logic             is_md;          // md_op != NONE
  logic             is_mul;         // MUL, MULH, MULHSU, MULHU
  logic             start_div_op;   // u_iter operation: 1 divide, 0 multiply (MULH*)
  logic             late_leave;     // a MUL leaves the stage: start u_mul
  logic             rs1_signed;
  logic             rs2_signed;
  logic             rs1_neg;        // signed operand with its sign bit set
  logic             rs2_neg;
  logic [XLEN-1:0]  rs1_mag;        // |rs1| (as unsigned)
  logic [XLEN-1:0]  rs2_mag;

  // state
  logic [1:0]       state_q;
  logic [1:0]       state_d;
  state_e           state;          // enum view of state_q
  state_e           state_nx;
  logic             start;          // start u_iter this cycle (divide, MULH*)
  logic             leave;          // the instruction leaves the stage
  logic             calc_done;      // u_iter finished (in S_CALC)

  // operation latched at start
  logic [OP_W-1:0]  op_q;
  md_op_e           op;             // enum view of op_q
  logic             op_mulh;        // op is MULH, MULHSU or MULHU
  logic             op_rem;         // op is REM or REMU
  logic             neg_res_q;      // negate the quotient / MULH* result
  logic             neg_res_d;
  logic             rem_neg_q;      // negate the remainder (dividend sign)

  // iterative unit: divide, MULH*
  logic             iter_busy;
  logic [2*XLEN-1:0] iter_product;  // |rs1| * |rs2|
  logic [XLEN-1:0]  quotient;       // |rs1| / |rs2|
  logic [XLEN-1:0]  remainder;      // |rs1| % |rs2|
  logic [XLEN-1:0]  iter_raw;       // unsigned result: MULH* high half, remainder or quotient
  logic             iter_neg;       // negate iter_raw
  logic             iter_inc;       // + 1 of the negation (MULH*: low half is zero)
  logic [XLEN-1:0]  iter_result_d;

  // ---------------------------------------------------------------------------
  // operation decode
  // ---------------------------------------------------------------------------
  assign is_md      = (md_op != MD_OP_NONE);
  assign is_mul     = (md_op == MD_OP_MUL)  || (md_op == MD_OP_MULH) ||
                      (md_op == MD_OP_MULHSU) || (md_op == MD_OP_MULHU);
  assign start_div_op = !is_mul;
  assign late       = in_valid && (md_op == MD_OP_MUL);
  assign late_leave = late && !stall;
  assign rs1_signed = (md_op == MD_OP_MULH) || (md_op == MD_OP_MULHSU) ||
                      (md_op == MD_OP_DIV)  || (md_op == MD_OP_REM);
  assign rs2_signed = (md_op == MD_OP_MULH) || (md_op == MD_OP_DIV) ||
                      (md_op == MD_OP_REM);
  assign rs1_neg    = rs1_signed && rs1_data[XLEN-1];
  assign rs2_neg    = rs2_signed && rs2_data[XLEN-1];
  assign rs1_mag    = rs1_neg ? (~rs1_data + 1'b1) : rs1_data;
  assign rs2_mag    = rs2_neg ? (~rs2_data + 1'b1) : rs2_data;

  // quotient / MULH* sign: a division by zero keeps q = all ones (= -1); a
  // product with rs2 = 0 is 0
  assign neg_res_d  = (rs1_neg ^ rs2_neg) && (rs2_data != '0);

  // ---------------------------------------------------------------------------
  // state
  // ---------------------------------------------------------------------------
  assign state     = state_e'(state_q);
  assign leave     = in_valid && !stall;
  assign calc_done = (state == S_CALC) && !iter_busy;
  assign start     = (state == S_IDLE) && in_valid && is_md && !late;

  always_comb begin
    state_nx = state;
    if (!in_valid) begin
      state_nx = S_IDLE;
    end else begin
      case (state)
        S_IDLE:  if (start)     state_nx = S_CALC;
        S_CALC:  if (calc_done) state_nx = S_DONE;
        S_DONE:  if (leave)     state_nx = S_IDLE;
        default:                state_nx = S_IDLE;
      endcase
    end
  end
  assign state_d = state_nx;

  assign busy = in_valid && is_md && !late && (state != S_DONE);

  basechili_dff #(.WIDTH(2)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  basechili_dffe #(.WIDTH(OP_W)) u_op (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (md_op),
    .q     (op_q)
  );
  assign op      = md_op_e'(op_q);
  assign op_mulh = (op == MD_OP_MULH) || (op == MD_OP_MULHSU) || (op == MD_OP_MULHU);
  assign op_rem  = (op == MD_OP_REM) || (op == MD_OP_REMU);

  basechili_dffe #(.WIDTH(1)) u_neg_res (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (neg_res_d),
    .q     (neg_res_q)
  );

  basechili_dffe #(.WIDTH(1)) u_rem_neg (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (rs1_neg),
    .q     (rem_neg_q)
  );

  // ---------------------------------------------------------------------------
  // MUL: low half, one cycle, started when the MUL leaves the stage
  // ---------------------------------------------------------------------------
  basechili_mul_lo #(.LATENCY(1)) u_mul (
    .clk       (clk),
    .rst_n     (rst_n),
    .test_en   (test_en),
    .in_valid  (late_leave),
    .a         (rs1_data),
    .b         (rs2_data),
    .out_valid (),
    .product   (late_result)
  );

  // ---------------------------------------------------------------------------
  // iterative: divide and MULH* on magnitudes; sign applied once, registered
  // ---------------------------------------------------------------------------
  basechili_muldiv_iter #(.WIDTH(XLEN)) u_iter (
    .clk       (clk),
    .rst_n     (rst_n),
    .test_en   (test_en),
    .start     (start),
    .div       (start_div_op),
    .a         (rs1_mag),
    .b         (rs2_mag),
    .busy      (iter_busy),
    .product   (iter_product),
    .quotient  (quotient),
    .remainder (remainder)
  );

  assign iter_raw      = op_mulh ? iter_product[2*XLEN-1:XLEN] : op_rem ? remainder : quotient;
  assign iter_neg      = op_rem ? rem_neg_q : neg_res_q;
  assign iter_inc      = !op_mulh || (iter_product[XLEN-1:0] == '0);
  assign iter_result_d = iter_neg ? (~iter_raw + XLEN'(iter_inc)) : iter_raw;

  basechili_dffe #(.WIDTH(XLEN)) u_iter_result (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (calc_done),
    .d     (iter_result_d),
    .q     (result)
  );

endmodule
