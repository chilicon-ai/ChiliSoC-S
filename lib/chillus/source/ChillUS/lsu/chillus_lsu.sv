// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_lsu
//
// Load/store unit for RV32I loads and stores (riscv-unprivileged.pdf,
// Chapter 2.6) on a data interface (req / gnt, then rvalid with
// rdata / err, in order). Stage-agnostic: an instruction presents its request
// at step req and completes at step rsp; the pipeline decides which stages
// these are (first top: req = ex, rsp = wb). FENCE makes no request: the MSS
// completes accesses in order and the LSU allows one outstanding, so a fence
// is a nop.
//
//   req : the address (rs1 + imm) comes from the ALU adder (the LSU
//         has no own adder). The request carries the word address
//         (addr & ~3), byte enables from size and addr[1:0], and the store
//         data replicated into every lane. Combinational, no registers.
//   rsp : the access's controls are registered when the MSS grants it
//         (req && gnt); the instruction waits in this step for rvalid. A
//         load's rdata is lane-selected and sign- / zero-extended
//         combinationally (load_data, straight into the register file
//         write); err reports access_fault with the access address.
//
// Data interface protocol
//   - mss_req stays high, with the same request, until mss_gnt; a request is
//     taken on a clock edge with mss_req && mss_gnt.
//   - mss_rvalid answers each taken request, in order, one or more cycles
//     after its grant; mss_rdata (loads) and mss_err are valid with it.
//     mss_err: the access failed and had no effect (bus error).
//   - At most one access is outstanding: a new request is presented only
//     with nothing outstanding, or in the cycle the outstanding one's rvalid
//     arrives (req_ok). The pipeline gates it on a bus error (in_valid low:
//     the error kills the instruction behind the faulting one).
//   - req_wait (registered: a request presented without a grant) tells the
//     pipeline not to withdraw the request (no interrupt / debug entry on
//     that instruction until it is granted).
//
// Misaligned access (address not divisible by the access size): no request
// (a misaligned store cannot corrupt memory); misaligned is raised in req for
// the exception logic (address-misaligned exception).
//
// PMP: an aligned access the PMP denies (pmp_deny_load / _store, from the
// same address) is never presented on the MSS. It waits in req one cycle
// with req_ok (pmp_wait, registered), then leaves it as if granted
// (pmp_fire) and gets an error response of its own in rsp the next cycle
// (rsp_pmp, a register): access_fault, the same load / store access fault
// as an mss_err, with its address. So the deny reaches only mss_req and
// the rsp registers combinationally: not req_stall (the pipeline hold and
// the fast fetch redirect) and not the exception logic (misaligned keeps
// its priority: no pmp_fire).
//
// Timing
//   mss_addr / mss_be / mss_wdata / mss_we: combinational from mem_op /
//   mem_size / addr / rs2_data only (not in_valid). mss_req and misaligned:
//   also from in_valid; mss_req also from mss_rvalid (req_ok) and
//   pmp_deny_*.
//   req_stall: combinational from the req inputs, mss_gnt, mss_rvalid and
//   pmp_wait (not from pmp_deny_*).
//   rsp_stall, access_fault, load_valid, load_data: combinational from the
//   rsp registers and mss_rvalid / mss_err / mss_rdata (no flop between
//   mss_rdata and load_data); a PMP-denied access's access_fault comes from
//   the rsp_pmp register, one cycle after req.
//
// Invariants
//   rsp_load && rsp_store never both set.
//   mss_req -> !misaligned && !pmp_fire && (!outstanding || mss_rvalid).
//   rsp_pmp -> (rsp_load || rsp_store) && !outstanding: a denied access has
//   no bus access outstanding.
//   req_wait -> mss_req (a presented request is not withdrawn).
//   pmp_wait -> the access in req is aligned and denied (it stayed in req:
//   address and PMP unchanged), so an allowed access never leaves without
//   req_fire.
//   load_valid -> rsp_load && mss_rvalid && !mss_err.
//
// Debug
//   Wrong address: the ALU result (alu_op ADD, alu_src2 IMM); check imm.
//   Wrong load value: mss_rdata in the rvalid cycle, selected and extended by
//   rsp_offset / rsp_size / rsp_unsigned into load_data.
//   Pipeline stuck in req: mss_gnt never high (req_wait stays set), or
//   req_ok low (an outstanding access without rvalid: rsp_stall).
//   Load result missing: misaligned in req, in_valid low (killed), or
//   access_fault (mss_err, or rsp_pmp: the PMP denied it) in rsp.
// -----------------------------------------------------------------------------
module chillus_lsu
  import chillus_dec_pkg::*;
