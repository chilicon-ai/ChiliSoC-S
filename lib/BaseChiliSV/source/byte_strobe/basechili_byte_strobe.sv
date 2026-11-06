// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_byte_strobe
//
// Byte-lane enables of a data bus for an access of 2**size bytes starting at
// byte lane `offset` (the low address bits). Combinational. Lane i is
// bus bits [8*i +: 8]:
//
//   strb[i] = offset <= i < offset + 2**size
//
// Example (DATA_W = 32): size 0, offset 1 -> 0010; size 1, offset 2 -> 1100;
// size 2, offset 0 -> 1111. Bytes that would fall beyond the top lane (a
// misaligned access crossing the bus width) are dropped; size > OFF_W (wider
// than the bus) gives no lanes.
// -----------------------------------------------------------------------------
module basechili_byte_strobe #(
  parameter  int DATA_W = 32,                              // bus width in bits, power of two >= 16
  localparam int N_LANE = DATA_W / 8,                      // byte lanes
  localparam int OFF_W  = $clog2(N_LANE),                  // lane offset bits
  localparam int SIZE_W = $clog2(OFF_W + 1)                // log2(bytes) bits, 0 .. OFF_W
) (
  input  logic [OFF_W-1:0]  offset,                        // first byte lane (address low bits)
  input  logic [SIZE_W-1:0] size,                          // access size: log2 of the byte count
  output logic [N_LANE-1:0] strb                           // byte lane enables
);

  logic [OFF_W:0] last;   // one past the last lane of the access (may exceed N_LANE)

  assign last = {1'b0, offset} + unsigned'((OFF_W+1)'(1 << size));

  always_comb begin
    for (int i = 0; i < N_LANE; i++) begin
      strb[i] = (unsigned'((OFF_W+1)'(i)) >= {1'b0, offset}) && (unsigned'((OFF_W+1)'(i)) < last);
    end
  end

endmodule
