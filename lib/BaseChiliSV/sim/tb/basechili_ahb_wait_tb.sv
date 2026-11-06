// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_wait -- a random AHB-Lite manager on the bus
// side (reads and writes of every size, IDLE gaps, dense phases of
// back-to-back transfers, transfers to another subordinate whose data phases
// pull HREADY low while our next address phase waits, and next transfers
// cancelled in the second ERROR cycle) and, behind the DUT, a memory
// subordinate model with random wait states and random two-cycle ERRORs.
// Checked per transfer: it reaches the subordinate exactly once with the same
// address, size and direction; the bus sees the subordinate's response
// (OKAY / ERROR shape, read data of a reference memory updated in AHB order);
// the bus data phase is longer than the subordinate's by exactly WAIT
// cycles, or by 1..WAIT with RANDOM (both ends hit); WAIT = 0 adds none.
`include "tb_common.svh"
module basechili_ahb_wait_tb #(
  parameter  int          ADDR_W = 32,
  parameter  int          DATA_W = 32,
  parameter  int          WAIT   = 1,
  parameter  bit          RANDOM = 1'b0,
  parameter  logic [15:0] SEED   = 16'h1,
  localparam int          N_LANE = DATA_W / 8,
  localparam int          OFF_W  = $clog2(N_LANE),
  localparam int          AW     = 6,              // word address bits used
  localparam int          WORDS  = 1 << AW
);
  `TB_CLOCK_RESET
  logic              HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [ADDR_W-1:0] HADDR;
  logic [1:0]        HTRANS;
  logic [2:0]        HSIZE;
  logic [DATA_W-1:0] HWDATA, HRDATA;
  logic              HSEL_s, HWRITE_s, HREADY_s, HREADYOUT_s, HRESP_s;
  logic [ADDR_W-1:0] HADDR_s;
  logic [1:0]        HTRANS_s;
  logic [2:0]        HSIZE_s;
  logic [DATA_W-1:0] HWDATA_s, HRDATA_s;

  basechili_ahb_wait #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .WAIT(WAIT), .RANDOM(RANDOM), .SEED(SEED)) dut (
    .clk, .rst_n, .HSEL, .HADDR, .HTRANS, .HWRITE, .HSIZE, .HWDATA, .HREADY, .HREADYOUT, .HRESP, .HRDATA,
    .HSEL_s, .HADDR_s, .HTRANS_s, .HWRITE_s, .HSIZE_s, .HWDATA_s, .HREADY_s, .HREADYOUT_s, .HRESP_s,
    .HRDATA_s);

  function automatic logic [DATA_W-1:0] rnd_data();
    return DATA_W'({$urandom, $urandom, $urandom, $urandom});   // DATA_W <= 128
  endfunction

  function automatic logic [N_LANE-1:0] lanes_of(logic [ADDR_W-1:0] a, logic [2:0] s);
    logic [N_LANE-1:0] l;
    for (int b = 0; b < N_LANE; b++)
      l[b] = (b >= int'(a[OFF_W-1:0])) && (b < int'(a[OFF_W-1:0]) + (1 << s));
    return l;
  endfunction

  // ---- subordinate model: memory, random waits and ERRORs -------------------------
  typedef struct {
    logic [ADDR_W-1:0] addr;
    logic [2:0]        size;
    logic              write;
    int                len;     // data phase cycles at the subordinate
    bit                err;
  } xfer_t;
  xfer_t             seen [$];          // transfers that reached the subordinate
  logic [DATA_W-1:0] ds_mem [WORDS];
  bit                ds_dp, ds_err, ds_write, ds_slow;
  int                ds_k, ds_len, n_ds_wait, n_seen, n_busy_addr;
  logic [AW-1:0]     ds_word;
  logic [N_LANE-1:0] ds_lanes;
  logic [DATA_W-1:0] garbage;

  assign HREADYOUT_s = !ds_dp || ds_k == ds_len - 1;
  assign HRESP_s     = ds_dp && ds_err && ds_k >= ds_len - 2;
  assign HRDATA_s    = (ds_dp && !ds_write && ds_k == ds_len - 1) ? ds_mem[ds_word] : garbage;

  always @(posedge clk) begin
    garbage <= rnd_data();
    if (!rst_n) ds_dp <= 1'b0;
    else if (HREADY_s) begin
      if (ds_dp && ds_write && !ds_err)
        for (int b = 0; b < N_LANE; b++)
          if (ds_lanes[b]) ds_mem[ds_word][8*b +: 8] <= HWDATA_s[8*b +: 8];
      ds_dp <= HSEL_s && HTRANS_s[1];
      if (HSEL_s && HTRANS_s[1]) begin
        xfer_t x;
        int    w;
        w       = (ds_slow && $urandom % 3 == 0) ? $urandom_range(1, 3) : 0;
        x.addr  = HADDR_s;
        x.size  = HSIZE_s;
        x.write = HWRITE_s;
        x.err   = ($urandom % 8 == 0);
        x.len   = w + (x.err ? 2 : 1);
        seen.push_back(x);
        n_seen++;
        if (w > 0) n_ds_wait++;
        ds_k     <= 0;
        ds_len   <= x.len;
        ds_err   <= x.err;
        ds_write <= HWRITE_s;
        ds_word  <= HADDR_s[OFF_W +: AW];
        ds_lanes <= lanes_of(HADDR_s, HSIZE_s);
      end
    end else begin
      ds_k <= ds_k + 1;
      if (HSEL_s && HTRANS_s[1]) n_busy_addr++;
    end
  end

  // ---- bus manager and reference ---------------------------------------------------
  logic [DATA_W-1:0] ref_mem [WORDS];
  logic              other_ready;      // HREADYOUT of the other subordinate
  bit                dp_valid, dp_ours, dp_write, hold, dense, err1_seen;
  logic [ADDR_W-1:0] dp_addr;
  logic [2:0]        dp_size;
  int                dp_len, w_min, w_max;
  int                n_ours, n_rd, n_wr, n_err, n_b2b, n_cancel, n_held_sel, n_wait_other;

  assign HREADY = (dp_valid && dp_ours) ? HREADYOUT : other_ready;

  task automatic new_addr();
    int size;
    HTRANS = (!dense && $urandom % 4 == 0) ? 2'b00 : {1'b1, 1'($urandom)};
    HSEL   = dense || ($urandom % 4 != 0);
    HWRITE = 1'($urandom);
    size   = $urandom_range(0, OFF_W);
    HADDR  = ADDR_W'({$urandom, $urandom});
    HADDR[OFF_W-1:0] = OFF_W'((($urandom % (N_LANE >> size)) << size));
    HSIZE  = 3'(size);
  endtask

  initial begin
    xfer_t             x;
    bit                rdy, resp_seen;
    logic [N_LANE-1:0] lanes;
    int                w;
    for (int i = 0; i < WORDS; i++) begin
      ds_mem[i]  = rnd_data();
      ref_mem[i] = ds_mem[i];
    end
    HSEL = 1'b0; HTRANS = 2'b00; HWRITE = 1'b0; HADDR = '0; HSIZE = '0; HWDATA = '0;
    other_ready = 1'b1; ds_slow = 1'b0; dense = 1'b0;
    n_ds_wait = 0; n_seen = 0; n_busy_addr = 0;
    tb_reset();
    dp_valid = 0; hold = 0; err1_seen = 0; resp_seen = 0; dp_len = 0;
    w_min = WAIT + 1; w_max = -1;
    n_ours = 0; n_rd = 0; n_wr = 0; n_err = 0; n_b2b = 0; n_cancel = 0; n_held_sel = 0; n_wait_other = 0;
    for (int t = 0; t < 30000; t++) begin
      if (t % 1500 == 0) begin   // switch the traffic mix now and then
        dense   = ($urandom % 3 == 0);
        ds_slow = ($urandom % 2 == 0);
      end
      // address phase: new, held, or cancelled in the second ERROR cycle
      if (!hold) begin
        new_addr();
        HWDATA = rnd_data();     // a new data phase starts
      end else if (err1_seen && $urandom % 2 == 0) begin
        HTRANS = 2'b00;
        n_cancel++;
      end
      other_ready = !(dp_valid && !dp_ours) || ($urandom % 3 != 0);
      #1;
      rdy = HREADY;
      if (!rdy && HSEL && HTRANS[1]) n_held_sel++;
      if (dp_valid && !dp_ours && !rdy) n_wait_other++;
      if (WAIT > 0)
        `CHECK(!(HSEL_s && HTRANS_s[1] && !HREADY_s), $sformatf("t=%0d downstream address phase while busy", t))
      if (dp_valid && dp_ours) begin
        dp_len++;
        if (!rdy) begin
          if (HRESP) begin
            `CHECK(!resp_seen, $sformatf("t=%0d ERROR first cycle twice", t))
            resp_seen = 1;
          end
        end else begin
          // data phase ends: compare with what reached the subordinate
          `CHECK(seen.size() == 1, $sformatf("t=%0d %0d transfers at the subordinate, expected 1", t, seen.size()))
          if (seen.size() > 0) begin
            x = seen.pop_front();
            `CHECK(x.addr == dp_addr && x.size == dp_size && x.write == dp_write,
                   $sformatf("t=%0d forwarded %h/%0d/%b expected %h/%0d/%b", t, x.addr, x.size, x.write,
                             dp_addr, dp_size, dp_write))
            `CHECK(HRESP == x.err && resp_seen == x.err,
                   $sformatf("t=%0d HRESP=%b first cycle=%b expected ERROR=%b", t, HRESP, resp_seen, x.err))
            w = dp_len - x.len;
            if (!RANDOM || WAIT == 0)
              `CHECK(w == WAIT, $sformatf("t=%0d %0d wait states added, expected %0d", t, w, WAIT))
            else
              `CHECK(w >= 1 && w <= WAIT, $sformatf("t=%0d %0d wait states added, expected 1..%0d", t, w, WAIT))
            if (w < w_min) w_min = w;
            if (w > w_max) w_max = w;
            if (x.err) n_err++;
            else if (dp_write) begin
              n_wr++;
              lanes = lanes_of(dp_addr, dp_size);
              for (int b = 0; b < N_LANE; b++)
                if (lanes[b]) ref_mem[dp_addr[OFF_W +: AW]][8*b +: 8] = HWDATA[8*b +: 8];
            end else begin
              n_rd++;
              `CHECK(HRDATA == ref_mem[dp_addr[OFF_W +: AW]],
                     $sformatf("t=%0d read %h: HRDATA=%h expected %h", t, dp_addr, HRDATA, ref_mem[dp_addr[OFF_W +: AW]]))
            end
          end
          n_ours++;
          if (HSEL && HTRANS[1]) n_b2b++;
        end
      end
      err1_seen = (dp_valid && dp_ours && !rdy && HRESP);
      @(posedge clk); #1;
      if (rdy) begin
        dp_valid  = HTRANS[1];
        dp_ours   = HSEL;
        dp_write  = HWRITE;
        dp_addr   = HADDR;
        dp_size   = HSIZE;
        dp_len    = 0;
        resp_seen = 0;
      end
      hold = !rdy;
      @(negedge clk);
    end
    `CHECK(n_seen - seen.size() == n_ours,
           $sformatf("%0d transfers reached the subordinate, %0d ended on the bus", n_seen, n_ours))
    `CHECK(n_rd > 1500 && n_wr > 1500 && n_err > 300 && n_b2b > 1000 && n_cancel > 50 && n_held_sel > 300
           && n_wait_other > 200 && n_ds_wait > 500,
           $sformatf("coverage rd=%0d wr=%0d err=%0d b2b=%0d cancel=%0d held_sel=%0d wait_other=%0d ds_wait=%0d",
                     n_rd, n_wr, n_err, n_b2b, n_cancel, n_held_sel, n_wait_other, n_ds_wait))
    if (RANDOM && WAIT > 0)
      `CHECK(w_min == 1 && w_max == WAIT, $sformatf("random waits seen %0d..%0d, expected 1..%0d", w_min, w_max, WAIT))
    $display("ours=%0d rd=%0d wr=%0d err=%0d b2b=%0d cancel=%0d held_sel=%0d wait_other=%0d ds_wait=%0d waits %0d..%0d",
             n_ours, n_rd, n_wr, n_err, n_b2b, n_cancel, n_held_sel, n_wait_other, n_ds_wait, w_min, w_max);
    tb_pass();
  end
endmodule
