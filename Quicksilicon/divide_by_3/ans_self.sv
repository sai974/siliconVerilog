module div_by_three (
  input   logic    clk,
  input   logic    reset,

  input   logic    x_i,

  output  logic    div_o

);

localparam REM0 = 2'h0;
localparam REM1 = 2'h1;
localparam REM2 = 2'h2;
  
  logic [1:0] state_q, state_d;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin 
      state_q <= REM0;
    end else begin
      state_q <= state_d;
    end
  end
  
  always_comb begin
    case (state_q)
      REM0: begin
        state_d = x_i ? REM1 : REM0;
      end
      REM1: begin
        state_d = x_i ? REM0 : REM2;
      end
      REM2: begin
        state_d = x_i ? REM2 : REM1;
      end
    endcase
  end
  
  assign div_o = state_d == REM0;
 

endmodule
