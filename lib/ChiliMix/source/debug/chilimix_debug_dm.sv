// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_debug_dm
//
// RISC-V debug module (debug spec 1.0) for one RV32 or RV64 hart (XLEN),
// execution-based (spec
// Appendix A.2, the riscv-dbg scheme): the hart runs chilimix_debug_pkg's
// ROM in debug mode and does the handshakes by loads / stores to this
// module's 4 KiB memory (DM at address 0, see chilimix_debug_pkg).
//
// DMI registers (ABITS = 7; other addresses read 0, writes are ignored; every
// access answers op 0):
//   0x04-0x05 data0-1     R/W (busy: cmderr 1, ignored); the hart's DATA
//   0x10 dmcontrol        haltreq, resumereq, ackhavereset, setresethaltreq,
//                         clrresethaltreq, ndmreset, dmactive (hartsel: one
//                         hart, HARTSELLEN 0; hartreset / keepalive absent)
//   0x11 dmstatus         version 3, authenticated, impebreak, hasresethaltreq,
//                         ndmresetpending and the hart's halted / running /
//                         unavail / resumeack / havereset (any = all)
//   0x12 hartinfo         dataaccess, datasize 2, dataaddr 0x380, nscratch 0
//                         (the ROM keeps s0 in dscratch0)
//   0x16 abstractcs       progbufsize 8, datacount 2, busy, cmderr (W1C)
//   0x17 command          access register only: GPRs (0x1000-0x101f) and
//                         CSRs, aarsize 2 (and 3 with XLEN 64: data0 low,
//                         data1 high), transfer / write / postexec
//   0x18 abstractauto     autoexecdata [1:0], autoexecprogbuf [23:16]: a DMI
//                         read or write of that data / progbuf word runs the
//                         last command again (after the access; spec 3.15.8)
//   0x20-0x27 progbuf0-7  R/W (busy: cmderr 1, ignored)
//   0x38 sbcs             system bus access (spec 3.12): sbversion 1,
//                         SB_ADDR_W-bit addresses, 8 / 16 / 32-bit accesses
//                         (and 64-bit with SB_DATA_W 64), sbreadonaddr,
//                         sbreadondata, sbautoincrement, sbbusy, sbbusyerror
//                         and sberror (W1C: 2 bus error, 3 alignment, 4 size)
//   0x39 sbaddress0, 0x3A sbaddress1 (SB_ADDR_W > 32), 0x3C sbdata0,
//   0x3D sbdata1 (SB_DATA_W 64)
//   0x40 haltsum0         bit 0: the hart is halted
// dmactive = 0 holds every other register at its reset value (writes to the
// rest are ignored), debug_req and ndmreset low.
//
// Halt: debug_req = haltreq (or a pending halt-on-reset); the ROM's park loop
// writes HALTED -> halted. Resume: resumereq (while halted, without haltreq)
// sets the resume flag; the hart writes RESUMING -> not halted, resumeack.
// Command: a valid command while halted latches into cmd_q and sets go
// (S_GO); an autoexec access starts cmd_q again the same way (not halted:
// cmderr 4; busy: cmderr 1, the access is ignored); GOING clears go (S_EXEC); HALTED ends it (S_IDLE). EXCEPTION sets
// cmderr 3. Errors: 1 busy, 2 not supported (cmdtype, aarsize, regno,
// aarpostincrement), 3 exception, 4 hart not halted / unavailable.
// The CMD words (A_CMD) are generated from cmd_q:
//   GPR read   sw xN, DATA0(x0)
//   GPR write  lw xN, DATA0(x0)   (s0: also csrw dscratch0, s0)
//   CSR read   csrw dscratch0, s0; csrr s0, csr; sw s0, DATA0(x0); csrr s0, dscratch0
//   CSR write  csrw dscratch0, s0; lw s0, DATA0(x0); csrw csr, s0; csrr s0, dscratch0
// (sd / ld in place of sw / lw for aarsize 3; a 64-bit hart reaches the
// 32-bit memory port through a bus downsizer).
// followed by ebreak, or (postexec) nops into the program buffer.
//
// Memory port: a single-port SRAM port (basechili_ahb_sram's mem_*):
// mem_rdata is registered, valid the cycle after a read.
// System bus: one access at a time to a bus manager (sb_*, SB_DATA_W bits,
// req_size = sbaccess, write data on the byte lanes of the address, read
// data taken from them). sbaddress0 / sbdata0 accesses while sbbusy set sbbusyerror;
// while sbbusyerror or sberror is set no access starts.
//
// Timing    : DMI responses come the cycle after the request (one at a
//             time); mem_rdata the cycle after mem_req; debug_req, ndmreset
//             and every status bit are registered.
// Invariants: busy == (state != S_IDLE); go is set only in S_GO; cmderr
//             changes from nonzero only by an abstractcs write (W1C);
//             dmactive low -> debug_req, ndmreset, busy low.
// Debug     : hart does not halt -> debug_req, haltreq, the hart's fetch at
//             0x800; halted never set -> HALTED writes (ev_halted); command
//             stuck busy -> state, go, ev_going / ev_halted, cmd_q, the CMD
//             words the hart fetched; cmderr -> the command written (cmdtype,
//             aarsize, regno) and halted.
// -----------------------------------------------------------------------------
module chilimix_debug_dm
  import chilimix_debug_pkg::*;
