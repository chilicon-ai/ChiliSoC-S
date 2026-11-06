// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_sram
//
// Zero-wait-state AHB-Lite subordinate for a single-port synchronous SRAM
// (1-cycle read latency, byte write enables). Every transfer completes with
// HREADYOUT high, back to back:
//
//   read : the SRAM read starts in the address phase (mem_addr from HADDR),
//          so mem_rdata is HRDATA in the data phase.
//   write: HWDATA arrives in the data phase. The SRAM port writes it then,
//          unless that cycle's address phase is a read (reads have the
//          port); then the write waits in a one-entry buffer and goes to the
//          SRAM in the next cycle without a read. A read of the buffered
//          word gets the buffered bytes merged into HRDATA.
//
//   SRAM port priority: address-phase read > buffered write > data-phase write.
//
// The buffer is free whenever a data-phase write arrives: it fills only in a
// read address phase, and the address phase of the next write (not a read)
// drains it. With READ_ONLY = 1 (boot ROM), writes get an ERROR response and
// never reach the SRAM.
//
// mem_addr is a word address: HADDR[OFF_W +: MEM_AW]; higher HADDR bits are
// ignored (the decoder selects the region).
//
// Timing    : mem_* are combinational from the AHB address phase (reads) or
//             the registered write; HRDATA is combinational from mem_rdata
//             and the buffer. HREADYOUT / HRESP are registered.
// Invariants: the buffer is never full while a data-phase write arrives
//             (!(buf_valid && dp_write)); a read and a write never use the
//             SRAM port together; HREADYOUT is low only in u_err's S_ERR1.
// Debug     : stale read data -> buf_valid, buf_addr vs rd_addr and buf_be
//             (hit); write lost -> dp_write, buf_fill and mem_we.
// -----------------------------------------------------------------------------
module basechili_ahb_sram #(
  parameter  int ADDR_W    = 32,               // HADDR width
  parameter  int DATA_W    = 32,               // data width (power of two, >= 16)
  parameter  int MEM_AW    = 10,               // SRAM word address bits (2**MEM_AW words)
  parameter  bit READ_ONLY = 1'b0,             // writes get ERROR (ROM)
  localparam int N_LANE    = DATA_W / 8,       // byte lanes
  localparam int OFF_W     = $clog2(N_LANE),   // byte offset bits
  localparam int SIZE_W    = $clog2(OFF_W + 1)
) (
  input  logic              clk,
  input  logic              rst_n,             // async, active-low

  // AHB subordinate
  input  logic              HSEL,
  input  logic [ADDR_W-1:0] HADDR,
  input  logic [1:0]        HTRANS,
  input  logic              HWRITE,
  input  logic [2:0]        HSIZE,
  input  logic [DATA_W-1:0] HWDATA,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [DATA_W-1:0] HRDATA,

  // SRAM port (mem_rdata valid the cycle after a read)
  output logic              mem_req,
  output logic              mem_we,
  output logic [MEM_AW-1:0] mem_addr,
  output logic [DATA_W-1:0] mem_wdata,
  output logic [N_LANE-1:0] mem_be,
  input  logic [DATA_W-1:0] mem_rdata
);

  logic              addr_fire;  // a transfer is addressed to this subordinate
  logic              rd_go;      // read address phase: SRAM read now
  logic              wr_go;      // write address phase (accepted)
  logic              err_sel;    // a write selects a READ_ONLY SRAM: ERROR response
  logic [MEM_AW-1:0] haddr_w;    // HADDR word address
  logic [N_LANE-1:0] hstrb;      // byte lanes of the address phase
  logic [OFF_W-1:0]  hoff;       // byte offset of the address phase
  logic [SIZE_W-1:0] hsize;      // log2 bytes of the address phase
  logic              dp_write;   // write data phase (HWDATA valid)
  logic [MEM_AW-1:0] wr_addr;    // its word address
  logic [N_LANE-1:0] wr_be;      // its byte lanes
  logic [MEM_AW-1:0] rd_addr;    // word address of the last read
  logic              buf_valid;  // the write buffer holds a write
  logic              buf_fill;   // data-phase write goes to the buffer
  logic              buf_drain;  // the buffered write goes to the SRAM
  logic              buf_valid_d;// next buf_valid
  logic [MEM_AW-1:0] buf_addr;   // buffered word address
  logic [DATA_W-1:0] buf_data;   // buffered data
  logic [N_LANE-1:0] buf_be;     // buffered byte lanes
  logic              hit;        // the read data phase is of the buffered word

  assign addr_fire = HSEL && HREADY && HTRANS[1];
  assign rd_go     = addr_fire && !HWRITE;
  assign wr_go     = addr_fire && HWRITE && !READ_ONLY;
  assign err_sel   = HSEL && HWRITE && READ_ONLY;
  assign haddr_w   = HADDR[OFF_W +: MEM_AW];

  // ---- error response (READ_ONLY writes) --------------------------------------
  // The two-cycle ERROR response of the default subordinate, selected by
  // writes; its HREADYOUT / HRESP are this subordinate's (OKAY otherwise).
  basechili_ahb_default_sub #(.DATA_W(DATA_W)) u_err (
    .clk       (clk),
    .rst_n     (rst_n),
    .HSEL      (err_sel),
    .HTRANS    (HTRANS),
    .HREADY    (HREADY),
    .HREADYOUT (HREADYOUT),
    .HRESP     (HRESP),
    .HRDATA    ()
  );

  // ---- data phase -------------------------------------------------------------
  assign hoff  = HADDR[OFF_W-1:0];
  assign hsize = HSIZE[SIZE_W-1:0];

  basechili_byte_strobe #(.DATA_W(DATA_W)) u_strb (
    .offset (hoff),
    .size   (hsize),
    .strb   (hstrb)
  );

  basechili_dff #(.WIDTH(1)) u_dp_write (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (wr_go),
    .q     (dp_write)
  );

  basechili_dffe #(.WIDTH(MEM_AW)) u_wr_addr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (wr_go),
    .d     (haddr_w),
    .q     (wr_addr)
  );

  basechili_dffe #(.WIDTH(N_LANE)) u_wr_be (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (wr_go),
    .d     (hstrb),
    .q     (wr_be)
  );

  basechili_dffe #(.WIDTH(MEM_AW)) u_rd_addr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rd_go),
    .d     (haddr_w),
    .q     (rd_addr)
  );

  // ---- write buffer -----------------------------------------------------------
  assign buf_fill    = dp_write && rd_go;
  assign buf_drain   = buf_valid && !rd_go;
  assign buf_valid_d = buf_fill || (buf_valid && !buf_drain);

  basechili_dff #(.WIDTH(1)) u_buf_valid (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (buf_valid_d),
    .q     (buf_valid)
  );

  basechili_dffe #(.WIDTH(MEM_AW)) u_buf_addr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (buf_fill),
    .d     (wr_addr),
    .q     (buf_addr)
  );

  basechili_dffe #(.WIDTH(DATA_W)) u_buf_data (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (buf_fill),
    .d     (HWDATA),
    .q     (buf_data)
  );

  basechili_dffe #(.WIDTH(N_LANE)) u_buf_be (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (buf_fill),
    .d     (wr_be),
    .q     (buf_be)
  );

  // ---- SRAM port --------------------------------------------------------------
  always_comb begin
    mem_req   = rd_go || buf_valid || dp_write;
    mem_we    = !rd_go;
    mem_addr  = haddr_w;
    mem_wdata = HWDATA;
    mem_be    = '1;
    if (rd_go) begin
      mem_be    = '1;
    end else if (buf_valid) begin
      mem_addr  = buf_addr;
      mem_wdata = buf_data;
      mem_be    = buf_be;
    end else begin
      mem_addr  = wr_addr;
      mem_be    = wr_be;
    end
  end

  // ---- read data --------------------------------------------------------------
  assign hit = buf_valid && (buf_addr == rd_addr);

  always_comb begin
    for (int b = 0; b < DATA_W; b++)
      HRDATA[b] = (hit && buf_be[b / 8]) ? buf_data[b] : mem_rdata[b];
  end

endmodule
