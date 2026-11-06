// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_muldiv_iter_chk (bound into every basechili_muldiv_iter)
//   - busy == (step_cnt != 0); step_cnt <= WIDTH          (header Invariant)
//   - divide, opnd != 0 -> hi < opnd after every step      (header Invariant)
//   - busy for exactly WIDTH cycles after a start          (header Timing)
//   - when busy falls: product == a * b (multiply), quotient == a / b and
//     remainder == a % b (divide; b == 0: all ones and a) of the last start
// -----------------------------------------------------------------------------
module basechili_muldiv_iter_chk #(
  parameter int WIDTH = 32,
  parameter int CNT_W = 6
) (
  input logic               clk,
  input logic               rst_n,
  input logic               start,
  input logic               div,
  input logic [WIDTH-1:0]   a,
  input logic [WIDTH-1:0]   b,
  input logic               busy,
  input logic [2*WIDTH-1:0] product,
  input logic [WIDTH-1:0]   quotient,
  input logic [WIDTH-1:0]   remainder,
  input logic               op_div,
  input logic [WIDTH-1:0]   opnd,
  input logic [WIDTH-1:0]   hi,
  input logic [CNT_W-1:0]   step_cnt
);

  logic [WIDTH-1:0] a_q, b_q;     // operands of the last start
  logic             div_q;        // operation of the last start
  int unsigned      busy_cnt;     // busy cycles since the last start
  logic             started;      // a start was seen since reset

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_q      <= '0;
      b_q      <= '0;
      div_q    <= 1'b0;
      busy_cnt <= 0;
      started  <= 1'b0;
    end else if (start) begin
      a_q      <= a;
      b_q      <= b;
      div_q    <= div;
      busy_cnt <= 0;
      started  <= 1'b1;
    end else if (busy) begin
      busy_cnt <= busy_cnt + 1;
    end
  end

  assert property (@(posedge clk) disable iff (!rst_n) busy == (step_cnt != '0))
    else $error("basechili_muldiv_iter: busy == (step_cnt != 0) violated: busy=%b step_cnt=%0d", busy, step_cnt);

  assert property (@(posedge clk) disable iff (!rst_n) 32'(step_cnt) <= WIDTH)
    else $error("basechili_muldiv_iter: step_cnt <= WIDTH violated: step_cnt=%0d", step_cnt);

  assert property (@(posedge clk) disable iff (!rst_n) op_div && opnd != '0 |-> hi < opnd)
    else $error("basechili_muldiv_iter: divide, hi < opnd violated: hi=%h opnd=%h", hi, opnd);

  assert property (@(posedge clk) disable iff (!rst_n)
                   $fell(busy) && started && !$past(start) |-> busy_cnt == WIDTH)
    else $error("basechili_muldiv_iter: busy for WIDTH cycles violated: busy_cnt=%0d WIDTH=%0d", busy_cnt, WIDTH);

  assert property (@(posedge clk) disable iff (!rst_n)
                   $fell(busy) && started && !$past(start) && !div_q |->
                   product == (2*WIDTH)'(a_q) * (2*WIDTH)'(b_q))
    else $error("basechili_muldiv_iter: product violated: a=%h b=%h product=%h", a_q, b_q, product);

  assert property (@(posedge clk) disable iff (!rst_n)
                   $fell(busy) && started && !$past(start) && div_q |->
                   (b_q == '0) ? (quotient == '1 && remainder == a_q)
                               : (quotient == a_q / b_q && remainder == a_q % b_q))
    else $error("basechili_muldiv_iter: divide violated: a=%h b=%h quotient=%h remainder=%h",
                a_q, b_q, quotient, remainder);

endmodule

bind basechili_muldiv_iter basechili_muldiv_iter_chk #(.WIDTH(WIDTH), .CNT_W(CNT_W)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .start     (start),
  .div       (div),
  .a         (a),
  .b         (b),
  .busy      (busy),
  .product   (product),
  .quotient  (quotient),
  .remainder (remainder),
  .op_div    (op_div),
  .opnd      (opnd),
  .hi        (hi),
  .step_cnt  (step_cnt)
);
