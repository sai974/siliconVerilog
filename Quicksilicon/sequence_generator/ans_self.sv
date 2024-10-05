module seq_generator (
  input   logic        clk,
  input   logic        reset,

  output  logic [31:0] seq_o
);

  // Write your logic here...
  logic [31:0] t0, t1, t2; 
  
  always_ff @(posedge clk or posedge reset) begin 
    if (reset) begin 
      t0 <= 32'h0;
      t1 <= 32'h1;
      t2 <= 32'h1;
    end else begin
      t0 <= t1;
      t1 <= t2;
      t2 <= (t0 + t1);
    end 
  end 
      
	assign seq_o = t0;
endmodule
