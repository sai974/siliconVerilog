// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Running Average - RTL
// --------------------------------------------------------

module running_average #(
  parameter N = 4
)(
  input   logic        clk,
  input   logic        reset,

  input   logic [31:0] data_i,

  output  logic [31:0] average_o 

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  localparam NLOG2        = $clog2(N);
  localparam NLOG2_PLUS1  = NLOG2 + 1;

  logic [31:0]        data_stack_q [N-1:0];
  logic [NLOG2-1:0]   stack_ptr_q;
  logic [NLOG2-1:0]   nxt_stack_ptr;

  logic [31:0]        accumulator_q;
  logic [31:0]        accumulator;
  logic [31:0]        stack_pop_data;

  // Mention that a shift register would consume more flops
  // hence implementing a counter would be helpful??
  logic [NLOG2:0] count_q;
  logic [NLOG2:0] nxt_count;
  logic           count_max;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      count_q <= NLOG2_PLUS1'(1'b0);
    else
      count_q <= nxt_count;

  assign count_max = (count_q == NLOG2_PLUS1'(N));
  assign nxt_count = count_max ? count_q : count_q + NLOG2_PLUS1'(1'b1);

  always_ff @(posedge clk or posedge reset)
    if (reset)
      accumulator_q <= 32'h0;
    else
      accumulator_q <= accumulator;

  assign accumulator = (accumulator_q + data_i) - stack_pop_data;

  // Stack
  always_ff @(posedge clk)
    data_stack_q[stack_ptr_q] <= data_i;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      stack_ptr_q <= NLOG2'(1'b0);
    else
      stack_ptr_q <= nxt_stack_ptr;

  assign nxt_stack_ptr = stack_ptr_q + NLOG2'(1'b1);

  assign stack_pop_data = {32{count_max}} & data_stack_q[stack_ptr_q];

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign average_o = (accumulator>>NLOG2);

endmodule