// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Parallel to Serial - RTL
// --------------------------------------------------------

module parallel_to_serial #(
  parameter DATA_W = 16
) (
  input   wire              clk,
  input   wire              reset,

  input   wire              p_valid_i,
  input   wire [DATA_W-1:0] p_data_i,
  output  wire              p_ready_o,

  output  wire              s_valid_o,
  output  wire              s_data_o,
  input   wire              s_ready_i
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  typedef enum {ST_RX, ST_TX} state_t;
  localparam CNT_W = $clog2(DATA_W);
  localparam CNT_MAX = DATA_W-1;

if (DATA_W>1) begin
  logic [CNT_W-1:0]  count_q;
  logic [CNT_W-1:0]  nxt_count;
  logic [DATA_W-1:0] shift_reg_q;
  logic [DATA_W-1:0] nxt_shift_reg;

  state_t            state_q;
  state_t            nxt_state;

  always @(posedge clk or posedge reset)
    if (reset) begin
      state_q     <= ST_RX;
      shift_reg_q <= {DATA_W{1'b0}};
      count_q     <= {CNT_W{1'b0}};
    end else begin
      state_q     <= nxt_state;
      shift_reg_q <= nxt_shift_reg;
      count_q     <= nxt_count;
    end

  always_comb begin
    nxt_shift_reg = shift_reg_q;
    nxt_state = state_q;
    nxt_count = count_q;
    case (state_q)
      ST_RX: begin
               if (p_valid_i) begin
                 nxt_shift_reg = p_data_i;
                 nxt_state = ST_TX;
               end
             end
      ST_TX: begin
               if ((count_q[CNT_W-1:0] == CNT_MAX[CNT_W-1:0]) & s_ready_i) begin
                 nxt_state = ST_RX;
                 nxt_count = {CNT_W{1'b0}};
               end else if (s_ready_i) begin
                 nxt_count     = count_q + CNT_W'(1'h1);
                 nxt_shift_reg = {1'b0, shift_reg_q[DATA_W-1:1]};
               end
             end
    endcase
  end

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign s_valid_o = (state_q == ST_TX);
  assign s_data_o  = (shift_reg_q[0]);
  assign p_ready_o = (state_q == ST_RX);

end else begin

  logic p_data_q;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      p_data_q <= 1'b0;
    else if(p_valid_i)
      p_data_q <= p_data_i;

  assign s_valid_o = p_valid_i;
  assign s_data_o  = p_valid_i ? p_data_i : p_data_q;
  assign p_ready_o = s_ready_i;
end


endmodule