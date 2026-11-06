// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_pmp
//
// Physical memory protection (riscv-privileged.pdf 3.7, version 1.12) with
// N_REGIONS entries (pmpcfg0 bytes 0..N_REGIONS-1, pmpaddr0..N_REGIONS-1;
// N_REGIONS = 0: no PMP, nothing denied, no CSR here, so every PMP CSR is
// chillus_csr's read-zero one and U-mode reaches all memory),
// grain 4 bytes (G = 0): modes OFF, TOR, NA4 and NAPOT, R / W / X and the
// lock bit L. Stage-agnostic, two check ports:
//   data  : a load / store address with its privilege (data_priv_m: MPRV
//           applied); data_deny_load / _store are combinational, so the LSU
//           drops the request before it reaches the bus (load / store access
//           fault).
//   fetch : the word address of a fetch response with the fetch privilege;
//           fetch_deny marks the word faulting like a bus error (instruction
//           access fault when it is executed). The request itself is not
//           checked: fetches have no side effects.
// Every access the core makes is naturally aligned and at most 4 bytes, and
// a fetch is one aligned word, so each one lies in a single 4-byte grain: an
// entry either covers it or not (no partial match), and only addr[XLEN-1:2]
// is compared.
//
// Rules (riscv-privileged.pdf 3.7.1): the lowest-numbered matching entry
// decides; with L = 0 it does not restrict M-mode. No match: M-mode allowed,
// U-mode denied. In debug mode every access is allowed (the debug ROM and
// program buffer run in M-mode regardless of locked entries).
//   TOR   entry i: pmpaddr[i-1] <= a < pmpaddr[i] (pmpaddr[-1] = 0)
//   NA4   a == pmpaddr[i]
//   NAPOT a matches pmpaddr[i] except in its trailing ones and the bit above
//         them (pmpaddr ^ (pmpaddr + 1) masks the ignored bits; all ones:
//         the whole address space)
// with a = address[XLEN-1:2] (pmpaddr holds address bits [XLEN+1:2]).
//
// CSRs
//   pmpcfg0 0x3A0 byte i = entry i: R [0], W [1], X [2], A [4:3], L [7];
//           bits [6:5] read 0. WARL as Sail: R = 0 with W = 1 writes
//           R = W = X = 0. Bytes of locked entries ignore writes.
//   pmpaddr0..N_REGIONS-1 0x3B0..: all XLEN bits; a write is ignored when
//           the entry is locked, or the next entry is locked and TOR.
//   The other PMP CSRs (pmpcfg1..15, pmpaddrN_REGIONS..63) are chillus_csr's
//   read-zero CSRs. Any write of a CSR here raises refetch, so instructions
//   already fetched are checked with the new configuration; locks clear only
//   at reset.
//
// Timing   : data_deny_* and fetch_deny are combinational from the address and
//            the registers; csr_rdata, csr_hit and refetch are combinational;
//            the CSRs update at the clock edge.
// Invariants
//   cfg bits [6:5] are 0, and no entry has R = 0 with W = 1.
//   A locked entry's cfg and pmpaddr never change.
//   debug_mode -> !data_deny_load && !data_deny_store && !fetch_deny.
// Debug    : unexpected access fault -> data_match / fetch_match (per entry),
//            the first match's cfg (data_sel / fetch_sel) and the privilege;
//            write ignored -> lock (cfg L), tor_lock of the next entry.
// -----------------------------------------------------------------------------
module chillus_pmp #(
  parameter int XLEN      = 32,          // register and address width
  parameter int N_REGIONS = 4            // PMP entries (0..4: pmpcfg0 only; 0 = no PMP)
) (
  input  logic            clk,
  input  logic            rst_n,                 // async, active-low

  // state
  input  logic            debug_mode,            // debug unit: no check

  // data check (load / store request)
  input  logic [XLEN-1:0] data_addr,             // byte address of the access
  input  logic            data_priv_m,           // access privilege is M (0: U)
  output logic            data_deny_load,        // a load there is not allowed
  output logic            data_deny_store,       // a store there is not allowed

  // fetch check (fetch response)
  input  logic [XLEN-1:0] fetch_addr,            // address of the fetched word
  input  logic            fetch_priv_m,          // fetch privilege is M (0: U)
  output logic            fetch_deny,            // the word may not be executed

  // CSR port (CSR instructions)
  input  logic [11:0]     csr_addr,
  input  logic            csr_we,                // write csr_wdata to csr_addr at the clock edge
  input  logic [XLEN-1:0] csr_wdata,
  output logic [XLEN-1:0] csr_rdata,             // 0 when !csr_hit
  output logic            csr_hit,               // csr_addr is pmpcfg0 or an implemented pmpaddr
  output logic            refetch                // a PMP CSR is written: refetch the next instruction
);

  localparam logic [11:0] CSR_PMPCFG0  = 12'h3A0;
  localparam logic [11:0] CSR_PMPADDR0 = 12'h3B0;

  localparam int N  = N_REGIONS;
  localparam int NW = (N > 0) ? N : 1;      // vector sizes (one unused entry when N = 0)

  localparam logic [1:0] A_TOR   = 2'd1;            // pmpcfg A = TOR (OFF 0, NA4 2, NAPOT 3: chillus_pmp_match)

  // cfg per entry, packed: {L, A[1:0], X, W, R} = 6 bits
  localparam int CW = 6;

  logic [NW*CW-1:0]  cfg;           // entry i: cfg[i*CW +: CW]
  logic [NW*XLEN-1:0] addr;         // entry i: pmpaddr[i] = addr[i*XLEN +: XLEN]
  logic [NW-1:0]     lock;          // L of each entry
  logic [NW-1:0]     tor_lock;      // pmpaddr i is the base of a locked TOR entry i + 1
  logic [NW*XLEN-1:0] napot_ign;    // entry i: address bits ignored by NAPOT
  logic              sel_cfg;       // csr_addr is pmpcfg0
  logic [NW-1:0]     sel_addr;      // csr_addr is pmpaddr i
  logic [NW-1:0]     cfg_en;        // write cfg byte i
  logic [NW-1:0]     addr_en;       // write pmpaddr i
  logic [NW*CW-1:0]  cfg_d;         // legalized new cfg per entry
  logic [NW-1:0]     data_match;    // entry i covers the data address
  logic [NW-1:0]     fetch_match;   // entry i covers the fetch address
  logic [XLEN-3:0]   data_a;        // data address grain (addr[XLEN-1:2])
  logic [XLEN-3:0]   fetch_a;       // fetch address grain
  logic [CW-1:0]     data_sel;      // cfg of the first data match
  logic [CW-1:0]     fetch_sel;     // cfg of the first fetch match
  logic              data_any;      // some entry matches the data address
  logic              fetch_any;     // some entry matches the fetch address
  logic              load_ok;       // a load is allowed
  logic              store_ok;      // a store is allowed
  logic              fetch_ok;      // the fetch is allowed

  // ===========================================================================
  // CSRs
  // ===========================================================================
  assign sel_cfg = (N > 0) && (csr_addr == CSR_PMPCFG0);
  assign data_a  = data_addr[XLEN-1:2];
  assign fetch_a = fetch_addr[XLEN-1:2];

  for (genvar i = 0; i < N; i++) begin : g_entry
    logic [7:0]      wbyte;         // written cfg byte
    logic            wr_r;          // R after the R = 0 / W = 1 rule
    logic            wr_w;
    logic            wr_x;
    logic [XLEN-1:0] pa;            // pmpaddr i
    logic [XLEN-1:0] pa_inc;        // pmpaddr i + 1 (NAPOT size)
    logic [XLEN-1:0] lo;            // TOR base: pmpaddr i-1 (0 for entry 0)
    logic [1:0]      mode;          // A field

    assign lock[i]     = cfg[i*CW + 5];
    assign mode        = cfg[i*CW + 3 +: 2];
    assign sel_addr[i] = (csr_addr == CSR_PMPADDR0 + unsigned'(12'(i)));

    assign wbyte  = csr_wdata[i*8 +: 8];
    assign wr_r   = wbyte[0];
    assign wr_w   = wbyte[1] && wbyte[0];
    assign wr_x   = wbyte[2] && !(wbyte[1] && !wbyte[0]);
    assign cfg_d[i*CW +: CW] = {wbyte[7], wbyte[4:3], wr_x, wr_w, wr_r};
    assign cfg_en[i]  = csr_we && sel_cfg && !lock[i];
    assign addr_en[i] = csr_we && sel_addr[i] && !lock[i] && !tor_lock[i];

    basechili_dffe #(.WIDTH(CW)) u_cfg (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (cfg_en[i]),
      .d     (cfg_d[i*CW +: CW]),
      .q     (cfg[i*CW +: CW])
    );

    basechili_dffe #(.WIDTH(XLEN)) u_addr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (addr_en[i]),
      .d     (csr_wdata),
      .q     (addr[i*XLEN +: XLEN])
    );

    if (i + 1 < N) begin : g_tor_lock
      assign tor_lock[i] = cfg[(i+1)*CW + 5] && (cfg[(i+1)*CW + 3 +: 2] == A_TOR);
    end else begin : g_tor_lock_last
      assign tor_lock[i] = 1'b0;
    end

    // matching (a = address[XLEN-1:2], compared with pmpaddr zero-extended)
    assign pa     = addr[i*XLEN +: XLEN];
    assign pa_inc = pa + unsigned'(XLEN'(1));
    assign napot_ign[i*XLEN +: XLEN] = pa ^ pa_inc;
    if (i == 0) begin : g_lo0
      assign lo = '0;
    end else begin : g_lo
      assign lo = addr[(i-1)*XLEN +: XLEN];
    end

    chillus_pmp_match #(.XLEN(XLEN)) u_data_match (
      .mode      (mode),
      .a         (data_a),
      .pa        (pa),
      .lo        (lo),
      .napot_ign (napot_ign[i*XLEN +: XLEN]),
      .match     (data_match[i])
    );

    chillus_pmp_match #(.XLEN(XLEN)) u_fetch_match (
      .mode      (mode),
      .a         (fetch_a),
      .pa        (pa),
      .lo        (lo),
      .napot_ign (napot_ign[i*XLEN +: XLEN]),
      .match     (fetch_match[i])
    );
  end

  if (N == 0) begin : g_none
    assign cfg         = '0;
    assign addr        = '0;
    assign lock        = '0;
    assign tor_lock    = '0;
    assign napot_ign   = '0;
    assign sel_addr    = '0;
    assign cfg_en      = '0;
    assign addr_en     = '0;
    assign cfg_d       = '0;
    assign data_match  = '0;
    assign fetch_match = '0;
  end

  assign csr_hit = sel_cfg || (sel_addr != '0);
  assign refetch = csr_we && csr_hit;

  always_comb begin
    csr_rdata = '0;
    if (sel_cfg) begin
      for (int i = 0; i < N; i++) begin
        csr_rdata[i*8 +: 8] = {cfg[i*CW + 5], 2'b00, cfg[i*CW +: 5]};
      end
    end
    for (int i = 0; i < N; i++) begin
      if (sel_addr[i]) csr_rdata = addr[i*XLEN +: XLEN];
    end
  end

  // ===========================================================================
  // Checks: the lowest-numbered match decides
  // ===========================================================================
  always_comb begin
    data_sel  = '0;
    fetch_sel = '0;
    for (int i = N - 1; i >= 0; i--) begin
      if (data_match[i])  data_sel  = cfg[i*CW +: CW];
      if (fetch_match[i]) fetch_sel = cfg[i*CW +: CW];
    end
  end

  assign data_any  = data_match != '0;
  assign fetch_any = fetch_match != '0;

  // {L, A, X, W, R}: bit 5 L, bit 2 X, bit 1 W, bit 0 R
  assign load_ok  = data_any ? ((data_priv_m && !data_sel[5]) || data_sel[0]) : data_priv_m;
  assign store_ok = data_any ? ((data_priv_m && !data_sel[5]) || data_sel[1]) : data_priv_m;
  assign fetch_ok = fetch_any ? ((fetch_priv_m && !fetch_sel[5]) || fetch_sel[2])
                              : fetch_priv_m;

  // N = 0: no PMP, so no match does not deny U-mode either
  assign data_deny_load  = (N > 0) && !load_ok && !debug_mode;
  assign data_deny_store = (N > 0) && !store_ok && !debug_mode;
  assign fetch_deny      = (N > 0) && !fetch_ok && !debug_mode;

endmodule
