// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_dma_ch
//
// One channel of chilimix_dma in the SiFive Platform DMA layout (FU540
// PDMA, 0x1000 bytes): the register block (chilimix_dma_regs), the control
// bits and the Exec registers of the running transfer. The engine in
// chilimix_dma moves the bytes, one beat (1, 2 or 4 bytes) at a time.
//   start   a control write with run 1 while run is clear and claim set
//           (or set by the same write) copies Next to Exec and sets run;
//           with next_bytes 0 it sets done at once and run stays clear.
//   beat    beat_done (while the engine serves this channel, active)
//           advances exec_src / exec_dst by beat_size and lowers
//           exec_bytes; the last beat sets done and clears run, or with
//           repeat copies Next to Exec again and keeps running; a beat
//           with beat_err sets error and clears run.
//   abort   a control write with run 0 while run is set stops the channel:
//           at once if the engine is not serving it, else after the beat
//           in flight (stop; run reads 1 until then).
//   claim   cannot be cleared while run is set. done and error are
//           cleared by writing 0 to them (the driver writes back the
//           control word with the bit cleared); a hardware set wins.
// req asks the engine for a beat: run set, no stop pending, bytes left.
//
// Timing    : APB reads are combinational; req, the Exec registers and
//             the interrupt levels come from flops.
// Invariants: active implies run; run implies claim; req implies run and
//             exec_bytes != 0; stop only while run.
// Debug     : no transfer -> claim, run, req, exec_bytes; never done ->
//             stop, active, beat_done; wrong addresses -> exec_src /
//             exec_dst against next_src / next_dst at start.
// -----------------------------------------------------------------------------
module chilimix_dma_ch (
  input  logic        clk,
  input  logic        rst_n,       // async, active-low
  // APB4 subordinate (this channel's 0x1000 bytes)
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [11:0] PADDR,
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,
  // engine
  output logic        req,         // a beat is wanted
  output logic [31:0] exec_src,
  output logic [31:0] exec_dst,
  output logic [31:0] exec_bytes,
  input  logic        active,      // the engine serves this channel (a beat in flight)
  input  logic        beat_done,   // pulse: the beat finished (while active)
  input  logic        beat_err,    // with beat_done: a bus error
  input  logic [2:0]  beat_size,   // with beat_done: bytes moved (1, 2 or 4)
  // interrupt levels
  output logic        done_irq,    // done & done_ie
  output logic        err_irq      // error & error_ie
);

  // ---- register fields ----------------------------------------------------------
  logic        w_claim, w_run, w_done_ie, w_error_ie, w_done, w_error, ctl_wr;
  logic        next_repeat, next_order;
  logic [3:0]  next_wsize, next_rsize;
  logic [31:0] next_bytes, next_dst, next_src;
  logic        exec_repeat, exec_order;
  logic [3:0]  exec_wsize, exec_rsize;

  // ---- control state --------------------------------------------------------------
  logic        claim, run, stop, done_ie, error_ie, done, error;
  logic        claim_d, run_d, stop_d, done_ie_d, error_ie_d, done_d, error_d;
  logic        start;          // copy Next to Exec and run
  logic        start_empty;    // a start with nothing to move
  logic        abort;
  logic        last;           // this beat moves the last bytes
  logic        reload;         // repeat: copy Next to Exec after the last beat
  logic        load;           // Exec loads from Next
  logic        halt;           // run clears (end, error, abort)
  logic        set_done, set_error;
  logic [9:0]  cfg_next, cfg_exec;  // {repeat, order, wsize, rsize}
  logic        exec_en;
  logic [31:0] bytes_d, src_d, dst_d;
  logic [31:0] size32;
  logic [31:0] zero32;         // the high address words (32-bit addresses)

  chilimix_dma_regs u_regs (
    .clk                (clk),
    .rst_n              (rst_n),
    .PSEL               (PSEL),
    .PENABLE            (PENABLE),
    .PWRITE             (PWRITE),
    .PADDR              (PADDR),
    .PWDATA             (PWDATA),
    .PSTRB              (PSTRB),
    .PREADY             (PREADY),
    .PRDATA             (PRDATA),
    .PSLVERR            (PSLVERR),
    .control_claim      (claim),
    .control_run        (run),
    .control_done_ie    (done_ie),
    .control_error_ie   (error_ie),
    .control_done       (done),
    .control_error      (error),
    .control_w_claim    (w_claim),
    .control_w_run      (w_run),
    .control_w_done_ie  (w_done_ie),
    .control_w_error_ie (w_error_ie),
    .control_w_done     (w_done),
    .control_w_error    (w_error),
    .control_w_wr       (ctl_wr),
    .next_config_repeat (next_repeat),
    .next_config_order  (next_order),
    .next_config_wsize  (next_wsize),
    .next_config_rsize  (next_rsize),
    .next_bytes_value   (next_bytes),
    .next_dst_value     (next_dst),
    .next_src_value     (next_src),
    .next_src_hi_value  (zero32),
    .exec_config_repeat (exec_repeat),
    .exec_config_order  (exec_order),
    .exec_config_wsize  (exec_wsize),
    .exec_config_rsize  (exec_rsize),
    .exec_bytes_value   (exec_bytes),
    .exec_dst_value     (exec_dst),
    .exec_src_value     (exec_src),
    .exec_src_hi_value  (zero32)
  );

  assign zero32 = '0;

  // ---- control ------------------------------------------------------------------
  assign start       = ctl_wr && w_run && !run && (w_claim || claim);
  assign start_empty = start && (next_bytes == 32'd0);
  assign abort       = ctl_wr && !w_run && run;
  assign size32      = {29'd0, beat_size};
  assign last        = beat_done && !beat_err && (exec_bytes == size32);
  assign reload      = last && exec_repeat && !stop && !abort && (next_bytes != 32'd0);
  assign load        = (start && !start_empty) || reload;
  assign set_done    = start_empty || last;
  assign set_error   = beat_done && beat_err;
  assign halt        = (beat_done && (beat_err || last || stop))
                    || (abort && (!active || beat_done));

  always_comb begin
    run_d  = run;
    stop_d = stop;
    if (load) begin
      run_d  = 1'b1;
      stop_d = 1'b0;
    end else if (halt) begin
      run_d  = 1'b0;
      stop_d = 1'b0;
    end else if (abort) begin
      stop_d = 1'b1;
    end
  end

  assign claim_d    = ctl_wr ? (w_claim || run_d) : claim;
  assign done_ie_d  = ctl_wr ? w_done_ie : done_ie;
  assign error_ie_d = ctl_wr ? w_error_ie : error_ie;
  assign done_d     = set_done || (done && !(ctl_wr && !w_done));
  assign error_d    = set_error || (error && !(ctl_wr && !w_error));

  basechili_dff #(.WIDTH(7)) u_ctl (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({claim_d, run_d, stop_d, done_ie_d, error_ie_d, done_d, error_d}),
    .q     ({claim, run, stop, done_ie, error_ie, done, error})
  );

  assign req = run && !stop && (exec_bytes != 32'd0);

  // ---- Exec registers ---------------------------------------------------------------
  assign cfg_next = {next_repeat, next_order, next_wsize, next_rsize};
  assign {exec_repeat, exec_order, exec_wsize, exec_rsize} = cfg_exec;

  basechili_dffe #(.WIDTH(10)) u_cfg (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (load),
    .d     (cfg_next),
    .q     (cfg_exec)
  );

  assign exec_en = load || (beat_done && !beat_err);
  assign bytes_d = load ? next_bytes : (exec_bytes - size32);
  assign src_d   = load ? next_src   : (exec_src + size32);
  assign dst_d   = load ? next_dst   : (exec_dst + size32);

  basechili_dffe #(.WIDTH(96)) u_exec (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (exec_en),
    .d     ({bytes_d, src_d, dst_d}),
    .q     ({exec_bytes, exec_src, exec_dst})
  );

  assign done_irq = done && done_ie;
  assign err_irq  = error && error_ie;

endmodule
