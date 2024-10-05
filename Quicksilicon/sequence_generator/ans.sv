// --------------------------------------------------------
// Sequence Generator - RTL
// --------------------------------------------------------

module seq_generator (
  input   wire        clk,
  input   wire        reset,

  output  wire [31:0] seq_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [31:0] seq_t0;
  logic [31:0] seq_t1;
  logic [31:0] seq_t2;

  logic [31:0] seq_nxt;

  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      seq_t0 <= 32'h1;
      seq_t1 <= 32'h1;
      seq_t2 <= 32'h0;
    end else begin
      seq_t0 <= seq_nxt[31:0];
      seq_t1 <= seq_t0[31:0];
      seq_t2 <= seq_t1[31:0];
    end

  assign seq_nxt[31:0] = {seq_t1[31:0]} + {seq_t2[31:0]};

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign seq_o[31:0] = seq_t2[31:0];

endmodule