// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// BaseChiliSV :: basechili_mul_lo
//
// Pipelined 32x32 multiplier, low half: product = a * b mod 2^32 (the low 32
// bits, the same for signed and unsigned operands, e.g. RISC-V MUL). Only the
// partial-product dots below column 32 are built, about half of the full
// array. Fully pipelined: a new operation may enter every cycle; results leave
// in order, LATENCY clock edges after in_valid.
//
// Datapath (points in order; a pipeline cut registers the bits live at a point)
//   op -> enc: b radix-4 Booth encoded (one / two / neg per group of
//   b[2i+1:2i-1], 16 groups). The operand signs and the top group only reach
//   columns >= 32, so they are not built.
//   enc -> pp: 16 partial-product rows, pp_i[j] = one_i & (A[j] ^ neg_i) |
//   two_i & (A[j-1] ^ neg_i), neg_i cleared for the digit -0; a negative digit
//   is the one's complement of the row plus neg_i at column 2i; row i is cut
//   at column 31 (its sign bit and the sign-extension constant lie above).
//   pp -> tree1..tree6: Dadda reduction (full / half adders) to two rows;
//   target heights 13, 9, 6, 4, 3, 2; earliest-arriving dots enter the
//   counters first.
//   pg -> pfx1..pfx5 -> sum: Kogge-Stone parallel-prefix adder over the two
//   rows; product[c] = p[c] ^ G[c-1].
//
//   point   bits   max column height
//   op        64
//   enc       80
//   pp       288   17
//   tree1    272   13
//   tree2    224   9
//   tree3    167   6
//   tree4    119   4
//   tree5     92   3
//   tree6     63   2
//   pg        62
//   pfx1      92
//   pfx2      90
//   pfx3      86
//   pfx4      78
//   pfx5      63
//   sum       32
//
//   Dadda level: full adders, half adders
//   tree1:  12 FA,  8 HA
//   tree2:  44 FA,  8 HA
//   tree3:  54 FA,  6 HA
//   tree4:  46 FA,  4 HA
//   tree5:  26 FA,  2 HA
//   tree6:  28 FA,  2 HA
//
// Timing (stage k = logic before the u_stg<k>_* registers)
// Every output is driven by a register or by logic after the last stage
// registers; nothing is combinational from the inputs. out_valid is a register
// (u_stg<LATENCY>_valid).
//   LATENCY 1:
//     stage 1: enc..tree4      -> u_stg1_tree4 (119 bits)
//     product: tree5..sum      combinational from the stage 1 registers
//   LATENCY 2:
//     stage 1: enc..pp         -> u_stg1_pp (288 bits)
//     stage 2: tree1..tree6    -> u_stg2_tree6 (63 bits)
//     product: pg..sum         combinational from the stage 2 registers
//
// Invariants
//   vld[k] (k >= 1, u_stg<k>_valid) is in_valid delayed by k edges; out_valid
//   = vld[LATENCY]. The stage k registers load only when vld[k-1] is high, so
//   product holds after the last result.
//   At every point from pp to tree6, sum over the dots of 2^column (plus the
//   constant 1'b1 dots in the assigns) equals the product mod 2^32.
//   After reset, before the first result, product is the constant the datapath
//   gives for all-zero stage registers (out_valid is 0).
//
// Debug
//   Wrong product: find the first point whose dots no longer sum to a * b (the
//   assign comments name each bit: pp<i>[j], c<col> fa.s / fa.c / ha.s / ha.c,
//   g / p / G / P <col>). Booth digit i: enc bits one<i> / two<i> / neg =
//   b[2i+1].
//   Missing or extra out_valid: vld[*] and the u_stg<k>_valid flops. Result of
//   a wrong operation: the stage enables (en = vld[k-1]).
// -----------------------------------------------------------------------------
module basechili_mul_lo #(
  parameter int LATENCY = 1,  // 1, 2: clock edges from in_valid to out_valid
  parameter bit CLOCK_GATE = 1'b0  // 1: stage registers are clock-gated (basechili_dffe_cg)
) (
  input  logic        clk,
  input  logic        rst_n,                // async, active-low
  input  logic        test_en,              // scan / test: open the stage clock gates (CLOCK_GATE)
  input  logic        in_valid,             // operands are used in this cycle
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic        out_valid,            // one-cycle pulse LATENCY edges after in_valid
  output logic [31:0] product               // a * b mod 2^32; holds until the next result
);

  logic [LATENCY:0] vld;  // vld[k]: stage k took an operation at the last edge; vld[0] = in_valid
  logic [63:0] op;  // bits live after operands
  logic [79:0] enc;  // bits live after Booth encode
  logic [287:0] pp_d;  // bits live after partial products
  logic [287:0] pp;  // pp_d, registered when a stage ends here
  logic [271:0] tree1;  // bits live after Dadda level 1
  logic [223:0] tree2;  // bits live after Dadda level 2
  logic [166:0] tree3;  // bits live after Dadda level 3
  logic [118:0] tree4_d;  // bits live after Dadda level 4
  logic [118:0] tree4;  // tree4_d, registered when a stage ends here
  logic [91:0] tree5;  // bits live after Dadda level 5
  logic [62:0] tree6_d;  // bits live after Dadda level 6
  logic [62:0] tree6;  // tree6_d, registered when a stage ends here
  logic [61:0] pg;  // bits live after generate / propagate
  logic [91:0] pfx1;  // bits live after prefix level 1
  logic [89:0] pfx2;  // bits live after prefix level 2
  logic [85:0] pfx3;  // bits live after prefix level 3
  logic [77:0] pfx4;  // bits live after prefix level 4
  logic [62:0] pfx5;  // bits live after prefix level 5
  logic [31:0] sum;  // bits live after sum XOR

  // ---- valid pipeline --------------------------------------------------------
  assign vld[0] = in_valid;
  if (LATENCY == 1) begin : g_vld_l1
    basechili_dff u_stg1_valid (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (vld[0]),
      .q     (vld[1])
    );
  end else if (LATENCY == 2) begin : g_vld_l2
    basechili_dff u_stg1_valid (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (vld[0]),
      .q     (vld[1])
    );
    basechili_dff u_stg2_valid (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (vld[1]),
      .q     (vld[2])
    );
  end
  assign out_valid = vld[LATENCY];

  // ---- op: operands --------------------------------------------------------
  assign op[31:0] = a[31:0];  // a[0]..a[31]
  assign op[63:32] = b[31:0];  // b[0]..b[31]

  // ---- enc: Booth encode ---------------------------------------------------
  assign enc[33:0] = op[33:0];  // a[0]..b[1]
  assign enc[34] = op[33] & ~op[32];  // two0
  assign enc[35] = op[34] ^ op[33];  // one1
  assign enc[36] = (op[35] & ~op[34] & ~op[33]) | (~op[35] & op[34] & op[33]);  // two1
  assign enc[37] = op[35] & ~(op[34] & op[33]);  // neg1
  assign enc[38] = op[36] ^ op[35];  // one2
  assign enc[39] = (op[37] & ~op[36] & ~op[35]) | (~op[37] & op[36] & op[35]);  // two2
  assign enc[40] = op[37] & ~(op[36] & op[35]);  // neg2
  assign enc[41] = op[38] ^ op[37];  // one3
  assign enc[42] = (op[39] & ~op[38] & ~op[37]) | (~op[39] & op[38] & op[37]);  // two3
  assign enc[43] = op[39] & ~(op[38] & op[37]);  // neg3
  assign enc[44] = op[40] ^ op[39];  // one4
  assign enc[45] = (op[41] & ~op[40] & ~op[39]) | (~op[41] & op[40] & op[39]);  // two4
  assign enc[46] = op[41] & ~(op[40] & op[39]);  // neg4
  assign enc[47] = op[42] ^ op[41];  // one5
  assign enc[48] = (op[43] & ~op[42] & ~op[41]) | (~op[43] & op[42] & op[41]);  // two5
  assign enc[49] = op[43] & ~(op[42] & op[41]);  // neg5
  assign enc[50] = op[44] ^ op[43];  // one6
  assign enc[51] = (op[45] & ~op[44] & ~op[43]) | (~op[45] & op[44] & op[43]);  // two6
  assign enc[52] = op[45] & ~(op[44] & op[43]);  // neg6
  assign enc[53] = op[46] ^ op[45];  // one7
  assign enc[54] = (op[47] & ~op[46] & ~op[45]) | (~op[47] & op[46] & op[45]);  // two7
  assign enc[55] = op[47] & ~(op[46] & op[45]);  // neg7
  assign enc[56] = op[48] ^ op[47];  // one8
  assign enc[57] = (op[49] & ~op[48] & ~op[47]) | (~op[49] & op[48] & op[47]);  // two8
  assign enc[58] = op[49] & ~(op[48] & op[47]);  // neg8
  assign enc[59] = op[50] ^ op[49];  // one9
  assign enc[60] = (op[51] & ~op[50] & ~op[49]) | (~op[51] & op[50] & op[49]);  // two9
  assign enc[61] = op[51] & ~(op[50] & op[49]);  // neg9
  assign enc[62] = op[52] ^ op[51];  // one10
  assign enc[63] = (op[53] & ~op[52] & ~op[51]) | (~op[53] & op[52] & op[51]);  // two10
  assign enc[64] = op[53] & ~(op[52] & op[51]);  // neg10
  assign enc[65] = op[54] ^ op[53];  // one11
  assign enc[66] = (op[55] & ~op[54] & ~op[53]) | (~op[55] & op[54] & op[53]);  // two11
  assign enc[67] = op[55] & ~(op[54] & op[53]);  // neg11
  assign enc[68] = op[56] ^ op[55];  // one12
  assign enc[69] = (op[57] & ~op[56] & ~op[55]) | (~op[57] & op[56] & op[55]);  // two12
  assign enc[70] = op[57] & ~(op[56] & op[55]);  // neg12
  assign enc[71] = op[58] ^ op[57];  // one13
  assign enc[72] = (op[59] & ~op[58] & ~op[57]) | (~op[59] & op[58] & op[57]);  // two13
  assign enc[73] = op[59] & ~(op[58] & op[57]);  // neg13
  assign enc[74] = op[60] ^ op[59];  // one14
  assign enc[75] = (op[61] & ~op[60] & ~op[59]) | (~op[61] & op[60] & op[59]);  // two14
  assign enc[76] = op[61] & ~(op[60] & op[59]);  // neg14
  assign enc[77] = op[62] ^ op[61];  // one15
  assign enc[78] = (op[63] & ~op[62] & ~op[61]) | (~op[63] & op[62] & op[61]);  // two15
  assign enc[79] = op[63] & ~(op[62] & op[61]);  // neg15

  // ---- pp: partial products ------------------------------------------------
  assign pp_d[0] = enc[33];  // c0 b[1]
  assign pp_d[1] = (enc[32] & (enc[0] ^ enc[33])) | (enc[34] & enc[33]);  // pp0[0]
  assign pp_d[2] = (enc[32] & (enc[1] ^ enc[33])) | (enc[34] & (enc[0] ^ enc[33]));  // pp0[1]
  assign pp_d[3] = enc[37];  // c2 neg1
  assign pp_d[4] = (enc[32] & (enc[2] ^ enc[33])) | (enc[34] & (enc[1] ^ enc[33]));  // pp0[2]
  assign pp_d[5] = (enc[35] & (enc[0] ^ enc[37])) | (enc[36] & enc[37]);  // pp1[0]
  assign pp_d[6] = (enc[32] & (enc[3] ^ enc[33])) | (enc[34] & (enc[2] ^ enc[33]));  // pp0[3]
  assign pp_d[7] = (enc[35] & (enc[1] ^ enc[37])) | (enc[36] & (enc[0] ^ enc[37]));  // pp1[1]
  assign pp_d[8] = enc[40];  // c4 neg2
  assign pp_d[9] = (enc[32] & (enc[4] ^ enc[33])) | (enc[34] & (enc[3] ^ enc[33]));  // pp0[4]
  assign pp_d[10] = (enc[35] & (enc[2] ^ enc[37])) | (enc[36] & (enc[1] ^ enc[37]));  // pp1[2]
  assign pp_d[11] = (enc[38] & (enc[0] ^ enc[40])) | (enc[39] & enc[40]);  // pp2[0]
  assign pp_d[12] = (enc[32] & (enc[5] ^ enc[33])) | (enc[34] & (enc[4] ^ enc[33]));  // pp0[5]
  assign pp_d[13] = (enc[35] & (enc[3] ^ enc[37])) | (enc[36] & (enc[2] ^ enc[37]));  // pp1[3]
  assign pp_d[14] = (enc[38] & (enc[1] ^ enc[40])) | (enc[39] & (enc[0] ^ enc[40]));  // pp2[1]
  assign pp_d[15] = enc[43];  // c6 neg3
  assign pp_d[16] = (enc[32] & (enc[6] ^ enc[33])) | (enc[34] & (enc[5] ^ enc[33]));  // pp0[6]
  assign pp_d[17] = (enc[35] & (enc[4] ^ enc[37])) | (enc[36] & (enc[3] ^ enc[37]));  // pp1[4]
  assign pp_d[18] = (enc[38] & (enc[2] ^ enc[40])) | (enc[39] & (enc[1] ^ enc[40]));  // pp2[2]
  assign pp_d[19] = (enc[41] & (enc[0] ^ enc[43])) | (enc[42] & enc[43]);  // pp3[0]
  assign pp_d[20] = (enc[32] & (enc[7] ^ enc[33])) | (enc[34] & (enc[6] ^ enc[33]));  // pp0[7]
  assign pp_d[21] = (enc[35] & (enc[5] ^ enc[37])) | (enc[36] & (enc[4] ^ enc[37]));  // pp1[5]
  assign pp_d[22] = (enc[38] & (enc[3] ^ enc[40])) | (enc[39] & (enc[2] ^ enc[40]));  // pp2[3]
  assign pp_d[23] = (enc[41] & (enc[1] ^ enc[43])) | (enc[42] & (enc[0] ^ enc[43]));  // pp3[1]
  assign pp_d[24] = enc[46];  // c8 neg4
  assign pp_d[25] = (enc[32] & (enc[8] ^ enc[33])) | (enc[34] & (enc[7] ^ enc[33]));  // pp0[8]
  assign pp_d[26] = (enc[35] & (enc[6] ^ enc[37])) | (enc[36] & (enc[5] ^ enc[37]));  // pp1[6]
  assign pp_d[27] = (enc[38] & (enc[4] ^ enc[40])) | (enc[39] & (enc[3] ^ enc[40]));  // pp2[4]
  assign pp_d[28] = (enc[41] & (enc[2] ^ enc[43])) | (enc[42] & (enc[1] ^ enc[43]));  // pp3[2]
  assign pp_d[29] = (enc[44] & (enc[0] ^ enc[46])) | (enc[45] & enc[46]);  // pp4[0]
  assign pp_d[30] = (enc[32] & (enc[9] ^ enc[33])) | (enc[34] & (enc[8] ^ enc[33]));  // pp0[9]
  assign pp_d[31] = (enc[35] & (enc[7] ^ enc[37])) | (enc[36] & (enc[6] ^ enc[37]));  // pp1[7]
  assign pp_d[32] = (enc[38] & (enc[5] ^ enc[40])) | (enc[39] & (enc[4] ^ enc[40]));  // pp2[5]
  assign pp_d[33] = (enc[41] & (enc[3] ^ enc[43])) | (enc[42] & (enc[2] ^ enc[43]));  // pp3[3]
  assign pp_d[34] = (enc[44] & (enc[1] ^ enc[46])) | (enc[45] & (enc[0] ^ enc[46]));  // pp4[1]
  assign pp_d[35] = enc[49];  // c10 neg5
  assign pp_d[36] = (enc[32] & (enc[10] ^ enc[33])) | (enc[34] & (enc[9] ^ enc[33]));  // pp0[10]
  assign pp_d[37] = (enc[35] & (enc[8] ^ enc[37])) | (enc[36] & (enc[7] ^ enc[37]));  // pp1[8]
  assign pp_d[38] = (enc[38] & (enc[6] ^ enc[40])) | (enc[39] & (enc[5] ^ enc[40]));  // pp2[6]
  assign pp_d[39] = (enc[41] & (enc[4] ^ enc[43])) | (enc[42] & (enc[3] ^ enc[43]));  // pp3[4]
  assign pp_d[40] = (enc[44] & (enc[2] ^ enc[46])) | (enc[45] & (enc[1] ^ enc[46]));  // pp4[2]
  assign pp_d[41] = (enc[47] & (enc[0] ^ enc[49])) | (enc[48] & enc[49]);  // pp5[0]
  assign pp_d[42] = (enc[32] & (enc[11] ^ enc[33])) | (enc[34] & (enc[10] ^ enc[33]));  // pp0[11]
  assign pp_d[43] = (enc[35] & (enc[9] ^ enc[37])) | (enc[36] & (enc[8] ^ enc[37]));  // pp1[9]
  assign pp_d[44] = (enc[38] & (enc[7] ^ enc[40])) | (enc[39] & (enc[6] ^ enc[40]));  // pp2[7]
  assign pp_d[45] = (enc[41] & (enc[5] ^ enc[43])) | (enc[42] & (enc[4] ^ enc[43]));  // pp3[5]
  assign pp_d[46] = (enc[44] & (enc[3] ^ enc[46])) | (enc[45] & (enc[2] ^ enc[46]));  // pp4[3]
  assign pp_d[47] = (enc[47] & (enc[1] ^ enc[49])) | (enc[48] & (enc[0] ^ enc[49]));  // pp5[1]
  assign pp_d[48] = enc[52];  // c12 neg6
  assign pp_d[49] = (enc[32] & (enc[12] ^ enc[33])) | (enc[34] & (enc[11] ^ enc[33]));  // pp0[12]
  assign pp_d[50] = (enc[35] & (enc[10] ^ enc[37])) | (enc[36] & (enc[9] ^ enc[37]));  // pp1[10]
  assign pp_d[51] = (enc[38] & (enc[8] ^ enc[40])) | (enc[39] & (enc[7] ^ enc[40]));  // pp2[8]
  assign pp_d[52] = (enc[41] & (enc[6] ^ enc[43])) | (enc[42] & (enc[5] ^ enc[43]));  // pp3[6]
  assign pp_d[53] = (enc[44] & (enc[4] ^ enc[46])) | (enc[45] & (enc[3] ^ enc[46]));  // pp4[4]
  assign pp_d[54] = (enc[47] & (enc[2] ^ enc[49])) | (enc[48] & (enc[1] ^ enc[49]));  // pp5[2]
  assign pp_d[55] = (enc[50] & (enc[0] ^ enc[52])) | (enc[51] & enc[52]);  // pp6[0]
  assign pp_d[56] = (enc[32] & (enc[13] ^ enc[33])) | (enc[34] & (enc[12] ^ enc[33]));  // pp0[13]
  assign pp_d[57] = (enc[35] & (enc[11] ^ enc[37])) | (enc[36] & (enc[10] ^ enc[37]));  // pp1[11]
  assign pp_d[58] = (enc[38] & (enc[9] ^ enc[40])) | (enc[39] & (enc[8] ^ enc[40]));  // pp2[9]
  assign pp_d[59] = (enc[41] & (enc[7] ^ enc[43])) | (enc[42] & (enc[6] ^ enc[43]));  // pp3[7]
  assign pp_d[60] = (enc[44] & (enc[5] ^ enc[46])) | (enc[45] & (enc[4] ^ enc[46]));  // pp4[5]
  assign pp_d[61] = (enc[47] & (enc[3] ^ enc[49])) | (enc[48] & (enc[2] ^ enc[49]));  // pp5[3]
  assign pp_d[62] = (enc[50] & (enc[1] ^ enc[52])) | (enc[51] & (enc[0] ^ enc[52]));  // pp6[1]
  assign pp_d[63] = enc[55];  // c14 neg7
  assign pp_d[64] = (enc[32] & (enc[14] ^ enc[33])) | (enc[34] & (enc[13] ^ enc[33]));  // pp0[14]
  assign pp_d[65] = (enc[35] & (enc[12] ^ enc[37])) | (enc[36] & (enc[11] ^ enc[37]));  // pp1[12]
  assign pp_d[66] = (enc[38] & (enc[10] ^ enc[40])) | (enc[39] & (enc[9] ^ enc[40]));  // pp2[10]
  assign pp_d[67] = (enc[41] & (enc[8] ^ enc[43])) | (enc[42] & (enc[7] ^ enc[43]));  // pp3[8]
  assign pp_d[68] = (enc[44] & (enc[6] ^ enc[46])) | (enc[45] & (enc[5] ^ enc[46]));  // pp4[6]
  assign pp_d[69] = (enc[47] & (enc[4] ^ enc[49])) | (enc[48] & (enc[3] ^ enc[49]));  // pp5[4]
  assign pp_d[70] = (enc[50] & (enc[2] ^ enc[52])) | (enc[51] & (enc[1] ^ enc[52]));  // pp6[2]
  assign pp_d[71] = (enc[53] & (enc[0] ^ enc[55])) | (enc[54] & enc[55]);  // pp7[0]
  assign pp_d[72] = (enc[32] & (enc[15] ^ enc[33])) | (enc[34] & (enc[14] ^ enc[33]));  // pp0[15]
  assign pp_d[73] = (enc[35] & (enc[13] ^ enc[37])) | (enc[36] & (enc[12] ^ enc[37]));  // pp1[13]
  assign pp_d[74] = (enc[38] & (enc[11] ^ enc[40])) | (enc[39] & (enc[10] ^ enc[40]));  // pp2[11]
  assign pp_d[75] = (enc[41] & (enc[9] ^ enc[43])) | (enc[42] & (enc[8] ^ enc[43]));  // pp3[9]
  assign pp_d[76] = (enc[44] & (enc[7] ^ enc[46])) | (enc[45] & (enc[6] ^ enc[46]));  // pp4[7]
  assign pp_d[77] = (enc[47] & (enc[5] ^ enc[49])) | (enc[48] & (enc[4] ^ enc[49]));  // pp5[5]
  assign pp_d[78] = (enc[50] & (enc[3] ^ enc[52])) | (enc[51] & (enc[2] ^ enc[52]));  // pp6[3]
  assign pp_d[79] = (enc[53] & (enc[1] ^ enc[55])) | (enc[54] & (enc[0] ^ enc[55]));  // pp7[1]
  assign pp_d[80] = enc[58];  // c16 neg8
  assign pp_d[81] = (enc[32] & (enc[16] ^ enc[33])) | (enc[34] & (enc[15] ^ enc[33]));  // pp0[16]
  assign pp_d[82] = (enc[35] & (enc[14] ^ enc[37])) | (enc[36] & (enc[13] ^ enc[37]));  // pp1[14]
  assign pp_d[83] = (enc[38] & (enc[12] ^ enc[40])) | (enc[39] & (enc[11] ^ enc[40]));  // pp2[12]
  assign pp_d[84] = (enc[41] & (enc[10] ^ enc[43])) | (enc[42] & (enc[9] ^ enc[43]));  // pp3[10]
  assign pp_d[85] = (enc[44] & (enc[8] ^ enc[46])) | (enc[45] & (enc[7] ^ enc[46]));  // pp4[8]
  assign pp_d[86] = (enc[47] & (enc[6] ^ enc[49])) | (enc[48] & (enc[5] ^ enc[49]));  // pp5[6]
  assign pp_d[87] = (enc[50] & (enc[4] ^ enc[52])) | (enc[51] & (enc[3] ^ enc[52]));  // pp6[4]
  assign pp_d[88] = (enc[53] & (enc[2] ^ enc[55])) | (enc[54] & (enc[1] ^ enc[55]));  // pp7[2]
  assign pp_d[89] = (enc[56] & (enc[0] ^ enc[58])) | (enc[57] & enc[58]);  // pp8[0]
  assign pp_d[90] = (enc[32] & (enc[17] ^ enc[33])) | (enc[34] & (enc[16] ^ enc[33]));  // pp0[17]
  assign pp_d[91] = (enc[35] & (enc[15] ^ enc[37])) | (enc[36] & (enc[14] ^ enc[37]));  // pp1[15]
  assign pp_d[92] = (enc[38] & (enc[13] ^ enc[40])) | (enc[39] & (enc[12] ^ enc[40]));  // pp2[13]
  assign pp_d[93] = (enc[41] & (enc[11] ^ enc[43])) | (enc[42] & (enc[10] ^ enc[43]));  // pp3[11]
  assign pp_d[94] = (enc[44] & (enc[9] ^ enc[46])) | (enc[45] & (enc[8] ^ enc[46]));  // pp4[9]
  assign pp_d[95] = (enc[47] & (enc[7] ^ enc[49])) | (enc[48] & (enc[6] ^ enc[49]));  // pp5[7]
  assign pp_d[96] = (enc[50] & (enc[5] ^ enc[52])) | (enc[51] & (enc[4] ^ enc[52]));  // pp6[5]
  assign pp_d[97] = (enc[53] & (enc[3] ^ enc[55])) | (enc[54] & (enc[2] ^ enc[55]));  // pp7[3]
  assign pp_d[98] = (enc[56] & (enc[1] ^ enc[58])) | (enc[57] & (enc[0] ^ enc[58]));  // pp8[1]
  assign pp_d[99] = enc[61];  // c18 neg9
  assign pp_d[100] = (enc[32] & (enc[18] ^ enc[33])) | (enc[34] & (enc[17] ^ enc[33]));  // pp0[18]
  assign pp_d[101] = (enc[35] & (enc[16] ^ enc[37])) | (enc[36] & (enc[15] ^ enc[37]));  // pp1[16]
  assign pp_d[102] = (enc[38] & (enc[14] ^ enc[40])) | (enc[39] & (enc[13] ^ enc[40]));  // pp2[14]
  assign pp_d[103] = (enc[41] & (enc[12] ^ enc[43])) | (enc[42] & (enc[11] ^ enc[43]));  // pp3[12]
  assign pp_d[104] = (enc[44] & (enc[10] ^ enc[46])) | (enc[45] & (enc[9] ^ enc[46]));  // pp4[10]
  assign pp_d[105] = (enc[47] & (enc[8] ^ enc[49])) | (enc[48] & (enc[7] ^ enc[49]));  // pp5[8]
  assign pp_d[106] = (enc[50] & (enc[6] ^ enc[52])) | (enc[51] & (enc[5] ^ enc[52]));  // pp6[6]
  assign pp_d[107] = (enc[53] & (enc[4] ^ enc[55])) | (enc[54] & (enc[3] ^ enc[55]));  // pp7[4]
  assign pp_d[108] = (enc[56] & (enc[2] ^ enc[58])) | (enc[57] & (enc[1] ^ enc[58]));  // pp8[2]
  assign pp_d[109] = (enc[59] & (enc[0] ^ enc[61])) | (enc[60] & enc[61]);  // pp9[0]
  assign pp_d[110] = (enc[32] & (enc[19] ^ enc[33])) | (enc[34] & (enc[18] ^ enc[33]));  // pp0[19]
  assign pp_d[111] = (enc[35] & (enc[17] ^ enc[37])) | (enc[36] & (enc[16] ^ enc[37]));  // pp1[17]
  assign pp_d[112] = (enc[38] & (enc[15] ^ enc[40])) | (enc[39] & (enc[14] ^ enc[40]));  // pp2[15]
  assign pp_d[113] = (enc[41] & (enc[13] ^ enc[43])) | (enc[42] & (enc[12] ^ enc[43]));  // pp3[13]
  assign pp_d[114] = (enc[44] & (enc[11] ^ enc[46])) | (enc[45] & (enc[10] ^ enc[46]));  // pp4[11]
  assign pp_d[115] = (enc[47] & (enc[9] ^ enc[49])) | (enc[48] & (enc[8] ^ enc[49]));  // pp5[9]
  assign pp_d[116] = (enc[50] & (enc[7] ^ enc[52])) | (enc[51] & (enc[6] ^ enc[52]));  // pp6[7]
  assign pp_d[117] = (enc[53] & (enc[5] ^ enc[55])) | (enc[54] & (enc[4] ^ enc[55]));  // pp7[5]
  assign pp_d[118] = (enc[56] & (enc[3] ^ enc[58])) | (enc[57] & (enc[2] ^ enc[58]));  // pp8[3]
  assign pp_d[119] = (enc[59] & (enc[1] ^ enc[61])) | (enc[60] & (enc[0] ^ enc[61]));  // pp9[1]
  assign pp_d[120] = enc[64];  // c20 neg10
  assign pp_d[121] = (enc[32] & (enc[20] ^ enc[33])) | (enc[34] & (enc[19] ^ enc[33]));  // pp0[20]
  assign pp_d[122] = (enc[35] & (enc[18] ^ enc[37])) | (enc[36] & (enc[17] ^ enc[37]));  // pp1[18]
  assign pp_d[123] = (enc[38] & (enc[16] ^ enc[40])) | (enc[39] & (enc[15] ^ enc[40]));  // pp2[16]
  assign pp_d[124] = (enc[41] & (enc[14] ^ enc[43])) | (enc[42] & (enc[13] ^ enc[43]));  // pp3[14]
  assign pp_d[125] = (enc[44] & (enc[12] ^ enc[46])) | (enc[45] & (enc[11] ^ enc[46]));  // pp4[12]
  assign pp_d[126] = (enc[47] & (enc[10] ^ enc[49])) | (enc[48] & (enc[9] ^ enc[49]));  // pp5[10]
  assign pp_d[127] = (enc[50] & (enc[8] ^ enc[52])) | (enc[51] & (enc[7] ^ enc[52]));  // pp6[8]
  assign pp_d[128] = (enc[53] & (enc[6] ^ enc[55])) | (enc[54] & (enc[5] ^ enc[55]));  // pp7[6]
  assign pp_d[129] = (enc[56] & (enc[4] ^ enc[58])) | (enc[57] & (enc[3] ^ enc[58]));  // pp8[4]
  assign pp_d[130] = (enc[59] & (enc[2] ^ enc[61])) | (enc[60] & (enc[1] ^ enc[61]));  // pp9[2]
  assign pp_d[131] = (enc[62] & (enc[0] ^ enc[64])) | (enc[63] & enc[64]);  // pp10[0]
  assign pp_d[132] = (enc[32] & (enc[21] ^ enc[33])) | (enc[34] & (enc[20] ^ enc[33]));  // pp0[21]
  assign pp_d[133] = (enc[35] & (enc[19] ^ enc[37])) | (enc[36] & (enc[18] ^ enc[37]));  // pp1[19]
  assign pp_d[134] = (enc[38] & (enc[17] ^ enc[40])) | (enc[39] & (enc[16] ^ enc[40]));  // pp2[17]
  assign pp_d[135] = (enc[41] & (enc[15] ^ enc[43])) | (enc[42] & (enc[14] ^ enc[43]));  // pp3[15]
  assign pp_d[136] = (enc[44] & (enc[13] ^ enc[46])) | (enc[45] & (enc[12] ^ enc[46]));  // pp4[13]
  assign pp_d[137] = (enc[47] & (enc[11] ^ enc[49])) | (enc[48] & (enc[10] ^ enc[49]));  // pp5[11]
  assign pp_d[138] = (enc[50] & (enc[9] ^ enc[52])) | (enc[51] & (enc[8] ^ enc[52]));  // pp6[9]
  assign pp_d[139] = (enc[53] & (enc[7] ^ enc[55])) | (enc[54] & (enc[6] ^ enc[55]));  // pp7[7]
  assign pp_d[140] = (enc[56] & (enc[5] ^ enc[58])) | (enc[57] & (enc[4] ^ enc[58]));  // pp8[5]
  assign pp_d[141] = (enc[59] & (enc[3] ^ enc[61])) | (enc[60] & (enc[2] ^ enc[61]));  // pp9[3]
  assign pp_d[142] = (enc[62] & (enc[1] ^ enc[64])) | (enc[63] & (enc[0] ^ enc[64]));  // pp10[1]
  assign pp_d[143] = enc[67];  // c22 neg11
  assign pp_d[144] = (enc[32] & (enc[22] ^ enc[33])) | (enc[34] & (enc[21] ^ enc[33]));  // pp0[22]
  assign pp_d[145] = (enc[35] & (enc[20] ^ enc[37])) | (enc[36] & (enc[19] ^ enc[37]));  // pp1[20]
  assign pp_d[146] = (enc[38] & (enc[18] ^ enc[40])) | (enc[39] & (enc[17] ^ enc[40]));  // pp2[18]
  assign pp_d[147] = (enc[41] & (enc[16] ^ enc[43])) | (enc[42] & (enc[15] ^ enc[43]));  // pp3[16]
  assign pp_d[148] = (enc[44] & (enc[14] ^ enc[46])) | (enc[45] & (enc[13] ^ enc[46]));  // pp4[14]
  assign pp_d[149] = (enc[47] & (enc[12] ^ enc[49])) | (enc[48] & (enc[11] ^ enc[49]));  // pp5[12]
  assign pp_d[150] = (enc[50] & (enc[10] ^ enc[52])) | (enc[51] & (enc[9] ^ enc[52]));  // pp6[10]
  assign pp_d[151] = (enc[53] & (enc[8] ^ enc[55])) | (enc[54] & (enc[7] ^ enc[55]));  // pp7[8]
  assign pp_d[152] = (enc[56] & (enc[6] ^ enc[58])) | (enc[57] & (enc[5] ^ enc[58]));  // pp8[6]
  assign pp_d[153] = (enc[59] & (enc[4] ^ enc[61])) | (enc[60] & (enc[3] ^ enc[61]));  // pp9[4]
  assign pp_d[154] = (enc[62] & (enc[2] ^ enc[64])) | (enc[63] & (enc[1] ^ enc[64]));  // pp10[2]
  assign pp_d[155] = (enc[65] & (enc[0] ^ enc[67])) | (enc[66] & enc[67]);  // pp11[0]
  assign pp_d[156] = (enc[32] & (enc[23] ^ enc[33])) | (enc[34] & (enc[22] ^ enc[33]));  // pp0[23]
  assign pp_d[157] = (enc[35] & (enc[21] ^ enc[37])) | (enc[36] & (enc[20] ^ enc[37]));  // pp1[21]
  assign pp_d[158] = (enc[38] & (enc[19] ^ enc[40])) | (enc[39] & (enc[18] ^ enc[40]));  // pp2[19]
  assign pp_d[159] = (enc[41] & (enc[17] ^ enc[43])) | (enc[42] & (enc[16] ^ enc[43]));  // pp3[17]
  assign pp_d[160] = (enc[44] & (enc[15] ^ enc[46])) | (enc[45] & (enc[14] ^ enc[46]));  // pp4[15]
  assign pp_d[161] = (enc[47] & (enc[13] ^ enc[49])) | (enc[48] & (enc[12] ^ enc[49]));  // pp5[13]
  assign pp_d[162] = (enc[50] & (enc[11] ^ enc[52])) | (enc[51] & (enc[10] ^ enc[52]));  // pp6[11]
  assign pp_d[163] = (enc[53] & (enc[9] ^ enc[55])) | (enc[54] & (enc[8] ^ enc[55]));  // pp7[9]
  assign pp_d[164] = (enc[56] & (enc[7] ^ enc[58])) | (enc[57] & (enc[6] ^ enc[58]));  // pp8[7]
  assign pp_d[165] = (enc[59] & (enc[5] ^ enc[61])) | (enc[60] & (enc[4] ^ enc[61]));  // pp9[5]
  assign pp_d[166] = (enc[62] & (enc[3] ^ enc[64])) | (enc[63] & (enc[2] ^ enc[64]));  // pp10[3]
  assign pp_d[167] = (enc[65] & (enc[1] ^ enc[67])) | (enc[66] & (enc[0] ^ enc[67]));  // pp11[1]
  assign pp_d[168] = enc[70];  // c24 neg12
  assign pp_d[169] = (enc[32] & (enc[24] ^ enc[33])) | (enc[34] & (enc[23] ^ enc[33]));  // pp0[24]
  assign pp_d[170] = (enc[35] & (enc[22] ^ enc[37])) | (enc[36] & (enc[21] ^ enc[37]));  // pp1[22]
  assign pp_d[171] = (enc[38] & (enc[20] ^ enc[40])) | (enc[39] & (enc[19] ^ enc[40]));  // pp2[20]
  assign pp_d[172] = (enc[41] & (enc[18] ^ enc[43])) | (enc[42] & (enc[17] ^ enc[43]));  // pp3[18]
  assign pp_d[173] = (enc[44] & (enc[16] ^ enc[46])) | (enc[45] & (enc[15] ^ enc[46]));  // pp4[16]
  assign pp_d[174] = (enc[47] & (enc[14] ^ enc[49])) | (enc[48] & (enc[13] ^ enc[49]));  // pp5[14]
  assign pp_d[175] = (enc[50] & (enc[12] ^ enc[52])) | (enc[51] & (enc[11] ^ enc[52]));  // pp6[12]
  assign pp_d[176] = (enc[53] & (enc[10] ^ enc[55])) | (enc[54] & (enc[9] ^ enc[55]));  // pp7[10]
  assign pp_d[177] = (enc[56] & (enc[8] ^ enc[58])) | (enc[57] & (enc[7] ^ enc[58]));  // pp8[8]
  assign pp_d[178] = (enc[59] & (enc[6] ^ enc[61])) | (enc[60] & (enc[5] ^ enc[61]));  // pp9[6]
  assign pp_d[179] = (enc[62] & (enc[4] ^ enc[64])) | (enc[63] & (enc[3] ^ enc[64]));  // pp10[4]
  assign pp_d[180] = (enc[65] & (enc[2] ^ enc[67])) | (enc[66] & (enc[1] ^ enc[67]));  // pp11[2]
  assign pp_d[181] = (enc[68] & (enc[0] ^ enc[70])) | (enc[69] & enc[70]);  // pp12[0]
  assign pp_d[182] = (enc[32] & (enc[25] ^ enc[33])) | (enc[34] & (enc[24] ^ enc[33]));  // pp0[25]
  assign pp_d[183] = (enc[35] & (enc[23] ^ enc[37])) | (enc[36] & (enc[22] ^ enc[37]));  // pp1[23]
  assign pp_d[184] = (enc[38] & (enc[21] ^ enc[40])) | (enc[39] & (enc[20] ^ enc[40]));  // pp2[21]
  assign pp_d[185] = (enc[41] & (enc[19] ^ enc[43])) | (enc[42] & (enc[18] ^ enc[43]));  // pp3[19]
  assign pp_d[186] = (enc[44] & (enc[17] ^ enc[46])) | (enc[45] & (enc[16] ^ enc[46]));  // pp4[17]
  assign pp_d[187] = (enc[47] & (enc[15] ^ enc[49])) | (enc[48] & (enc[14] ^ enc[49]));  // pp5[15]
  assign pp_d[188] = (enc[50] & (enc[13] ^ enc[52])) | (enc[51] & (enc[12] ^ enc[52]));  // pp6[13]
  assign pp_d[189] = (enc[53] & (enc[11] ^ enc[55])) | (enc[54] & (enc[10] ^ enc[55]));  // pp7[11]
  assign pp_d[190] = (enc[56] & (enc[9] ^ enc[58])) | (enc[57] & (enc[8] ^ enc[58]));  // pp8[9]
  assign pp_d[191] = (enc[59] & (enc[7] ^ enc[61])) | (enc[60] & (enc[6] ^ enc[61]));  // pp9[7]
  assign pp_d[192] = (enc[62] & (enc[5] ^ enc[64])) | (enc[63] & (enc[4] ^ enc[64]));  // pp10[5]
  assign pp_d[193] = (enc[65] & (enc[3] ^ enc[67])) | (enc[66] & (enc[2] ^ enc[67]));  // pp11[3]
  assign pp_d[194] = (enc[68] & (enc[1] ^ enc[70])) | (enc[69] & (enc[0] ^ enc[70]));  // pp12[1]
  assign pp_d[195] = enc[73];  // c26 neg13
  assign pp_d[196] = (enc[32] & (enc[26] ^ enc[33])) | (enc[34] & (enc[25] ^ enc[33]));  // pp0[26]
  assign pp_d[197] = (enc[35] & (enc[24] ^ enc[37])) | (enc[36] & (enc[23] ^ enc[37]));  // pp1[24]
  assign pp_d[198] = (enc[38] & (enc[22] ^ enc[40])) | (enc[39] & (enc[21] ^ enc[40]));  // pp2[22]
  assign pp_d[199] = (enc[41] & (enc[20] ^ enc[43])) | (enc[42] & (enc[19] ^ enc[43]));  // pp3[20]
  assign pp_d[200] = (enc[44] & (enc[18] ^ enc[46])) | (enc[45] & (enc[17] ^ enc[46]));  // pp4[18]
  assign pp_d[201] = (enc[47] & (enc[16] ^ enc[49])) | (enc[48] & (enc[15] ^ enc[49]));  // pp5[16]
  assign pp_d[202] = (enc[50] & (enc[14] ^ enc[52])) | (enc[51] & (enc[13] ^ enc[52]));  // pp6[14]
  assign pp_d[203] = (enc[53] & (enc[12] ^ enc[55])) | (enc[54] & (enc[11] ^ enc[55]));  // pp7[12]
  assign pp_d[204] = (enc[56] & (enc[10] ^ enc[58])) | (enc[57] & (enc[9] ^ enc[58]));  // pp8[10]
  assign pp_d[205] = (enc[59] & (enc[8] ^ enc[61])) | (enc[60] & (enc[7] ^ enc[61]));  // pp9[8]
  assign pp_d[206] = (enc[62] & (enc[6] ^ enc[64])) | (enc[63] & (enc[5] ^ enc[64]));  // pp10[6]
  assign pp_d[207] = (enc[65] & (enc[4] ^ enc[67])) | (enc[66] & (enc[3] ^ enc[67]));  // pp11[4]
  assign pp_d[208] = (enc[68] & (enc[2] ^ enc[70])) | (enc[69] & (enc[1] ^ enc[70]));  // pp12[2]
  assign pp_d[209] = (enc[71] & (enc[0] ^ enc[73])) | (enc[72] & enc[73]);  // pp13[0]
  assign pp_d[210] = (enc[32] & (enc[27] ^ enc[33])) | (enc[34] & (enc[26] ^ enc[33]));  // pp0[27]
  assign pp_d[211] = (enc[35] & (enc[25] ^ enc[37])) | (enc[36] & (enc[24] ^ enc[37]));  // pp1[25]
  assign pp_d[212] = (enc[38] & (enc[23] ^ enc[40])) | (enc[39] & (enc[22] ^ enc[40]));  // pp2[23]
  assign pp_d[213] = (enc[41] & (enc[21] ^ enc[43])) | (enc[42] & (enc[20] ^ enc[43]));  // pp3[21]
  assign pp_d[214] = (enc[44] & (enc[19] ^ enc[46])) | (enc[45] & (enc[18] ^ enc[46]));  // pp4[19]
  assign pp_d[215] = (enc[47] & (enc[17] ^ enc[49])) | (enc[48] & (enc[16] ^ enc[49]));  // pp5[17]
  assign pp_d[216] = (enc[50] & (enc[15] ^ enc[52])) | (enc[51] & (enc[14] ^ enc[52]));  // pp6[15]
  assign pp_d[217] = (enc[53] & (enc[13] ^ enc[55])) | (enc[54] & (enc[12] ^ enc[55]));  // pp7[13]
  assign pp_d[218] = (enc[56] & (enc[11] ^ enc[58])) | (enc[57] & (enc[10] ^ enc[58]));  // pp8[11]
  assign pp_d[219] = (enc[59] & (enc[9] ^ enc[61])) | (enc[60] & (enc[8] ^ enc[61]));  // pp9[9]
  assign pp_d[220] = (enc[62] & (enc[7] ^ enc[64])) | (enc[63] & (enc[6] ^ enc[64]));  // pp10[7]
  assign pp_d[221] = (enc[65] & (enc[5] ^ enc[67])) | (enc[66] & (enc[4] ^ enc[67]));  // pp11[5]
  assign pp_d[222] = (enc[68] & (enc[3] ^ enc[70])) | (enc[69] & (enc[2] ^ enc[70]));  // pp12[3]
  assign pp_d[223] = (enc[71] & (enc[1] ^ enc[73])) | (enc[72] & (enc[0] ^ enc[73]));  // pp13[1]
  assign pp_d[224] = enc[76];  // c28 neg14
  assign pp_d[225] = (enc[32] & (enc[28] ^ enc[33])) | (enc[34] & (enc[27] ^ enc[33]));  // pp0[28]
  assign pp_d[226] = (enc[35] & (enc[26] ^ enc[37])) | (enc[36] & (enc[25] ^ enc[37]));  // pp1[26]
  assign pp_d[227] = (enc[38] & (enc[24] ^ enc[40])) | (enc[39] & (enc[23] ^ enc[40]));  // pp2[24]
  assign pp_d[228] = (enc[41] & (enc[22] ^ enc[43])) | (enc[42] & (enc[21] ^ enc[43]));  // pp3[22]
  assign pp_d[229] = (enc[44] & (enc[20] ^ enc[46])) | (enc[45] & (enc[19] ^ enc[46]));  // pp4[20]
  assign pp_d[230] = (enc[47] & (enc[18] ^ enc[49])) | (enc[48] & (enc[17] ^ enc[49]));  // pp5[18]
  assign pp_d[231] = (enc[50] & (enc[16] ^ enc[52])) | (enc[51] & (enc[15] ^ enc[52]));  // pp6[16]
  assign pp_d[232] = (enc[53] & (enc[14] ^ enc[55])) | (enc[54] & (enc[13] ^ enc[55]));  // pp7[14]
  assign pp_d[233] = (enc[56] & (enc[12] ^ enc[58])) | (enc[57] & (enc[11] ^ enc[58]));  // pp8[12]
  assign pp_d[234] = (enc[59] & (enc[10] ^ enc[61])) | (enc[60] & (enc[9] ^ enc[61]));  // pp9[10]
  assign pp_d[235] = (enc[62] & (enc[8] ^ enc[64])) | (enc[63] & (enc[7] ^ enc[64]));  // pp10[8]
  assign pp_d[236] = (enc[65] & (enc[6] ^ enc[67])) | (enc[66] & (enc[5] ^ enc[67]));  // pp11[6]
  assign pp_d[237] = (enc[68] & (enc[4] ^ enc[70])) | (enc[69] & (enc[3] ^ enc[70]));  // pp12[4]
  assign pp_d[238] = (enc[71] & (enc[2] ^ enc[73])) | (enc[72] & (enc[1] ^ enc[73]));  // pp13[2]
  assign pp_d[239] = (enc[74] & (enc[0] ^ enc[76])) | (enc[75] & enc[76]);  // pp14[0]
  assign pp_d[240] = (enc[32] & (enc[29] ^ enc[33])) | (enc[34] & (enc[28] ^ enc[33]));  // pp0[29]
  assign pp_d[241] = (enc[35] & (enc[27] ^ enc[37])) | (enc[36] & (enc[26] ^ enc[37]));  // pp1[27]
  assign pp_d[242] = (enc[38] & (enc[25] ^ enc[40])) | (enc[39] & (enc[24] ^ enc[40]));  // pp2[25]
  assign pp_d[243] = (enc[41] & (enc[23] ^ enc[43])) | (enc[42] & (enc[22] ^ enc[43]));  // pp3[23]
  assign pp_d[244] = (enc[44] & (enc[21] ^ enc[46])) | (enc[45] & (enc[20] ^ enc[46]));  // pp4[21]
  assign pp_d[245] = (enc[47] & (enc[19] ^ enc[49])) | (enc[48] & (enc[18] ^ enc[49]));  // pp5[19]
  assign pp_d[246] = (enc[50] & (enc[17] ^ enc[52])) | (enc[51] & (enc[16] ^ enc[52]));  // pp6[17]
  assign pp_d[247] = (enc[53] & (enc[15] ^ enc[55])) | (enc[54] & (enc[14] ^ enc[55]));  // pp7[15]
  assign pp_d[248] = (enc[56] & (enc[13] ^ enc[58])) | (enc[57] & (enc[12] ^ enc[58]));  // pp8[13]
  assign pp_d[249] = (enc[59] & (enc[11] ^ enc[61])) | (enc[60] & (enc[10] ^ enc[61]));  // pp9[11]
  assign pp_d[250] = (enc[62] & (enc[9] ^ enc[64])) | (enc[63] & (enc[8] ^ enc[64]));  // pp10[9]
  assign pp_d[251] = (enc[65] & (enc[7] ^ enc[67])) | (enc[66] & (enc[6] ^ enc[67]));  // pp11[7]
  assign pp_d[252] = (enc[68] & (enc[5] ^ enc[70])) | (enc[69] & (enc[4] ^ enc[70]));  // pp12[5]
  assign pp_d[253] = (enc[71] & (enc[3] ^ enc[73])) | (enc[72] & (enc[2] ^ enc[73]));  // pp13[3]
  assign pp_d[254] = (enc[74] & (enc[1] ^ enc[76])) | (enc[75] & (enc[0] ^ enc[76]));  // pp14[1]
  assign pp_d[255] = enc[79];  // c30 neg15
  assign pp_d[256] = (enc[32] & (enc[30] ^ enc[33])) | (enc[34] & (enc[29] ^ enc[33]));  // pp0[30]
  assign pp_d[257] = (enc[35] & (enc[28] ^ enc[37])) | (enc[36] & (enc[27] ^ enc[37]));  // pp1[28]
  assign pp_d[258] = (enc[38] & (enc[26] ^ enc[40])) | (enc[39] & (enc[25] ^ enc[40]));  // pp2[26]
  assign pp_d[259] = (enc[41] & (enc[24] ^ enc[43])) | (enc[42] & (enc[23] ^ enc[43]));  // pp3[24]
  assign pp_d[260] = (enc[44] & (enc[22] ^ enc[46])) | (enc[45] & (enc[21] ^ enc[46]));  // pp4[22]
  assign pp_d[261] = (enc[47] & (enc[20] ^ enc[49])) | (enc[48] & (enc[19] ^ enc[49]));  // pp5[20]
  assign pp_d[262] = (enc[50] & (enc[18] ^ enc[52])) | (enc[51] & (enc[17] ^ enc[52]));  // pp6[18]
  assign pp_d[263] = (enc[53] & (enc[16] ^ enc[55])) | (enc[54] & (enc[15] ^ enc[55]));  // pp7[16]
  assign pp_d[264] = (enc[56] & (enc[14] ^ enc[58])) | (enc[57] & (enc[13] ^ enc[58]));  // pp8[14]
  assign pp_d[265] = (enc[59] & (enc[12] ^ enc[61])) | (enc[60] & (enc[11] ^ enc[61]));  // pp9[12]
  assign pp_d[266] = (enc[62] & (enc[10] ^ enc[64])) | (enc[63] & (enc[9] ^ enc[64]));  // pp10[10]
  assign pp_d[267] = (enc[65] & (enc[8] ^ enc[67])) | (enc[66] & (enc[7] ^ enc[67]));  // pp11[8]
  assign pp_d[268] = (enc[68] & (enc[6] ^ enc[70])) | (enc[69] & (enc[5] ^ enc[70]));  // pp12[6]
  assign pp_d[269] = (enc[71] & (enc[4] ^ enc[73])) | (enc[72] & (enc[3] ^ enc[73]));  // pp13[4]
  assign pp_d[270] = (enc[74] & (enc[2] ^ enc[76])) | (enc[75] & (enc[1] ^ enc[76]));  // pp14[2]
  assign pp_d[271] = (enc[77] & (enc[0] ^ enc[79])) | (enc[78] & enc[79]);  // pp15[0]
  assign pp_d[272] = (enc[32] & (enc[31] ^ enc[33])) | (enc[34] & (enc[30] ^ enc[33]));  // pp0[31]
  assign pp_d[273] = (enc[35] & (enc[29] ^ enc[37])) | (enc[36] & (enc[28] ^ enc[37]));  // pp1[29]
  assign pp_d[274] = (enc[38] & (enc[27] ^ enc[40])) | (enc[39] & (enc[26] ^ enc[40]));  // pp2[27]
  assign pp_d[275] = (enc[41] & (enc[25] ^ enc[43])) | (enc[42] & (enc[24] ^ enc[43]));  // pp3[25]
  assign pp_d[276] = (enc[44] & (enc[23] ^ enc[46])) | (enc[45] & (enc[22] ^ enc[46]));  // pp4[23]
  assign pp_d[277] = (enc[47] & (enc[21] ^ enc[49])) | (enc[48] & (enc[20] ^ enc[49]));  // pp5[21]
  assign pp_d[278] = (enc[50] & (enc[19] ^ enc[52])) | (enc[51] & (enc[18] ^ enc[52]));  // pp6[19]
  assign pp_d[279] = (enc[53] & (enc[17] ^ enc[55])) | (enc[54] & (enc[16] ^ enc[55]));  // pp7[17]
  assign pp_d[280] = (enc[56] & (enc[15] ^ enc[58])) | (enc[57] & (enc[14] ^ enc[58]));  // pp8[15]
  assign pp_d[281] = (enc[59] & (enc[13] ^ enc[61])) | (enc[60] & (enc[12] ^ enc[61]));  // pp9[13]
  assign pp_d[282] = (enc[62] & (enc[11] ^ enc[64])) | (enc[63] & (enc[10] ^ enc[64]));  // pp10[11]
  assign pp_d[283] = (enc[65] & (enc[9] ^ enc[67])) | (enc[66] & (enc[8] ^ enc[67]));  // pp11[9]
  assign pp_d[284] = (enc[68] & (enc[7] ^ enc[70])) | (enc[69] & (enc[6] ^ enc[70]));  // pp12[7]
  assign pp_d[285] = (enc[71] & (enc[5] ^ enc[73])) | (enc[72] & (enc[4] ^ enc[73]));  // pp13[5]
  assign pp_d[286] = (enc[74] & (enc[3] ^ enc[76])) | (enc[75] & (enc[2] ^ enc[76]));  // pp14[3]
  assign pp_d[287] = (enc[77] & (enc[1] ^ enc[79])) | (enc[78] & (enc[0] ^ enc[79]));  // pp15[1]
  if (LATENCY == 2) begin : g_pp_l2
    basechili_dffe_cg #(.WIDTH(288), .GATE(CLOCK_GATE)) u_stg1_pp (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .en      (vld[0]),
      .d       (pp_d),
      .q       (pp)
    );
  end else begin : g_pp_wire
    assign pp = pp_d;
  end

  // ---- tree1: Dadda level 1 ------------------------------------------------
  assign tree1[167:0] = pp[167:0];  // c0..c23
  assign tree1[179:168] = pp[181:170];  // c24
  assign tree1[180] = pp[168] ^ pp[169];  // c24 ha.s
  assign tree1[191:181] = pp[194:184];  // c25
  assign tree1[192] = pp[168] & pp[169];  // c24 ha.c
  assign tree1[193] = pp[182] ^ pp[183];  // c25 ha.s
  assign tree1[203:194] = pp[209:200];  // c26
  assign tree1[204] = pp[182] & pp[183];  // c25 ha.c
  assign tree1[205] = pp[195] ^ pp[196] ^ pp[197];  // c26 fa.s
  assign tree1[206] = pp[198] ^ pp[199];  // c26 ha.s
  assign tree1[215:207] = pp[223:215];  // c27
  assign tree1[216] = (pp[195] & pp[196]) | (pp[195] & pp[197]) | (pp[196] & pp[197]);  // c26 fa.c
  assign tree1[217] = pp[198] & pp[199];  // c26 ha.c
  assign tree1[218] = pp[210] ^ pp[211] ^ pp[212];  // c27 fa.s
  assign tree1[219] = pp[213] ^ pp[214];  // c27 ha.s
  assign tree1[227:220] = pp[239:232];  // c28
  assign tree1[228] = (pp[210] & pp[211]) | (pp[210] & pp[212]) | (pp[211] & pp[212]);  // c27 fa.c
  assign tree1[229] = pp[213] & pp[214];  // c27 ha.c
  assign tree1[230] = pp[224] ^ pp[225] ^ pp[226];  // c28 fa.s
  assign tree1[231] = pp[227] ^ pp[228] ^ pp[229];  // c28 fa.s
  assign tree1[232] = pp[230] ^ pp[231];  // c28 ha.s
  assign tree1[239:233] = pp[254:248];  // c29
  assign tree1[240] = (pp[224] & pp[225]) | (pp[224] & pp[226]) | (pp[225] & pp[226]);  // c28 fa.c
  assign tree1[241] = (pp[227] & pp[228]) | (pp[227] & pp[229]) | (pp[228] & pp[229]);  // c28 fa.c
  assign tree1[242] = pp[230] & pp[231];  // c28 ha.c
  assign tree1[243] = pp[240] ^ pp[241] ^ pp[242];  // c29 fa.s
  assign tree1[244] = pp[243] ^ pp[244] ^ pp[245];  // c29 fa.s
  assign tree1[245] = pp[246] ^ pp[247];  // c29 ha.s
  assign tree1[251:246] = pp[271:266];  // c30
  assign tree1[252] = (pp[240] & pp[241]) | (pp[240] & pp[242]) | (pp[241] & pp[242]);  // c29 fa.c
  assign tree1[253] = (pp[243] & pp[244]) | (pp[243] & pp[245]) | (pp[244] & pp[245]);  // c29 fa.c
  assign tree1[254] = pp[246] & pp[247];  // c29 ha.c
  assign tree1[255] = pp[255] ^ pp[256] ^ pp[257];  // c30 fa.s
  assign tree1[256] = pp[258] ^ pp[259] ^ pp[260];  // c30 fa.s
  assign tree1[257] = pp[261] ^ pp[262] ^ pp[263];  // c30 fa.s
  assign tree1[258] = pp[264] ^ pp[265];  // c30 ha.s
  assign tree1[263:259] = pp[287:283];  // c31
  assign tree1[264] = (pp[255] & pp[256]) | (pp[255] & pp[257]) | (pp[256] & pp[257]);  // c30 fa.c
  assign tree1[265] = (pp[258] & pp[259]) | (pp[258] & pp[260]) | (pp[259] & pp[260]);  // c30 fa.c
  assign tree1[266] = (pp[261] & pp[262]) | (pp[261] & pp[263]) | (pp[262] & pp[263]);  // c30 fa.c
  assign tree1[267] = pp[264] & pp[265];  // c30 ha.c
  assign tree1[268] = pp[272] ^ pp[273] ^ pp[274];  // c31 fa.s
  assign tree1[269] = pp[275] ^ pp[276] ^ pp[277];  // c31 fa.s
  assign tree1[270] = pp[278] ^ pp[279] ^ pp[280];  // c31 fa.s
  assign tree1[271] = pp[281] ^ pp[282];  // c31 ha.s

  // ---- tree2: Dadda level 2 ------------------------------------------------
  assign tree2[79:0] = tree1[79:0];  // c0..c15
  assign tree2[87:80] = tree1[89:82];  // c16
  assign tree2[88] = tree1[80] ^ tree1[81];  // c16 ha.s
  assign tree2[95:89] = tree1[98:92];  // c17
  assign tree2[96] = tree1[80] & tree1[81];  // c16 ha.c
  assign tree2[97] = tree1[90] ^ tree1[91];  // c17 ha.s
  assign tree2[103:98] = tree1[109:104];  // c18
  assign tree2[104] = tree1[90] & tree1[91];  // c17 ha.c
  assign tree2[105] = tree1[99] ^ tree1[100] ^ tree1[101];  // c18 fa.s
  assign tree2[106] = tree1[102] ^ tree1[103];  // c18 ha.s
  assign tree2[111:107] = tree1[119:115];  // c19
  assign tree2[112] = (tree1[99] & tree1[100]) | (tree1[99] & tree1[101]) | (tree1[100] & tree1[101]);  // c18 fa.c
  assign tree2[113] = tree1[102] & tree1[103];  // c18 ha.c
  assign tree2[114] = tree1[110] ^ tree1[111] ^ tree1[112];  // c19 fa.s
  assign tree2[115] = tree1[113] ^ tree1[114];  // c19 ha.s
  assign tree2[119:116] = tree1[131:128];  // c20
  assign tree2[120] = (tree1[110] & tree1[111]) | (tree1[110] & tree1[112]) | (tree1[111] & tree1[112]);  // c19 fa.c
  assign tree2[121] = tree1[113] & tree1[114];  // c19 ha.c
  assign tree2[122] = tree1[120] ^ tree1[121] ^ tree1[122];  // c20 fa.s
  assign tree2[123] = tree1[123] ^ tree1[124] ^ tree1[125];  // c20 fa.s
  assign tree2[124] = tree1[126] ^ tree1[127];  // c20 ha.s
  assign tree2[127:125] = tree1[142:140];  // c21
  assign tree2[128] = (tree1[120] & tree1[121]) | (tree1[120] & tree1[122]) | (tree1[121] & tree1[122]);  // c20 fa.c
  assign tree2[129] = (tree1[123] & tree1[124]) | (tree1[123] & tree1[125]) | (tree1[124] & tree1[125]);  // c20 fa.c
  assign tree2[130] = tree1[126] & tree1[127];  // c20 ha.c
  assign tree2[131] = tree1[132] ^ tree1[133] ^ tree1[134];  // c21 fa.s
  assign tree2[132] = tree1[135] ^ tree1[136] ^ tree1[137];  // c21 fa.s
  assign tree2[133] = tree1[138] ^ tree1[139];  // c21 ha.s
  assign tree2[135:134] = tree1[155:154];  // c22
  assign tree2[136] = (tree1[132] & tree1[133]) | (tree1[132] & tree1[134]) | (tree1[133] & tree1[134]);  // c21 fa.c
  assign tree2[137] = (tree1[135] & tree1[136]) | (tree1[135] & tree1[137]) | (tree1[136] & tree1[137]);  // c21 fa.c
  assign tree2[138] = tree1[138] & tree1[139];  // c21 ha.c
  assign tree2[139] = tree1[143] ^ tree1[144] ^ tree1[145];  // c22 fa.s
  assign tree2[140] = tree1[146] ^ tree1[147] ^ tree1[148];  // c22 fa.s
  assign tree2[141] = tree1[149] ^ tree1[150] ^ tree1[151];  // c22 fa.s
  assign tree2[142] = tree1[152] ^ tree1[153];  // c22 ha.s
  assign tree2[143] = tree1[167];  // c23
  assign tree2[144] = (tree1[143] & tree1[144]) | (tree1[143] & tree1[145]) | (tree1[144] & tree1[145]);  // c22 fa.c
  assign tree2[145] = (tree1[146] & tree1[147]) | (tree1[146] & tree1[148]) | (tree1[147] & tree1[148]);  // c22 fa.c
  assign tree2[146] = (tree1[149] & tree1[150]) | (tree1[149] & tree1[151]) | (tree1[150] & tree1[151]);  // c22 fa.c
  assign tree2[147] = tree1[152] & tree1[153];  // c22 ha.c
  assign tree2[148] = tree1[156] ^ tree1[157] ^ tree1[158];  // c23 fa.s
  assign tree2[149] = tree1[159] ^ tree1[160] ^ tree1[161];  // c23 fa.s
  assign tree2[150] = tree1[162] ^ tree1[163] ^ tree1[164];  // c23 fa.s
  assign tree2[151] = tree1[165] ^ tree1[166];  // c23 ha.s
  assign tree2[152] = tree1[180];  // c24
  assign tree2[153] = (tree1[156] & tree1[157]) | (tree1[156] & tree1[158]) | (tree1[157] & tree1[158]);  // c23 fa.c
  assign tree2[154] = (tree1[159] & tree1[160]) | (tree1[159] & tree1[161]) | (tree1[160] & tree1[161]);  // c23 fa.c
  assign tree2[155] = (tree1[162] & tree1[163]) | (tree1[162] & tree1[164]) | (tree1[163] & tree1[164]);  // c23 fa.c
  assign tree2[156] = tree1[165] & tree1[166];  // c23 ha.c
  assign tree2[157] = tree1[168] ^ tree1[169] ^ tree1[170];  // c24 fa.s
  assign tree2[158] = tree1[171] ^ tree1[172] ^ tree1[173];  // c24 fa.s
  assign tree2[159] = tree1[174] ^ tree1[175] ^ tree1[176];  // c24 fa.s
  assign tree2[160] = tree1[177] ^ tree1[178] ^ tree1[179];  // c24 fa.s
  assign tree2[161] = tree1[193];  // c25
  assign tree2[162] = (tree1[168] & tree1[169]) | (tree1[168] & tree1[170]) | (tree1[169] & tree1[170]);  // c24 fa.c
  assign tree2[163] = (tree1[171] & tree1[172]) | (tree1[171] & tree1[173]) | (tree1[172] & tree1[173]);  // c24 fa.c
  assign tree2[164] = (tree1[174] & tree1[175]) | (tree1[174] & tree1[176]) | (tree1[175] & tree1[176]);  // c24 fa.c
  assign tree2[165] = (tree1[177] & tree1[178]) | (tree1[177] & tree1[179]) | (tree1[178] & tree1[179]);  // c24 fa.c
  assign tree2[166] = tree1[181] ^ tree1[182] ^ tree1[183];  // c25 fa.s
  assign tree2[167] = tree1[184] ^ tree1[185] ^ tree1[186];  // c25 fa.s
  assign tree2[168] = tree1[187] ^ tree1[188] ^ tree1[189];  // c25 fa.s
  assign tree2[169] = tree1[190] ^ tree1[191] ^ tree1[192];  // c25 fa.s
  assign tree2[170] = tree1[205];  // c26
  assign tree2[171] = (tree1[181] & tree1[182]) | (tree1[181] & tree1[183]) | (tree1[182] & tree1[183]);  // c25 fa.c
  assign tree2[172] = (tree1[184] & tree1[185]) | (tree1[184] & tree1[186]) | (tree1[185] & tree1[186]);  // c25 fa.c
  assign tree2[173] = (tree1[187] & tree1[188]) | (tree1[187] & tree1[189]) | (tree1[188] & tree1[189]);  // c25 fa.c
  assign tree2[174] = (tree1[190] & tree1[191]) | (tree1[190] & tree1[192]) | (tree1[191] & tree1[192]);  // c25 fa.c
  assign tree2[175] = tree1[194] ^ tree1[195] ^ tree1[196];  // c26 fa.s
  assign tree2[176] = tree1[197] ^ tree1[198] ^ tree1[199];  // c26 fa.s
  assign tree2[177] = tree1[200] ^ tree1[201] ^ tree1[202];  // c26 fa.s
  assign tree2[178] = tree1[203] ^ tree1[204] ^ tree1[206];  // c26 fa.s
  assign tree2[179] = tree1[218];  // c27
  assign tree2[180] = (tree1[194] & tree1[195]) | (tree1[194] & tree1[196]) | (tree1[195] & tree1[196]);  // c26 fa.c
  assign tree2[181] = (tree1[197] & tree1[198]) | (tree1[197] & tree1[199]) | (tree1[198] & tree1[199]);  // c26 fa.c
  assign tree2[182] = (tree1[200] & tree1[201]) | (tree1[200] & tree1[202]) | (tree1[201] & tree1[202]);  // c26 fa.c
  assign tree2[183] = (tree1[203] & tree1[204]) | (tree1[203] & tree1[206]) | (tree1[204] & tree1[206]);  // c26 fa.c
  assign tree2[184] = tree1[207] ^ tree1[208] ^ tree1[209];  // c27 fa.s
  assign tree2[185] = tree1[210] ^ tree1[211] ^ tree1[212];  // c27 fa.s
  assign tree2[186] = tree1[213] ^ tree1[214] ^ tree1[215];  // c27 fa.s
  assign tree2[187] = tree1[217] ^ tree1[216] ^ tree1[219];  // c27 fa.s
  assign tree2[188] = tree1[231];  // c28
  assign tree2[189] = (tree1[207] & tree1[208]) | (tree1[207] & tree1[209]) | (tree1[208] & tree1[209]);  // c27 fa.c
  assign tree2[190] = (tree1[210] & tree1[211]) | (tree1[210] & tree1[212]) | (tree1[211] & tree1[212]);  // c27 fa.c
  assign tree2[191] = (tree1[213] & tree1[214]) | (tree1[213] & tree1[215]) | (tree1[214] & tree1[215]);  // c27 fa.c
  assign tree2[192] = (tree1[217] & tree1[216]) | (tree1[217] & tree1[219]) | (tree1[216] & tree1[219]);  // c27 fa.c
  assign tree2[193] = tree1[220] ^ tree1[221] ^ tree1[222];  // c28 fa.s
  assign tree2[194] = tree1[223] ^ tree1[224] ^ tree1[225];  // c28 fa.s
  assign tree2[195] = tree1[226] ^ tree1[227] ^ tree1[229];  // c28 fa.s
  assign tree2[196] = tree1[228] ^ tree1[232] ^ tree1[230];  // c28 fa.s
  assign tree2[197] = tree1[244];  // c29
  assign tree2[198] = (tree1[220] & tree1[221]) | (tree1[220] & tree1[222]) | (tree1[221] & tree1[222]);  // c28 fa.c
  assign tree2[199] = (tree1[223] & tree1[224]) | (tree1[223] & tree1[225]) | (tree1[224] & tree1[225]);  // c28 fa.c
  assign tree2[200] = (tree1[226] & tree1[227]) | (tree1[226] & tree1[229]) | (tree1[227] & tree1[229]);  // c28 fa.c
  assign tree2[201] = (tree1[228] & tree1[232]) | (tree1[228] & tree1[230]) | (tree1[232] & tree1[230]);  // c28 fa.c
  assign tree2[202] = tree1[233] ^ tree1[234] ^ tree1[235];  // c29 fa.s
  assign tree2[203] = tree1[236] ^ tree1[237] ^ tree1[238];  // c29 fa.s
  assign tree2[204] = tree1[239] ^ tree1[242] ^ tree1[240];  // c29 fa.s
  assign tree2[205] = tree1[241] ^ tree1[245] ^ tree1[243];  // c29 fa.s
  assign tree2[206] = tree1[257];  // c30
  assign tree2[207] = (tree1[233] & tree1[234]) | (tree1[233] & tree1[235]) | (tree1[234] & tree1[235]);  // c29 fa.c
  assign tree2[208] = (tree1[236] & tree1[237]) | (tree1[236] & tree1[238]) | (tree1[237] & tree1[238]);  // c29 fa.c
  assign tree2[209] = (tree1[239] & tree1[242]) | (tree1[239] & tree1[240]) | (tree1[242] & tree1[240]);  // c29 fa.c
  assign tree2[210] = (tree1[241] & tree1[245]) | (tree1[241] & tree1[243]) | (tree1[245] & tree1[243]);  // c29 fa.c
  assign tree2[211] = tree1[246] ^ tree1[247] ^ tree1[248];  // c30 fa.s
  assign tree2[212] = tree1[249] ^ tree1[250] ^ tree1[251];  // c30 fa.s
  assign tree2[213] = tree1[254] ^ tree1[252] ^ tree1[253];  // c30 fa.s
  assign tree2[214] = tree1[258] ^ tree1[255] ^ tree1[256];  // c30 fa.s
  assign tree2[215] = tree1[270];  // c31
  assign tree2[216] = (tree1[246] & tree1[247]) | (tree1[246] & tree1[248]) | (tree1[247] & tree1[248]);  // c30 fa.c
  assign tree2[217] = (tree1[249] & tree1[250]) | (tree1[249] & tree1[251]) | (tree1[250] & tree1[251]);  // c30 fa.c
  assign tree2[218] = (tree1[254] & tree1[252]) | (tree1[254] & tree1[253]) | (tree1[252] & tree1[253]);  // c30 fa.c
  assign tree2[219] = (tree1[258] & tree1[255]) | (tree1[258] & tree1[256]) | (tree1[255] & tree1[256]);  // c30 fa.c
  assign tree2[220] = tree1[259] ^ tree1[260] ^ tree1[261];  // c31 fa.s
  assign tree2[221] = tree1[262] ^ tree1[263] ^ tree1[267];  // c31 fa.s
  assign tree2[222] = tree1[264] ^ tree1[265] ^ tree1[266];  // c31 fa.s
  assign tree2[223] = tree1[271] ^ tree1[268] ^ tree1[269];  // c31 fa.s

  // ---- tree3: Dadda level 3 ------------------------------------------------
  assign tree3[34:0] = tree2[34:0];  // c0..c9
  assign tree3[39:35] = tree2[41:37];  // c10
  assign tree3[40] = tree2[35] ^ tree2[36];  // c10 ha.s
  assign tree3[44:41] = tree2[47:44];  // c11
  assign tree3[45] = tree2[35] & tree2[36];  // c10 ha.c
  assign tree3[46] = tree2[42] ^ tree2[43];  // c11 ha.s
  assign tree3[49:47] = tree2[55:53];  // c12
  assign tree3[50] = tree2[42] & tree2[43];  // c11 ha.c
  assign tree3[51] = tree2[48] ^ tree2[49] ^ tree2[50];  // c12 fa.s
  assign tree3[52] = tree2[51] ^ tree2[52];  // c12 ha.s
  assign tree3[54:53] = tree2[62:61];  // c13
  assign tree3[55] = (tree2[48] & tree2[49]) | (tree2[48] & tree2[50]) | (tree2[49] & tree2[50]);  // c12 fa.c
  assign tree3[56] = tree2[51] & tree2[52];  // c12 ha.c
  assign tree3[57] = tree2[56] ^ tree2[57] ^ tree2[58];  // c13 fa.s
  assign tree3[58] = tree2[59] ^ tree2[60];  // c13 ha.s
  assign tree3[59] = tree2[71];  // c14
  assign tree3[60] = (tree2[56] & tree2[57]) | (tree2[56] & tree2[58]) | (tree2[57] & tree2[58]);  // c13 fa.c
  assign tree3[61] = tree2[59] & tree2[60];  // c13 ha.c
  assign tree3[62] = tree2[63] ^ tree2[64] ^ tree2[65];  // c14 fa.s
  assign tree3[63] = tree2[66] ^ tree2[67] ^ tree2[68];  // c14 fa.s
  assign tree3[64] = tree2[69] ^ tree2[70];  // c14 ha.s
  assign tree3[65] = (tree2[63] & tree2[64]) | (tree2[63] & tree2[65]) | (tree2[64] & tree2[65]);  // c14 fa.c
  assign tree3[66] = (tree2[66] & tree2[67]) | (tree2[66] & tree2[68]) | (tree2[67] & tree2[68]);  // c14 fa.c
  assign tree3[67] = tree2[69] & tree2[70];  // c14 ha.c
  assign tree3[68] = tree2[72] ^ tree2[73] ^ tree2[74];  // c15 fa.s
  assign tree3[69] = tree2[75] ^ tree2[76] ^ tree2[77];  // c15 fa.s
  assign tree3[70] = tree2[78] ^ tree2[79];  // c15 ha.s
  assign tree3[71] = (tree2[72] & tree2[73]) | (tree2[72] & tree2[74]) | (tree2[73] & tree2[74]);  // c15 fa.c
  assign tree3[72] = (tree2[75] & tree2[76]) | (tree2[75] & tree2[77]) | (tree2[76] & tree2[77]);  // c15 fa.c
  assign tree3[73] = tree2[78] & tree2[79];  // c15 ha.c
  assign tree3[74] = tree2[80] ^ tree2[81] ^ tree2[82];  // c16 fa.s
  assign tree3[75] = tree2[83] ^ tree2[84] ^ tree2[85];  // c16 fa.s
  assign tree3[76] = tree2[86] ^ tree2[87] ^ tree2[88];  // c16 fa.s
  assign tree3[77] = (tree2[80] & tree2[81]) | (tree2[80] & tree2[82]) | (tree2[81] & tree2[82]);  // c16 fa.c
  assign tree3[78] = (tree2[83] & tree2[84]) | (tree2[83] & tree2[85]) | (tree2[84] & tree2[85]);  // c16 fa.c
  assign tree3[79] = (tree2[86] & tree2[87]) | (tree2[86] & tree2[88]) | (tree2[87] & tree2[88]);  // c16 fa.c
  assign tree3[80] = tree2[89] ^ tree2[90] ^ tree2[91];  // c17 fa.s
  assign tree3[81] = tree2[92] ^ tree2[93] ^ tree2[94];  // c17 fa.s
  assign tree3[82] = tree2[95] ^ tree2[96] ^ tree2[97];  // c17 fa.s
  assign tree3[83] = (tree2[89] & tree2[90]) | (tree2[89] & tree2[91]) | (tree2[90] & tree2[91]);  // c17 fa.c
  assign tree3[84] = (tree2[92] & tree2[93]) | (tree2[92] & tree2[94]) | (tree2[93] & tree2[94]);  // c17 fa.c
  assign tree3[85] = (tree2[95] & tree2[96]) | (tree2[95] & tree2[97]) | (tree2[96] & tree2[97]);  // c17 fa.c
  assign tree3[86] = tree2[98] ^ tree2[99] ^ tree2[100];  // c18 fa.s
  assign tree3[87] = tree2[101] ^ tree2[102] ^ tree2[103];  // c18 fa.s
  assign tree3[88] = tree2[104] ^ tree2[106] ^ tree2[105];  // c18 fa.s
  assign tree3[89] = (tree2[98] & tree2[99]) | (tree2[98] & tree2[100]) | (tree2[99] & tree2[100]);  // c18 fa.c
  assign tree3[90] = (tree2[101] & tree2[102]) | (tree2[101] & tree2[103]) | (tree2[102] & tree2[103]);  // c18 fa.c
  assign tree3[91] = (tree2[104] & tree2[106]) | (tree2[104] & tree2[105]) | (tree2[106] & tree2[105]);  // c18 fa.c
  assign tree3[92] = tree2[107] ^ tree2[108] ^ tree2[109];  // c19 fa.s
  assign tree3[93] = tree2[110] ^ tree2[111] ^ tree2[113];  // c19 fa.s
  assign tree3[94] = tree2[112] ^ tree2[115] ^ tree2[114];  // c19 fa.s
  assign tree3[95] = (tree2[107] & tree2[108]) | (tree2[107] & tree2[109]) | (tree2[108] & tree2[109]);  // c19 fa.c
  assign tree3[96] = (tree2[110] & tree2[111]) | (tree2[110] & tree2[113]) | (tree2[111] & tree2[113]);  // c19 fa.c
  assign tree3[97] = (tree2[112] & tree2[115]) | (tree2[112] & tree2[114]) | (tree2[115] & tree2[114]);  // c19 fa.c
  assign tree3[98] = tree2[116] ^ tree2[117] ^ tree2[118];  // c20 fa.s
  assign tree3[99] = tree2[119] ^ tree2[121] ^ tree2[120];  // c20 fa.s
  assign tree3[100] = tree2[124] ^ tree2[122] ^ tree2[123];  // c20 fa.s
  assign tree3[101] = (tree2[116] & tree2[117]) | (tree2[116] & tree2[118]) | (tree2[117] & tree2[118]);  // c20 fa.c
  assign tree3[102] = (tree2[119] & tree2[121]) | (tree2[119] & tree2[120]) | (tree2[121] & tree2[120]);  // c20 fa.c
  assign tree3[103] = (tree2[124] & tree2[122]) | (tree2[124] & tree2[123]) | (tree2[122] & tree2[123]);  // c20 fa.c
  assign tree3[104] = tree2[125] ^ tree2[126] ^ tree2[127];  // c21 fa.s
  assign tree3[105] = tree2[130] ^ tree2[128] ^ tree2[129];  // c21 fa.s
  assign tree3[106] = tree2[133] ^ tree2[131] ^ tree2[132];  // c21 fa.s
  assign tree3[107] = (tree2[125] & tree2[126]) | (tree2[125] & tree2[127]) | (tree2[126] & tree2[127]);  // c21 fa.c
  assign tree3[108] = (tree2[130] & tree2[128]) | (tree2[130] & tree2[129]) | (tree2[128] & tree2[129]);  // c21 fa.c
  assign tree3[109] = (tree2[133] & tree2[131]) | (tree2[133] & tree2[132]) | (tree2[131] & tree2[132]);  // c21 fa.c
  assign tree3[110] = tree2[134] ^ tree2[135] ^ tree2[138];  // c22 fa.s
  assign tree3[111] = tree2[136] ^ tree2[137] ^ tree2[142];  // c22 fa.s
  assign tree3[112] = tree2[139] ^ tree2[140] ^ tree2[141];  // c22 fa.s
  assign tree3[113] = (tree2[134] & tree2[135]) | (tree2[134] & tree2[138]) | (tree2[135] & tree2[138]);  // c22 fa.c
  assign tree3[114] = (tree2[136] & tree2[137]) | (tree2[136] & tree2[142]) | (tree2[137] & tree2[142]);  // c22 fa.c
  assign tree3[115] = (tree2[139] & tree2[140]) | (tree2[139] & tree2[141]) | (tree2[140] & tree2[141]);  // c22 fa.c
  assign tree3[116] = tree2[143] ^ tree2[147] ^ tree2[144];  // c23 fa.s
  assign tree3[117] = tree2[145] ^ tree2[146] ^ tree2[151];  // c23 fa.s
  assign tree3[118] = tree2[148] ^ tree2[149] ^ tree2[150];  // c23 fa.s
  assign tree3[119] = (tree2[143] & tree2[147]) | (tree2[143] & tree2[144]) | (tree2[147] & tree2[144]);  // c23 fa.c
  assign tree3[120] = (tree2[145] & tree2[146]) | (tree2[145] & tree2[151]) | (tree2[146] & tree2[151]);  // c23 fa.c
  assign tree3[121] = (tree2[148] & tree2[149]) | (tree2[148] & tree2[150]) | (tree2[149] & tree2[150]);  // c23 fa.c
  assign tree3[122] = tree2[156] ^ tree2[152] ^ tree2[153];  // c24 fa.s
  assign tree3[123] = tree2[154] ^ tree2[155] ^ tree2[157];  // c24 fa.s
  assign tree3[124] = tree2[158] ^ tree2[159] ^ tree2[160];  // c24 fa.s
  assign tree3[125] = (tree2[156] & tree2[152]) | (tree2[156] & tree2[153]) | (tree2[152] & tree2[153]);  // c24 fa.c
  assign tree3[126] = (tree2[154] & tree2[155]) | (tree2[154] & tree2[157]) | (tree2[155] & tree2[157]);  // c24 fa.c
  assign tree3[127] = (tree2[158] & tree2[159]) | (tree2[158] & tree2[160]) | (tree2[159] & tree2[160]);  // c24 fa.c
  assign tree3[128] = tree2[161] ^ tree2[162] ^ tree2[163];  // c25 fa.s
  assign tree3[129] = tree2[164] ^ tree2[165] ^ tree2[166];  // c25 fa.s
  assign tree3[130] = tree2[167] ^ tree2[168] ^ tree2[169];  // c25 fa.s
  assign tree3[131] = (tree2[161] & tree2[162]) | (tree2[161] & tree2[163]) | (tree2[162] & tree2[163]);  // c25 fa.c
  assign tree3[132] = (tree2[164] & tree2[165]) | (tree2[164] & tree2[166]) | (tree2[165] & tree2[166]);  // c25 fa.c
  assign tree3[133] = (tree2[167] & tree2[168]) | (tree2[167] & tree2[169]) | (tree2[168] & tree2[169]);  // c25 fa.c
  assign tree3[134] = tree2[171] ^ tree2[172] ^ tree2[173];  // c26 fa.s
  assign tree3[135] = tree2[174] ^ tree2[170] ^ tree2[175];  // c26 fa.s
  assign tree3[136] = tree2[176] ^ tree2[177] ^ tree2[178];  // c26 fa.s
  assign tree3[137] = (tree2[171] & tree2[172]) | (tree2[171] & tree2[173]) | (tree2[172] & tree2[173]);  // c26 fa.c
  assign tree3[138] = (tree2[174] & tree2[170]) | (tree2[174] & tree2[175]) | (tree2[170] & tree2[175]);  // c26 fa.c
  assign tree3[139] = (tree2[176] & tree2[177]) | (tree2[176] & tree2[178]) | (tree2[177] & tree2[178]);  // c26 fa.c
  assign tree3[140] = tree2[180] ^ tree2[181] ^ tree2[182];  // c27 fa.s
  assign tree3[141] = tree2[179] ^ tree2[183] ^ tree2[184];  // c27 fa.s
  assign tree3[142] = tree2[185] ^ tree2[186] ^ tree2[187];  // c27 fa.s
  assign tree3[143] = (tree2[180] & tree2[181]) | (tree2[180] & tree2[182]) | (tree2[181] & tree2[182]);  // c27 fa.c
  assign tree3[144] = (tree2[179] & tree2[183]) | (tree2[179] & tree2[184]) | (tree2[183] & tree2[184]);  // c27 fa.c
  assign tree3[145] = (tree2[185] & tree2[186]) | (tree2[185] & tree2[187]) | (tree2[186] & tree2[187]);  // c27 fa.c
  assign tree3[146] = tree2[189] ^ tree2[190] ^ tree2[191];  // c28 fa.s
  assign tree3[147] = tree2[188] ^ tree2[192] ^ tree2[193];  // c28 fa.s
  assign tree3[148] = tree2[194] ^ tree2[195] ^ tree2[196];  // c28 fa.s
  assign tree3[149] = (tree2[189] & tree2[190]) | (tree2[189] & tree2[191]) | (tree2[190] & tree2[191]);  // c28 fa.c
  assign tree3[150] = (tree2[188] & tree2[192]) | (tree2[188] & tree2[193]) | (tree2[192] & tree2[193]);  // c28 fa.c
  assign tree3[151] = (tree2[194] & tree2[195]) | (tree2[194] & tree2[196]) | (tree2[195] & tree2[196]);  // c28 fa.c
  assign tree3[152] = tree2[198] ^ tree2[199] ^ tree2[200];  // c29 fa.s
  assign tree3[153] = tree2[197] ^ tree2[202] ^ tree2[203];  // c29 fa.s
  assign tree3[154] = tree2[201] ^ tree2[204] ^ tree2[205];  // c29 fa.s
  assign tree3[155] = (tree2[198] & tree2[199]) | (tree2[198] & tree2[200]) | (tree2[199] & tree2[200]);  // c29 fa.c
  assign tree3[156] = (tree2[197] & tree2[202]) | (tree2[197] & tree2[203]) | (tree2[202] & tree2[203]);  // c29 fa.c
  assign tree3[157] = (tree2[201] & tree2[204]) | (tree2[201] & tree2[205]) | (tree2[204] & tree2[205]);  // c29 fa.c
  assign tree3[158] = tree2[207] ^ tree2[208] ^ tree2[206];  // c30 fa.s
  assign tree3[159] = tree2[209] ^ tree2[211] ^ tree2[212];  // c30 fa.s
  assign tree3[160] = tree2[210] ^ tree2[213] ^ tree2[214];  // c30 fa.s
  assign tree3[161] = (tree2[207] & tree2[208]) | (tree2[207] & tree2[206]) | (tree2[208] & tree2[206]);  // c30 fa.c
  assign tree3[162] = (tree2[209] & tree2[211]) | (tree2[209] & tree2[212]) | (tree2[211] & tree2[212]);  // c30 fa.c
  assign tree3[163] = (tree2[210] & tree2[213]) | (tree2[210] & tree2[214]) | (tree2[213] & tree2[214]);  // c30 fa.c
  assign tree3[164] = tree2[216] ^ tree2[217] ^ tree2[215];  // c31 fa.s
  assign tree3[165] = tree2[218] ^ tree2[220] ^ tree2[221];  // c31 fa.s
  assign tree3[166] = tree2[219] ^ tree2[222] ^ tree2[223];  // c31 fa.s

  // ---- tree4: Dadda level 4 ------------------------------------------------
  assign tree4_d[14:0] = tree3[14:0];  // c0..c5
  assign tree4_d[17:15] = tree3[19:17];  // c6
  assign tree4_d[18] = tree3[15] ^ tree3[16];  // c6 ha.s
  assign tree4_d[20:19] = tree3[23:22];  // c7
  assign tree4_d[21] = tree3[15] & tree3[16];  // c6 ha.c
  assign tree4_d[22] = tree3[20] ^ tree3[21];  // c7 ha.s
  assign tree4_d[23] = tree3[29];  // c8
  assign tree4_d[24] = tree3[20] & tree3[21];  // c7 ha.c
  assign tree4_d[25] = tree3[24] ^ tree3[25] ^ tree3[26];  // c8 fa.s
  assign tree4_d[26] = tree3[27] ^ tree3[28];  // c8 ha.s
  assign tree4_d[27] = (tree3[24] & tree3[25]) | (tree3[24] & tree3[26]) | (tree3[25] & tree3[26]);  // c8 fa.c
  assign tree4_d[28] = tree3[27] & tree3[28];  // c8 ha.c
  assign tree4_d[29] = tree3[30] ^ tree3[31] ^ tree3[32];  // c9 fa.s
  assign tree4_d[30] = tree3[33] ^ tree3[34];  // c9 ha.s
  assign tree4_d[31] = (tree3[30] & tree3[31]) | (tree3[30] & tree3[32]) | (tree3[31] & tree3[32]);  // c9 fa.c
  assign tree4_d[32] = tree3[33] & tree3[34];  // c9 ha.c
  assign tree4_d[33] = tree3[35] ^ tree3[36] ^ tree3[37];  // c10 fa.s
  assign tree4_d[34] = tree3[38] ^ tree3[39] ^ tree3[40];  // c10 fa.s
  assign tree4_d[35] = (tree3[35] & tree3[36]) | (tree3[35] & tree3[37]) | (tree3[36] & tree3[37]);  // c10 fa.c
  assign tree4_d[36] = (tree3[38] & tree3[39]) | (tree3[38] & tree3[40]) | (tree3[39] & tree3[40]);  // c10 fa.c
  assign tree4_d[37] = tree3[41] ^ tree3[42] ^ tree3[43];  // c11 fa.s
  assign tree4_d[38] = tree3[44] ^ tree3[45] ^ tree3[46];  // c11 fa.s
  assign tree4_d[39] = (tree3[41] & tree3[42]) | (tree3[41] & tree3[43]) | (tree3[42] & tree3[43]);  // c11 fa.c
  assign tree4_d[40] = (tree3[44] & tree3[45]) | (tree3[44] & tree3[46]) | (tree3[45] & tree3[46]);  // c11 fa.c
  assign tree4_d[41] = tree3[47] ^ tree3[48] ^ tree3[49];  // c12 fa.s
  assign tree4_d[42] = tree3[50] ^ tree3[52] ^ tree3[51];  // c12 fa.s
  assign tree4_d[43] = (tree3[47] & tree3[48]) | (tree3[47] & tree3[49]) | (tree3[48] & tree3[49]);  // c12 fa.c
  assign tree4_d[44] = (tree3[50] & tree3[52]) | (tree3[50] & tree3[51]) | (tree3[52] & tree3[51]);  // c12 fa.c
  assign tree4_d[45] = tree3[53] ^ tree3[54] ^ tree3[56];  // c13 fa.s
  assign tree4_d[46] = tree3[55] ^ tree3[58] ^ tree3[57];  // c13 fa.s
  assign tree4_d[47] = (tree3[53] & tree3[54]) | (tree3[53] & tree3[56]) | (tree3[54] & tree3[56]);  // c13 fa.c
  assign tree4_d[48] = (tree3[55] & tree3[58]) | (tree3[55] & tree3[57]) | (tree3[58] & tree3[57]);  // c13 fa.c
  assign tree4_d[49] = tree3[59] ^ tree3[61] ^ tree3[60];  // c14 fa.s
  assign tree4_d[50] = tree3[64] ^ tree3[62] ^ tree3[63];  // c14 fa.s
  assign tree4_d[51] = (tree3[59] & tree3[61]) | (tree3[59] & tree3[60]) | (tree3[61] & tree3[60]);  // c14 fa.c
  assign tree4_d[52] = (tree3[64] & tree3[62]) | (tree3[64] & tree3[63]) | (tree3[62] & tree3[63]);  // c14 fa.c
  assign tree4_d[53] = tree3[67] ^ tree3[65] ^ tree3[66];  // c15 fa.s
  assign tree4_d[54] = tree3[70] ^ tree3[68] ^ tree3[69];  // c15 fa.s
  assign tree4_d[55] = (tree3[67] & tree3[65]) | (tree3[67] & tree3[66]) | (tree3[65] & tree3[66]);  // c15 fa.c
  assign tree4_d[56] = (tree3[70] & tree3[68]) | (tree3[70] & tree3[69]) | (tree3[68] & tree3[69]);  // c15 fa.c
  assign tree4_d[57] = tree3[73] ^ tree3[71] ^ tree3[72];  // c16 fa.s
  assign tree4_d[58] = tree3[74] ^ tree3[75] ^ tree3[76];  // c16 fa.s
  assign tree4_d[59] = (tree3[73] & tree3[71]) | (tree3[73] & tree3[72]) | (tree3[71] & tree3[72]);  // c16 fa.c
  assign tree4_d[60] = (tree3[74] & tree3[75]) | (tree3[74] & tree3[76]) | (tree3[75] & tree3[76]);  // c16 fa.c
  assign tree4_d[61] = tree3[77] ^ tree3[78] ^ tree3[79];  // c17 fa.s
  assign tree4_d[62] = tree3[80] ^ tree3[81] ^ tree3[82];  // c17 fa.s
  assign tree4_d[63] = (tree3[77] & tree3[78]) | (tree3[77] & tree3[79]) | (tree3[78] & tree3[79]);  // c17 fa.c
  assign tree4_d[64] = (tree3[80] & tree3[81]) | (tree3[80] & tree3[82]) | (tree3[81] & tree3[82]);  // c17 fa.c
  assign tree4_d[65] = tree3[83] ^ tree3[84] ^ tree3[85];  // c18 fa.s
  assign tree4_d[66] = tree3[86] ^ tree3[87] ^ tree3[88];  // c18 fa.s
  assign tree4_d[67] = (tree3[83] & tree3[84]) | (tree3[83] & tree3[85]) | (tree3[84] & tree3[85]);  // c18 fa.c
  assign tree4_d[68] = (tree3[86] & tree3[87]) | (tree3[86] & tree3[88]) | (tree3[87] & tree3[88]);  // c18 fa.c
  assign tree4_d[69] = tree3[89] ^ tree3[90] ^ tree3[92];  // c19 fa.s
  assign tree4_d[70] = tree3[93] ^ tree3[91] ^ tree3[94];  // c19 fa.s
  assign tree4_d[71] = (tree3[89] & tree3[90]) | (tree3[89] & tree3[92]) | (tree3[90] & tree3[92]);  // c19 fa.c
  assign tree4_d[72] = (tree3[93] & tree3[91]) | (tree3[93] & tree3[94]) | (tree3[91] & tree3[94]);  // c19 fa.c
  assign tree4_d[73] = tree3[95] ^ tree3[96] ^ tree3[98];  // c20 fa.s
  assign tree4_d[74] = tree3[97] ^ tree3[99] ^ tree3[100];  // c20 fa.s
  assign tree4_d[75] = (tree3[95] & tree3[96]) | (tree3[95] & tree3[98]) | (tree3[96] & tree3[98]);  // c20 fa.c
  assign tree4_d[76] = (tree3[97] & tree3[99]) | (tree3[97] & tree3[100]) | (tree3[99] & tree3[100]);  // c20 fa.c
  assign tree4_d[77] = tree3[101] ^ tree3[102] ^ tree3[104];  // c21 fa.s
  assign tree4_d[78] = tree3[103] ^ tree3[105] ^ tree3[106];  // c21 fa.s
  assign tree4_d[79] = (tree3[101] & tree3[102]) | (tree3[101] & tree3[104]) | (tree3[102] & tree3[104]);  // c21 fa.c
  assign tree4_d[80] = (tree3[103] & tree3[105]) | (tree3[103] & tree3[106]) | (tree3[105] & tree3[106]);  // c21 fa.c
  assign tree4_d[81] = tree3[107] ^ tree3[108] ^ tree3[110];  // c22 fa.s
  assign tree4_d[82] = tree3[109] ^ tree3[111] ^ tree3[112];  // c22 fa.s
  assign tree4_d[83] = (tree3[107] & tree3[108]) | (tree3[107] & tree3[110]) | (tree3[108] & tree3[110]);  // c22 fa.c
  assign tree4_d[84] = (tree3[109] & tree3[111]) | (tree3[109] & tree3[112]) | (tree3[111] & tree3[112]);  // c22 fa.c
  assign tree4_d[85] = tree3[113] ^ tree3[114] ^ tree3[115];  // c23 fa.s
  assign tree4_d[86] = tree3[116] ^ tree3[117] ^ tree3[118];  // c23 fa.s
  assign tree4_d[87] = (tree3[113] & tree3[114]) | (tree3[113] & tree3[115]) | (tree3[114] & tree3[115]);  // c23 fa.c
  assign tree4_d[88] = (tree3[116] & tree3[117]) | (tree3[116] & tree3[118]) | (tree3[117] & tree3[118]);  // c23 fa.c
  assign tree4_d[89] = tree3[119] ^ tree3[120] ^ tree3[121];  // c24 fa.s
  assign tree4_d[90] = tree3[122] ^ tree3[123] ^ tree3[124];  // c24 fa.s
  assign tree4_d[91] = (tree3[119] & tree3[120]) | (tree3[119] & tree3[121]) | (tree3[120] & tree3[121]);  // c24 fa.c
  assign tree4_d[92] = (tree3[122] & tree3[123]) | (tree3[122] & tree3[124]) | (tree3[123] & tree3[124]);  // c24 fa.c
  assign tree4_d[93] = tree3[125] ^ tree3[126] ^ tree3[127];  // c25 fa.s
  assign tree4_d[94] = tree3[128] ^ tree3[129] ^ tree3[130];  // c25 fa.s
  assign tree4_d[95] = (tree3[125] & tree3[126]) | (tree3[125] & tree3[127]) | (tree3[126] & tree3[127]);  // c25 fa.c
  assign tree4_d[96] = (tree3[128] & tree3[129]) | (tree3[128] & tree3[130]) | (tree3[129] & tree3[130]);  // c25 fa.c
  assign tree4_d[97] = tree3[131] ^ tree3[132] ^ tree3[134];  // c26 fa.s
  assign tree4_d[98] = tree3[133] ^ tree3[135] ^ tree3[136];  // c26 fa.s
  assign tree4_d[99] = (tree3[131] & tree3[132]) | (tree3[131] & tree3[134]) | (tree3[132] & tree3[134]);  // c26 fa.c
  assign tree4_d[100] = (tree3[133] & tree3[135]) | (tree3[133] & tree3[136]) | (tree3[135] & tree3[136]);  // c26 fa.c
  assign tree4_d[101] = tree3[137] ^ tree3[138] ^ tree3[140];  // c27 fa.s
  assign tree4_d[102] = tree3[139] ^ tree3[141] ^ tree3[142];  // c27 fa.s
  assign tree4_d[103] = (tree3[137] & tree3[138]) | (tree3[137] & tree3[140]) | (tree3[138] & tree3[140]);  // c27 fa.c
  assign tree4_d[104] = (tree3[139] & tree3[141]) | (tree3[139] & tree3[142]) | (tree3[141] & tree3[142]);  // c27 fa.c
  assign tree4_d[105] = tree3[143] ^ tree3[144] ^ tree3[146];  // c28 fa.s
  assign tree4_d[106] = tree3[145] ^ tree3[147] ^ tree3[148];  // c28 fa.s
  assign tree4_d[107] = (tree3[143] & tree3[144]) | (tree3[143] & tree3[146]) | (tree3[144] & tree3[146]);  // c28 fa.c
  assign tree4_d[108] = (tree3[145] & tree3[147]) | (tree3[145] & tree3[148]) | (tree3[147] & tree3[148]);  // c28 fa.c
  assign tree4_d[109] = tree3[149] ^ tree3[150] ^ tree3[152];  // c29 fa.s
  assign tree4_d[110] = tree3[153] ^ tree3[151] ^ tree3[154];  // c29 fa.s
  assign tree4_d[111] = (tree3[149] & tree3[150]) | (tree3[149] & tree3[152]) | (tree3[150] & tree3[152]);  // c29 fa.c
  assign tree4_d[112] = (tree3[153] & tree3[151]) | (tree3[153] & tree3[154]) | (tree3[151] & tree3[154]);  // c29 fa.c
  assign tree4_d[113] = tree3[155] ^ tree3[156] ^ tree3[158];  // c30 fa.s
  assign tree4_d[114] = tree3[159] ^ tree3[157] ^ tree3[160];  // c30 fa.s
  assign tree4_d[115] = (tree3[155] & tree3[156]) | (tree3[155] & tree3[158]) | (tree3[156] & tree3[158]);  // c30 fa.c
  assign tree4_d[116] = (tree3[159] & tree3[157]) | (tree3[159] & tree3[160]) | (tree3[157] & tree3[160]);  // c30 fa.c
  assign tree4_d[117] = tree3[161] ^ tree3[162] ^ tree3[164];  // c31 fa.s
  assign tree4_d[118] = tree3[165] ^ tree3[163] ^ tree3[166];  // c31 fa.s
  if (LATENCY == 1) begin : g_tree4_l1
    basechili_dffe_cg #(.WIDTH(119), .GATE(CLOCK_GATE)) u_stg1_tree4 (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .en      (vld[0]),
      .d       (tree4_d),
      .q       (tree4)
    );
  end else begin : g_tree4_wire
    assign tree4 = tree4_d;
  end

  // ---- tree5: Dadda level 5 ------------------------------------------------
  assign tree5[7:0] = tree4[7:0];  // c0..c3
  assign tree5[9:8] = tree4[11:10];  // c4
  assign tree5[10] = tree4[8] ^ tree4[9];  // c4 ha.s
  assign tree5[11] = tree4[14];  // c5
  assign tree5[12] = tree4[8] & tree4[9];  // c4 ha.c
  assign tree5[13] = tree4[12] ^ tree4[13];  // c5 ha.s
  assign tree5[14] = tree4[18];  // c6
  assign tree5[15] = tree4[12] & tree4[13];  // c5 ha.c
  assign tree5[16] = tree4[15] ^ tree4[16] ^ tree4[17];  // c6 fa.s
  assign tree5[17] = tree4[22];  // c7
  assign tree5[18] = (tree4[15] & tree4[16]) | (tree4[15] & tree4[17]) | (tree4[16] & tree4[17]);  // c6 fa.c
  assign tree5[19] = tree4[19] ^ tree4[20] ^ tree4[21];  // c7 fa.s
  assign tree5[20] = tree4[25];  // c8
  assign tree5[21] = (tree4[19] & tree4[20]) | (tree4[19] & tree4[21]) | (tree4[20] & tree4[21]);  // c7 fa.c
  assign tree5[22] = tree4[23] ^ tree4[24] ^ tree4[26];  // c8 fa.s
  assign tree5[23] = tree4[29];  // c9
  assign tree5[24] = (tree4[23] & tree4[24]) | (tree4[23] & tree4[26]) | (tree4[24] & tree4[26]);  // c8 fa.c
  assign tree5[25] = tree4[28] ^ tree4[27] ^ tree4[30];  // c9 fa.s
  assign tree5[26] = tree4[34];  // c10
  assign tree5[27] = (tree4[28] & tree4[27]) | (tree4[28] & tree4[30]) | (tree4[27] & tree4[30]);  // c9 fa.c
  assign tree5[28] = tree4[32] ^ tree4[31] ^ tree4[33];  // c10 fa.s
  assign tree5[29] = tree4[38];  // c11
  assign tree5[30] = (tree4[32] & tree4[31]) | (tree4[32] & tree4[33]) | (tree4[31] & tree4[33]);  // c10 fa.c
  assign tree5[31] = tree4[35] ^ tree4[36] ^ tree4[37];  // c11 fa.s
  assign tree5[32] = tree4[42];  // c12
  assign tree5[33] = (tree4[35] & tree4[36]) | (tree4[35] & tree4[37]) | (tree4[36] & tree4[37]);  // c11 fa.c
  assign tree5[34] = tree4[39] ^ tree4[40] ^ tree4[41];  // c12 fa.s
  assign tree5[35] = tree4[46];  // c13
  assign tree5[36] = (tree4[39] & tree4[40]) | (tree4[39] & tree4[41]) | (tree4[40] & tree4[41]);  // c12 fa.c
  assign tree5[37] = tree4[43] ^ tree4[45] ^ tree4[44];  // c13 fa.s
  assign tree5[38] = tree4[50];  // c14
  assign tree5[39] = (tree4[43] & tree4[45]) | (tree4[43] & tree4[44]) | (tree4[45] & tree4[44]);  // c13 fa.c
  assign tree5[40] = tree4[47] ^ tree4[48] ^ tree4[49];  // c14 fa.s
  assign tree5[41] = tree4[54];  // c15
  assign tree5[42] = (tree4[47] & tree4[48]) | (tree4[47] & tree4[49]) | (tree4[48] & tree4[49]);  // c14 fa.c
  assign tree5[43] = tree4[51] ^ tree4[52] ^ tree4[53];  // c15 fa.s
  assign tree5[44] = tree4[58];  // c16
  assign tree5[45] = (tree4[51] & tree4[52]) | (tree4[51] & tree4[53]) | (tree4[52] & tree4[53]);  // c15 fa.c
  assign tree5[46] = tree4[55] ^ tree4[56] ^ tree4[57];  // c16 fa.s
  assign tree5[47] = tree4[62];  // c17
  assign tree5[48] = (tree4[55] & tree4[56]) | (tree4[55] & tree4[57]) | (tree4[56] & tree4[57]);  // c16 fa.c
  assign tree5[49] = tree4[59] ^ tree4[60] ^ tree4[61];  // c17 fa.s
  assign tree5[50] = tree4[66];  // c18
  assign tree5[51] = (tree4[59] & tree4[60]) | (tree4[59] & tree4[61]) | (tree4[60] & tree4[61]);  // c17 fa.c
  assign tree5[52] = tree4[63] ^ tree4[64] ^ tree4[65];  // c18 fa.s
  assign tree5[53] = tree4[70];  // c19
  assign tree5[54] = (tree4[63] & tree4[64]) | (tree4[63] & tree4[65]) | (tree4[64] & tree4[65]);  // c18 fa.c
  assign tree5[55] = tree4[67] ^ tree4[69] ^ tree4[68];  // c19 fa.s
  assign tree5[56] = tree4[74];  // c20
  assign tree5[57] = (tree4[67] & tree4[69]) | (tree4[67] & tree4[68]) | (tree4[69] & tree4[68]);  // c19 fa.c
  assign tree5[58] = tree4[71] ^ tree4[73] ^ tree4[72];  // c20 fa.s
  assign tree5[59] = tree4[78];  // c21
  assign tree5[60] = (tree4[71] & tree4[73]) | (tree4[71] & tree4[72]) | (tree4[73] & tree4[72]);  // c20 fa.c
  assign tree5[61] = tree4[75] ^ tree4[77] ^ tree4[76];  // c21 fa.s
  assign tree5[62] = tree4[82];  // c22
  assign tree5[63] = (tree4[75] & tree4[77]) | (tree4[75] & tree4[76]) | (tree4[77] & tree4[76]);  // c21 fa.c
  assign tree5[64] = tree4[79] ^ tree4[81] ^ tree4[80];  // c22 fa.s
  assign tree5[65] = tree4[86];  // c23
  assign tree5[66] = (tree4[79] & tree4[81]) | (tree4[79] & tree4[80]) | (tree4[81] & tree4[80]);  // c22 fa.c
  assign tree5[67] = tree4[83] ^ tree4[84] ^ tree4[85];  // c23 fa.s
  assign tree5[68] = tree4[90];  // c24
  assign tree5[69] = (tree4[83] & tree4[84]) | (tree4[83] & tree4[85]) | (tree4[84] & tree4[85]);  // c23 fa.c
  assign tree5[70] = tree4[87] ^ tree4[88] ^ tree4[89];  // c24 fa.s
  assign tree5[71] = tree4[94];  // c25
  assign tree5[72] = (tree4[87] & tree4[88]) | (tree4[87] & tree4[89]) | (tree4[88] & tree4[89]);  // c24 fa.c
  assign tree5[73] = tree4[91] ^ tree4[92] ^ tree4[93];  // c25 fa.s
  assign tree5[74] = tree4[98];  // c26
  assign tree5[75] = (tree4[91] & tree4[92]) | (tree4[91] & tree4[93]) | (tree4[92] & tree4[93]);  // c25 fa.c
  assign tree5[76] = tree4[95] ^ tree4[97] ^ tree4[96];  // c26 fa.s
  assign tree5[77] = tree4[102];  // c27
  assign tree5[78] = (tree4[95] & tree4[97]) | (tree4[95] & tree4[96]) | (tree4[97] & tree4[96]);  // c26 fa.c
  assign tree5[79] = tree4[99] ^ tree4[101] ^ tree4[100];  // c27 fa.s
  assign tree5[80] = tree4[106];  // c28
  assign tree5[81] = (tree4[99] & tree4[101]) | (tree4[99] & tree4[100]) | (tree4[101] & tree4[100]);  // c27 fa.c
  assign tree5[82] = tree4[103] ^ tree4[105] ^ tree4[104];  // c28 fa.s
  assign tree5[83] = tree4[110];  // c29
  assign tree5[84] = (tree4[103] & tree4[105]) | (tree4[103] & tree4[104]) | (tree4[105] & tree4[104]);  // c28 fa.c
  assign tree5[85] = tree4[107] ^ tree4[109] ^ tree4[108];  // c29 fa.s
  assign tree5[86] = tree4[114];  // c30
  assign tree5[87] = (tree4[107] & tree4[109]) | (tree4[107] & tree4[108]) | (tree4[109] & tree4[108]);  // c29 fa.c
  assign tree5[88] = tree4[111] ^ tree4[113] ^ tree4[112];  // c30 fa.s
  assign tree5[89] = tree4[118];  // c31
  assign tree5[90] = (tree4[111] & tree4[113]) | (tree4[111] & tree4[112]) | (tree4[113] & tree4[112]);  // c30 fa.c
  assign tree5[91] = tree4[115] ^ tree4[117] ^ tree4[116];  // c31 fa.s

  // ---- tree6: Dadda level 6 ------------------------------------------------
  assign tree6_d[2:0] = tree5[2:0];  // c0..c1
  assign tree6_d[3] = tree5[5];  // c2
  assign tree6_d[4] = tree5[3] ^ tree5[4];  // c2 ha.s
  assign tree6_d[5] = tree5[3] & tree5[4];  // c2 ha.c
  assign tree6_d[6] = tree5[6] ^ tree5[7];  // c3 ha.s
  assign tree6_d[7] = tree5[6] & tree5[7];  // c3 ha.c
  assign tree6_d[8] = tree5[8] ^ tree5[9] ^ tree5[10];  // c4 fa.s
  assign tree6_d[9] = (tree5[8] & tree5[9]) | (tree5[8] & tree5[10]) | (tree5[9] & tree5[10]);  // c4 fa.c
  assign tree6_d[10] = tree5[11] ^ tree5[12] ^ tree5[13];  // c5 fa.s
  assign tree6_d[11] = (tree5[11] & tree5[12]) | (tree5[11] & tree5[13]) | (tree5[12] & tree5[13]);  // c5 fa.c
  assign tree6_d[12] = tree5[15] ^ tree5[14] ^ tree5[16];  // c6 fa.s
  assign tree6_d[13] = (tree5[15] & tree5[14]) | (tree5[15] & tree5[16]) | (tree5[14] & tree5[16]);  // c6 fa.c
  assign tree6_d[14] = tree5[17] ^ tree5[18] ^ tree5[19];  // c7 fa.s
  assign tree6_d[15] = (tree5[17] & tree5[18]) | (tree5[17] & tree5[19]) | (tree5[18] & tree5[19]);  // c7 fa.c
  assign tree6_d[16] = tree5[21] ^ tree5[20] ^ tree5[22];  // c8 fa.s
  assign tree6_d[17] = (tree5[21] & tree5[20]) | (tree5[21] & tree5[22]) | (tree5[20] & tree5[22]);  // c8 fa.c
  assign tree6_d[18] = tree5[23] ^ tree5[24] ^ tree5[25];  // c9 fa.s
  assign tree6_d[19] = (tree5[23] & tree5[24]) | (tree5[23] & tree5[25]) | (tree5[24] & tree5[25]);  // c9 fa.c
  assign tree6_d[20] = tree5[27] ^ tree5[26] ^ tree5[28];  // c10 fa.s
  assign tree6_d[21] = (tree5[27] & tree5[26]) | (tree5[27] & tree5[28]) | (tree5[26] & tree5[28]);  // c10 fa.c
  assign tree6_d[22] = tree5[29] ^ tree5[30] ^ tree5[31];  // c11 fa.s
  assign tree6_d[23] = (tree5[29] & tree5[30]) | (tree5[29] & tree5[31]) | (tree5[30] & tree5[31]);  // c11 fa.c
  assign tree6_d[24] = tree5[33] ^ tree5[32] ^ tree5[34];  // c12 fa.s
  assign tree6_d[25] = (tree5[33] & tree5[32]) | (tree5[33] & tree5[34]) | (tree5[32] & tree5[34]);  // c12 fa.c
  assign tree6_d[26] = tree5[36] ^ tree5[35] ^ tree5[37];  // c13 fa.s
  assign tree6_d[27] = (tree5[36] & tree5[35]) | (tree5[36] & tree5[37]) | (tree5[35] & tree5[37]);  // c13 fa.c
  assign tree6_d[28] = tree5[38] ^ tree5[39] ^ tree5[40];  // c14 fa.s
  assign tree6_d[29] = (tree5[38] & tree5[39]) | (tree5[38] & tree5[40]) | (tree5[39] & tree5[40]);  // c14 fa.c
  assign tree6_d[30] = tree5[41] ^ tree5[42] ^ tree5[43];  // c15 fa.s
  assign tree6_d[31] = (tree5[41] & tree5[42]) | (tree5[41] & tree5[43]) | (tree5[42] & tree5[43]);  // c15 fa.c
  assign tree6_d[32] = tree5[45] ^ tree5[44] ^ tree5[46];  // c16 fa.s
  assign tree6_d[33] = (tree5[45] & tree5[44]) | (tree5[45] & tree5[46]) | (tree5[44] & tree5[46]);  // c16 fa.c
  assign tree6_d[34] = tree5[48] ^ tree5[47] ^ tree5[49];  // c17 fa.s
  assign tree6_d[35] = (tree5[48] & tree5[47]) | (tree5[48] & tree5[49]) | (tree5[47] & tree5[49]);  // c17 fa.c
  assign tree6_d[36] = tree5[51] ^ tree5[50] ^ tree5[52];  // c18 fa.s
  assign tree6_d[37] = (tree5[51] & tree5[50]) | (tree5[51] & tree5[52]) | (tree5[50] & tree5[52]);  // c18 fa.c
  assign tree6_d[38] = tree5[54] ^ tree5[53] ^ tree5[55];  // c19 fa.s
  assign tree6_d[39] = (tree5[54] & tree5[53]) | (tree5[54] & tree5[55]) | (tree5[53] & tree5[55]);  // c19 fa.c
  assign tree6_d[40] = tree5[56] ^ tree5[57] ^ tree5[58];  // c20 fa.s
  assign tree6_d[41] = (tree5[56] & tree5[57]) | (tree5[56] & tree5[58]) | (tree5[57] & tree5[58]);  // c20 fa.c
  assign tree6_d[42] = tree5[59] ^ tree5[60] ^ tree5[61];  // c21 fa.s
  assign tree6_d[43] = (tree5[59] & tree5[60]) | (tree5[59] & tree5[61]) | (tree5[60] & tree5[61]);  // c21 fa.c
  assign tree6_d[44] = tree5[62] ^ tree5[63] ^ tree5[64];  // c22 fa.s
  assign tree6_d[45] = (tree5[62] & tree5[63]) | (tree5[62] & tree5[64]) | (tree5[63] & tree5[64]);  // c22 fa.c
  assign tree6_d[46] = tree5[65] ^ tree5[66] ^ tree5[67];  // c23 fa.s
  assign tree6_d[47] = (tree5[65] & tree5[66]) | (tree5[65] & tree5[67]) | (tree5[66] & tree5[67]);  // c23 fa.c
  assign tree6_d[48] = tree5[68] ^ tree5[69] ^ tree5[70];  // c24 fa.s
  assign tree6_d[49] = (tree5[68] & tree5[69]) | (tree5[68] & tree5[70]) | (tree5[69] & tree5[70]);  // c24 fa.c
  assign tree6_d[50] = tree5[72] ^ tree5[71] ^ tree5[73];  // c25 fa.s
  assign tree6_d[51] = (tree5[72] & tree5[71]) | (tree5[72] & tree5[73]) | (tree5[71] & tree5[73]);  // c25 fa.c
  assign tree6_d[52] = tree5[75] ^ tree5[74] ^ tree5[76];  // c26 fa.s
  assign tree6_d[53] = (tree5[75] & tree5[74]) | (tree5[75] & tree5[76]) | (tree5[74] & tree5[76]);  // c26 fa.c
  assign tree6_d[54] = tree5[78] ^ tree5[77] ^ tree5[79];  // c27 fa.s
  assign tree6_d[55] = (tree5[78] & tree5[77]) | (tree5[78] & tree5[79]) | (tree5[77] & tree5[79]);  // c27 fa.c
  assign tree6_d[56] = tree5[81] ^ tree5[80] ^ tree5[82];  // c28 fa.s
  assign tree6_d[57] = (tree5[81] & tree5[80]) | (tree5[81] & tree5[82]) | (tree5[80] & tree5[82]);  // c28 fa.c
  assign tree6_d[58] = tree5[84] ^ tree5[83] ^ tree5[85];  // c29 fa.s
  assign tree6_d[59] = (tree5[84] & tree5[83]) | (tree5[84] & tree5[85]) | (tree5[83] & tree5[85]);  // c29 fa.c
  assign tree6_d[60] = tree5[86] ^ tree5[87] ^ tree5[88];  // c30 fa.s
  assign tree6_d[61] = (tree5[86] & tree5[87]) | (tree5[86] & tree5[88]) | (tree5[87] & tree5[88]);  // c30 fa.c
  assign tree6_d[62] = tree5[89] ^ tree5[90] ^ tree5[91];  // c31 fa.s
  if (LATENCY == 2) begin : g_tree6_l2
    basechili_dffe_cg #(.WIDTH(63), .GATE(CLOCK_GATE)) u_stg2_tree6 (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .en      (vld[1]),
      .d       (tree6_d),
      .q       (tree6)
    );
  end else begin : g_tree6_wire
    assign tree6 = tree6_d;
  end

  // ---- pg: generate / propagate --------------------------------------------
  assign pg[0] = tree6[0] & tree6[1];  // g0
  assign pg[1] = tree6[0] ^ tree6[1];  // p0
  assign pg[2] = tree6[2];  // c1
  assign pg[3] = tree6[4] & tree6[3];  // g2
  assign pg[4] = tree6[4] ^ tree6[3];  // p2
  assign pg[5] = tree6[5] & tree6[6];  // g3
  assign pg[6] = tree6[5] ^ tree6[6];  // p3
  assign pg[7] = tree6[7] & tree6[8];  // g4
  assign pg[8] = tree6[7] ^ tree6[8];  // p4
  assign pg[9] = tree6[9] & tree6[10];  // g5
  assign pg[10] = tree6[9] ^ tree6[10];  // p5
  assign pg[11] = tree6[11] & tree6[12];  // g6
  assign pg[12] = tree6[11] ^ tree6[12];  // p6
  assign pg[13] = tree6[13] & tree6[14];  // g7
  assign pg[14] = tree6[13] ^ tree6[14];  // p7
  assign pg[15] = tree6[15] & tree6[16];  // g8
  assign pg[16] = tree6[15] ^ tree6[16];  // p8
  assign pg[17] = tree6[17] & tree6[18];  // g9
  assign pg[18] = tree6[17] ^ tree6[18];  // p9
  assign pg[19] = tree6[19] & tree6[20];  // g10
  assign pg[20] = tree6[19] ^ tree6[20];  // p10
  assign pg[21] = tree6[21] & tree6[22];  // g11
  assign pg[22] = tree6[21] ^ tree6[22];  // p11
  assign pg[23] = tree6[23] & tree6[24];  // g12
  assign pg[24] = tree6[23] ^ tree6[24];  // p12
  assign pg[25] = tree6[25] & tree6[26];  // g13
  assign pg[26] = tree6[25] ^ tree6[26];  // p13
  assign pg[27] = tree6[27] & tree6[28];  // g14
  assign pg[28] = tree6[27] ^ tree6[28];  // p14
  assign pg[29] = tree6[29] & tree6[30];  // g15
  assign pg[30] = tree6[29] ^ tree6[30];  // p15
  assign pg[31] = tree6[31] & tree6[32];  // g16
  assign pg[32] = tree6[31] ^ tree6[32];  // p16
  assign pg[33] = tree6[33] & tree6[34];  // g17
  assign pg[34] = tree6[33] ^ tree6[34];  // p17
  assign pg[35] = tree6[35] & tree6[36];  // g18
  assign pg[36] = tree6[35] ^ tree6[36];  // p18
  assign pg[37] = tree6[37] & tree6[38];  // g19
  assign pg[38] = tree6[37] ^ tree6[38];  // p19
  assign pg[39] = tree6[39] & tree6[40];  // g20
  assign pg[40] = tree6[39] ^ tree6[40];  // p20
  assign pg[41] = tree6[41] & tree6[42];  // g21
  assign pg[42] = tree6[41] ^ tree6[42];  // p21
  assign pg[43] = tree6[43] & tree6[44];  // g22
  assign pg[44] = tree6[43] ^ tree6[44];  // p22
  assign pg[45] = tree6[45] & tree6[46];  // g23
  assign pg[46] = tree6[45] ^ tree6[46];  // p23
  assign pg[47] = tree6[47] & tree6[48];  // g24
  assign pg[48] = tree6[47] ^ tree6[48];  // p24
  assign pg[49] = tree6[49] & tree6[50];  // g25
  assign pg[50] = tree6[49] ^ tree6[50];  // p25
  assign pg[51] = tree6[51] & tree6[52];  // g26
  assign pg[52] = tree6[51] ^ tree6[52];  // p26
  assign pg[53] = tree6[53] & tree6[54];  // g27
  assign pg[54] = tree6[53] ^ tree6[54];  // p27
  assign pg[55] = tree6[55] & tree6[56];  // g28
  assign pg[56] = tree6[55] ^ tree6[56];  // p28
  assign pg[57] = tree6[57] & tree6[58];  // g29
  assign pg[58] = tree6[57] ^ tree6[58];  // p29
  assign pg[59] = tree6[59] & tree6[60];  // g30
  assign pg[60] = tree6[59] ^ tree6[60];  // p30
  assign pg[61] = tree6[61] ^ tree6[62];  // p31

  // ---- pfx1: prefix level 1 ------------------------------------------------
  assign pfx1[2:0] = pg[2:0];  // c0..c1
  assign pfx1[3] = pg[2] & pg[0];  // G1 l1
  assign pfx1[5:4] = pg[4:3];  // c2
  assign pfx1[6] = pg[4] & pg[2];  // P2 l1
  assign pfx1[7] = pg[6];  // c3
  assign pfx1[8] = pg[5] | (pg[6] & pg[3]);  // G3 l1
  assign pfx1[9] = pg[6] & pg[4];  // P3 l1
  assign pfx1[10] = pg[8];  // c4
  assign pfx1[11] = pg[7] | (pg[8] & pg[5]);  // G4 l1
  assign pfx1[12] = pg[8] & pg[6];  // P4 l1
  assign pfx1[13] = pg[10];  // c5
  assign pfx1[14] = pg[9] | (pg[10] & pg[7]);  // G5 l1
  assign pfx1[15] = pg[10] & pg[8];  // P5 l1
  assign pfx1[16] = pg[12];  // c6
  assign pfx1[17] = pg[11] | (pg[12] & pg[9]);  // G6 l1
  assign pfx1[18] = pg[12] & pg[10];  // P6 l1
  assign pfx1[19] = pg[14];  // c7
  assign pfx1[20] = pg[13] | (pg[14] & pg[11]);  // G7 l1
  assign pfx1[21] = pg[14] & pg[12];  // P7 l1
  assign pfx1[22] = pg[16];  // c8
  assign pfx1[23] = pg[15] | (pg[16] & pg[13]);  // G8 l1
  assign pfx1[24] = pg[16] & pg[14];  // P8 l1
  assign pfx1[25] = pg[18];  // c9
  assign pfx1[26] = pg[17] | (pg[18] & pg[15]);  // G9 l1
  assign pfx1[27] = pg[18] & pg[16];  // P9 l1
  assign pfx1[28] = pg[20];  // c10
  assign pfx1[29] = pg[19] | (pg[20] & pg[17]);  // G10 l1
  assign pfx1[30] = pg[20] & pg[18];  // P10 l1
  assign pfx1[31] = pg[22];  // c11
  assign pfx1[32] = pg[21] | (pg[22] & pg[19]);  // G11 l1
  assign pfx1[33] = pg[22] & pg[20];  // P11 l1
  assign pfx1[34] = pg[24];  // c12
  assign pfx1[35] = pg[23] | (pg[24] & pg[21]);  // G12 l1
  assign pfx1[36] = pg[24] & pg[22];  // P12 l1
  assign pfx1[37] = pg[26];  // c13
  assign pfx1[38] = pg[25] | (pg[26] & pg[23]);  // G13 l1
  assign pfx1[39] = pg[26] & pg[24];  // P13 l1
  assign pfx1[40] = pg[28];  // c14
  assign pfx1[41] = pg[27] | (pg[28] & pg[25]);  // G14 l1
  assign pfx1[42] = pg[28] & pg[26];  // P14 l1
  assign pfx1[43] = pg[30];  // c15
  assign pfx1[44] = pg[29] | (pg[30] & pg[27]);  // G15 l1
  assign pfx1[45] = pg[30] & pg[28];  // P15 l1
  assign pfx1[46] = pg[32];  // c16
  assign pfx1[47] = pg[31] | (pg[32] & pg[29]);  // G16 l1
  assign pfx1[48] = pg[32] & pg[30];  // P16 l1
  assign pfx1[49] = pg[34];  // c17
  assign pfx1[50] = pg[33] | (pg[34] & pg[31]);  // G17 l1
  assign pfx1[51] = pg[34] & pg[32];  // P17 l1
  assign pfx1[52] = pg[36];  // c18
  assign pfx1[53] = pg[35] | (pg[36] & pg[33]);  // G18 l1
  assign pfx1[54] = pg[36] & pg[34];  // P18 l1
  assign pfx1[55] = pg[38];  // c19
  assign pfx1[56] = pg[37] | (pg[38] & pg[35]);  // G19 l1
  assign pfx1[57] = pg[38] & pg[36];  // P19 l1
  assign pfx1[58] = pg[40];  // c20
  assign pfx1[59] = pg[39] | (pg[40] & pg[37]);  // G20 l1
  assign pfx1[60] = pg[40] & pg[38];  // P20 l1
  assign pfx1[61] = pg[42];  // c21
  assign pfx1[62] = pg[41] | (pg[42] & pg[39]);  // G21 l1
  assign pfx1[63] = pg[42] & pg[40];  // P21 l1
  assign pfx1[64] = pg[44];  // c22
  assign pfx1[65] = pg[43] | (pg[44] & pg[41]);  // G22 l1
  assign pfx1[66] = pg[44] & pg[42];  // P22 l1
  assign pfx1[67] = pg[46];  // c23
  assign pfx1[68] = pg[45] | (pg[46] & pg[43]);  // G23 l1
  assign pfx1[69] = pg[46] & pg[44];  // P23 l1
  assign pfx1[70] = pg[48];  // c24
  assign pfx1[71] = pg[47] | (pg[48] & pg[45]);  // G24 l1
  assign pfx1[72] = pg[48] & pg[46];  // P24 l1
  assign pfx1[73] = pg[50];  // c25
  assign pfx1[74] = pg[49] | (pg[50] & pg[47]);  // G25 l1
  assign pfx1[75] = pg[50] & pg[48];  // P25 l1
  assign pfx1[76] = pg[52];  // c26
  assign pfx1[77] = pg[51] | (pg[52] & pg[49]);  // G26 l1
  assign pfx1[78] = pg[52] & pg[50];  // P26 l1
  assign pfx1[79] = pg[54];  // c27
  assign pfx1[80] = pg[53] | (pg[54] & pg[51]);  // G27 l1
  assign pfx1[81] = pg[54] & pg[52];  // P27 l1
  assign pfx1[82] = pg[56];  // c28
  assign pfx1[83] = pg[55] | (pg[56] & pg[53]);  // G28 l1
  assign pfx1[84] = pg[56] & pg[54];  // P28 l1
  assign pfx1[85] = pg[58];  // c29
  assign pfx1[86] = pg[57] | (pg[58] & pg[55]);  // G29 l1
  assign pfx1[87] = pg[58] & pg[56];  // P29 l1
  assign pfx1[88] = pg[60];  // c30
  assign pfx1[89] = pg[59] | (pg[60] & pg[57]);  // G30 l1
  assign pfx1[90] = pg[60] & pg[58];  // P30 l1
  assign pfx1[91] = pg[61];  // c31

  // ---- pfx2: prefix level 2 ------------------------------------------------
  assign pfx2[3:0] = pfx1[3:0];  // c0..c1
  assign pfx2[4] = pfx1[5];  // c2
  assign pfx2[5] = pfx1[4] | (pfx1[6] & pfx1[0]);  // G2 l2
  assign pfx2[6] = pfx1[7];  // c3
  assign pfx2[7] = pfx1[8] | (pfx1[9] & pfx1[3]);  // G3 l2
  assign pfx2[8] = pfx1[10];  // c4
  assign pfx2[9] = pfx1[11] | (pfx1[12] & pfx1[4]);  // G4 l2
  assign pfx2[10] = pfx1[12] & pfx1[6];  // P4 l2
  assign pfx2[11] = pfx1[13];  // c5
  assign pfx2[12] = pfx1[14] | (pfx1[15] & pfx1[8]);  // G5 l2
  assign pfx2[13] = pfx1[15] & pfx1[9];  // P5 l2
  assign pfx2[14] = pfx1[16];  // c6
  assign pfx2[15] = pfx1[17] | (pfx1[18] & pfx1[11]);  // G6 l2
  assign pfx2[16] = pfx1[18] & pfx1[12];  // P6 l2
  assign pfx2[17] = pfx1[19];  // c7
  assign pfx2[18] = pfx1[20] | (pfx1[21] & pfx1[14]);  // G7 l2
  assign pfx2[19] = pfx1[21] & pfx1[15];  // P7 l2
  assign pfx2[20] = pfx1[22];  // c8
  assign pfx2[21] = pfx1[23] | (pfx1[24] & pfx1[17]);  // G8 l2
  assign pfx2[22] = pfx1[24] & pfx1[18];  // P8 l2
  assign pfx2[23] = pfx1[25];  // c9
  assign pfx2[24] = pfx1[26] | (pfx1[27] & pfx1[20]);  // G9 l2
  assign pfx2[25] = pfx1[27] & pfx1[21];  // P9 l2
  assign pfx2[26] = pfx1[28];  // c10
  assign pfx2[27] = pfx1[29] | (pfx1[30] & pfx1[23]);  // G10 l2
  assign pfx2[28] = pfx1[30] & pfx1[24];  // P10 l2
  assign pfx2[29] = pfx1[31];  // c11
  assign pfx2[30] = pfx1[32] | (pfx1[33] & pfx1[26]);  // G11 l2
  assign pfx2[31] = pfx1[33] & pfx1[27];  // P11 l2
  assign pfx2[32] = pfx1[34];  // c12
  assign pfx2[33] = pfx1[35] | (pfx1[36] & pfx1[29]);  // G12 l2
  assign pfx2[34] = pfx1[36] & pfx1[30];  // P12 l2
  assign pfx2[35] = pfx1[37];  // c13
  assign pfx2[36] = pfx1[38] | (pfx1[39] & pfx1[32]);  // G13 l2
  assign pfx2[37] = pfx1[39] & pfx1[33];  // P13 l2
  assign pfx2[38] = pfx1[40];  // c14
  assign pfx2[39] = pfx1[41] | (pfx1[42] & pfx1[35]);  // G14 l2
  assign pfx2[40] = pfx1[42] & pfx1[36];  // P14 l2
  assign pfx2[41] = pfx1[43];  // c15
  assign pfx2[42] = pfx1[44] | (pfx1[45] & pfx1[38]);  // G15 l2
  assign pfx2[43] = pfx1[45] & pfx1[39];  // P15 l2
  assign pfx2[44] = pfx1[46];  // c16
  assign pfx2[45] = pfx1[47] | (pfx1[48] & pfx1[41]);  // G16 l2
  assign pfx2[46] = pfx1[48] & pfx1[42];  // P16 l2
  assign pfx2[47] = pfx1[49];  // c17
  assign pfx2[48] = pfx1[50] | (pfx1[51] & pfx1[44]);  // G17 l2
  assign pfx2[49] = pfx1[51] & pfx1[45];  // P17 l2
  assign pfx2[50] = pfx1[52];  // c18
  assign pfx2[51] = pfx1[53] | (pfx1[54] & pfx1[47]);  // G18 l2
  assign pfx2[52] = pfx1[54] & pfx1[48];  // P18 l2
  assign pfx2[53] = pfx1[55];  // c19
  assign pfx2[54] = pfx1[56] | (pfx1[57] & pfx1[50]);  // G19 l2
  assign pfx2[55] = pfx1[57] & pfx1[51];  // P19 l2
  assign pfx2[56] = pfx1[58];  // c20
  assign pfx2[57] = pfx1[59] | (pfx1[60] & pfx1[53]);  // G20 l2
  assign pfx2[58] = pfx1[60] & pfx1[54];  // P20 l2
  assign pfx2[59] = pfx1[61];  // c21
  assign pfx2[60] = pfx1[62] | (pfx1[63] & pfx1[56]);  // G21 l2
  assign pfx2[61] = pfx1[63] & pfx1[57];  // P21 l2
  assign pfx2[62] = pfx1[64];  // c22
  assign pfx2[63] = pfx1[65] | (pfx1[66] & pfx1[59]);  // G22 l2
  assign pfx2[64] = pfx1[66] & pfx1[60];  // P22 l2
  assign pfx2[65] = pfx1[67];  // c23
  assign pfx2[66] = pfx1[68] | (pfx1[69] & pfx1[62]);  // G23 l2
  assign pfx2[67] = pfx1[69] & pfx1[63];  // P23 l2
  assign pfx2[68] = pfx1[70];  // c24
  assign pfx2[69] = pfx1[71] | (pfx1[72] & pfx1[65]);  // G24 l2
  assign pfx2[70] = pfx1[72] & pfx1[66];  // P24 l2
  assign pfx2[71] = pfx1[73];  // c25
  assign pfx2[72] = pfx1[74] | (pfx1[75] & pfx1[68]);  // G25 l2
  assign pfx2[73] = pfx1[75] & pfx1[69];  // P25 l2
  assign pfx2[74] = pfx1[76];  // c26
  assign pfx2[75] = pfx1[77] | (pfx1[78] & pfx1[71]);  // G26 l2
  assign pfx2[76] = pfx1[78] & pfx1[72];  // P26 l2
  assign pfx2[77] = pfx1[79];  // c27
  assign pfx2[78] = pfx1[80] | (pfx1[81] & pfx1[74]);  // G27 l2
  assign pfx2[79] = pfx1[81] & pfx1[75];  // P27 l2
  assign pfx2[80] = pfx1[82];  // c28
  assign pfx2[81] = pfx1[83] | (pfx1[84] & pfx1[77]);  // G28 l2
  assign pfx2[82] = pfx1[84] & pfx1[78];  // P28 l2
  assign pfx2[83] = pfx1[85];  // c29
  assign pfx2[84] = pfx1[86] | (pfx1[87] & pfx1[80]);  // G29 l2
  assign pfx2[85] = pfx1[87] & pfx1[81];  // P29 l2
  assign pfx2[86] = pfx1[88];  // c30
  assign pfx2[87] = pfx1[89] | (pfx1[90] & pfx1[83]);  // G30 l2
  assign pfx2[88] = pfx1[90] & pfx1[84];  // P30 l2
  assign pfx2[89] = pfx1[91];  // c31

  // ---- pfx3: prefix level 3 ------------------------------------------------
  assign pfx3[8:0] = pfx2[8:0];  // c0..c4
  assign pfx3[9] = pfx2[9] | (pfx2[10] & pfx2[0]);  // G4 l3
  assign pfx3[10] = pfx2[11];  // c5
  assign pfx3[11] = pfx2[12] | (pfx2[13] & pfx2[3]);  // G5 l3
  assign pfx3[12] = pfx2[14];  // c6
  assign pfx3[13] = pfx2[15] | (pfx2[16] & pfx2[5]);  // G6 l3
  assign pfx3[14] = pfx2[17];  // c7
  assign pfx3[15] = pfx2[18] | (pfx2[19] & pfx2[7]);  // G7 l3
  assign pfx3[16] = pfx2[20];  // c8
  assign pfx3[17] = pfx2[21] | (pfx2[22] & pfx2[9]);  // G8 l3
  assign pfx3[18] = pfx2[22] & pfx2[10];  // P8 l3
  assign pfx3[19] = pfx2[23];  // c9
  assign pfx3[20] = pfx2[24] | (pfx2[25] & pfx2[12]);  // G9 l3
  assign pfx3[21] = pfx2[25] & pfx2[13];  // P9 l3
  assign pfx3[22] = pfx2[26];  // c10
  assign pfx3[23] = pfx2[27] | (pfx2[28] & pfx2[15]);  // G10 l3
  assign pfx3[24] = pfx2[28] & pfx2[16];  // P10 l3
  assign pfx3[25] = pfx2[29];  // c11
  assign pfx3[26] = pfx2[30] | (pfx2[31] & pfx2[18]);  // G11 l3
  assign pfx3[27] = pfx2[31] & pfx2[19];  // P11 l3
  assign pfx3[28] = pfx2[32];  // c12
  assign pfx3[29] = pfx2[33] | (pfx2[34] & pfx2[21]);  // G12 l3
  assign pfx3[30] = pfx2[34] & pfx2[22];  // P12 l3
  assign pfx3[31] = pfx2[35];  // c13
  assign pfx3[32] = pfx2[36] | (pfx2[37] & pfx2[24]);  // G13 l3
  assign pfx3[33] = pfx2[37] & pfx2[25];  // P13 l3
  assign pfx3[34] = pfx2[38];  // c14
  assign pfx3[35] = pfx2[39] | (pfx2[40] & pfx2[27]);  // G14 l3
  assign pfx3[36] = pfx2[40] & pfx2[28];  // P14 l3
  assign pfx3[37] = pfx2[41];  // c15
  assign pfx3[38] = pfx2[42] | (pfx2[43] & pfx2[30]);  // G15 l3
  assign pfx3[39] = pfx2[43] & pfx2[31];  // P15 l3
  assign pfx3[40] = pfx2[44];  // c16
  assign pfx3[41] = pfx2[45] | (pfx2[46] & pfx2[33]);  // G16 l3
  assign pfx3[42] = pfx2[46] & pfx2[34];  // P16 l3
  assign pfx3[43] = pfx2[47];  // c17
  assign pfx3[44] = pfx2[48] | (pfx2[49] & pfx2[36]);  // G17 l3
  assign pfx3[45] = pfx2[49] & pfx2[37];  // P17 l3
  assign pfx3[46] = pfx2[50];  // c18
  assign pfx3[47] = pfx2[51] | (pfx2[52] & pfx2[39]);  // G18 l3
  assign pfx3[48] = pfx2[52] & pfx2[40];  // P18 l3
  assign pfx3[49] = pfx2[53];  // c19
  assign pfx3[50] = pfx2[54] | (pfx2[55] & pfx2[42]);  // G19 l3
  assign pfx3[51] = pfx2[55] & pfx2[43];  // P19 l3
  assign pfx3[52] = pfx2[56];  // c20
  assign pfx3[53] = pfx2[57] | (pfx2[58] & pfx2[45]);  // G20 l3
  assign pfx3[54] = pfx2[58] & pfx2[46];  // P20 l3
  assign pfx3[55] = pfx2[59];  // c21
  assign pfx3[56] = pfx2[60] | (pfx2[61] & pfx2[48]);  // G21 l3
  assign pfx3[57] = pfx2[61] & pfx2[49];  // P21 l3
  assign pfx3[58] = pfx2[62];  // c22
  assign pfx3[59] = pfx2[63] | (pfx2[64] & pfx2[51]);  // G22 l3
  assign pfx3[60] = pfx2[64] & pfx2[52];  // P22 l3
  assign pfx3[61] = pfx2[65];  // c23
  assign pfx3[62] = pfx2[66] | (pfx2[67] & pfx2[54]);  // G23 l3
  assign pfx3[63] = pfx2[67] & pfx2[55];  // P23 l3
  assign pfx3[64] = pfx2[68];  // c24
  assign pfx3[65] = pfx2[69] | (pfx2[70] & pfx2[57]);  // G24 l3
  assign pfx3[66] = pfx2[70] & pfx2[58];  // P24 l3
  assign pfx3[67] = pfx2[71];  // c25
  assign pfx3[68] = pfx2[72] | (pfx2[73] & pfx2[60]);  // G25 l3
  assign pfx3[69] = pfx2[73] & pfx2[61];  // P25 l3
  assign pfx3[70] = pfx2[74];  // c26
  assign pfx3[71] = pfx2[75] | (pfx2[76] & pfx2[63]);  // G26 l3
  assign pfx3[72] = pfx2[76] & pfx2[64];  // P26 l3
  assign pfx3[73] = pfx2[77];  // c27
  assign pfx3[74] = pfx2[78] | (pfx2[79] & pfx2[66]);  // G27 l3
  assign pfx3[75] = pfx2[79] & pfx2[67];  // P27 l3
  assign pfx3[76] = pfx2[80];  // c28
  assign pfx3[77] = pfx2[81] | (pfx2[82] & pfx2[69]);  // G28 l3
  assign pfx3[78] = pfx2[82] & pfx2[70];  // P28 l3
  assign pfx3[79] = pfx2[83];  // c29
  assign pfx3[80] = pfx2[84] | (pfx2[85] & pfx2[72]);  // G29 l3
  assign pfx3[81] = pfx2[85] & pfx2[73];  // P29 l3
  assign pfx3[82] = pfx2[86];  // c30
  assign pfx3[83] = pfx2[87] | (pfx2[88] & pfx2[75]);  // G30 l3
  assign pfx3[84] = pfx2[88] & pfx2[76];  // P30 l3
  assign pfx3[85] = pfx2[89];  // c31

  // ---- pfx4: prefix level 4 ------------------------------------------------
  assign pfx4[16:0] = pfx3[16:0];  // c0..c8
  assign pfx4[17] = pfx3[17] | (pfx3[18] & pfx3[0]);  // G8 l4
  assign pfx4[18] = pfx3[19];  // c9
  assign pfx4[19] = pfx3[20] | (pfx3[21] & pfx3[3]);  // G9 l4
  assign pfx4[20] = pfx3[22];  // c10
  assign pfx4[21] = pfx3[23] | (pfx3[24] & pfx3[5]);  // G10 l4
  assign pfx4[22] = pfx3[25];  // c11
  assign pfx4[23] = pfx3[26] | (pfx3[27] & pfx3[7]);  // G11 l4
  assign pfx4[24] = pfx3[28];  // c12
  assign pfx4[25] = pfx3[29] | (pfx3[30] & pfx3[9]);  // G12 l4
  assign pfx4[26] = pfx3[31];  // c13
  assign pfx4[27] = pfx3[32] | (pfx3[33] & pfx3[11]);  // G13 l4
  assign pfx4[28] = pfx3[34];  // c14
  assign pfx4[29] = pfx3[35] | (pfx3[36] & pfx3[13]);  // G14 l4
  assign pfx4[30] = pfx3[37];  // c15
  assign pfx4[31] = pfx3[38] | (pfx3[39] & pfx3[15]);  // G15 l4
  assign pfx4[32] = pfx3[40];  // c16
  assign pfx4[33] = pfx3[41] | (pfx3[42] & pfx3[17]);  // G16 l4
  assign pfx4[34] = pfx3[42] & pfx3[18];  // P16 l4
  assign pfx4[35] = pfx3[43];  // c17
  assign pfx4[36] = pfx3[44] | (pfx3[45] & pfx3[20]);  // G17 l4
  assign pfx4[37] = pfx3[45] & pfx3[21];  // P17 l4
  assign pfx4[38] = pfx3[46];  // c18
  assign pfx4[39] = pfx3[47] | (pfx3[48] & pfx3[23]);  // G18 l4
  assign pfx4[40] = pfx3[48] & pfx3[24];  // P18 l4
  assign pfx4[41] = pfx3[49];  // c19
  assign pfx4[42] = pfx3[50] | (pfx3[51] & pfx3[26]);  // G19 l4
  assign pfx4[43] = pfx3[51] & pfx3[27];  // P19 l4
  assign pfx4[44] = pfx3[52];  // c20
  assign pfx4[45] = pfx3[53] | (pfx3[54] & pfx3[29]);  // G20 l4
  assign pfx4[46] = pfx3[54] & pfx3[30];  // P20 l4
  assign pfx4[47] = pfx3[55];  // c21
  assign pfx4[48] = pfx3[56] | (pfx3[57] & pfx3[32]);  // G21 l4
  assign pfx4[49] = pfx3[57] & pfx3[33];  // P21 l4
  assign pfx4[50] = pfx3[58];  // c22
  assign pfx4[51] = pfx3[59] | (pfx3[60] & pfx3[35]);  // G22 l4
  assign pfx4[52] = pfx3[60] & pfx3[36];  // P22 l4
  assign pfx4[53] = pfx3[61];  // c23
  assign pfx4[54] = pfx3[62] | (pfx3[63] & pfx3[38]);  // G23 l4
  assign pfx4[55] = pfx3[63] & pfx3[39];  // P23 l4
  assign pfx4[56] = pfx3[64];  // c24
  assign pfx4[57] = pfx3[65] | (pfx3[66] & pfx3[41]);  // G24 l4
  assign pfx4[58] = pfx3[66] & pfx3[42];  // P24 l4
  assign pfx4[59] = pfx3[67];  // c25
  assign pfx4[60] = pfx3[68] | (pfx3[69] & pfx3[44]);  // G25 l4
  assign pfx4[61] = pfx3[69] & pfx3[45];  // P25 l4
  assign pfx4[62] = pfx3[70];  // c26
  assign pfx4[63] = pfx3[71] | (pfx3[72] & pfx3[47]);  // G26 l4
  assign pfx4[64] = pfx3[72] & pfx3[48];  // P26 l4
  assign pfx4[65] = pfx3[73];  // c27
  assign pfx4[66] = pfx3[74] | (pfx3[75] & pfx3[50]);  // G27 l4
  assign pfx4[67] = pfx3[75] & pfx3[51];  // P27 l4
  assign pfx4[68] = pfx3[76];  // c28
  assign pfx4[69] = pfx3[77] | (pfx3[78] & pfx3[53]);  // G28 l4
  assign pfx4[70] = pfx3[78] & pfx3[54];  // P28 l4
  assign pfx4[71] = pfx3[79];  // c29
  assign pfx4[72] = pfx3[80] | (pfx3[81] & pfx3[56]);  // G29 l4
  assign pfx4[73] = pfx3[81] & pfx3[57];  // P29 l4
  assign pfx4[74] = pfx3[82];  // c30
  assign pfx4[75] = pfx3[83] | (pfx3[84] & pfx3[59]);  // G30 l4
  assign pfx4[76] = pfx3[84] & pfx3[60];  // P30 l4
  assign pfx4[77] = pfx3[85];  // c31

  // ---- pfx5: prefix level 5 ------------------------------------------------
  assign pfx5[32:0] = pfx4[32:0];  // c0..c16
  assign pfx5[33] = pfx4[33] | (pfx4[34] & pfx4[0]);  // G16 l5
  assign pfx5[34] = pfx4[35];  // c17
  assign pfx5[35] = pfx4[36] | (pfx4[37] & pfx4[3]);  // G17 l5
  assign pfx5[36] = pfx4[38];  // c18
  assign pfx5[37] = pfx4[39] | (pfx4[40] & pfx4[5]);  // G18 l5
  assign pfx5[38] = pfx4[41];  // c19
  assign pfx5[39] = pfx4[42] | (pfx4[43] & pfx4[7]);  // G19 l5
  assign pfx5[40] = pfx4[44];  // c20
  assign pfx5[41] = pfx4[45] | (pfx4[46] & pfx4[9]);  // G20 l5
  assign pfx5[42] = pfx4[47];  // c21
  assign pfx5[43] = pfx4[48] | (pfx4[49] & pfx4[11]);  // G21 l5
  assign pfx5[44] = pfx4[50];  // c22
  assign pfx5[45] = pfx4[51] | (pfx4[52] & pfx4[13]);  // G22 l5
  assign pfx5[46] = pfx4[53];  // c23
  assign pfx5[47] = pfx4[54] | (pfx4[55] & pfx4[15]);  // G23 l5
  assign pfx5[48] = pfx4[56];  // c24
  assign pfx5[49] = pfx4[57] | (pfx4[58] & pfx4[17]);  // G24 l5
  assign pfx5[50] = pfx4[59];  // c25
  assign pfx5[51] = pfx4[60] | (pfx4[61] & pfx4[19]);  // G25 l5
  assign pfx5[52] = pfx4[62];  // c26
  assign pfx5[53] = pfx4[63] | (pfx4[64] & pfx4[21]);  // G26 l5
  assign pfx5[54] = pfx4[65];  // c27
  assign pfx5[55] = pfx4[66] | (pfx4[67] & pfx4[23]);  // G27 l5
  assign pfx5[56] = pfx4[68];  // c28
  assign pfx5[57] = pfx4[69] | (pfx4[70] & pfx4[25]);  // G28 l5
  assign pfx5[58] = pfx4[71];  // c29
  assign pfx5[59] = pfx4[72] | (pfx4[73] & pfx4[27]);  // G29 l5
  assign pfx5[60] = pfx4[74];  // c30
  assign pfx5[61] = pfx4[75] | (pfx4[76] & pfx4[29]);  // G30 l5
  assign pfx5[62] = pfx4[77];  // c31

  // ---- sum: sum XOR --------------------------------------------------------
  assign sum[0] = pfx5[1];  // c0
  assign sum[1] = pfx5[2] ^ pfx5[0];  // product[1]
  assign sum[2] = pfx5[4] ^ pfx5[3];  // product[2]
  assign sum[3] = pfx5[6] ^ pfx5[5];  // product[3]
  assign sum[4] = pfx5[8] ^ pfx5[7];  // product[4]
  assign sum[5] = pfx5[10] ^ pfx5[9];  // product[5]
  assign sum[6] = pfx5[12] ^ pfx5[11];  // product[6]
  assign sum[7] = pfx5[14] ^ pfx5[13];  // product[7]
  assign sum[8] = pfx5[16] ^ pfx5[15];  // product[8]
  assign sum[9] = pfx5[18] ^ pfx5[17];  // product[9]
  assign sum[10] = pfx5[20] ^ pfx5[19];  // product[10]
  assign sum[11] = pfx5[22] ^ pfx5[21];  // product[11]
  assign sum[12] = pfx5[24] ^ pfx5[23];  // product[12]
  assign sum[13] = pfx5[26] ^ pfx5[25];  // product[13]
  assign sum[14] = pfx5[28] ^ pfx5[27];  // product[14]
  assign sum[15] = pfx5[30] ^ pfx5[29];  // product[15]
  assign sum[16] = pfx5[32] ^ pfx5[31];  // product[16]
  assign sum[17] = pfx5[34] ^ pfx5[33];  // product[17]
  assign sum[18] = pfx5[36] ^ pfx5[35];  // product[18]
  assign sum[19] = pfx5[38] ^ pfx5[37];  // product[19]
  assign sum[20] = pfx5[40] ^ pfx5[39];  // product[20]
  assign sum[21] = pfx5[42] ^ pfx5[41];  // product[21]
  assign sum[22] = pfx5[44] ^ pfx5[43];  // product[22]
  assign sum[23] = pfx5[46] ^ pfx5[45];  // product[23]
  assign sum[24] = pfx5[48] ^ pfx5[47];  // product[24]
  assign sum[25] = pfx5[50] ^ pfx5[49];  // product[25]
  assign sum[26] = pfx5[52] ^ pfx5[51];  // product[26]
  assign sum[27] = pfx5[54] ^ pfx5[53];  // product[27]
  assign sum[28] = pfx5[56] ^ pfx5[55];  // product[28]
  assign sum[29] = pfx5[58] ^ pfx5[57];  // product[29]
  assign sum[30] = pfx5[60] ^ pfx5[59];  // product[30]
  assign sum[31] = pfx5[62] ^ pfx5[61];  // product[31]

  assign product[31:0] = sum[31:0];

endmodule
