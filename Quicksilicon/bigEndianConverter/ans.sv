// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Big Endian Converter - RTL
// --------------------------------------------------------

module big_endian_converter #(
  parameter DATA_W = 32
)(
  input   logic              clk,
  input   logic              reset,

  input   logic [DATA_W-1:0] le_data_i,

  output  logic [DATA_W-1:0] be_data_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  genvar i;

  for (i=0; i<DATA_W/8; i=i+1) begin
    assign be_data_o[(DATA_W-1)-8*i-:8] = le_data_i[i*8+:8];
  end
endmodule