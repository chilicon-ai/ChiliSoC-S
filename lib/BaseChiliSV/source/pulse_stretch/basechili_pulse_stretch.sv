// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_pulse_stretch
//
// Per-bit pulse stretcher: a high cycle of in makes out high for the next
// CYCLES cycles; a new pulse while out is high restarts the count
// (retriggerable), so out stays high until CYCLES cycles after the last
// high cycle of in. Use it to widen a one-cycle event for a slower clock
// domain (CYCLES >= 1.5 slow periods + synchronizer margin; for full
// handshaking use basechili_pulse_sync), an LED, or a minimum-width
// output pin.
//
// Timing    : out is registered (from its own flop, so it does not glitch):
//             high from the edge after the first high cycle of in until
//             CYCLES edges after the last one.
// Invariants: in high -> out high after the next edge; out falls only when
//             in was low for the last CYCLES cycles.
// Debug     : out too short -> g_bit[i].g_cnt.cnt (cycles still to go after
//             the next); out never high -> in sampled on a different clock.
// -----------------------------------------------------------------------------
module basechili_pulse_stretch #(
  parameter  int WIDTH  = 1,                             // independent bits
  parameter  int CYCLES = 4,                             // out cycles per pulse, >= 1
  localparam int CW     = (CYCLES > 1) ? $clog2(CYCLES) : 1
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic [WIDTH-1:0] in,      // pulses, synchronous to clk
  output logic [WIDTH-1:0] out      // stretched pulses
);

  logic [WIDTH-1:0] out_d;   // next out

  for (genvar i = 0; i < WIDTH; i++) begin : g_bit
    if (CYCLES > 1) begin : g_cnt
      localparam logic [CW-1:0] LOAD = CW'(CYCLES - 1);

      logic [CW-1:0] cnt;     // high cycles left after the next one
      logic          more;    // out stays high after the next edge

      assign more     = cnt != '0;
      assign out_d[i] = in[i] || more;

      basechili_updown_counter #(.WIDTH(CW)) u_cnt (
        .clk      (clk),
        .rst_n    (rst_n),
        .load     (in[i]),
        .load_val (LOAD),
        .inc      (1'b0),
        .dec      (more),
        .count    (cnt),
        .count_d  ()
      );
    end else begin : g_one
      assign out_d[i] = in[i];
    end
  end

  basechili_dff #(.WIDTH(WIDTH)) u_out (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (out_d),
    .q     (out)
  );

endmodule
