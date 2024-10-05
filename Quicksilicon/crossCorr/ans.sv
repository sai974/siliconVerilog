// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Cross Correlation - RTL
// --------------------------------------------------------

module cross_correlation (
  input   logic  clk,
  input   logic  reset,

  input   logic  sig_x_i,
  input   logic  sig_y_i,

  output  logic  z_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [4:0] count;
  logic [4:0] count_q;

  always @(posedge clk or posedge reset) begin
    if (reset)
      count_q <= 5'h0;
    else
      count_q <= count;
  end

  assign count[4:0] = count_q[4:0] + {4'h0, sig_x_i} -
                                     {4'h0, sig_y_i};

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign z_o = |count_q[4:0];

endmodule