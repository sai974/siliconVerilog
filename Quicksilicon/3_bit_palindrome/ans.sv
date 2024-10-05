// --------------------------------------------------------
// Palindrome-3b - RTL
// --------------------------------------------------------

module palindrome3b (
  input   wire        clk,
  input   wire        reset,

  input   wire        x_i,

  output  wire        palindrome_o
);

  // --------------------------------------------------------
  // Internal wires
  // --------------------------------------------------------
  // 2-bit counter
  logic [1:0] cnt_q;
  logic [1:0] nxt_cnt;
  // 2-bit shift register
  logic [1:0] bits_seen;
  logic [1:0] nxt_bits;

  // Flops for counter and shift register
  always @(posedge clk or posedge reset)
    if (reset) begin
      cnt_q[1:0]      <= 2'h0;
      bits_seen[1:0]  <= 2'h0;
    end else begin
      cnt_q[1:0]      <= nxt_cnt[1:0];
      bits_seen[1:0]  <= nxt_bits[1:0];
    end

  // Next counter logic
  assign nxt_cnt[1:0]  = cnt_q[1] ? cnt_q[1:0] : cnt_q[1:0] + 2'b01;
  // Next shift register logic
  assign nxt_bits[1:0] = {bits_seen[0], x_i};

  // Palindrome comparator
  assign palindrome_o  = cnt_q[1] & (bits_seen[1] == x_i);

endmodule