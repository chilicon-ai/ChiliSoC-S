// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_pulse_stretch_chk (bound into every basechili_pulse_stretch)
//   - in high -> out high after the next edge                (header Invariant)
//   - out falls only when in was low for the last CYCLES cycles
//                                                             (header Invariant)
// -----------------------------------------------------------------------------
module basechili_pulse_stretch_chk #(
  parameter int WIDTH  = 1,
  parameter int CYCLES = 4
) (
  input logic             clk,
  input logic             rst_n,
  input logic [WIDTH-1:0] in,
  input logic [WIDTH-1:0] out
);

  logic [CYCLES*WIDTH-1:0] hist;    // in at the last CYCLES edges, newest in [WIDTH-1:0]
  logic [WIDTH-1:0]        seen;    // in was high at one of them
  logic [WIDTH-1:0]        out_q;   // out, one edge ago

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hist  <= '0;
      out_q <= '0;
    end else begin
      hist  <= (CYCLES*WIDTH)'({hist, in});
      out_q <= out;
    end
  end

  always_comb begin
    seen = '0;
    for (int k = 0; k < CYCLES; k++) seen |= hist[k*WIDTH +: WIDTH];
  end

  assert property (@(posedge clk) disable iff (!rst_n) (out & hist[WIDTH-1:0]) == hist[WIDTH-1:0])
    else $error("basechili_pulse_stretch: in high, out not high after the next edge: in=%b out=%b", hist[WIDTH-1:0], out);

  assert property (@(posedge clk) disable iff (!rst_n) (out_q & ~out & seen) == '0)
    else $error("basechili_pulse_stretch: out fell within CYCLES cycles of a pulse: out=%b", out);

endmodule

bind basechili_pulse_stretch basechili_pulse_stretch_chk #(.WIDTH(WIDTH), .CYCLES(CYCLES)) u_chk (
  .clk   (clk),
  .rst_n (rst_n),
  .in    (in),
  .out   (out)
);