#(
  parameter  int XLEN   = 32,                   // register and data bus width
  localparam int N_LANE = XLEN / 8,             // byte lanes on the bus
  localparam int OFF_W  = $clog2(N_LANE),       // byte offset bits within a bus word
  localparam int SIZE_W = $bits(mem_size_e)     // access size: log2 of the byte count
) (
  input  logic              clk,
  input  logic              rst_n,              // async, active-low

  // req: instruction presenting its access (decoder indications of its stage)
  input  logic              in_valid,           // real instruction; 0 when killed or a bubble
  input  mem_op_e           mem_op,
  input  mem_size_e         mem_size,
  input  logic              mem_unsigned,       // LBU / LHU
  input  logic [XLEN-1:0]   addr,               // rs1 + imm (ALU result)
  input  logic [XLEN-1:0]   rs2_data,           // store data (after forwarding)
  output logic              misaligned,         // access not naturally aligned: no request
  input  logic              pmp_deny_load,      // PMP: a load at addr is not allowed (chillus_pmp)
  input  logic              pmp_deny_store,     // PMP: a store at addr is not allowed
  output logic              req_stall,          // hold req: the access is not granted this cycle
  output logic              req_wait,           // a request was presented without a grant (registered)

  // MSS request (req)
  output logic              mss_req,
  input  logic              mss_gnt,
  output logic              mss_we,
  output logic [XLEN-1:0]   mss_addr,           // word address (low OFF_W bits 0)
  output logic [N_LANE-1:0] mss_be,             // byte lane enables
  output logic [XLEN-1:0]   mss_wdata,          // store data in every lane, 0 for loads

  // MSS response (rsp)
  input  logic              mss_rvalid,
  input  logic [XLEN-1:0]   mss_rdata,          // whole bus word, all lanes
  input  logic              mss_err,            // with mss_rvalid: the access failed

  // rsp: the access waiting for its response
  output logic              rsp_stall,          // hold rsp: an access is outstanding, no rvalid yet
  output logic              access_fault,       // the outstanding access got mss_err
  output logic              access_fault_store, // the faulting access is a store
  output logic [XLEN-1:0]   access_fault_addr,  // its byte address (mtval)
  output logic              load_valid,         // a load completes this cycle
  output logic [XLEN-1:0]   load_data           // its value, selected and extended
);

  // req
  logic                is_load;
  logic                is_store;
  logic                is_access;       // load or store (has an address)
  logic                pmp_deny;        // the PMP denies this access (load or store)
  logic                aligned_access;  // aligned load / store
  logic                access;          // aligned access the PMP allows: wants a request
  logic                pmp_fire;        // denied access leaves req (as if granted)
  logic                pmp_wait;        // the access in req was denied last cycle with req_ok: it leaves now
  logic                pmp_wait_d;
  logic                req_leave;       // an aligned access in req leaves it this cycle (if allowed: req_fire)
  logic [OFF_W-1:0]    offset;          // byte lane of the first accessed byte
  logic [SIZE_W-1:0]   size_bits;       // mem_size as log2(bytes)
  logic [OFF_W-1:0]    align_mask;      // address bits that must be 0 for this size
  logic                unaligned;       // offset & align_mask != 0
  logic [XLEN-1:0]     store_data;      // rs2_data replicated per access size
  logic [N_LANE-1:0]   access_be;       // byte lanes of the access
  logic                outstanding;     // a bus access waits for its rvalid
  logic                req_ok;          // a new request may be presented
  logic                req_fire;        // request granted this cycle
  logic                req_wait_d;

  // rsp registers (load on a grant, clear on rvalid)
  logic                rsp_en;
  logic                rsp_take;        // an access enters rsp (granted or PMP-denied)
  logic                rsp_pmp;         // the access in rsp was denied by the PMP: error response now
  logic                rsp_load;        // a load is outstanding
  logic                rsp_load_d;
  logic                rsp_store;       // a store is outstanding
  logic                rsp_store_d;
  logic [SIZE_W-1:0]   rsp_size_q;
  logic [SIZE_W-1:0]   rsp_size_d;
  mem_size_e           rsp_size;        // enum view of rsp_size_q
  logic                rsp_unsigned;
  logic                rsp_unsigned_d;
  logic [OFF_W-1:0]    rsp_offset;
  logic [OFF_W-1:0]    rsp_offset_d;
  logic [XLEN-1:0]     rsp_addr;        // byte address of the outstanding access
  logic [XLEN-1:0]     rsp_addr_d;

  // rsp: load value
  logic [XLEN-1:0]     rdata_lane;      // mss_rdata shifted so the first byte is in [7:0]

  // ===========================================================================
  // req: alignment, request
  // ===========================================================================
  assign is_load    = in_valid && (mem_op == MEM_OP_LOAD);
  assign is_store   = in_valid && (mem_op == MEM_OP_STORE);
  assign is_access  = is_load || is_store;

  assign offset     = addr[OFF_W-1:0];
  assign size_bits  = mem_size;
  assign align_mask = unsigned'(OFF_W'((1 << size_bits) - 1));
  assign unaligned  = (offset & align_mask) != '0;
  assign misaligned = is_access && unaligned;
  assign pmp_deny   = is_store ? pmp_deny_store : pmp_deny_load;
  assign aligned_access = is_access && !unaligned;
  assign access     = aligned_access && !pmp_deny;

  always_comb begin
    case (mem_size)
      MEM_SIZE_BYTE: store_data = {(XLEN/8){rs2_data[7:0]}};
      MEM_SIZE_HALF: store_data = {(XLEN/16){rs2_data[15:0]}};
      MEM_SIZE_WORD: store_data = {(XLEN/32){rs2_data[31:0]}};
      default:       store_data = '0;
    endcase
  end

  basechili_byte_strobe #(.DATA_W(XLEN)) u_strb (
    .offset (offset),
    .size   (size_bits),
    .strb   (access_be)
  );

  assign outstanding = (rsp_load || rsp_store) && !rsp_pmp;
  assign req_ok      = !outstanding || mss_rvalid;
  assign mss_req     = access && req_ok;
  // we / addr / be / wdata come from the decode and the ALU only (not
  // in_valid), so the response handshake (rvalid / err -> in_valid) reaches
  // only mss_req; they are meaningful with mss_req.
  assign mss_we      = (mem_op == MEM_OP_STORE);
  assign mss_addr    = {addr[XLEN-1:OFF_W], OFF_W'(0)};
  assign mss_be      = (mem_op != MEM_OP_NONE) ? access_be : '0;
  assign mss_wdata   = (mem_op == MEM_OP_STORE) ? store_data : '0;

  assign req_fire    = mss_req && mss_gnt;
  // req leaves on a grant, or (denied) one cycle after the deny was seen
  // with req_ok (pmp_wait). pmp_deny stays off req_stall (the pipeline's
  // hold and the fast fetch redirect): a denied access just waits a cycle,
  // or leaves on an mss_gnt that answers no request.
  assign req_leave   = req_ok && (mss_gnt || pmp_wait);
  assign req_stall   = aligned_access && !req_leave;
  assign pmp_fire    = aligned_access && pmp_deny && req_leave;
  assign pmp_wait_d  = aligned_access && pmp_deny && req_ok && !req_leave;
  assign req_wait_d  = mss_req && !mss_gnt;

  basechili_dff #(.WIDTH(1)) u_pmp_wait (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pmp_wait_d),
    .q     (pmp_wait)
  );

  basechili_dff #(.WIDTH(1)) u_req_wait (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (req_wait_d),
    .q     (req_wait)
  );

  // ===========================================================================
  // rsp: the granted access waits for rvalid
  // ===========================================================================
  // a PMP-denied access holds rsp for one cycle (its error response), then
  // clears it: nothing follows it (access_fault kills in_valid)
  assign rsp_take       = req_fire || pmp_fire;
  assign rsp_en         = rsp_take || mss_rvalid || rsp_pmp;
  assign rsp_load_d     = rsp_take && is_load;
  assign rsp_store_d    = rsp_take && is_store;
  assign rsp_size_d     = (req_fire && is_load) ? size_bits : '0;
  assign rsp_unsigned_d = (req_fire && is_load) ? mem_unsigned : '0;
  assign rsp_offset_d   = (req_fire && is_load) ? offset : '0;
  assign rsp_addr_d     = rsp_take ? addr : '0;

  basechili_dffe #(.WIDTH(1)) u_rsp_load (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_load_d),
    .q     (rsp_load)
  );

  basechili_dff #(.WIDTH(1)) u_rsp_pmp (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pmp_fire),
    .q     (rsp_pmp)
  );

  basechili_dffe #(.WIDTH(1)) u_rsp_store (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_store_d),
    .q     (rsp_store)
  );

  basechili_dffe #(.WIDTH(SIZE_W)) u_rsp_size (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_size_d),
    .q     (rsp_size_q)
  );
  assign rsp_size = mem_size_e'(rsp_size_q);

  basechili_dffe #(.WIDTH(1)) u_rsp_unsigned (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_unsigned_d),
    .q     (rsp_unsigned)
  );

  basechili_dffe #(.WIDTH(OFF_W)) u_rsp_offset (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_offset_d),
    .q     (rsp_offset)
  );

  basechili_dffe #(.WIDTH(XLEN)) u_rsp_addr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (rsp_en),
    .d     (rsp_addr_d),
    .q     (rsp_addr)
  );

  assign rsp_stall          = outstanding && !mss_rvalid;
  assign access_fault       = (outstanding && mss_rvalid && mss_err) || rsp_pmp;
  assign access_fault_store = rsp_store;
  assign access_fault_addr  = rsp_addr;
  assign load_valid         = rsp_load && mss_rvalid && !mss_err;

  // Lane select (little-endian: byte k of the word is bits [8k+7:8k]), then
  // sign- or zero-extend. {N{msb}, rest} avoids a zero-width replication.
  assign rdata_lane = mss_rdata >> {rsp_offset, 3'b000};

  always_comb begin
    case (rsp_size)
      MEM_SIZE_BYTE: load_data = rsp_unsigned ? XLEN'(rdata_lane[7:0]) :
                                                {{(XLEN-7){rdata_lane[7]}}, rdata_lane[6:0]};
      MEM_SIZE_HALF: load_data = rsp_unsigned ? XLEN'(rdata_lane[15:0]) :
                                                {{(XLEN-15){rdata_lane[15]}}, rdata_lane[14:0]};
      MEM_SIZE_WORD: load_data = rsp_unsigned ? XLEN'(rdata_lane[31:0]) :
                                                {{(XLEN-31){rdata_lane[31]}}, rdata_lane[30:0]};
      default:       load_data = '0;
    endcase
  end

endmodule
