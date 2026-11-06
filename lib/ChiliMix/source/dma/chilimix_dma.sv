// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_dma
//
// Memory-to-memory DMA in the SiFive Platform DMA layout (sifive,fu540-c000-
// pdma), so the Linux sf-pdma driver works: N_CH channels (chilimix_dma_ch),
// channel i at byte offset 0x1000 * i, each with Next registers (programmed
// by software), Exec registers (the transfer in progress) and a control word
// (claim, run, done / error and their interrupt enables).
//
// One engine serves the channels round robin, one beat at a time: it reads
// a beat of 1, 2 or 4 bytes (the largest that both addresses are aligned to
// and that is left) from exec_src and writes it to exec_dst over one AHB-Lite
// manager port (basechili_ahb_manager), moving the data from the source byte
// lanes to the destination lanes. A read error skips the write; an error on
// either access stops the channel with error set. Channels interleave beat
// by beat.
//
// Interrupts: irq[2i] is channel i's done & done_ie, irq[2i+1] its error &
// error_ie (the FU540 order), registered.
//
// Timing    : APB reads are combinational (no wait states); irq and the AHB
//             outputs are registered; a beat takes a read and a write, each
//             at least 3 clocks (request, address, data / response).
// Invariants: the engine is S_IDLE or in a beat; in a beat the served
//             channel (cur) is running, beat_size is 1, 2 or 4, no larger
//             than its exec_bytes, and src_q / dst_q are aligned to it;
//             gnt_accept only in S_IDLE; irq is the registered done / error
//             levels.
// Debug     : no bus traffic -> u_ch[i] req, gnt_valid, state; stuck in a
//             beat -> u_mgr.state, HREADY; wrong data -> src_q / dst_q,
//             size_q, data_q (lane shift); missing irq -> u_ch[i] done,
//             done_ie.
// -----------------------------------------------------------------------------
module chilimix_dma #(
  parameter int N_CH = 1                 // channels, 1 .. 4
) (
  input  logic              clk,
  input  logic              rst_n,       // async, active-low
  // APB4 subordinate (registers, 0x1000 bytes per channel)
  input  logic              PSEL,
  input  logic              PENABLE,
  input  logic              PWRITE,
  input  logic [13:0]       PADDR,       // byte address inside the controller
  input  logic [31:0]       PWDATA,
  input  logic [3:0]        PSTRB,
  output logic              PREADY,
  output logic [31:0]       PRDATA,
  output logic              PSLVERR,
  // AHB-Lite manager (the transfers)
  output logic [31:0]       HADDR,
  output logic [1:0]        HTRANS,
  output logic              HWRITE,
  output logic [2:0]        HSIZE,
  output logic [2:0]        HBURST,
  output logic [3:0]        HPROT,
  output logic              HMASTLOCK,
  output logic [31:0]       HWDATA,
  input  logic              HREADY,
  input  logic              HRESP,
  input  logic [31:0]       HRDATA,
  // interrupts (level, active high): [2i] done, [2i+1] error of channel i
  output logic [2*N_CH-1:0] irq
);

  localparam int IDX_W = (N_CH > 1) ? $clog2(N_CH) : 1;

  function automatic logic [N_CH*14-1:0] f_base();
    for (int i = 0; i < N_CH; i++) f_base[i*14 +: 14] = {2'(unsigned'(i)), 12'h000};
  endfunction

  function automatic logic [N_CH*14-1:0] f_mask();
    for (int i = 0; i < N_CH; i++) f_mask[i*14 +: 14] = 14'h3000;
  endfunction

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_RD_REQ = 3'd1,   // read request waits for the manager
    S_RD     = 3'd2,   // read in flight
    S_WR_REQ = 3'd3,
    S_WR     = 3'd4
  } state_e;

  // ---- APB ----------------------------------------------------------------------
  logic [N_CH-1:0]    psel_ch;
  logic [N_CH-1:0]    pready_ch;
  logic [N_CH*32-1:0] prdata_ch;
  logic [N_CH-1:0]    pslverr_ch;
  logic [11:0]        paddr_ch;     // offset inside a channel

  // ---- channels -----------------------------------------------------------------
  logic [N_CH-1:0]    req;
  logic [N_CH*32-1:0] src_all, dst_all, bytes_all;
  logic [N_CH-1:0]    active;       // the engine serves channel i (or grants it)
  logic [N_CH-1:0]    beat_done;
  logic               beat_err;
  logic [N_CH-1:0]    done_irq, err_irq;
  logic [2*N_CH-1:0]  irq_d;

  // ---- arbiter and engine -------------------------------------------------------
  logic [N_CH-1:0]    gnt;
  logic [IDX_W-1:0]   gnt_idx;
  logic               gnt_valid;
  logic               gnt_accept;   // a beat starts for gnt_idx
  logic [2:0]         state_q;
  state_e             state;
  state_e             state_d;
  logic [IDX_W-1:0]   cur;          // the channel being served
  logic [31:0]        g_src, g_dst, g_bytes;  // the granted channel's Exec values
  logic [2:0]         g_size;       // its beat size (1, 2, 4)
  logic [31:0]        src_q, dst_q;
  logic [2:0]         size_q;       // beat size in bytes
  logic [2:0]         hsize_q;      // log2 size_q
  logic [2:0]         g_hsize;
  logic [66:0]        beat_d, beat_q;  // {src, dst, size}
  logic [31:0]        data_d, data_q;  // read data, at lane 0
  logic               data_en;
  logic [4:0]         src_sh, dst_sh;  // lane shifts in bits
  logic               busy;         // in a beat

  // ---- AHB manager user side ----------------------------------------------------
  logic               m_req_valid;
  logic               m_req_write;
  logic [31:0]        m_req_addr;
  logic [31:0]        m_req_wdata;
  logic               m_req_accept;
  logic               m_ack_valid;
  logic               m_ack_error;
  logic [31:0]        m_ack_rdata;
  logic               m_ack_accept;

  // ---- APB decode ---------------------------------------------------------------
  basechili_apb_interconnect #(
    .ADDR_W (14),
    .DATA_W (32),
    .N      (N_CH),
    .BASE   (f_base()),
    .MASK   (f_mask())
  ) u_apb (
    .PSEL      (PSEL),
    .PADDR     (PADDR),
    .PREADY    (PREADY),
    .PRDATA    (PRDATA),
    .PSLVERR   (PSLVERR),
    .PSEL_s    (psel_ch),
    .PREADY_s  (pready_ch),
    .PRDATA_s  (prdata_ch),
    .PSLVERR_s (pslverr_ch)
  );

  assign paddr_ch = PADDR[11:0];

  // ---- channels -----------------------------------------------------------------
  for (genvar i = 0; i < N_CH; i++) begin : g_ch
    chilimix_dma_ch u_ch (
      .clk        (clk),
      .rst_n      (rst_n),
      .PSEL       (psel_ch[i]),
      .PENABLE    (PENABLE),
      .PWRITE     (PWRITE),
      .PADDR      (paddr_ch),
      .PWDATA     (PWDATA),
      .PSTRB      (PSTRB),
      .PREADY     (pready_ch[i]),
      .PRDATA     (prdata_ch[i*32 +: 32]),
      .PSLVERR    (pslverr_ch[i]),
      .req        (req[i]),
      .exec_src   (src_all[i*32 +: 32]),
      .exec_dst   (dst_all[i*32 +: 32]),
      .exec_bytes (bytes_all[i*32 +: 32]),
      .active     (active[i]),
      .beat_done  (beat_done[i]),
      .beat_err   (beat_err),
      .beat_size  (size_q),
      .done_irq   (done_irq[i]),
      .err_irq    (err_irq[i])
    );

    assign active[i]    = (busy && (cur == IDX_W'(unsigned'(i)))) || (gnt_accept && gnt[i]);
    assign irq_d[2*i]   = done_irq[i];
    assign irq_d[2*i+1] = err_irq[i];
  end

  basechili_dff #(.WIDTH(2*N_CH)) u_irq (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (irq_d),
    .q     (irq)
  );

  // ---- arbiter --------------------------------------------------------------------
  basechili_rr_arbiter #(.N(N_CH)) u_arb (
    .clk        (clk),
    .rst_n      (rst_n),
    .req        (req),
    .gnt_accept (gnt_accept),
    .gnt        (gnt),
    .gnt_idx    (gnt_idx),
    .gnt_valid  (gnt_valid)
  );

  assign gnt_accept = (state == S_IDLE) && gnt_valid;

  basechili_dffe #(.WIDTH(IDX_W)) u_cur (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (gnt_accept),
    .d     (gnt_idx),
    .q     (cur)
  );

  // ---- beat: size and addresses of the granted channel --------------------------
  always_comb begin
    g_src   = '0;
    g_dst   = '0;
    g_bytes = '0;
    for (int i = 0; i < N_CH; i++) begin
      g_src   = g_src   | (src_all[i*32 +: 32]   & {32{gnt[i]}});
      g_dst   = g_dst   | (dst_all[i*32 +: 32]   & {32{gnt[i]}});
      g_bytes = g_bytes | (bytes_all[i*32 +: 32] & {32{gnt[i]}});
    end
  end

  always_comb begin
    if ((g_src[1:0] == 2'd0) && (g_dst[1:0] == 2'd0) && (g_bytes >= 32'd4)) begin
      g_size  = 3'd4;
      g_hsize = 3'd2;
    end else if (!g_src[0] && !g_dst[0] && (g_bytes >= 32'd2)) begin
      g_size  = 3'd2;
      g_hsize = 3'd1;
    end else begin
      g_size  = 3'd1;
      g_hsize = 3'd0;
    end
  end

  assign beat_d = {g_src, g_dst, g_size};

  basechili_dffe #(.WIDTH(67)) u_beat (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (gnt_accept),
    .d     (beat_d),
    .q     (beat_q)
  );

  assign {src_q, dst_q, size_q} = beat_q;

  basechili_dffe #(.WIDTH(3)) u_hsize (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (gnt_accept),
    .d     (g_hsize),
    .q     (hsize_q)
  );

  // ---- engine state machine -------------------------------------------------------
  basechili_dff #(.WIDTH(3)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);
  assign busy  = (state != S_IDLE);

  always_comb begin
    state_d   = state;
    beat_done = '0;
    beat_err  = 1'b0;
    data_en   = 1'b0;
    case (state)
      S_IDLE: begin
        if (gnt_valid) state_d = S_RD_REQ;
      end
      S_RD_REQ: begin
        if (m_req_accept) state_d = S_RD;
      end
      S_RD: begin
        if (m_ack_valid) begin
          if (m_ack_error) begin
            state_d        = S_IDLE;
            beat_done[cur] = 1'b1;
            beat_err       = 1'b1;
          end else begin
            state_d = S_WR_REQ;
            data_en = 1'b1;
          end
        end
      end
      S_WR_REQ: begin
        if (m_req_accept) state_d = S_WR;
      end
      S_WR: begin
        if (m_ack_valid) begin
          state_d        = S_IDLE;
          beat_done[cur] = 1'b1;
          beat_err       = m_ack_error;
        end
      end
      default: state_d = S_IDLE;
    endcase
  end

  // ---- data: source lanes to lane 0, lane 0 to destination lanes ------------------
  assign src_sh = {src_q[1:0], 3'b000};
  assign dst_sh = {dst_q[1:0], 3'b000};
  assign data_d = m_ack_rdata >> src_sh;

  basechili_dffe #(.WIDTH(32)) u_data (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (data_en),
    .d     (data_d),
    .q     (data_q)
  );

  assign m_req_valid  = (state == S_RD_REQ) || (state == S_WR_REQ);
  assign m_req_write  = (state == S_WR_REQ);
  assign m_req_addr   = m_req_write ? dst_q : src_q;
  assign m_req_wdata  = data_q << dst_sh;
  assign m_ack_accept = 1'b1;

  basechili_ahb_manager #(
    .HADDR_W     (32),
    .HDATA_W     (32),
    .USER_DATA_W (32)
  ) u_mgr (
    .clk        (clk),
    .rst_n      (rst_n),
    .req_valid  (m_req_valid),
    .req_write  (m_req_write),
    .req_addr   (m_req_addr),
    .req_wdata  (m_req_wdata),
    .req_size   (hsize_q),
    .req_accept (m_req_accept),
    .ack_valid  (m_ack_valid),
    .ack_error  (m_ack_error),
    .ack_rdata  (m_ack_rdata),
    .ack_accept (m_ack_accept),
    .HADDR      (HADDR),
    .HTRANS     (HTRANS),
    .HWRITE     (HWRITE),
    .HSIZE      (HSIZE),
    .HBURST     (HBURST),
    .HPROT      (HPROT),
    .HMASTLOCK  (HMASTLOCK),
    .HWDATA     (HWDATA),
    .HREADY     (HREADY),
    .HRESP      (HRESP),
    .HRDATA     (HRDATA)
  );

endmodule
