// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S sim :: fakeram45_1024x32 (gate-level simulation model)
//
// Behaviour of the Nangate45 fakeram45_1024x32 macro that the ORFS flow puts
// in for basechili_sram_sp (syn/orfs/nangate45/chilisocs/basechili_sram_sp.sv),
// matching basechili_sram_sp: a write updates the bits set in w_mask_in, a
// read gives rd_out the next cycle, rd_out holds otherwise.
//
// Preload: the instance finds its memory and bank in its own path
// (u_rom / u_sram0 / u_sram1, g_ram[<bank>]) and loads its 1024 words of the
// testbench's +rom / +sram0 / +sram1 image.
// -----------------------------------------------------------------------------
module fakeram45_1024x32 (
  input  logic        clk,
  input  logic        ce_in,
  input  logic        we_in,
  input  logic [9:0]  addr_in,
  input  logic [31:0] wd_in,
  input  logic [31:0] w_mask_in,
  output logic [31:0] rd_out
);
  logic [31:0] mem [1024];

  always_ff @(posedge clk)
    if (ce_in) begin
      if (we_in) mem[addr_in] <= (wd_in & w_mask_in) | (mem[addr_in] & ~w_mask_in);
      else       rd_out <= mem[addr_in];
    end

  // index of the first occurrence of pat in s, or -1
  function automatic int find(input string s, input string pat);
    for (int i = 0; i + pat.len() <= s.len(); i++)
      if (s.substr(i, i + pat.len() - 1) == pat) return i;
    return -1;
  endfunction

  initial begin
    string path, plus, f;
    int    bank, at;
    logic [31:0] img [16 * 1024];      // the largest image (64 KiB SRAM)
    path = $sformatf("%m");
    plus = find(path, "u_sram0") >= 0 ? "sram0=%s" :
           find(path, "u_sram1") >= 0 ? "sram1=%s" :
           find(path, "u_rom")   >= 0 ? "rom=%s"   : "";
    bank = 0;
    at = find(path, "g_ram[");
    if (at >= 0)
      for (int i = at + 6; i < path.len() && path[i] >= "0" && path[i] <= "9"; i++)
        bank = bank * 10 + (path[i] - "0");
    if (plus != "" && $value$plusargs(plus, f)) begin
      $readmemh(f, img);
      for (int w = 0; w < 1024; w++)
        mem[w] = img[bank * 1024 + w];
    end
  end
endmodule
