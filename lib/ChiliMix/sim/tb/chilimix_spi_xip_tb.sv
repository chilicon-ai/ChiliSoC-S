// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_spi_xip -- random AHB reads and writes of the flash
// window against a frame-level model of the phy and a flash.
//
// Stimulus: AHB single transfers (any size) to a few line addresses spread
// over the window, pipelined or with idle cycles, some writes; en
// toggled now and then; flushes alone and with a new random read format
// (cmd_en, addr_len 0 .. 7, pad_cnt, each protocol, codes), changed only
// while no fill runs. The model takes frames after random delays and
// returns the data bytes after random delays.
// Checked: the frames of every fill in order (first flag, command, address
// bytes of the line, driven and floating dummy cycles, LINE_B data frames,
// keep cleared only on the last); every response: ERROR for writes and
// reads with en 0, else the flash bytes of the line (address truncated to
// addr_len bytes) on the right lanes; hits answer with one wait state.
`include "tb_common.svh"
module chilimix_spi_xip_tb #(
  parameter int ADDR_W = 29,
  parameter int LINES  = 4,
  parameter int LINE_B = 16
);
  localparam int N_XFER = 6000;
  localparam int OFF_W  = $clog2(LINE_B);
  localparam int N_LA   = 3 * LINES;        // distinct line addresses used

  `TB_CLOCK_RESET

  logic              HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [ADDR_W-1:0] HADDR;
  logic [1:0]        HTRANS;
  logic [2:0]        HSIZE;
  logic [31:0]       HWDATA, HRDATA;
  logic              en, flush, cmd_en;
  logic [2:0]        addr_len;
  logic [3:0]        pad_cnt;
  logic [1:0]        cmd_proto, addr_proto, data_proto;
  logic [7:0]        cmd_code, pad_code;
  logic              f_valid, f_accept;
  logic [7:0]        f_data;
  logic [3:0]        f_cycles;
  logic [1:0]        f_proto;
  logic              f_oe, f_rx, f_keep, f_first;
  logic              rx_valid;
  logic [7:0]        rx_data;
  logic              busy;

  chilimix_spi_xip #(.ADDR_W(ADDR_W), .LINES(LINES), .LINE_B(LINE_B)) dut (.*);

  logic [ADDR_W-1:0] lines [N_LA];
  logic [ADDR_W-1:0] req_addr;         // address of the read in its data phase
  // model: frames of the current fill
  int         fr_n;                    // frames taken in this fill
  int         n_cmd, n_addr, n_pad, n_dummy;
  logic [7:0] exp_addr [4];
  logic [31:0] fill_fa;                // flash address of the line (truncated)
  logic [7:0] rxq [$];                 // data bytes to return
  int         n_fill, n_hit, n_err, n_flush_fill;

  assign HREADY = HREADYOUT;           // the only subordinate on the bus

  function automatic logic [7:0] flash(logic [31:0] a);
    return 8'(a * 32'd7 + (a >> 8) * 32'd13 + (a >> 19) + 32'd5);
  endfunction

  function automatic int cyc8(logic [1:0] p);
    return (p == 2'd2) ? 2 : (p == 2'd1) ? 4 : 8;
  endfunction

  function automatic int addr_n();
    return (addr_len > 3'd4) ? 4 : int'(addr_len);
  endfunction

  function automatic logic [31:0] trunc(logic [31:0] a);
    return (addr_n() == 4) ? a : a & ((32'd1 << (8 * addr_n())) - 1);
  endfunction

  task automatic new_format();
    cmd_en     = $urandom % 4 != 0;
    addr_len   = 3'($urandom % 8);
    pad_cnt    = ($urandom % 2 == 0) ? 4'd0 : 4'($urandom);
    cmd_proto  = 2'($urandom);
    addr_proto = 2'($urandom);
    data_proto = 2'($urandom);
    cmd_code   = $urandom;
    pad_code   = $urandom;
  endtask

  // ---- phy and flash model --------------------------------------------------
  always @(negedge clk) begin
    if (rst_n) begin
      #2;
      f_accept = $urandom % 3 == 0;
      rx_valid = 0;
      if (rxq.size() > 0 && $urandom % 2 == 0) begin
        rx_valid = 1;
        rx_data  = rxq.pop_front();
      end
      #1;
      if (f_valid && f_accept) begin
        int k, pd, pf, na;
        na = addr_n();
        pd = (int'(pad_cnt) < cyc8(addr_proto)) ? int'(pad_cnt) : cyc8(addr_proto);
        pf = int'(pad_cnt) - pd;
        `CHECK(busy, "a frame only during a fill")
        `CHECK(f_first == (fr_n == 0), "f_first on the first frame of a fill only")
        k = fr_n;
        if (cmd_en && k == 0) begin
          `CHECK(f_data == cmd_code && int'(f_cycles) == cyc8(cmd_proto) && f_proto == cmd_proto
                 && f_oe && !f_rx && f_keep, "command frame")
          n_cmd++;
        end else begin
          k -= int'(cmd_en);
          if (k < na) begin
            `CHECK(f_data == exp_addr[na - 1 - k] && int'(f_cycles) == cyc8(addr_proto)
                   && f_proto == addr_proto && f_oe && !f_rx && f_keep, "address frame")
            n_addr++;
          end else begin
            k -= na;
            if (pad_cnt != 0 && k == 0) begin
              `CHECK(f_data == pad_code && int'(f_cycles) == pd && f_proto == addr_proto
                     && f_oe && !f_rx && f_keep, "driven dummy frame")
              n_pad++;
            end else begin
              k -= int'(pad_cnt != 0);
              if (pf != 0 && k == 0) begin
                `CHECK(int'(f_cycles) == pf && f_proto == addr_proto && !f_oe && !f_rx && f_keep,
                       "floating dummy frame")
                n_dummy++;
              end else begin
                k -= int'(pf != 0);
                `CHECK(k < LINE_B, "data frames of one line")
                `CHECK(int'(f_cycles) == cyc8(data_proto) && f_proto == data_proto && f_rx
                       && f_oe == (data_proto != 2'd1 && data_proto != 2'd2)
                       && f_keep == (k != LINE_B - 1), "data frame")
                rxq.push_back(flash(fill_fa + 32'(k)));
                if (k == LINE_B - 1) begin fr_n = -1; n_fill++; end
              end
            end
          end
        end
        fr_n++;
      end
    end
  end

  // a read that starts a fill: its frames carry the line address
  always @(posedge clk) begin
    if (rst_n && dut.start) begin
      logic [31:0] base;
      `CHECK(fr_n == 0, "a fill starts after the previous one ended")
      base    = 32'(dut.req_addr) & ~32'(LINE_B - 1);
      for (int i = 0; i < 4; i++) exp_addr[i] = base[8*i +: 8];
      fill_fa = trunc(base);
    end
  end

  // ---- AHB transfers ---------------------------------------------------------
  task automatic xfer(input logic wr, input logic [ADDR_W-1:0] a);
    logic [31:0] exp;
    logic        exp_err;
    int          waits;
    // address phase
    HSEL = 1; HTRANS = 2'b10; HWRITE = wr; HADDR = a; HSIZE = 3'($urandom % 3);
    @(posedge clk);
    @(negedge clk);
    HWDATA = $urandom;
    HSEL = $urandom; HTRANS = 2'b00;
    flush = 0;
    exp_err = wr || !en;
    waits = 0;
    while (!HREADYOUT) begin
      if (HRESP) `CHECK(exp_err, "ERROR response")
      @(negedge clk);
      flush = busy && $urandom % 400 == 0;      // a register write while a line fills
      if (flush) n_flush_fill++;
      waits++;
    end
    flush = 0;
    `CHECK(HRESP == exp_err, "response kind")
    if (exp_err) n_err++;
    else begin
      logic [31:0] w;
      w = trunc(32'(a) & ~32'(LINE_B - 1)) + 32'(a[OFF_W-1:2]) * 4;
      exp = {flash(w + 3), flash(w + 2), flash(w + 1), flash(w)};
      `CHECK(HRDATA == exp, "read data")
      if (waits == 1) n_hit++;
    end
  endtask

  initial begin
    HSEL = 0; HTRANS = 0; HWRITE = 0; HADDR = '0; HSIZE = 0; HWDATA = '0;
    en = 1; flush = 0; new_format(); f_accept = 0; rx_valid = 0; rx_data = '0;
    fr_n = 0; n_cmd = 0; n_addr = 0; n_pad = 0; n_dummy = 0; n_fill = 0; n_hit = 0; n_err = 0;
    n_flush_fill = 0;
    for (int i = 0; i < N_LA; i++) lines[i] = ADDR_W'($urandom) & ~ADDR_W'(LINE_B - 1);
    tb_reset();
    @(negedge clk);
    for (int t = 0; t < N_XFER; t++) begin
      logic [ADDR_W-1:0] a;
      flush = 0;
      if ($urandom % 50 == 0) begin
        flush = 1;                              // a register write: fctrl / ffmt
        if (busy) n_flush_fill++;
        if (!busy && $urandom % 2 == 0) new_format();
      end
      if ($urandom % 40 == 0) en = !en;
      if ($urandom % 8 == 0) en = 1;
      a = lines[$urandom % N_LA] | ADDR_W'($urandom % LINE_B);
      xfer($urandom % 10 == 0, a);   // the next address phase overlaps its last data cycle
      flush = 0;
      if ($urandom % 3 == 0) begin HSEL = 0; HTRANS = 0; @(negedge clk); end
    end
    $display("fills %0d (flushed while filling %0d), hits %0d, errors %0d; frames: cmd %0d addr %0d pad %0d dummy %0d",
             n_fill, n_flush_fill, n_hit, n_err, n_cmd, n_addr, n_pad, n_dummy);
    `CHECK(n_fill > 200 && n_hit > 500 && n_err > 300 && n_pad > 20 && n_dummy > 20, "coverage")
    tb_pass();
  end
endmodule
