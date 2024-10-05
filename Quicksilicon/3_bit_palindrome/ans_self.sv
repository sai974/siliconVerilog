module palindrome3b (
  input   logic        clk,
  input   logic        reset,

  input   logic        x_i,

  output  logic        palindrome_o
);

  // Write your logic here...
  logic [1:0] state_q; 
  logic [1:0] cycle;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin 
      state_q <= 2'b0;
      cycle <= 2'b0;
    end
    else begin
      state_q <= {state_q[0], x_i};
      cycle <= (cycle == 2'b10) ? cycle : cycle + 1'b1;
    end
  end
  
  assign palindrome_o = (state_q[1] == x_i) && (cycle == 2'b10);
  
endmodule
