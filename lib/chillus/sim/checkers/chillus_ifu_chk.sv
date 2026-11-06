// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_ifu_chk (bound into chillus_ifu)
//   - rsp_addr (pc's word + buf_count) is the address of every word pushed
//     into the buffer: compared with a reference that starts at the redirect
//     target's word and advances by 4 per push (the PMP fetch check relies
//     on it)
// -----------------------------------------------------------------------------
module chillus_ifu_chk #(
  parameter int ADDR_W = 32
) (
  input logic              clk,
  input logic              rst_n,
  input logic              redirect_valid,
  input logic [ADDR_W-1:0] redirect_pc,
  input logic              buf_push,
  input logic [ADDR_W-1:0] rsp_addr
);

  logic [ADDR_W-1:0] ref_addr;      // address of the next word to be pushed
  logic              ref_ok;        // a redirect has set ref_addr

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_addr <= '0;
      ref_ok   <= 1'b0;
    end else if (redirect_valid) begin
      ref_addr <= {redirect_pc[ADDR_W-1:2], 2'b00};
      ref_ok   <= 1'b1;
    end else if (buf_push) begin
      ref_addr <= ref_addr + ADDR_W'(4);
    end
  end

  assert property (@(posedge clk) disable iff (!rst_n)
                   ref_ok && buf_push && !redirect_valid |-> rsp_addr == ref_addr)
    else $error("chillus_ifu: pushed word at rsp_addr=%h, expected %h", rsp_addr, ref_addr);

endmodule

bind chillus_ifu chillus_ifu_chk #(.ADDR_W(ADDR_W)) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .redirect_valid (redirect_valid),
  .redirect_pc    (redirect_pc),
  .buf_push       (buf_push),
  .rsp_addr       (rsp_addr)
);
