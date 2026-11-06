// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_plic
//
// RISC-V PLIC in the SiFive layout for 63 level-triggered sources (IDs
// 1 .. 63) and N_CTX contexts (1 .. 16; by convention hart h has context 2h
// for M-mode and 2h+1 for S-mode), so existing PLIC drivers work:
//   0x000004 + 4*(i-1)        priority of source i (3 bits, 0 = never interrupts)
//   0x001000 / 0x001004       pending bits of sources 1 .. 31 / 32 .. 63
//   0x002000 + 0x80*c (+4)    context c enable bits of sources 1 .. 31 (32 .. 63)
//   0x200000 + 0x1000*c       context c threshold
//   0x200004 + 0x1000*c       context c claim (read) / complete (write)
// Context registers of c >= N_CTX read 0 and ignore writes.
// Gateway per source (level): an asserted irq becomes pending unless the
// source is in service (claimed by any context, not completed). A claim read
// of context c returns the pending source enabled for c with the highest
// priority above 0 (lowest ID on a tie; 0 if none), clears its pending bit
// and puts it in service. Writing its ID to c's claim register completes it
// (ignored unless the source is enabled for c); a still-asserted irq then
// becomes pending again. eip[c] = (c's best priority > c's threshold),
// registered.
//
// Timing    : APB reads are combinational (no wait states); pending, the
//             in-service bits and eip are registered (an irq shows on eip
//             two cycles later).
// Invariants: pending and in_service are never both set for a source;
//             source 0 is never pending; eip[c] is the registered
//             (best_valid[c] && best_prio[c] > threshold[c]) of the cycle
//             before; claim_rd and claim_wr are zero or one-hot (one APB
//             access at a time).
// Debug     : no interrupt on context c -> pending, enable_id[c*64 +: 64], prio
//             of the source, threshold, g_ctx[c].u_best.max_valid / max_val;
//             source stuck -> in_service (no complete, or completed while
//             disabled for that context: complete_go, complete_id); wrong ID
//             -> g_ctx[c].u_best.
// -----------------------------------------------------------------------------
module chilimix_plic #(
  parameter int N_CTX = 1         // contexts (1 .. 16)
) (
  input  logic             clk,
  input  logic             rst_n,      // async, active-low
  // APB4 subordinate (registers)
  input  logic             PSEL,
  input  logic             PENABLE,
  input  logic             PWRITE,
  input  logic [21:0]      PADDR,      // byte address inside the PLIC
  input  logic [31:0]      PWDATA,
  input  logic [3:0]       PSTRB,
  output logic             PREADY,
  output logic [31:0]      PRDATA,
  output logic             PSLVERR,
  // sources and targets
  input  logic [63:1]      irq,        // level interrupt requests, synchronous to clk
  output logic [N_CTX-1:0] eip         // external interrupt pending to each context
);

  localparam int N_SRC   = 64;    // IDs 0 .. 63 (0: no interrupt)
  localparam int PRIO_W  = 3;     // priority bits
  localparam int ID_W    = 6;
  localparam int MAX_CTX = 16;    // contexts in the register map

  logic [N_SRC*PRIO_W-1:0]      prio;          // priority of source i at prio[i*PRIO_W +: PRIO_W]
  logic [MAX_CTX*31-1:0]        enable0;       // enables of sources 1 .. 31, 31 bits per context
  logic [MAX_CTX*32-1:0]        enable1;       // enables of sources 32 .. 63, 32 bits per context
  logic [MAX_CTX*PRIO_W-1:0]    threshold;     // threshold of context c at threshold[c*PRIO_W +: PRIO_W]
  logic [MAX_CTX*ID_W-1:0]      claim_id;      // claim register read values (0 past N_CTX)
  logic [MAX_CTX-1:0]           claim_rd_all;  // claim register of context c read (ACCESS)
  logic [MAX_CTX-1:0]           claim_wr_all;  // claim register of context c written (ACCESS)
  logic [N_CTX-1:0]             claim_rd;      // claim_rd_all of the contexts present
  logic [N_CTX-1:0]             claim_wr;
  logic [N_SRC-1:1]             pending;       // gateway forwarded, not claimed (pending0: 31:1, pending1: 63:32)
  logic [N_SRC-1:1]             pending_d;
  logic [N_SRC-1:1]             in_service;    // claimed, not completed
  logic [N_SRC-1:0]             svc_valid;     // in_service by ID (bit 0 never set)
  logic [N_CTX*N_SRC-1:0]       enable_id;     // enables of context c by ID at [c*N_SRC +: N_SRC] (bit 0: no source)
  logic [N_CTX-1:0]             best_valid;    // context c has a candidate
  logic [N_CTX*PRIO_W-1:0]      best_prio;     // its highest candidate priority
  logic [N_CTX*ID_W-1:0]        best_id;       // its source ID
  logic [N_CTX-1:0]             eip_d;
  logic [ID_W-1:0]              claim_sel_id;  // best_id of the context claiming
  logic [N_SRC-1:0]             wr_enable_id;  // enable_id of the context completing
  logic                         claim_go;      // a claim read takes claim_sel_id
  logic [N_SRC-1:0]             claim_onehot;  // claim_sel_id decoded
  logic [N_SRC-1:1]             claim_hit;     // source claimed this cycle
  logic [ID_W-1:0]              complete_id;   // ID written to claim
  logic                         complete_go;   // that ID completes (enabled source)

  assign prio[0 +: PRIO_W] = '0;   // source 0 does not exist

  chilimix_plic_regs #(.N_CTX(N_CTX)) u_regs (
    .clk             (clk),
    .rst_n           (rst_n),
    .PSEL            (PSEL),
    .PENABLE         (PENABLE),
    .PWRITE          (PWRITE),
    .PADDR           (PADDR),
    .PWDATA          (PWDATA),
    .PSTRB           (PSTRB),
    .PREADY          (PREADY),
    .PRDATA          (PRDATA),
    .PSLVERR         (PSLVERR),
    .priority_value  (prio[PRIO_W +: (N_SRC-1)*PRIO_W]),
    .pending0_src    (pending[31:1]),
    .pending1_src    (pending[63:32]),
    .enable0_src     (enable0),
    .enable1_src     (enable1),
    .threshold_value (threshold),
    .claim_id        (claim_id),
    .claim_rd        (claim_rd_all),
    .claim_wr        (claim_wr_all)
  );

  assign claim_rd = claim_rd_all[N_CTX-1:0];
  assign claim_wr = claim_wr_all[N_CTX-1:0];

  // ---- per context: highest-priority enabled pending source, notification
  for (genvar c = 0; c < N_CTX; c++) begin : g_ctx
    logic [N_SRC-1:0] cand;   // pending, enabled for c, priority above 0

    assign enable_id[c*N_SRC +: N_SRC] = {enable1[c*32 +: 32], enable0[c*31 +: 31], 1'b0};

    always_comb begin
      cand[0] = 1'b0;
      for (int i = 1; i < N_SRC; i++)
        cand[i] = pending[i] && enable_id[c*N_SRC + i] && prio[i*PRIO_W +: PRIO_W] != '0;
    end

    basechili_max_tree #(.N(N_SRC), .W(PRIO_W)) u_best (
      .val       (prio),
      .valid     (cand),
      .max_valid (best_valid[c]),
      .max_val   (best_prio[c*PRIO_W +: PRIO_W]),
      .max_idx   (best_id[c*ID_W +: ID_W])
    );

    assign claim_id[c*ID_W +: ID_W] = best_valid[c] ? best_id[c*ID_W +: ID_W] : '0;
    assign eip_d[c] = best_valid[c] && best_prio[c*PRIO_W +: PRIO_W] > threshold[c*PRIO_W +: PRIO_W];
  end

  if (N_CTX < MAX_CTX) begin : g_absent
    assign claim_id[MAX_CTX*ID_W-1:N_CTX*ID_W] = '0;
  end

  // ---- gateways, claim and complete (one APB access: claim_rd / claim_wr zero or one-hot)
  basechili_onehot_mux #(.WIDTH(ID_W), .N(N_CTX)) u_claim_mux (
    .in  (best_id),
    .sel (claim_rd),
    .out (claim_sel_id)
  );

  basechili_onehot_mux #(.WIDTH(N_SRC), .N(N_CTX)) u_complete_mux (
    .in  (enable_id),
    .sel (claim_wr),
    .out (wr_enable_id)
  );

  basechili_decoder #(.N(N_SRC)) u_claim_dec (
    .in  (claim_sel_id),
    .out (claim_onehot)
  );

  assign claim_go    = |(claim_rd & best_valid);
  assign claim_hit   = claim_onehot[N_SRC-1:1] & {(N_SRC-1){claim_go}};
  assign complete_id = PWDATA[ID_W-1:0];
  assign complete_go = (|claim_wr) && PSTRB[0] && wr_enable_id[complete_id];
  assign pending_d   = (pending | (irq & ~in_service)) & ~claim_hit;

  basechili_dff #(.WIDTH(N_SRC-1)) u_pending (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pending_d),
    .q     (pending)
  );

  // claim sets, complete clears (never both: a claim is a read, a complete a write)
  basechili_valid_array #(.N(N_SRC)) u_in_service (
    .clk      (clk),
    .rst_n    (rst_n),
    .flush    (1'b0),
    .set_en   (claim_go),
    .set_idx  (claim_sel_id),
    .clr_en   (complete_go),
    .clr_idx  (complete_id),
    .valid    (svc_valid),
    .full     (),
    .empty    (),
    .free_idx ()
  );

  assign in_service = svc_valid[N_SRC-1:1];

  // ---- notification
  basechili_dff #(.WIDTH(N_CTX)) u_eip (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (eip_d),
    .q     (eip)
  );

endmodule
