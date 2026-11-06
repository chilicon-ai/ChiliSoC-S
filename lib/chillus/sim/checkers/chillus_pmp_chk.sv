// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_pmp_chk (bound into chillus_pmp)
//   - cfg bits [6:5] are 0 (not stored), no entry has R = 0 with W = 1
//                                                         (header Invariants)
//   - a locked entry's cfg and pmpaddr never change       (header Invariants)
//   - debug_mode -> no deny                               (header Invariants)
// -----------------------------------------------------------------------------
module chillus_pmp_chk #(
  parameter int XLEN = 32,
  parameter int N    = 4,
  parameter int CW   = 6
) (
  input logic            clk,
  input logic            rst_n,
  input logic            debug_mode,
  input logic            data_deny_load,
  input logic            data_deny_store,
  input logic            fetch_deny,
  input logic [N*CW-1:0] cfg,
  input logic [N*XLEN-1:0] addr,
  input logic [N-1:0]    lock
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(debug_mode |-> !data_deny_load && !data_deny_store && !fetch_deny,
       ("chillus_pmp: an access is denied in debug mode"))

  for (genvar i = 0; i < N; i++) begin : g_entry
    `CHK(!(cfg[i*CW + 1] && !cfg[i*CW]),
         ("chillus_pmp: entry %0d has W = 1 with R = 0: cfg=%b", i, cfg[i*CW +: CW]))
    `CHK(lock[i] |=> $stable(cfg[i*CW +: CW]) && $stable(addr[i*XLEN +: XLEN]),
         ("chillus_pmp: locked entry %0d changed: cfg %b -> %b, pmpaddr %h -> %h", i,
          $past(cfg[i*CW +: CW]), cfg[i*CW +: CW], $past(addr[i*XLEN +: XLEN]), addr[i*XLEN +: XLEN]))
  end

  `undef CHK

endmodule

bind chillus_pmp chillus_pmp_chk #(.XLEN(XLEN), .N(NW)) u_chk (
  .clk             (clk),
  .rst_n           (rst_n),
  .debug_mode      (debug_mode),
  .data_deny_load  (data_deny_load),
  .data_deny_store (data_deny_store),
  .fetch_deny      (fetch_deny),
  .cfg             (cfg),
  .addr            (addr),
  .lock            (lock)
);
