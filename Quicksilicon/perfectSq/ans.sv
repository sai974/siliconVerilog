module perfect_squares (
  input   logic        clk,
  input   logic        reset,

  output  logic [31:0] sqr_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [31:0] count_q;
  logic [31:0] nxt_count;

  logic [31:0] sqr_q;
  logic [31:0] sqr;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      count_q <= 32'h3;
    else
      count_q <= nxt_count;

  assign nxt_count = count_q + 32'h2;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      sqr_q <= 32'h1;
    else
      sqr_q <= sqr;

  assign sqr = count_q + sqr_q;

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign sqr_o = sqr;

endmodule