// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Edge Capture - RTL
// --------------------------------------------------------

module edge_capture (
  input   logic        clk,
  input   logic        reset,

  input   logic [31:0] data_i,

  output  logic [31:0] edge_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [31:0] data_q;
  logic [31:0] edge_q;
  logic [31:0] data_next;

  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      data_q[31:0] <= 32'h0;
      edge_q[31:0] <= 32'h0;
    end else begin
      data_q[31:0] <= data_i[31:0];
      edge_q[31:0] <= data_next[31:0];
    end

  assign data_next[31:0] = (~data_i[31:0] & data_q[31:0]) |
                           (edge_q[31:0]);

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign edge_o[31:0] = data_next[31:0];

endmodule