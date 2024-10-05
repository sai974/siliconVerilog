// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Asynchronous Reset - RTL
// --------------------------------------------------------

module async_reset (
  input   logic        clk,
  input   logic        reset,

  output  logic        release_reset_o,
  output  logic        gate_clk_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  // Minimum Reset time = 5 cycles
  // Clock tree time    = 7 cycles
  // Reset tree time    = 8 cycles

  logic [4:0] cnt_q;
  logic [4:0] nxt_cnt;

  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      cnt_q   <= 5'h11;
    end else begin
      cnt_q   <= nxt_cnt;
    end

  assign nxt_cnt =  |cnt_q ? cnt_q - 5'h1 : cnt_q;

  // -------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------
  assign gate_clk_o      = (cnt_q < 5'hE) & |cnt_q;
  assign release_reset_o = (cnt_q < 5'h8);

endmodule