// --------------------------------------------------------
// Divide By Three - RTL
// --------------------------------------------------------

module div_by_three (
  input   logic    clk,
  input   logic    reset,

  input   logic    x_i,

  output  logic    div_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  typedef enum logic[1:0] {REM_0, REM_1, REM_2} state_t;

  state_t state_q;
  state_t state;

  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      state_q <= REM_0;
    end else begin
      state_q <= state;
    end

  always_comb begin
    div_o = 1'b0;
    case (state_q)
      REM_0:
      begin
        if (x_i) begin
          state = REM_1;
        end else begin
          state = REM_0;
          div_o = 1'b1;
        end
      end
      REM_1:
      begin
        if (x_i) begin
          state = REM_0;
          div_o = 1'b1;
        end
        else begin
          state = REM_2;
        end
      end
      REM_2:
      begin
        if (x_i) begin
          state = REM_2;
        end
        else begin
          state = REM_1;
        end
      end
      default: begin
        state = REM_0;
      end
    endcase
  end

endmodule