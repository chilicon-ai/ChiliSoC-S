// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_sram_chk (bound into every basechili_ahb_sram)
//   - the buffer is never full while a data-phase write arrives
//     (!(buf_valid && dp_write))                             (header Invariant)
//   - a read and a write never use the SRAM port together: an address-phase
//     read is a port read, any other port access is a pending write, and a
//     buffered write survives a read cycle unchanged        (header Invariant)
//   - HREADYOUT is low only in S_ERR1                        (header Invariant)
//   - READ_ONLY: the SRAM is never written                   (header)
// -----------------------------------------------------------------------------
module basechili_ahb_sram_chk #(
  parameter int MEM_AW    = 10,
  parameter bit READ_ONLY = 1'b0
) (
  input logic              clk,
  input logic              rst_n,
  input logic [1:0]        state,       // u_err.state_q: 1 is S_ERR1
  input logic              HREADYOUT,
  input logic              rd_go,
  input logic              dp_write,
  input logic              buf_valid,
  input logic [MEM_AW-1:0] buf_addr,
  input logic              mem_req,
  input logic              mem_we
);

  localparam logic [1:0] S_ERR1 = 2'd1;

  assert property (@(posedge clk) disable iff (!rst_n) !(buf_valid && dp_write))
    else $error("basechili_ahb_sram: write buffer full while a data-phase write arrives");

  assert property (@(posedge clk) disable iff (!rst_n) rd_go |-> mem_req && !mem_we)
    else $error("basechili_ahb_sram: address-phase read is not a SRAM read: mem_req=%b mem_we=%b", mem_req, mem_we);

  assert property (@(posedge clk) disable iff (!rst_n) mem_req && !rd_go |-> mem_we && (buf_valid || dp_write))
    else $error("basechili_ahb_sram: SRAM access without a read or a pending write");

  assert property (@(posedge clk) disable iff (!rst_n) buf_valid && rd_go |=> buf_valid && $stable(buf_addr))
    else $error("basechili_ahb_sram: buffered write lost during a read");

  assert property (@(posedge clk) disable iff (!rst_n) !HREADYOUT |-> state == S_ERR1)
    else $error("basechili_ahb_sram: HREADYOUT low outside S_ERR1: state=%0d", state);

  assert property (@(posedge clk) disable iff (!rst_n) READ_ONLY |-> !(mem_req && mem_we))
    else $error("basechili_ahb_sram: READ_ONLY SRAM written");

endmodule

bind basechili_ahb_sram basechili_ahb_sram_chk #(.MEM_AW(MEM_AW), .READ_ONLY(READ_ONLY)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state     (u_err.state_q),
  .HREADYOUT (HREADYOUT),
  .rd_go     (rd_go),
  .dp_write  (dp_write),
  .buf_valid (buf_valid),
  .buf_addr  (buf_addr),
  .mem_req   (mem_req),
  .mem_we    (mem_we)
);
