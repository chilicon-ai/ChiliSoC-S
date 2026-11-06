// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_sram -- a random AHB-Lite manager: back-to-back
// aligned reads and writes of every size the bus allows (mostly to a few hot
// words, so writes are buffered behind reads and reads hit the buffer, with
// partial byte writes), IDLE gaps, and transfers to another subordinate
// (HSEL low) whose data phases pull HREADY low for random cycles while this
// subordinate's next address phase waits. Behind the mem_* port, an SRAM
// model with 1-cycle read latency and byte enables (mem_rdata is garbage
// except the cycle after a read). Checked: every read returns the bytes of a
// reference memory updated in AHB order; zero wait states and OKAY, except
// READ_ONLY writes: the two-cycle ERROR, and no SRAM write ever.
`include "tb_common.svh"
module basechili_ahb_sram_tb #(
  parameter  int ADDR_W    = 32,
  parameter  int DATA_W    = 32,
  parameter  int MEM_AW    = 10,
  parameter  bit READ_ONLY = 1'b0,
  localparam int N_LANE    = DATA_W / 8,
  localparam int OFF_W     = $clog2(N_LANE),
  localparam int WORDS     = 1 << MEM_AW,
  localparam int N_HOT     = 3                // hot words (buffer hits)
);
  `TB_CLOCK_RESET
  logic              HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [ADDR_W-1:0] HADDR;
  logic [1:0]        HTRANS;
  logic [2:0]        HSIZE;
  logic [DATA_W-1:0] HWDATA, HRDATA;
  logic              mem_req, mem_we;
  logic [MEM_AW-1:0] mem_addr;
  logic [DATA_W-1:0] mem_wdata, mem_rdata;
  logic [N_LANE-1:0] mem_be;

  basechili_ahb_sram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .MEM_AW(MEM_AW), .READ_ONLY(READ_ONLY)) dut (
    .clk, .rst_n, .HSEL, .HADDR, .HTRANS, .HWRITE, .HSIZE, .HWDATA, .HREADY, .HREADYOUT, .HRESP, .HRDATA,
    .mem_req, .mem_we, .mem_addr, .mem_wdata, .mem_be, .mem_rdata);

  function automatic logic [DATA_W-1:0] rnd_data();
    return DATA_W'({$urandom, $urandom, $urandom, $urandom});   // DATA_W <= 128
  endfunction

  // ---- SRAM model ------------------------------------------------------------
  logic [DATA_W-1:0] sram [WORDS];
  int                n_mem_wr;   // SRAM writes seen
  always @(posedge clk) begin
    if (mem_req && mem_we) begin
      n_mem_wr <= n_mem_wr + 1;
      for (int b = 0; b < N_LANE; b++)
        if (mem_be[b]) sram[mem_addr][8*b +: 8] <= mem_wdata[8*b +: 8];
    end
    mem_rdata <= (mem_req && !mem_we) ? sram[mem_addr] : rnd_data();
  end

  // ---- reference memory and manager ---------------------------------------------
  logic [7:0]        ref_mem [WORDS * N_LANE];   // byte-level reference
  logic [MEM_AW-1:0] hot [N_HOT];

  // data phase in progress
  bit                dp_valid, dp_ours, dp_write;
  logic [MEM_AW-1:0] dp_word;
  logic [N_LANE-1:0] dp_lanes;
  int                ecyc;    // ERROR cycle of a READ_ONLY write data phase (0, 1, 2)
  bit                hold;    // HREADY was low: the address phase is held
  int                n_rd, n_wr, n_err, n_fill, n_hit, n_hit_part, n_drain_wr, n_wait_other, n_held_sel;

  task automatic new_addr();
    int                size, off;
    logic [MEM_AW-1:0] w;
    HTRANS = ($urandom % 5 == 0) ? 2'b00 : {1'b1, 1'($urandom)};
    HSEL   = ($urandom % 6 != 0);
    HWRITE = 1'($urandom);
    size   = $urandom_range(0, OFF_W);
    off    = ($urandom % (N_LANE >> size)) << size;
    w      = ($urandom % 3 != 0) ? hot[$urandom % N_HOT] : MEM_AW'($urandom);
    HADDR  = ADDR_W'({$urandom, $urandom});
    HADDR[OFF_W +: MEM_AW] = w;
    HADDR[OFF_W-1:0]       = OFF_W'(off);
    HSIZE  = 3'(size);
  endtask

  initial begin
    bit                e_ready, e_resp;
    logic [DATA_W-1:0] e_data;
    n_mem_wr = 0;
    for (int i = 0; i < WORDS; i++) begin
      sram[i] = rnd_data();
      for (int b = 0; b < N_LANE; b++) ref_mem[i*N_LANE + b] = sram[i][8*b +: 8];
    end
    for (int i = 0; i < N_HOT; i++) hot[i] = MEM_AW'($urandom);
    HSEL = 1'b0; HTRANS = 2'b00; HWRITE = 1'b0; HADDR = '0; HSIZE = '0; HWDATA = '0; HREADY = 1'b1;
    tb_reset();
    dp_valid = 0; ecyc = 0; hold = 0;
    n_rd = 0; n_wr = 0; n_err = 0; n_fill = 0; n_hit = 0; n_hit_part = 0; n_drain_wr = 0;
    n_wait_other = 0; n_held_sel = 0;
    for (int t = 0; t < 30000; t++) begin
      if (t % 3000 == 0)   // move the hot words now and then
        for (int i = 0; i < N_HOT; i++) hot[i] = MEM_AW'($urandom);
      // expected subordinate response and the bus HREADY
      if (dp_valid && dp_ours && dp_write && READ_ONLY) ecyc = (ecyc == 1) ? 2 : 1;
      else ecyc = 0;
      e_ready = (ecyc != 1);
      e_resp  = (ecyc != 0);
      if (!dp_valid)     HREADY = 1'b1;
      else if (dp_ours)  HREADY = e_ready;
      else begin
        HREADY = ($urandom % 3 != 0);   // another subordinate's wait states
        if (!HREADY) n_wait_other++;
      end
      // address phase: new, held, or cancelled during an ERROR
      if (!hold) new_addr();
      else if (ecyc == 2 && $urandom % 2 == 0) HTRANS = 2'b00;
      if (!HREADY && HSEL && HTRANS[1]) n_held_sel++;
      HWDATA = rnd_data();
      #1;
      `CHECK(HREADYOUT == e_ready && HRESP == e_resp,
             $sformatf("t=%0d HREADYOUT=%b HRESP=%b expected %b %b", t, HREADYOUT, HRESP, e_ready, e_resp))
      if (dp_valid && dp_ours && !dp_write) begin
        for (int b = 0; b < N_LANE; b++) e_data[8*b +: 8] = ref_mem[dp_word*N_LANE + b];
        `CHECK(HRDATA == e_data, $sformatf("t=%0d read word %h: HRDATA=%h expected %h (lanes %b)",
                                           t, dp_word, HRDATA, e_data, dp_lanes))
        n_rd++;
        if (dut.hit) begin
          n_hit++;
          if (dut.buf_be != '1) n_hit_part++;
        end
      end
      if (dut.buf_fill) n_fill++;
      if (dut.buf_drain && dut.wr_go) n_drain_wr++;
      @(posedge clk); #1;
      // the data phase ends with HREADY high; the address phase moves into it
      if (HREADY) begin
        if (dp_valid && dp_ours && dp_write) begin
          if (READ_ONLY) n_err++;
          else begin
            n_wr++;
            for (int b = 0; b < N_LANE; b++)
              if (dp_lanes[b]) ref_mem[dp_word*N_LANE + b] = HWDATA[8*b +: 8];
          end
        end
        dp_valid = HTRANS[1];
        dp_ours  = HSEL;
        dp_write = HWRITE;
        dp_word  = HADDR[OFF_W +: MEM_AW];
        for (int b = 0; b < N_LANE; b++)
          dp_lanes[b] = (b >= int'(HADDR[OFF_W-1:0])) && (b < int'(HADDR[OFF_W-1:0]) + (1 << HSIZE));
      end
      hold = !HREADY;
      @(negedge clk);
    end
    `CHECK(n_rd > 3000 && n_wait_other > 1000 && n_held_sel > 300,
           $sformatf("coverage rd=%0d wait_other=%0d held_sel=%0d", n_rd, n_wait_other, n_held_sel))
    if (READ_ONLY) begin
      `CHECK(n_mem_wr == 0 && n_err > 1000, $sformatf("READ_ONLY: %0d SRAM writes, %0d errors", n_mem_wr, n_err))
    end else begin
      `CHECK(n_wr > 3000 && n_fill > 1000 && n_hit > 300 && n_hit_part > 200 && n_drain_wr > 300,
             $sformatf("coverage wr=%0d fill=%0d hit=%0d hit_part=%0d drain_wr=%0d",
                       n_wr, n_fill, n_hit, n_hit_part, n_drain_wr))
    end
    $display("rd=%0d wr=%0d err=%0d fill=%0d hit=%0d hit_part=%0d drain_wr=%0d wait_other=%0d held_sel=%0d",
             n_rd, n_wr, n_err, n_fill, n_hit, n_hit_part, n_drain_wr, n_wait_other, n_held_sel);
    tb_pass();
  end
endmodule