#(
  parameter  int XLEN      = 32,              // hart register width: 32 or 64
  parameter  int SB_ADDR_W = 32,              // system bus address bits (32 .. 64)
  parameter  int SB_DATA_W = 32,              // system bus data bits: 32 or 64
  localparam int ABITS     = 7,               // DMI address bits
  localparam int SB_LANES  = SB_DATA_W / 8,
  localparam int SB_LO     = $clog2(SB_LANES) // byte-lane address bits
) (
  input  logic             clk,
  input  logic             rst_n,             // async, active-low (debug domain, not ndmreset)
  // DMI (from chilimix_debug_dtm)
  input  logic             dmi_req_valid,
  output logic             dmi_req_accept,
  input  logic [ABITS-1:0] dmi_req_addr,
  input  logic [31:0]      dmi_req_data,
  input  logic [1:0]       dmi_req_op,        // 1 read, 2 write
  output logic             dmi_rsp_valid,
  input  logic             dmi_rsp_accept,
  output logic [31:0]      dmi_rsp_data,
  output logic [1:0]       dmi_rsp_op,        // always 0 (errors go to cmderr)
  // hart
  output logic             debug_req,         // halt request to the hart
  input  logic             hart_unavail,      // the hart is in reset (or off)
  output logic             ndmreset,          // reset the system except debug
  // DM memory, hart side (single-port SRAM port)
  input  logic             mem_req,
  input  logic             mem_we,
  input  logic [9:0]       mem_addr,          // word address in the 4 KiB region
  input  logic [31:0]      mem_wdata,
  input  logic [3:0]       mem_be,
  output logic [31:0]      mem_rdata,
  // system bus access (to basechili_ahb_manager)
  output logic             sb_req_valid,
  input  logic             sb_req_accept,
  output logic             sb_req_write,
  output logic [SB_ADDR_W-1:0] sb_req_addr,
  output logic [SB_DATA_W-1:0] sb_req_wdata,  // on the byte lanes of sb_req_addr
  output logic [2:0]       sb_req_size,       // HSIZE: 0 byte, 1 halfword, 2 word, 3 doubleword
  input  logic             sb_ack_valid,
  output logic             sb_ack_accept,
  input  logic             sb_ack_error,
  input  logic [SB_DATA_W-1:0] sb_ack_rdata
);

  // ---- DMI addresses
  localparam logic [ABITS-1:0] D_DATA0      = 7'h04;
  localparam logic [ABITS-1:0] D_DATA_END   = 7'h06;    // D_DATA0 + DATA_COUNT
  localparam logic [ABITS-1:0] D_DMCONTROL  = 7'h10;
  localparam logic [ABITS-1:0] D_DMSTATUS   = 7'h11;
  localparam logic [ABITS-1:0] D_HARTINFO   = 7'h12;
  localparam logic [ABITS-1:0] D_ABSTRACTCS = 7'h16;
  localparam logic [ABITS-1:0] D_COMMAND    = 7'h17;
  localparam logic [ABITS-1:0] D_ABSTRACTAUTO = 7'h18;
  localparam logic [ABITS-1:0] D_PROGBUF0   = 7'h20;
  localparam logic [ABITS-1:0] D_PROGBUF_END = 7'h28;   // D_PROGBUF0 + PROGBUF_SIZE
  localparam logic [ABITS-1:0] D_SBCS       = 7'h38;
  localparam logic [ABITS-1:0] D_SBADDRESS0 = 7'h39;
  localparam logic [ABITS-1:0] D_SBADDRESS1 = 7'h3A;
  localparam logic [ABITS-1:0] D_SBDATA0    = 7'h3C;
  localparam logic [ABITS-1:0] D_SBDATA1    = 7'h3D;
  localparam bit               SB_A64       = SB_ADDR_W > 32;    // sbaddress1 exists
  localparam bit               SB_D64       = SB_DATA_W == 64;   // sbdata1 and 64-bit accesses exist
  localparam logic [2:0]       SB_MAX_SIZE  = SB_D64 ? 3'd3 : 3'd2;
  localparam logic [SB_ADDR_W-1:0] SB_ONE = 1;
  localparam logic [2:0]       AAR_MAX      = (XLEN == 64) ? 3'd3 : 3'd2;
  localparam logic [ABITS-1:0] D_HALTSUM0   = 7'h40;

  typedef enum logic [1:0] {
    S_IDLE = 2'd0,    // no command
    S_GO   = 2'd1,    // go flag set, waiting for GOING
    S_EXEC = 2'd2     // the hart runs the command, waiting for HALTED
  } state_e;

  typedef enum logic [1:0] {
    SB_IDLE = 2'd0,   // no bus access
    SB_REQ  = 2'd1,   // request to the AHB manager, until accepted
    SB_WAIT = 2'd2    // waiting for the response
  } sb_state_e;

  localparam logic [5:0] SB_CFG_RESET = 6'b0_010_0_0;     // sbaccess 2 (32-bit)
  localparam logic [2:0] SBE_NONE = 3'd0, SBE_BADADDR = 3'd2, SBE_ALIGN = 3'd3, SBE_SIZE = 3'd4;

  localparam logic [2:0] E_NONE = 3'd0, E_BUSY = 3'd1, E_NOTSUP = 3'd2, E_EXC = 3'd3, E_HALT = 3'd4;

  // ---- DMI access decode
  logic             dmi_fire;          // request taken this cycle
  logic             dmi_wr;            // ... a write
  logic             dmi_rd;            // ... a read
  logic [31:0]      wd;                // write data
  logic             wr_dmcontrol;
  logic             wr_abstractcs;
  logic             wr_command;
  logic             wr_abstractauto;
  logic             data_hit;          // address is data0 .. data1
  logic             progbuf_hit;       // address is progbuf0 .. 7
  logic [0:0]       data_idx;
  logic [2:0]       progbuf_idx;
  logic             wr_data;           // data write while idle
  logic             wr_progbuf;        // progbuf write while idle
  logic             busy_access;       // data / progbuf / abstract access while busy
  logic             auto_hit;          // data / progbuf access with its autoexec bit
  logic             auto_start;        // ... runs cmd_q again
  logic [9:0]       auto_q;            // {autoexecprogbuf[7:0], autoexecdata[1:0]}
  logic [9:0]       auto_d;
  // ---- state
  logic             dmactive;
  logic             dmactive_en;
  logic             dm_clr;            // !dmactive: hold the DM in reset
  logic             ctl_wr;            // dmcontrol write with dmactive (stays) 1
  logic             haltreq;
  logic             haltreq_d;
  logic             ndmreset_q;
  logic             ndmreset_d;
  logic             resethaltreq;
  logic             resethaltreq_d;
  logic             ndm_wait;          // ndmreset not finished (ndmresetpending)
  logic             ndm_wait_d;
  logic             havereset;
  logic             havereset_d;
  logic             halted;
  logic             halted_d;
  logic             resumeack;
  logic             resumeack_d;
  logic             resume;            // resume flag (FLAGS bit 1)
  logic             resume_d;
  logic             resumereq_ok;      // resumereq write takes effect
  logic             rh_pending;        // halt-on-reset pending
  logic             rh_pending_d;
  logic [1:0]       state_q;
  state_e           state;
  state_e           state_d;
  logic             busy;
  logic             go;                // go flag (FLAGS bit 0)
  logic [2:0]       cmderr;
  logic [2:0]       cmderr_d;
  logic [2:0]       cmd_err;           // error of the command written
  logic             cmd_start;         // command accepted, the hart runs it
  logic             cmd_en;            // latch cmd_q
  logic [31:0]      cmd_q;             // the command being executed
  logic [63:0]      data_q;            // data1, data0
  logic [63:0]      data_d;
  logic             data_en;
  logic [255:0]     progbuf_q;         // progbuf7 .. progbuf0
  logic [255:0]     progbuf_d;
  logic             progbuf_en;
  // ---- hart events (memory writes)
  logic             mem_wr;
  logic             mem_rd;
  logic [11:0]      mem_byte;          // byte address of the access
  logic             ev_halted;
  logic             ev_going;
  logic             ev_resuming;
  logic             ev_exception;
  logic             hart_data_wr;      // the hart writes DATA
  logic [0:0]       hart_data_idx;
  logic [31:0]      hart_data_mask;    // mem_be as a bit mask
  // ---- reads
  logic [31:0]      dmstatus;
  logic [31:0]      rd_val;            // DMI read value
  logic [31:0]      rsp_data_d;
  logic             rsp_valid_d;
  logic [31:0]      mem_rd_val;        // hart read value
  logic [255:0]     cmd_words;         // CMD words 7 .. 0
  logic [31:0]      cmd_end;           // ebreak, or nop with postexec
  logic             cmd_64;            // the command moves 64 bits (aarsize 3)

  // ---- system bus access
  logic             wr_sbcs;
  logic             wr_sbaddr;
  logic             wr_sbaddr1;        // sbaddress1 write (SB_ADDR_W > 32)
  logic             wr_sbdata;
  logic             wr_sbdata1;        // sbdata1 write (SB_DATA_W 64)
  logic             rd_sbdata;
  logic [1:0]       sb_state_q;
  sb_state_e        sb_state;
  sb_state_e        sb_state_d;
  logic             sb_busy;
  logic             sb_blocked;        // sbbusyerror or sberror set: no access starts
  logic             sb_busyerror;
  logic             sb_busyerror_d;
  logic [2:0]       sb_error;
  logic [2:0]       sb_error_d;
  logic [5:0]       sb_cfg;            // {sbreadonaddr, sbaccess, sbautoincrement, sbreadondata}
  logic [5:0]       sb_cfg_d;
  logic             sb_readonaddr;
  logic [2:0]       sb_access;
  logic             sb_autoinc;
  logic             sb_readondata;
  logic [SB_ADDR_W-1:0] sb_addr;       // sbaddress1, sbaddress0
  logic [SB_ADDR_W-1:0] sb_addr_d;
  logic [63:0]      sb_addr64;         // sb_addr zero-extended (sbaddress reads)
  logic [SB_DATA_W-1:0] sb_data;       // sbdata1, sbdata0
  logic [SB_DATA_W-1:0] sb_data_d;
  logic [63:0]      sb_data64;         // sb_data zero-extended (sbdata reads)
  logic             sb_write;          // the access in flight writes
  logic             sb_write_d;
  logic [2:0]       sb_size;           // sbaccess of the access in flight
  logic [2:0]       sb_size_d;
  logic [SB_ADDR_W-1:0] sb_addr_go;    // address of an access starting now
  logic             sb_go_read;        // an access is asked for
  logic             sb_go_write;
  logic             sb_go;
  logic             sb_size_ok;
  logic             sb_align_ok;
  logic             sb_start;          // ... and starts
  logic             sb_done;           // the response arrives
  logic [SB_DATA_W-1:0] sb_rd_shift;   // read data shifted down to bit 0
  logic [SB_DATA_W-1:0] sb_rd_val;     // read data, zero-extended
  logic [SB_ADDR_W-1:0] sb_addr_inc;   // sb_addr + access size

  // ---- DMI access decode
  assign dmi_req_accept = !dmi_rsp_valid;
  assign dmi_fire       = dmi_req_valid && dmi_req_accept;
  assign dmi_wr         = dmi_fire && dmi_req_op == 2'd2;
  assign dmi_rd         = dmi_fire && dmi_req_op == 2'd1;
  assign wd             = dmi_req_data;
  assign data_hit       = dmi_req_addr >= D_DATA0 && dmi_req_addr < D_DATA_END;
  assign progbuf_hit    = dmi_req_addr >= D_PROGBUF0 && dmi_req_addr < D_PROGBUF_END;
  assign data_idx       = 1'(dmi_req_addr - D_DATA0);
  assign progbuf_idx    = 3'(dmi_req_addr - D_PROGBUF0);

  assign wr_dmcontrol    = dmi_wr && dmi_req_addr == D_DMCONTROL;
  assign wr_abstractcs   = dmi_wr && dmactive && dmi_req_addr == D_ABSTRACTCS;
  assign wr_command      = dmi_wr && dmactive && dmi_req_addr == D_COMMAND;
  assign wr_abstractauto = dmi_wr && dmactive && dmi_req_addr == D_ABSTRACTAUTO;
  assign wr_data         = dmi_wr && dmactive && data_hit && !busy;
  assign wr_progbuf      = dmi_wr && dmactive && progbuf_hit && !busy;
  assign busy_access     = busy && dmactive && (((dmi_wr || dmi_rd) && (data_hit || progbuf_hit))
                           || wr_abstractcs || wr_command || wr_abstractauto);
  assign auto_hit        = dmactive && (dmi_wr || dmi_rd)
                           && ((data_hit && auto_q[int'(data_idx)]) || (progbuf_hit && auto_q[2 + int'(progbuf_idx)]));

  // ---- dmactive: the only bit written while the DM is inactive
  assign dmactive_en = wr_dmcontrol;
  assign dm_clr      = !dmactive;
  assign ctl_wr      = wr_dmcontrol && dmactive && wd[0];

  basechili_dffe #(.WIDTH(1)) u_dmactive (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (dmactive_en),
    .d     (wd[0]),
    .q     (dmactive)
  );

  // ---- dmcontrol fields
  assign haltreq_d      = ctl_wr ? wd[31] : haltreq;
  assign ndmreset_d     = ctl_wr ? wd[1] : ndmreset_q;
  assign resethaltreq_d = (ctl_wr && wd[3]) || (resethaltreq && !(ctl_wr && wd[2]));
  assign resumereq_ok   = ctl_wr && wd[30] && !wd[31];

  basechili_dff_sclr #(.WIDTH(3)) u_ctl (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     ({haltreq_d, ndmreset_d, resethaltreq_d}),
    .q     ({haltreq, ndmreset_q, resethaltreq})
  );

  assign ndmreset   = ndmreset_q;
  assign ndm_wait_d = ndmreset_q || (ndm_wait && hart_unavail);

  basechili_dff_sclr #(.WIDTH(1)) u_ndm_wait (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (ndm_wait_d),
    .q     (ndm_wait)
  );

  // havereset is the hart's state: set by its reset, kept across dmactive
  assign havereset_d = hart_unavail || (havereset && !(ctl_wr && wd[28]));

  basechili_dff #(.WIDTH(1), .RESET_VAL(1'b1)) u_havereset (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (havereset_d),
    .q     (havereset)
  );

  // ---- hart events: stores to the flag words
  assign mem_wr         = mem_req && mem_we;
  assign mem_rd         = mem_req && !mem_we;
  assign mem_byte       = {mem_addr, 2'b00};
  assign ev_halted      = mem_wr && mem_byte == A_HALTED;
  assign ev_going       = mem_wr && mem_byte == A_GOING;
  assign ev_resuming    = mem_wr && mem_byte == A_RESUMING;
  assign ev_exception   = mem_wr && mem_byte == A_EXCEPTION;
  assign hart_data_wr   = mem_wr && mem_byte >= A_DATA && mem_byte < A_DATA_END;
  assign hart_data_idx  = 1'((mem_byte - A_DATA) >> 2);
  assign hart_data_mask = {{8{mem_be[3]}}, {8{mem_be[2]}}, {8{mem_be[1]}}, {8{mem_be[0]}}};

  // ---- halted, resume, halt-on-reset
  assign halted_d     = !hart_unavail && (ev_halted || (halted && !ev_resuming));
  assign resume_d     = !ev_resuming && !hart_unavail && (resume || (resumereq_ok && halted));
  assign resumeack_d  = ev_resuming || (resumeack && !resumereq_ok);
  assign rh_pending_d = !halted && (rh_pending || (resethaltreq && hart_unavail));

  basechili_dff_sclr #(.WIDTH(4)) u_hart (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     ({halted_d, resume_d, resumeack_d, rh_pending_d}),
    .q     ({halted, resume, resumeack, rh_pending})
  );

  assign debug_req = haltreq || rh_pending;

  // ---- abstract command
  always_comb begin
    if (wd[31:24] != 8'd0)                                cmd_err = E_NOTSUP;   // cmdtype
    else if (!halted || hart_unavail)                     cmd_err = E_HALT;
    else if (wd[19])                                      cmd_err = E_NOTSUP;   // aarpostincrement
    else if (wd[17] && (wd[22:20] < 3'd2 || wd[22:20] > AAR_MAX)) cmd_err = E_NOTSUP; // aarsize
    else if (wd[17] && wd[15:0] >= 16'h1020)              cmd_err = E_NOTSUP;   // FPRs and beyond
    else                                                  cmd_err = E_NONE;
  end

  assign auto_start = auto_hit && !busy && cmderr == E_NONE && halted && !hart_unavail && (cmd_q[17] || cmd_q[18]);
  assign cmd_start  = (wr_command && !busy && cmderr == E_NONE && cmd_err == E_NONE && (wd[17] || wd[18]))
                      || auto_start;
  assign cmd_en     = wr_command && cmd_start;

  basechili_dffe #(.WIDTH(32)) u_cmd (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cmd_en),
    .d     (wd),
    .q     (cmd_q)
  );

  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:  if (cmd_start)    state_d = S_GO;
      S_GO:    if (ev_going)     state_d = S_EXEC;
      S_EXEC:  if (ev_halted)    state_d = S_IDLE;
      default:                   state_d = S_IDLE;
    endcase
    if (hart_unavail) state_d = S_IDLE;                  // the hart was reset: abort
  end

  basechili_dff_sclr #(.WIDTH(2)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);
  assign busy  = state != S_IDLE;
  assign go    = state == S_GO;

  always_comb begin
    cmderr_d = cmderr;
    if (wr_abstractcs && !busy) cmderr_d = cmderr & ~wd[10:8];
    if (cmderr == E_NONE) begin
      if (busy_access)                                   cmderr_d = E_BUSY;
      else if (busy && hart_unavail)                     cmderr_d = E_HALT;
      else if (state == S_EXEC && ev_exception)          cmderr_d = E_EXC;
      else if (wr_command && cmd_err != E_NONE)          cmderr_d = cmd_err;
      else if (auto_hit && (!halted || hart_unavail))    cmderr_d = E_HALT;
    end
  end

  basechili_dff_sclr #(.WIDTH(3)) u_cmderr (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (cmderr_d),
    .q     (cmderr)
  );

  // ---- abstractauto (written while idle)
  assign auto_d = (wr_abstractauto && !busy) ? {wd[23:16], wd[1:0]} : auto_q;

  basechili_dff_sclr #(.WIDTH(10)) u_auto (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (auto_d),
    .q     (auto_q)
  );

  // ---- data and progbuf
  always_comb begin
    data_d = data_q;
    if (wr_data) data_d[int'(data_idx)*32 +: 32] = wd;
    if (hart_data_wr)
      data_d[int'(hart_data_idx)*32 +: 32] = (data_q[int'(hart_data_idx)*32 +: 32] & ~hart_data_mask)
                                       | (mem_wdata & hart_data_mask);
  end

  assign data_en = wr_data || hart_data_wr;

  basechili_dff_sclr #(.WIDTH(64)) u_data (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (data_en),
    .d     (data_d),
    .q     (data_q)
  );

  always_comb begin
    progbuf_d = progbuf_q;
    progbuf_d[int'(progbuf_idx)*32 +: 32] = wd;
  end

  assign progbuf_en = wr_progbuf;

  basechili_dff_sclr #(.WIDTH(256)) u_progbuf (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (progbuf_en),
    .d     (progbuf_d),
    .q     (progbuf_q)
  );

  // ---- CMD words from cmd_q
  assign cmd_end = cmd_q[18] ? RV_NOP : RV_EBREAK;
  assign cmd_64  = cmd_q[22:20] == 3'd3;                         // aarsize 3: ld / sd

  always_comb begin
    for (int i = 0; i < CMD_WORDS; i++) cmd_words[i*32 +: 32] = cmd_end;
    if (cmd_q[17]) begin
      if (cmd_q[12]) begin                                       // GPR x(regno[4:0])
        if (cmd_q[16]) begin
          cmd_words[0 +: 32] = cmd_64 ? rv_ld(cmd_q[4:0], X_ZERO, A_DATA) : rv_lw(cmd_q[4:0], X_ZERO, A_DATA);
          if (cmd_q[4:0] == X_S0) cmd_words[32 +: 32] = CMD_SAVE_S0;
        end else begin
          cmd_words[0 +: 32] = cmd_64 ? rv_sd(cmd_q[4:0], X_ZERO, A_DATA) : rv_sw(cmd_q[4:0], X_ZERO, A_DATA);
        end
      end else begin                                             // CSR regno[11:0]
        cmd_words[0 +: 32]  = CMD_SAVE_S0;
        if (cmd_q[16]) begin
          cmd_words[32 +: 32] = cmd_64 ? CMD_LOAD64_S0 : CMD_LOAD_S0;
          cmd_words[64 +: 32] = rv_csrw(cmd_q[11:0], X_S0);
        end else begin
          cmd_words[32 +: 32] = rv_csrr(X_S0, cmd_q[11:0]);
          cmd_words[64 +: 32] = cmd_64 ? CMD_STORE64_S0 : CMD_STORE_S0;
        end
        cmd_words[96 +: 32] = CMD_RESTORE_S0;
      end
    end
  end

  // ---- hart reads (registered: valid the cycle after mem_req)
  always_comb begin
    mem_rd_val = 32'h0;
    if (mem_byte >= A_CMD && mem_byte < A_CMD_END)
      mem_rd_val = cmd_words[((mem_byte - A_CMD) >> 2) * 32 +: 32];
    else if (mem_byte >= A_PROGBUF && mem_byte < A_PROGBUF_END)
      mem_rd_val = progbuf_q[((mem_byte - A_PROGBUF) >> 2) * 32 +: 32];
    else if (mem_byte == A_IMPEBREAK)
      mem_rd_val = RV_EBREAK;
    else if (mem_byte >= A_DATA && mem_byte < A_DATA_END)
      mem_rd_val = data_q[((mem_byte - A_DATA) >> 2) * 32 +: 32];
    else if (mem_byte == A_FLAGS)
      mem_rd_val = {30'd0, resume, go};
    else if (mem_byte >= A_ROM && mem_byte < A_ROM_END)
      mem_rd_val = ROM[((mem_byte - A_ROM) >> 2) * 32 +: 32];
  end

  basechili_dffe #(.WIDTH(32)) u_mem_rdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mem_rd),
    .d     (mem_rd_val),
    .q     (mem_rdata)
  );

  // ---- system bus access (sbcs / sbaddress0 / sbdata0, spec 3.12)
  assign wr_sbcs   = dmi_wr && dmactive && dmi_req_addr == D_SBCS;
  assign wr_sbaddr  = dmi_wr && dmactive && dmi_req_addr == D_SBADDRESS0;
  assign wr_sbaddr1 = SB_A64 && dmi_wr && dmactive && dmi_req_addr == D_SBADDRESS1;
  assign wr_sbdata  = dmi_wr && dmactive && dmi_req_addr == D_SBDATA0;
  assign wr_sbdata1 = SB_D64 && dmi_wr && dmactive && dmi_req_addr == D_SBDATA1;
  assign rd_sbdata = dmi_rd && dmactive && dmi_req_addr == D_SBDATA0;

  assign sb_state      = sb_state_e'(sb_state_q);
  assign sb_busy       = sb_state != SB_IDLE;
  assign sb_blocked    = sb_busyerror || sb_error != SBE_NONE;
  assign sb_readonaddr = sb_cfg[5];
  assign sb_access     = sb_cfg[4:2];
  assign sb_autoinc    = sb_cfg[1];
  assign sb_readondata = sb_cfg[0];

  // an access starts on: sbaddress0 write with sbreadonaddr, sbdata0 read with
  // sbreadondata (after the read returns the old data), sbdata0 write
  always_comb begin
    sb_addr_go = sb_addr;
    if (wr_sbaddr) sb_addr_go[31:0] = wd;
  end

  assign sb_go_read  = (wr_sbaddr && sb_readonaddr) || (rd_sbdata && sb_readondata);
  assign sb_go_write = wr_sbdata;
  assign sb_go       = !sb_busy && !sb_blocked && (sb_go_read || sb_go_write);
  assign sb_size_ok  = sb_access <= SB_MAX_SIZE;
  assign sb_align_ok = sb_access == 3'd0 || (sb_access == 3'd1 && !sb_addr_go[0])
                       || (sb_access == 3'd2 && sb_addr_go[1:0] == 2'b00)
                       || (sb_access == 3'd3 && sb_addr_go[2:0] == 3'b000);
  assign sb_start    = sb_go && sb_size_ok && sb_align_ok;
  assign sb_done     = sb_state == SB_WAIT && sb_ack_valid;

  always_comb begin
    sb_state_d = sb_state;
    case (sb_state)
      SB_IDLE: if (sb_start)      sb_state_d = SB_REQ;
      SB_REQ:  if (sb_req_accept) sb_state_d = SB_WAIT;
      SB_WAIT: if (sb_ack_valid)  sb_state_d = SB_IDLE;
      default:                    sb_state_d = SB_IDLE;
    endcase
  end

  always_comb begin
    sb_busyerror_d = sb_busyerror && !(wr_sbcs && wd[22]);
    if (sb_busy && (wr_sbaddr || wr_sbaddr1 || wr_sbdata || wr_sbdata1 || rd_sbdata)) sb_busyerror_d = 1'b1;
    sb_error_d = wr_sbcs ? (sb_error & ~wd[14:12]) : sb_error;
    if (sb_go && !sb_size_ok)        sb_error_d = SBE_SIZE;
    else if (sb_go && !sb_align_ok)  sb_error_d = SBE_ALIGN;
    else if (sb_done && sb_ack_error) sb_error_d = SBE_BADADDR;
  end

  assign sb_cfg_d   = wr_sbcs ? wd[20:15] : sb_cfg;
  assign sb_write_d = sb_start ? sb_go_write : sb_write;
  assign sb_size_d  = sb_start ? sb_access : sb_size;     // sbcs writes do not reach an access in flight

  assign sb_rd_shift = sb_ack_rdata >> {sb_addr[SB_LO-1:0], 3'b000};
  assign sb_addr_inc = sb_addr + (SB_ONE << sb_size);

  always_comb begin
    sb_rd_val = sb_rd_shift;
    case (sb_size)
      3'd0:    sb_rd_val = SB_DATA_W'(sb_rd_shift[7:0]);
      3'd1:    sb_rd_val = SB_DATA_W'(sb_rd_shift[15:0]);
      3'd2:    sb_rd_val = SB_DATA_W'(sb_rd_shift[31:0]);
      default: ;
    endcase
  end

  always_comb begin
    sb_addr_d = sb_addr;
    sb_data_d = sb_data;
    if (wr_sbaddr && !sb_busy) sb_addr_d[31:0] = wd;
    if (wr_sbaddr1 && !sb_busy) sb_addr_d = (SB_ADDR_W)'({wd, sb_addr[31:0]});
    if (wr_sbdata && !sb_busy && !sb_blocked) sb_data_d[31:0] = wd;
    if (wr_sbdata1 && !sb_busy && !sb_blocked) sb_data_d = (SB_DATA_W)'({wd, sb_data[31:0]});
    if (sb_done && !sb_ack_error) begin
      if (!sb_write) sb_data_d = sb_rd_val;
      if (sb_autoinc) sb_addr_d = sb_addr_inc;
    end
  end

  basechili_dff_sclr #(.WIDTH(2)) u_sb_state (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (sb_state_d),
    .q     (sb_state_q)
  );

  basechili_dff_sclr #(.WIDTH(8)) u_sb_err (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     ({sb_busyerror_d, sb_error_d, sb_write_d, sb_size_d}),
    .q     ({sb_busyerror, sb_error, sb_write, sb_size})
  );

  basechili_dff_sclr #(.WIDTH(6), .RESET_VAL(SB_CFG_RESET)) u_sb_cfg (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     (sb_cfg_d),
    .q     (sb_cfg)
  );

  basechili_dff_sclr #(.WIDTH(SB_ADDR_W + SB_DATA_W)) u_sb_addr_data (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (dm_clr),
    .en    (1'b1),
    .d     ({sb_addr_d, sb_data_d}),
    .q     ({sb_addr, sb_data})
  );

  assign sb_req_valid  = sb_state == SB_REQ;
  assign sb_req_write  = sb_write;
  assign sb_req_addr   = sb_addr;
  assign sb_req_size   = sb_size;
  always_comb begin
    sb_req_wdata = sb_data;
    case (sb_size)
      3'd0:    sb_req_wdata = {SB_LANES{sb_data[7:0]}};
      3'd1:    sb_req_wdata = {(SB_LANES / 2){sb_data[15:0]}};
      3'd2:    sb_req_wdata = {(SB_LANES / 4){sb_data[31:0]}};
      default: ;
    endcase
  end
  assign sb_ack_accept = 1'b1;

  // ---- DMI reads and the response
  assign sb_addr64 = 64'(sb_addr);
  assign sb_data64 = 64'(sb_data);

  assign dmstatus = {7'd0, ndm_wait, 1'b0, 1'b1, 2'b00,
                     {2{havereset}}, {2{resumeack}}, 2'b00, {2{hart_unavail}},
                     {2{!halted && !hart_unavail}}, {2{halted}},
                     1'b1, 1'b0, 1'b1, 1'b0, 4'd3};

  always_comb begin
    rd_val = 32'h0;
    if (data_hit)         rd_val = data_q[int'(data_idx)*32 +: 32];
    else if (progbuf_hit) rd_val = progbuf_q[int'(progbuf_idx)*32 +: 32];
    else begin
      case (dmi_req_addr)
        D_DMCONTROL:  rd_val = {30'd0, ndmreset_q, dmactive};          // haltreq reads 0
        D_DMSTATUS:   rd_val = dmstatus;
        D_HARTINFO:   rd_val = {8'd0, 4'd0, 3'd0, 1'b1, 4'(DATA_COUNT), A_DATA};
        D_ABSTRACTCS: rd_val = {3'd0, 5'(PROGBUF_SIZE), 11'd0, busy, 1'b0, cmderr, 4'd0, 4'(DATA_COUNT)};
        D_ABSTRACTAUTO: rd_val = {8'd0, auto_q[9:2], 14'd0, auto_q[1:0]};
        D_SBCS:       rd_val = {3'd1, 6'd0, sb_busyerror, sb_busy, sb_cfg, sb_error, 7'(SB_ADDR_W),
                                1'b0, SB_D64, 3'b111};
        D_SBADDRESS0: rd_val = sb_addr64[31:0];
        D_SBADDRESS1: rd_val = sb_addr64[63:32];                     // 0 with 32-bit addresses
        D_SBDATA0:    rd_val = sb_data64[31:0];
        D_SBDATA1:    rd_val = sb_data64[63:32];                     // 0 with a 32-bit bus
        D_HALTSUM0:   rd_val = {31'd0, halted};
        default:      rd_val = 32'h0;
      endcase
    end
    if (busy && (data_hit || progbuf_hit)) rd_val = 32'h0;   // busy: not readable
  end

  assign rsp_valid_d = dmi_fire || (dmi_rsp_valid && !dmi_rsp_accept);
  assign rsp_data_d  = dmi_fire ? rd_val : dmi_rsp_data;

  basechili_dff #(.WIDTH(33)) u_rsp (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({rsp_valid_d, rsp_data_d}),
    .q     ({dmi_rsp_valid, dmi_rsp_data})
  );

  assign dmi_rsp_op = 2'd0;

endmodule
