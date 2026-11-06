// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_apb_interconnect -- one APB manager, N subordinate
// models with random wait states, PSLVERR and PRDATA.
//
// Regions (when BASE / MASK are left at the TB defaults): region i is the
// 1/16 of the address space with top nibble i + 1; other top nibbles are
// unmapped. The manager runs SETUP / ACCESS transfers with idle gaps;
// every cycle PSEL_s must be the matching region's bit (zero when PSEL is
// low) and PREADY / PSLVERR / PRDATA the selected subordinate's, or
// PREADY = PSLVERR = 1 for an unmapped address. Every transfer completes.
`include "tb_common.svh"
module basechili_apb_interconnect_tb #(
  parameter int                  ADDR_W = 32,
  parameter int                  DATA_W = 32,
  parameter int                  N      = 2,
  parameter logic [N*ADDR_W-1:0] BASE   = tb_base(),
  parameter logic [N*ADDR_W-1:0] MASK   = tb_mask()
);
  localparam int N_XFER = 3000;

  function automatic logic [N*ADDR_W-1:0] tb_base();
    logic [N*ADDR_W-1:0] b;
    b = '0;
    for (int i = 0; i < N; i++) b[i*ADDR_W +: ADDR_W] = ADDR_W'(i + 1) << (ADDR_W - 4);
    return b;
  endfunction

  function automatic logic [N*ADDR_W-1:0] tb_mask();
    logic [N*ADDR_W-1:0] m;
    m = '0;
    for (int i = 0; i < N; i++) m[i*ADDR_W +: ADDR_W] = ADDR_W'(4'hF) << (ADDR_W - 4);
    return m;
  endfunction

  `TB_CLOCK_RESET

  logic                PSEL, PENABLE, PREADY, PSLVERR;
  logic [ADDR_W-1:0]   PADDR;
  logic [DATA_W-1:0]   PRDATA;
  logic [N-1:0]        PSEL_s, PREADY_s, PSLVERR_s;
  logic [N*DATA_W-1:0] PRDATA_s;

  basechili_apb_interconnect #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .N(N), .BASE(BASE), .MASK(MASK)) dut (
    .PSEL, .PADDR, .PREADY, .PRDATA, .PSLVERR, .PSEL_s, .PREADY_s, .PRDATA_s, .PSLVERR_s);

  // reference decode: index of the matching region, -1 when none
  function automatic int ref_target(logic [ADDR_W-1:0] a);
    for (int i = 0; i < N; i++)
      if ((a & MASK[i*ADDR_W +: ADDR_W]) == BASE[i*ADDR_W +: ADDR_W]) return i;
    return -1;
  endfunction

  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] d;
    for (int k = 0; k < DATA_W; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  int done, unmapped;
  int per_sub [N];

  initial begin
    int tgt;
    PSEL = 1'b0; PENABLE = 1'b0; PADDR = '0;
    PREADY_s = '0; PSLVERR_s = '0; PRDATA_s = '0;
    done = 0; unmapped = 0;
    for (int i = 0; i < N; i++) per_sub[i] = 0;
    tb_reset();
    while (done < N_XFER) begin
      // ---- manager: idle -> SETUP -> ACCESS (until PREADY) ----
      if (!PSEL) begin
        if ($urandom % 3 != 0) begin
          logic [3:0] top;
          top   = ($urandom % 4 == 0) ? 4'($urandom) : 4'(1 + $urandom % N);
          PADDR = (ADDR_W'(top) << (ADDR_W - 4)) | (ADDR_W'($urandom) & ~(ADDR_W'(4'hF) << (ADDR_W - 4)));
          PSEL  = 1'b1;
        end else PADDR = ADDR_W'($urandom);   // address may change while idle
      end else if (!PENABLE) PENABLE = 1'b1;
      // ---- subordinates: random wait states / errors / data every cycle ----
      PREADY_s  = N'($urandom);
      PSLVERR_s = N'($urandom % 4 == 0 ? $urandom : 0);
      for (int i = 0; i < N; i++) PRDATA_s[i*DATA_W +: DATA_W] = rnd_data();
      #1;
      tgt = ref_target(PADDR);
      `CHECK(PSEL_s == ((PSEL && tgt >= 0) ? N'(1) << tgt : N'(0)),
             $sformatf("PSEL_s=%b PSEL=%b PADDR=%h", PSEL_s, PSEL, PADDR))
      if (tgt < 0) begin
        `CHECK(PREADY && PSLVERR, $sformatf("unmapped PADDR=%h: PREADY=%b PSLVERR=%b", PADDR, PREADY, PSLVERR))
      end else begin
        `CHECK(PREADY == PREADY_s[tgt] && PSLVERR == PSLVERR_s[tgt]
               && PRDATA == PRDATA_s[tgt*DATA_W +: DATA_W],
               $sformatf("PADDR=%h target %0d: PREADY=%b PSLVERR=%b PRDATA=%h", PADDR, tgt, PREADY, PSLVERR, PRDATA))
      end
      // ---- transfer end ----
      if (PSEL && PENABLE && PREADY) begin
        if (tgt < 0) unmapped++; else per_sub[tgt]++;
        done++;
        @(negedge clk);
        PSEL = 1'b0; PENABLE = 1'b0;
        // back to back half of the time: SETUP right after ACCESS
        if ($urandom % 2) continue;
      end else @(negedge clk);
    end
    `CHECK(unmapped > 0, "no unmapped transfer")
    for (int i = 0; i < N; i++) `CHECK(per_sub[i] > 0, $sformatf("no transfer to subordinate %0d", i))
    tb_pass();
  end

  initial begin
    #(N_XFER * 200);
    `CHECK(1'b0, $sformatf("timeout after %0d transfers", done))
  end
endmodule
