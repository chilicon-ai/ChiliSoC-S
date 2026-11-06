// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_icache_chk (bound into chillus_icache)
//   - one c_rvalid per granted core request, after its grant (header Invariants)
//   - one m_rvalid per granted bus request; at most 2 bus requests outstanding
//   - c_addr / m_addr word-aligned while requested
// Port-level only, so it holds for SIZE_KB = 0 (wires) too.
// -----------------------------------------------------------------------------
module chillus_icache_chk (
  input logic        clk,
  input logic        rst_n,
  input logic        c_req,
  input logic        c_gnt,
  input logic [31:0] c_addr,
  input logic        c_rvalid,
  input logic        m_req,
  input logic        m_gnt,
  input logic [31:0] m_addr,
  input logic        m_rvalid
);

  int c_os;   // core requests granted, response not yet returned
  int m_os;   // bus requests granted, response not yet returned

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      c_os <= 0;
      m_os <= 0;
    end else begin
      c_os <= c_os + int'(c_req && c_gnt) - int'(c_rvalid);
      m_os <= m_os + int'(m_req && m_gnt) - int'(m_rvalid);
    end
  end

  assert property (@(posedge clk) disable iff (!rst_n) !c_rvalid || c_os > 0)
    else $error("chillus_icache: c_rvalid without a granted request (c_os %0d)", c_os);

  assert property (@(posedge clk) disable iff (!rst_n) !m_rvalid || m_os > 0)
    else $error("chillus_icache: m_rvalid without a granted bus request (m_os %0d)", m_os);

  assert property (@(posedge clk) disable iff (!rst_n) m_os <= 2)
    else $error("chillus_icache: %0d bus requests outstanding", m_os);

  assert property (@(posedge clk) disable iff (!rst_n)
                   (!c_req || c_addr[1:0] == 2'b00) && (!m_req || m_addr[1:0] == 2'b00))
    else $error("chillus_icache: unaligned request (c_addr %h, m_addr %h)", c_addr, m_addr);

endmodule

bind chillus_icache chillus_icache_chk u_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .c_req    (c_req),
  .c_gnt    (c_gnt),
  .c_addr   (c_addr),
  .c_rvalid (c_rvalid),
  .m_req    (m_req),
  .m_gnt    (m_gnt),
  .m_addr   (m_addr),
  .m_rvalid (m_rvalid)
);
