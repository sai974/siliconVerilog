// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Skid Buffer - RTL
// --------------------------------------------------------

module skid_buffer (
  input   logic        clk,
  input   logic        reset,

  input   logic        i_valid_i,
  input   logic [7:0]  i_data_i,
  output  logic        i_ready_o,

  input   logic        e_ready_i,
  output  logic        e_valid_o,
  output  logic [7:0]  e_data_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic       buf_valid_q;
  logic [7:0] buf_data_q;

  logic       buf_valid;
  logic       buf_valid_en;

  logic       i_ready;

  logic       e_valid;
  logic [7:0] e_data;

  // Skid Buffer:
  // Should behave as a pass-through if e_ready_i is HIGH else,
  // buffer the input data
  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      buf_valid_q <= 1'b0;
      buf_data_q  <= 8'h0;
    end else if (buf_valid_en) begin
      buf_valid_q <= buf_valid;
      buf_data_q  <= i_data_i;
    end

  // Buffer data whenever all of these hold:
  //    - both valid and ready are HIGH on the input
  //    - valid high but ready low on the output
  assign buf_valid = ((i_valid_i & i_ready) & (e_valid & !e_ready_i));
  assign buf_valid_en = buf_valid | e_ready_i;

  assign i_ready = ~buf_valid_q;

  assign e_valid = buf_valid_q | i_valid_i;
  assign e_data  = buf_valid_q ? buf_data_q : i_data_i;

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign i_ready_o = i_ready;

  assign e_valid_o = e_valid;
  assign e_data_o  = e_data;

endmodule