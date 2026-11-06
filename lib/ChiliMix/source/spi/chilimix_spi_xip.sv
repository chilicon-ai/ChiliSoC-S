// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_spi_xip
//
// Memory-mapped flash reads (execute in place) of chilimix_spi: an AHB-Lite
// subordinate over the flash window with a small fully associative read
// cache of LINES lines of LINE_B bytes. A read that misses fills the line
// with one flash read instruction, issued as phy frames in the ffmt format:
//   command  cmd_code in cmd_proto (when cmd_en)
//   address  addr_len bytes (0 .. 4) of the line address, MSB first, in
//            addr_proto
//   dummy    pad_cnt sck cycles in addr_proto: pad_code is driven in the
//            first ones (up to 8 bits), the dq pins float in the rest
//   data     LINE_B bytes in data_proto (single: dq0 driven low)
// then answers from the cache. Flash byte A goes to byte lane A[1:0]
// (little-endian words); any read size returns the whole aligned word.
//
// Replacement: the lowest invalid line, else round robin (rr_cnt).
// A flush (fctrl or ffmt written) invalidates every line; a fill running
// across a flush completes but leaves its line invalid, so the waiting read
// misses again and refills with the new format.
// Writes and reads while en is 0 get an AHB ERROR response.
//
// Timing    : a hit answers with one wait state (basechili_ahb_subordinate);
//             a miss after the fill (frame and rx ports of chilimix_spi_phy).
//             f_* come from flops and the configuration.
// Invariants: f_valid only while a fill runs (busy); no two valid lines hold
//             the same tag; while a fill runs its line is
//             invalid and no valid line holds its tag; rx_cnt counts the
//             data bytes received, never more than LINE_B per fill.
// Debug     : read never answered -> state, f_valid / f_accept, rx_cnt,
//             u_ahb state; wrong data -> victim, u_data entries, fill_tag,
//             the address bytes on the pins; refills of one line -> flush
//             (fctrl / ffmt writes), fill_ok.
// -----------------------------------------------------------------------------
module chilimix_spi_xip #(
  parameter  int ADDR_W = 29,                  // flash window address bits (512 MiB)
  parameter  int LINES  = 4,                   // cache lines, a power of 2 (>= 2)
  parameter  int LINE_B = 16,                  // bytes per line, a power of 2 (8 .. 128)
  localparam int OFF_W  = $clog2(LINE_B),
  localparam int TAG_W  = ADDR_W - OFF_W,
  localparam int IDX_W  = $clog2(LINES),
  localparam int WRD_W  = $clog2(LINE_B / 4),
  localparam int DAW    = IDX_W + WRD_W
) (
  input  logic              clk,
  input  logic              rst_n,         // async, active-low
  // AHB-Lite subordinate (flash window)
  input  logic              HSEL,
  input  logic [ADDR_W-1:0] HADDR,         // byte address inside the window
  input  logic [1:0]        HTRANS,
  input  logic              HWRITE,
  input  logic [2:0]        HSIZE,
  input  logic [31:0]       HWDATA,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [31:0]       HRDATA,
  // configuration (registers)
  input  logic              en,            // fctrl.en
  input  logic              flush,         // fctrl or ffmt written
  input  logic              cmd_en,
  input  logic [2:0]        addr_len,
  input  logic [3:0]        pad_cnt,
  input  logic [1:0]        cmd_proto,
  input  logic [1:0]        addr_proto,
  input  logic [1:0]        data_proto,
  input  logic [7:0]        cmd_code,
  input  logic [7:0]        pad_code,
  // frames to chilimix_spi_phy (MSB first, with cs, no gap)
  output logic              f_valid,
  input  logic              f_accept,
  output logic [7:0]        f_data,
  output logic [3:0]        f_cycles,
  output logic [1:0]        f_proto,
  output logic              f_oe,
  output logic              f_rx,
  output logic              f_keep,
  output logic              f_first,
  // received data bytes
  input  logic              rx_valid,
  input  logic [7:0]        rx_data,
  // status
  output logic              busy           // a fill runs
);

  localparam int CNT_W = OFF_W + 1;        // frame / byte counters (0 .. LINE_B)
  localparam logic [CNT_W-1:0] LAST_B = LINE_B - 1;   // index of a line's last byte

  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,   // no fill
    S_CMD   = 3'd1,   // command frame
    S_ADDR  = 3'd2,   // address byte frames
    S_PAD   = 3'd3,   // dummy cycles driving pad_code
    S_DUMMY = 3'd4,   // dummy cycles with the pins floating
    S_DATA  = 3'd5,   // data byte frames
    S_WAIT  = 3'd6    // last data frame sent, waiting for its byte
  } state_e;

  // ---- AHB side -------------------------------------------------------------
  logic              req_valid;
  logic              req_write;
  logic [ADDR_W-1:0] req_addr;
  logic              req_accept;
  logic              ack_valid;
  logic              ack_error;
  logic [31:0]       ack_rdata;
  logic              bad;          // request answered with ERROR
  logic [TAG_W-1:0]  req_tag;
  logic [WRD_W-1:0]  req_word;
  // ---- cache ----------------------------------------------------------------
  logic [LINES*TAG_W-1:0] tags;    // tag of line i at i*TAG_W
  logic [LINES-1:0]  valid;
  logic              valid_full;
  logic [IDX_W-1:0]  free_idx;
  logic              hit;
  logic [IDX_W-1:0]  hit_idx;
  logic [DAW-1:0]    raddr;
  logic [IDX_W-1:0]  rr_cnt;       // round-robin victim when every line is valid
  logic [IDX_W-1:0]  victim_d;
  logic [IDX_W-1:0]  victim;       // line being filled
  logic [LINES-1:0]  tag_we;       // per line: store fill_tag
  logic [TAG_W-1:0]  fill_tag;     // tag of the line being filled
  logic              fill_ok;      // no flush since the fill started
  logic              fill_ok_d;
  logic              fill_set;     // fill ends with its line valid
  logic              we;           // cache word write
  logic [DAW-1:0]    waddr;
  logic [31:0]       wdata;
  // ---- fill sequencer -------------------------------------------------------
  logic [2:0]        state_q;
  state_e            state;
  state_e            state_d;
  logic              start;        // a fill starts
  logic              fill_end;     // last data byte received
  state_e            after_cmd;    // phase after the command
  state_e            after_addr;   // phase after the address
  state_e            after_pad;    // phase after the driven dummy cycles
  state_e            first_phase;
  logic              phase_last;   // the phase's last frame is offered
  logic              phase_end;    // f_accept of the phase's last frame
  logic [2:0]        addr_n;       // address bytes, 0 .. 4
  logic [3:0]        cyc_cmd;      // sck cycles of a byte in each protocol
  logic [3:0]        cyc_addr;
  logic [3:0]        cyc_data;
  logic [3:0]        pad_drive;    // dummy cycles driving pad_code
  logic [3:0]        pad_float;    // dummy cycles with the pins floating
  logic [CNT_W-1:0]  f_cnt;        // frames sent in this phase
  logic              f_cnt_clr;
  logic [CNT_W-1:0]  rx_cnt;       // data bytes received in this fill
  logic [1:0]        addr_sel;     // address byte sent (3 = bits 31:24)
  logic [31:0]       flash_addr;   // address of the line in the flash
  logic [7:0]        addr_byte;
  logic [23:0]       word_sr;      // the line word's first three bytes
  logic [23:0]       word_sr_d;
  logic              first_d;

  basechili_ahb_subordinate #(.HADDR_W(ADDR_W), .HDATA_W(32)) u_ahb (
    .clk        (clk),
    .rst_n      (rst_n),
    .HSEL       (HSEL),
    .HADDR      (HADDR),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HSIZE      (HSIZE),
    .HWDATA     (HWDATA),
    .HREADY     (HREADY),
    .HREADYOUT  (HREADYOUT),
    .HRESP      (HRESP),
    .HRDATA     (HRDATA),
    .req_valid  (req_valid),
    .req_write  (req_write),
    .req_addr   (req_addr),
    .req_size   (),
    .req_wdata  (),
    .req_accept (req_accept),
    .ack_valid  (ack_valid),
    .ack_error  (ack_error),
    .ack_rdata  (ack_rdata),
    .ack_accept ()
  );

  assign req_tag  = req_addr[ADDR_W-1:OFF_W];
  assign req_word = req_addr[OFF_W-1:2];
  assign bad      = req_write || !en;

  basechili_tag_compare #(.TAG_W(TAG_W), .WAYS(LINES)) u_lookup (
    .tags      (tags),
    .valid     (valid),
    .tag       (req_tag),
    .hit_way   (),
    .hit       (hit),
    .hit_idx   (hit_idx),
    .multi_hit ()
  );

  // a request is answered when it is bad or hits; a miss waits for its fill
  assign req_accept = req_valid && (bad || hit);
  assign ack_valid  = req_accept;
  assign ack_error  = bad;
  assign raddr      = {hit_idx, req_word};

  basechili_reg_array #(.WIDTH(32), .DEPTH(LINES * LINE_B / 4), .N_RD(1)) u_data (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (1'b0),
    .we      (we),
    .waddr   (waddr),
    .wdata   (wdata),
    .raddr   (raddr),
    .rdata   (ack_rdata)
  );

  // ---- lines ----------------------------------------------------------------
  assign start    = (state == S_IDLE) && req_valid && !bad && !hit;
  assign victim_d = valid_full ? rr_cnt : free_idx;

  basechili_dffe #(.WIDTH(IDX_W)) u_victim (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (victim_d),
    .q     (victim)
  );

  basechili_dffe #(.WIDTH(TAG_W)) u_fill_tag (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (start),
    .d     (req_tag),
    .q     (fill_tag)
  );

  for (genvar i = 0; i < LINES; i++) begin : g_line
    localparam logic [IDX_W-1:0] LINE = i;

    assign tag_we[i] = start && (victim_d == LINE);

    basechili_dffe #(.WIDTH(TAG_W)) u_tag (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (tag_we[i]),
      .d     (req_tag),
      .q     (tags[i*TAG_W +: TAG_W])
    );
  end

  assign fill_ok_d = start || (fill_ok && !flush);
  assign fill_set  = fill_end && fill_ok;

  basechili_dff #(.WIDTH(1)) u_fill_ok (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (fill_ok_d),
    .q     (fill_ok)
  );

  // the victim is invalid from the start of its fill; valid again at its end
  basechili_valid_array #(.N(LINES)) u_valid (
    .clk      (clk),
    .rst_n    (rst_n),
    .flush    (flush),
    .set_en   (fill_set),
    .set_idx  (victim),
    .clr_en   (start),
    .clr_idx  (victim_d),
    .valid    (valid),
    .full     (valid_full),
    .empty    (),
    .free_idx (free_idx)
  );

  basechili_counter #(.WIDTH(IDX_W)) u_rr_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (1'b0),
    .en    (fill_end),
    .count (rr_cnt)
  );

  // ---- fill sequencer -------------------------------------------------------
  basechili_dff #(.WIDTH(3)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);
  assign busy  = (state != S_IDLE);

  assign addr_n = (addr_len > 3'd4) ? 3'd4 : addr_len;

  always_comb begin
    case (cmd_proto)
      2'd1:    cyc_cmd = 4'd4;
      2'd2:    cyc_cmd = 4'd2;
      default: cyc_cmd = 4'd8;
    endcase
    case (addr_proto)
      2'd1:    cyc_addr = 4'd4;
      2'd2:    cyc_addr = 4'd2;
      default: cyc_addr = 4'd8;
    endcase
    case (data_proto)
      2'd1:    cyc_data = 4'd4;
      2'd2:    cyc_data = 4'd2;
      default: cyc_data = 4'd8;
    endcase
  end

  assign pad_drive = (pad_cnt < cyc_addr) ? pad_cnt : cyc_addr;
  assign pad_float = pad_cnt - pad_drive;

  assign after_pad   = (pad_float != 4'd0) ? S_DUMMY : S_DATA;
  assign after_addr  = (pad_cnt != 4'd0) ? S_PAD : S_DATA;
  assign after_cmd   = (addr_n != 3'd0) ? S_ADDR : after_addr;
  assign first_phase = cmd_en ? S_CMD : after_cmd;

  assign flash_addr = 32'({fill_tag, {OFF_W{1'b0}}});
  assign addr_sel   = 2'(addr_n - 3'd1 - 3'(f_cnt));

  always_comb begin
    case (addr_sel)
      2'd0:    addr_byte = flash_addr[7:0];
      2'd1:    addr_byte = flash_addr[15:8];
      2'd2:    addr_byte = flash_addr[23:16];
      default: addr_byte = flash_addr[31:24];
    endcase
  end

  always_comb begin
    f_valid  = 1'b1;
    f_data   = 8'd0;
    f_cycles = cyc_data;
    f_proto  = data_proto;
    f_oe     = 1'b1;
    f_rx     = 1'b0;
    f_keep   = 1'b1;
    case (state)
      S_CMD: begin
        f_data   = cmd_code;
        f_cycles = cyc_cmd;
        f_proto  = cmd_proto;
      end
      S_ADDR: begin
        f_data   = addr_byte;
        f_cycles = cyc_addr;
        f_proto  = addr_proto;
      end
      S_PAD: begin
        f_data   = pad_code;
        f_cycles = pad_drive;
        f_proto  = addr_proto;
      end
      S_DUMMY: begin
        f_cycles = pad_float;
        f_proto  = addr_proto;
        f_oe     = 1'b0;
      end
      S_DATA: begin
        f_oe   = (data_proto != 2'd1) && (data_proto != 2'd2);
        f_rx   = 1'b1;
        f_keep = (f_cnt != LAST_B);
      end
      S_IDLE, S_WAIT: f_valid = 1'b0;
      default:        f_valid = 1'b0;
    endcase
  end

  assign phase_last = (state == S_ADDR) ? (f_cnt == CNT_W'(addr_n - 3'd1))
                    : (state == S_DATA) ? (f_cnt == LAST_B) : 1'b1;
  assign phase_end  = f_accept && phase_last;

  // the last byte comes after its frame ran, so always in S_WAIT
  assign fill_end = (state == S_WAIT) && rx_valid && (rx_cnt == LAST_B);

  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:  if (start)     state_d = first_phase;
      S_CMD:   if (phase_end) state_d = after_cmd;
      S_ADDR:  if (phase_end) state_d = after_addr;
      S_PAD:   if (phase_end) state_d = after_pad;
      S_DUMMY: if (phase_end) state_d = S_DATA;
      S_DATA:  if (phase_end) state_d = S_WAIT;
      S_WAIT:  if (fill_end)  state_d = S_IDLE;
      default: state_d = S_IDLE;
    endcase
  end

  // the first frame of a fill starts a fresh chip select
  assign first_d = start || (f_first && !f_accept);

  basechili_dff #(.WIDTH(1)) u_first (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (first_d),
    .q     (f_first)
  );

  assign f_cnt_clr = (state_d != state);

  basechili_updown_counter #(.WIDTH(CNT_W)) u_f_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (f_cnt_clr),
    .load_val ('0),
    .inc      (f_accept),
    .dec      (1'b0),
    .count    (f_cnt),
    .count_d  ()
  );

  // ---- data bytes into the line -------------------------------------------
  basechili_updown_counter #(.WIDTH(CNT_W)) u_rx_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (start),
    .load_val ('0),
    .inc      (rx_valid),
    .dec      (1'b0),
    .count    (rx_cnt),
    .count_d  ()
  );

  assign word_sr_d = {rx_data, word_sr[23:8]};

  basechili_dffe #(.WIDTH(24)) u_word_sr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rx_valid),
    .d     (word_sr_d),
    .q     (word_sr)
  );

  assign we    = rx_valid && (rx_cnt[1:0] == 2'd3);
  assign waddr = {victim, rx_cnt[OFF_W-1:2]};
  assign wdata = {rx_data, word_sr};

endmodule
