// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// One Shot - RTL
// --------------------------------------------------------

module one_shot (
  input   logic        clk,
  input   logic        reset,

  input   logic        data_i,

  output  logic        shot_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic data_q;

  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      data_q <= 1'b0;
    end else begin
      data_q <= data_i;
    end

  assign shot_o = data_i & ~data_q;

endmodule