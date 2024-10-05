module single_cycle_arbiter #(
  parameter N = 32
) (
  input   logic          clk,
  input   logic          reset,
  input   logic [N-1:0]  req_i,
  output  logic [N-1:0]  gnt_o
);

  // Write your logic here...
  always_comb begin 
    gnt_o = (req_i & (~req_i + 1'b1));
  end 
      
endmodule

