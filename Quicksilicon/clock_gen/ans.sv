// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Frequency Divider - RTL
// --------------------------------------------------------

module clk_gen (
  input   logic        clk_in,

  input   logic        reset,

  output  logic        clk_v1,
  output  logic        clk_v2
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic d;
  logic q;
  logic clk_div;
  
  always_ff @(posedge clk_in or posedge reset)
    if (reset)
      q <= 1'b0;
  	else
      q <= d;
  
  assign d = ~q;
  assign clk_div = q;
  
  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign clk_v1 = clk_div & clk_in;
  assign clk_v2 = clk_v1 ^ clk_in;

endmodule