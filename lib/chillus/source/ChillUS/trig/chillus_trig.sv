// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_trig
//
// Trigger module (Sdtrig, riscv-debug-specification.pdf Chapter 5) with
// NUM_TRIGGERS execute-address triggers (mcontrol6, timing "before"), for an
// M / U-mode core. NUM_TRIGGERS = 0 removes it (no flops, no CSRs: every Sdtrig
// CSR is an illegal instruction, as Sdext without Sdtrig requires).
//
// Matching: the pc of the instruction in the compare stage (first top: id)
// is compared with every enabled trigger; the hit vector is registered with
// the instruction into the next stage (adv: it moves on; load: that stage
// loads, the decoder's rule), so the comparators are off the next stage's
// paths. A trigger is enabled when type = 6, execute = 1, not in debug mode,
// and in M-mode m = 1 and (for action 0) tcontrol.mte = 1, in U-mode u = 1
// (priv_m: the mode; it changes only with a redirect, so the compared
// instruction runs in it). Only the instruction's own
// address (pc) matches. In the next stage:
//   trig_dbg: a hit trigger has action 1 (enter debug mode, cause 2)
//   trig_exc: hit triggers with action 0 only (breakpoint exception)
// The pipeline takes them on that instruction like an interrupt: it does not
// execute (brk_take: mcause 3, mepc = mtval = pc; dbg_take: dpc = pc).
// Matches computed in the compare stage stay valid in the next one: every
// change of their inputs (trigger CSR write: refetch, trap / mret / debug
// entry / dret: redirect) kills the younger instructions.
//
// CSRs (NUM_TRIGGERS > 0)
//   0x7A0 tselect   index; WARL: a write >= NUM_TRIGGERS is ignored
//   0x7A1 tdata1    per trigger, type 6 (mcontrol6) or 15 (disabled):
//                   type [31:28], dmode [27], hit0 [22], action [15:12]
//                   (0 or 1; 1 only with dmode = 1), m [6], u [3],
//                   execute [2]; select, size, match (equal), chain, s / vs / vu,
//                   load / store, uncertain, hit1 read 0. A write of any
//                   other type disables the trigger (type 15). dmode is
//                   written only in debug mode (0 otherwise); a trigger with
//                   dmode = 1 ignores tdata writes outside debug mode.
//                   DEBUG = 0: dmode and action are 0.
//   0x7A2 tdata2    compare address (XLEN), per trigger
//   0x7A3 tdata3    reads 0, writes ignored (no textra matching)
//   0x7A4 tinfo     version 1 [31:24], info [15:0] = types 6 and 15
//   0x7A5 tcontrol  mte [3], mpte [7]: a trap into M-mode (trap_m) sets
//                   mpte = mte, mte = 0; mret sets mte = mpte
// hit0 is set on every hit trigger when the instruction's trigger fires
// (brk_take, or dbg_take with trig_dbg). Any write of a trigger CSR raises
// refetch (the pipeline refetches the next instruction, so it is compared
// with the new configuration).
//
// Timing   : trig_exc / trig_dbg come from registers; csr_rdata, csr_hit and
//            refetch are combinational; the CSRs update at the clock edge.
// Invariants
//   debug_mode -> no new hit is captured.
//   trig_exc -> !trig_dbg.
//   tselect < NUM_TRIGGERS.
// Debug    : no breakpoint -> en (type6, execute, m, mte / action), the
//            compare (tdata2 vs pc), mode (priv_m, u_en), hit_q and the pipeline's brk_take /
//            dbg_take terms; dmode writes ignored -> debug_mode.
// -----------------------------------------------------------------------------
module chillus_trig #(
  parameter int XLEN         = 32,      // register width
  parameter int NUM_TRIGGERS = 1,       // execute-address triggers (0: none)
  parameter bit DEBUG        = 1'b1     // Sdext present (0: dmode / action hardwired 0)
) (
  input  logic            clk,
  input  logic            rst_n,                 // async, active-low

  // compare stage
  input  logic [XLEN-1:0] pc,                    // address of the instruction compared
  input  logic            adv,                   // it moves to the next stage at this edge
  input  logic            load,                  // the next stage loads at this edge
  // next stage
  output logic            trig_exc,              // an action-0 trigger fires (and no action-1 one)
  output logic            trig_dbg,              // an action-1 trigger fires
  input  logic            brk_take,              // pipeline: breakpoint exception taken for it
  input  logic            dbg_take,              // pipeline: debug entry taken on that instruction

  // state
  input  logic            debug_mode,            // debug unit: no match; dmode writable
  input  logic            priv_m,                // trap unit: the mode is M (0: U)
  input  logic            trap_m,                // trap unit: a trap into M-mode is taken
  input  logic            mret,                  // trap unit: MRET executes

  // CSR port (CSR instructions)
  input  logic [11:0]     csr_addr,
  input  logic            csr_we,                // write csr_wdata to csr_addr at the clock edge
  input  logic [XLEN-1:0] csr_wdata,
  output logic [XLEN-1:0] csr_rdata,             // 0 when !csr_hit
  output logic            csr_hit,               // csr_addr is a trigger CSR (NUM_TRIGGERS > 0)
  output logic            refetch                // a trigger CSR is written: refetch the next instruction
);

  localparam logic [11:0] CSR_TSELECT  = 12'h7A0;
  localparam logic [11:0] CSR_TDATA1   = 12'h7A1;
  localparam logic [11:0] CSR_TDATA2   = 12'h7A2;
  localparam logic [11:0] CSR_TDATA3   = 12'h7A3;
  localparam logic [11:0] CSR_TINFO    = 12'h7A4;
  localparam logic [11:0] CSR_TCONTROL = 12'h7A5;

  localparam logic [3:0]  TYPE_MCONTROL6 = 4'd6;
  localparam logic [3:0]  TYPE_DISABLED  = 4'd15;
  localparam logic [7:0]  TINFO_VERSION  = 8'd1;

  localparam int N  = (NUM_TRIGGERS > 0) ? NUM_TRIGGERS : 1;   // vector widths (no zero width)
  localparam int SW = (N > 1) ? $clog2(N) : 1;                 // tselect width

  if (NUM_TRIGGERS > 0) begin : g_trig
    logic [SW-1:0]   tsel;          // tselect
    logic [SW-1:0]   tsel_d;
    logic            tsel_en;
    logic [N-1:0]    type6;         // per trigger: type 6 (else 15, disabled)
    logic [N-1:0]    dmode;
    logic [N-1:0]    action;        // 1: enter debug mode, 0: breakpoint exception
    logic [N-1:0]    m_en;          // m: match in M-mode
    logic [N-1:0]    u_en;          // u: match in U-mode
    logic [N-1:0]    execute;
    logic [N-1:0]    hit0;
    logic [N*XLEN-1:0] tdata2;      // trigger i: tdata2[i*XLEN +: XLEN]
    logic [N-1:0]    en;            // trigger enabled for a match now
    logic [N-1:0]    match;         // enabled and tdata2 == pc
    logic [N-1:0]    hit_d;
    logic [N-1:0]    hit_q;         // hit vector of the next stage's instruction
    logic            fire;          // the next stage's instruction's trigger fires
    logic            mte;
    logic            mpte;
    logic            tctl_en;
    logic            mte_d;
    logic            mpte_d;
    logic            sel_trig;      // csr_addr in 0x7A0 .. 0x7A5
    logic            wr;            // trigger CSR write
    logic            sel_locked;    // selected trigger has dmode = 1 outside debug mode
    logic            wr_tdata1;
    logic            wr_tdata2;
    logic            type6_w;       // written tdata1 selects type 6
    logic            dmode_w;       // dmode as written (debug mode only)
    logic            action_w;      // action as written, legalized
    logic [XLEN-1:0] tdata1_rd;     // selected trigger's tdata1 as read
    logic [XLEN-1:0] tdata2_rd;
    logic [XLEN-1:0] tinfo_rd;
    logic [XLEN-1:0] tctl_rd;

    // -------------------------------------------------------------------------
    // Match (compare stage) and hit register (next stage)
    // -------------------------------------------------------------------------
    for (genvar i = 0; i < N; i++) begin : g_match
      assign en[i]    = type6[i] && execute[i] && !debug_mode &&
                        (priv_m ? (m_en[i] && (action[i] || mte)) : u_en[i]);
      assign match[i] = en[i] && (tdata2[i*XLEN +: XLEN] == pc);
    end

    assign hit_d = adv ? match : '0;

    basechili_dffe #(.WIDTH(N)) u_hit (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (load),
      .d     (hit_d),
      .q     (hit_q)
    );

    assign trig_dbg = (hit_q & action) != '0;
    assign trig_exc = (hit_q != '0) && !trig_dbg;
    assign fire     = brk_take || (dbg_take && trig_dbg);

    // -------------------------------------------------------------------------
    // CSR port
    // -------------------------------------------------------------------------
    assign sel_trig   = (csr_addr >= CSR_TSELECT) && (csr_addr <= CSR_TCONTROL);
    assign csr_hit    = sel_trig;
    assign wr         = csr_we && sel_trig;
    assign refetch    = wr;
    assign sel_locked = dmode[tsel] && !debug_mode;
    assign wr_tdata1  = wr && (csr_addr == CSR_TDATA1) && !sel_locked;
    assign wr_tdata2  = wr && (csr_addr == CSR_TDATA2) && !sel_locked;

    // tselect: values >= NUM_TRIGGERS are ignored
    assign tsel_en = wr && (csr_addr == CSR_TSELECT) && (csr_wdata < XLEN'(unsigned'(NUM_TRIGGERS)));
    assign tsel_d  = csr_wdata[SW-1:0];

    if (NUM_TRIGGERS > 1) begin : g_tsel
      basechili_dffe #(.WIDTH(SW)) u_tselect (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (tsel_en),
        .d     (tsel_d),
        .q     (tsel)
      );
    end else begin : g_tsel1
      assign tsel = '0;
    end

    // tdata1 fields as written
    assign type6_w  = csr_wdata[XLEN-1 -: 4] == TYPE_MCONTROL6;
    assign dmode_w  = DEBUG && debug_mode && csr_wdata[XLEN-5];
    assign action_w = DEBUG && type6_w && dmode_w && (csr_wdata[15:12] == 4'd1);

    for (genvar i = 0; i < N; i++) begin : g_cfg
      logic          sel;          // this trigger is selected
      logic          cfg_en;       // tdata1 written
      logic [5:0]    cfg_d;        // {type6, dmode, action, m, u, execute}
      logic [5:0]    cfg_q;
      logic          hit_en;
      logic          hit_dd;
      logic          t2_en;

      assign sel    = tsel == SW'(unsigned'(i));
      assign cfg_en = wr_tdata1 && sel;
      assign cfg_d  = {type6_w, dmode_w, action_w, type6_w && csr_wdata[6], type6_w && csr_wdata[3],
                       type6_w && csr_wdata[2]};

      basechili_dffe #(.WIDTH(6)) u_cfg (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (cfg_en),
        .d     (cfg_d),
        .q     (cfg_q)
      );

      assign {type6[i], dmode[i], action[i], m_en[i], u_en[i], execute[i]} = cfg_q;

      // hit0: set when the trigger fires, written by tdata1
      assign hit_en = cfg_en || (fire && hit_q[i]);
      assign hit_dd = cfg_en ? (type6_w && csr_wdata[22]) : 1'b1;

      basechili_dffe #(.WIDTH(1)) u_hit0 (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (hit_en),
        .d     (hit_dd),
        .q     (hit0[i])
      );

      assign t2_en = wr_tdata2 && sel;

      basechili_dffe #(.WIDTH(XLEN)) u_tdata2 (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (t2_en),
        .d     (csr_wdata),
        .q     (tdata2[i*XLEN +: XLEN])
      );
    end

    // tcontrol: trap into M pushes mte, mret pops it; CSR write
    assign tctl_en = trap_m || mret || (wr && (csr_addr == CSR_TCONTROL));
    assign mte_d   = trap_m ? 1'b0 :
                     mret   ? mpte : csr_wdata[3];
    assign mpte_d  = trap_m ? mte  :
                     mret   ? mpte : csr_wdata[7];

    basechili_dffe #(.WIDTH(2)) u_tcontrol (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (tctl_en),
      .d     ({mpte_d, mte_d}),
      .q     ({mpte, mte})
    );

    // reads
    always_comb begin
      tdata1_rd = '0;
      tdata1_rd[XLEN-1 -: 4] = type6[tsel] ? TYPE_MCONTROL6 : TYPE_DISABLED;
      tdata1_rd[XLEN-5]      = dmode[tsel];
      if (type6[tsel]) begin
        tdata1_rd[22]    = hit0[tsel];
        tdata1_rd[12]    = action[tsel];
        tdata1_rd[6]     = m_en[tsel];
        tdata1_rd[3]     = u_en[tsel];
        tdata1_rd[2]     = execute[tsel];
      end
    end

    always_comb begin
      tdata2_rd = '0;
      for (int i = 0; i < N; i++) begin
        if (tsel == SW'(unsigned'(i))) tdata2_rd = tdata2[i*XLEN +: XLEN];
      end
    end

    always_comb begin
      tinfo_rd        = '0;
      tinfo_rd[31:24] = TINFO_VERSION;
      tinfo_rd[6]     = 1'b1;              // mcontrol6
      tinfo_rd[15]    = 1'b1;              // disabled
      tctl_rd         = '0;
      tctl_rd[3]      = mte;
      tctl_rd[7]      = mpte;
    end

    always_comb begin
      case (csr_addr)
        CSR_TSELECT:  csr_rdata = XLEN'(tsel);
        CSR_TDATA1:   csr_rdata = tdata1_rd;
        CSR_TDATA2:   csr_rdata = tdata2_rd;
        CSR_TDATA3:   csr_rdata = '0;
        CSR_TINFO:    csr_rdata = tinfo_rd;
        CSR_TCONTROL: csr_rdata = tctl_rd;
        default:      csr_rdata = '0;
      endcase
    end
  end else begin : g_notrig
    assign trig_exc  = 1'b0;
    assign trig_dbg  = 1'b0;
    assign csr_hit   = 1'b0;
    assign csr_rdata = '0;
    assign refetch   = 1'b0;
  end

endmodule
