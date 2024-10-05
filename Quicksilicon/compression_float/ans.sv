// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Compression Engine - RTL
// --------------------------------------------------------

module compression_engine (
  input   logic        clk,
  input   logic        reset,

  input   logic [23:0] num_i,

  output  logic [11:0] mantissa_o,
  output  logic [3:0]  exponent_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [23:12] exp_oh;
  logic [3:0]   exp_bin;
  logic [3:0]   exponent;

  logic [11:0]  mantissa;
  assign exp_oh[23] = num_i[23];
  // Exponent
  for (genvar i=22; i>=12; i=i-1) begin
    assign exp_oh[i] = num_i[i] & ~|exp_oh[23:i+1];
  end

  qs_1hot_bin #(.ONE_HOT_W(12), .BIN_W(4)) exp_oh_bin (
    .clk        (clk),
    .reset      (reset),
    .oh_vec_i   (exp_oh),
    .bin_vec_o  (exp_bin)
  );

  assign exponent = (|exp_oh) ? exp_bin + 4'h1 : exp_bin;

  // Mantissa
  assign mantissa = (|exp_oh) ? num_i[exponent+11-1-:12] :
                                num_i[11:0];
  
  // -------------------------------------------------------
  // Output assignments
  // -------------------------------------------------------
  assign exponent_o = exponent;
  assign mantissa_o = mantissa;

endmodule