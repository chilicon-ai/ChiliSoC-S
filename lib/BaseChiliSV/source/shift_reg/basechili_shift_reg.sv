// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_shift_reg
//
// Shift register with parallel load and parallel output (serializer /
// deserializer for UART, SPI, I2C). Each shift moves q one place toward the
// output end and takes shift_in at the other end:
//
//   MSB_FIRST = 0 : shift_out = q[0],       q <= {shift_in, q[WIDTH-1:1]}
//   MSB_FIRST = 1 : shift_out = q[WIDTH-1], q <= {q[WIDTH-2:0], shift_in}
//
// load wins over shift in the same cycle.
//
// Timing    : q and shift_out are registered; shift_out shows the next bit
//             the cycle after a load or shift.
// Debug     : wrong bit order -> MSB_FIRST; lost bits -> load and shift in
//             the same cycle.
// -----------------------------------------------------------------------------
module basechili_shift_reg #(
  parameter int               WIDTH     = 8,       // bits
  parameter bit               MSB_FIRST = 1'b0,    // shift out q[WIDTH-1] first (else q[0])
  parameter logic [WIDTH-1:0] RESET_VAL = '0
) (
  input  logic             clk,
  input  logic             rst_n,                  // async, active-low
  input  logic             load,                   // q <= load_val
  input  logic [WIDTH-1:0] load_val,
  input  logic             shift,                  // shift one place
  input  logic             shift_in,               // bit entering the register
  output logic [WIDTH-1:0] q,                      // parallel contents
  output logic             shift_out               // bit at the output end
);

  logic [WIDTH-1:0] shifted;   // q after one shift
  logic [WIDTH-1:0] q_d;       // next q
  logic             q_en;      // q changes

  if (WIDTH == 1) begin : g_one
    assign shifted = shift_in;
  end else if (MSB_FIRST) begin : g_msb
    assign shifted = {q[WIDTH-2:0], shift_in};
  end else begin : g_lsb
    assign shifted = {shift_in, q[WIDTH-1:1]};
  end

  assign q_d  = load ? load_val : shifted;
  assign q_en = load || shift;

  basechili_dffe #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_q (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (q_en),
    .d     (q_d),
    .q     (q)
  );

  assign shift_out = MSB_FIRST ? q[WIDTH-1] : q[0];

endmodule
