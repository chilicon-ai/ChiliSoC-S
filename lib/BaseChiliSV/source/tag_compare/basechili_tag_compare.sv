// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_tag_compare
//
// N-way parallel tag compare (set-associative cache / TLB lookup): way w
// hits when valid[w] is set and tags[w*TAG_W +: TAG_W] equals tag.
//   hit_way  : one-hot (normally) vector of hitting ways
//   hit      : some way hit
//   hit_idx  : index of the hitting way (OR of the indices if several hit)
//   multi_hit: two or more ways hit; in a cache or TLB this is a
//              corrupted-state error (duplicate fill), reported, not resolved
//
// Timing    : combinational from tags, valid and tag.
// Invariants: hit_way is a subset of valid; hit == |hit_way.
// Debug     : unexpected miss -> valid[w] and tags of the expected way;
//             multi_hit -> two ways were filled with the same tag.
// -----------------------------------------------------------------------------
module basechili_tag_compare #(
  parameter  int TAG_W = 20,                        // tag width in bits
  parameter  int WAYS  = 4,                         // number of ways compared
  localparam int IDX_W = (WAYS > 1) ? $clog2(WAYS) : 1
) (
  input  logic [WAYS*TAG_W-1:0] tags,       // stored tag of way w at w*TAG_W
  input  logic [WAYS-1:0]       valid,      // way holds a valid tag
  input  logic [TAG_W-1:0]      tag,        // lookup tag
  output logic [WAYS-1:0]       hit_way,    // ways that hit
  output logic                  hit,
  output logic [IDX_W-1:0]      hit_idx,
  output logic                  multi_hit
);

  always_comb begin
    for (int w = 0; w < WAYS; w++) begin
      hit_way[w] = valid[w] && (tags[w*TAG_W +: TAG_W] == tag);
    end
  end

  basechili_encoder #(.N(WAYS)) u_enc (
    .in    (hit_way),
    .out   (hit_idx),
    .valid (hit)
  );

  basechili_onehot_check #(.N(WAYS)) u_multi (
    .in      (hit_way),
    .zero    (),
    .onehot  (),
    .onehot0 (),
    .multi   (multi_hit)
  );

endmodule
