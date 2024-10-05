module skid_buffer (
  input   logic        clk,
  input   logic        reset,

  input   logic        i_valid_i,
  input   logic [7:0]  i_data_i,
  output  logic        i_ready_o,

  input   logic        e_ready_i,
  output  logic        e_valid_o,
  output  logic [7:0]  e_data_o
);

  localparam bit WAIT = 1'b1; 
  localparam bit READY = 1'b0; 
  
  logic state, nxt_state; 
  logic [7:0] data_q, data_d;
  
  always_ff @(posedge clk) begin 
    if (reset) begin
      state <= READY; 
      data_q <= '0; 
    end else begin 
      state <= nxt_state; 
      data_q <= data_d; 
    end 
  end
  
  always_comb begin 
    nxt_state = state; 
    data_d = data_q; 
    e_valid_o = 1'b0;
    e_data_o = '0;
    case (state)
      READY: begin 
        nxt_state = (i_valid_i && !e_ready_i) ? WAIT : READY; 
        data_d = (i_valid_i && !e_ready_i) ? i_data_i : data_q; 
        e_valid_o = i_valid_i; 
        e_data_o = i_data_i; 
      end 
      WAIT: begin
        nxt_state = (e_ready_i) ? READY : WAIT;
        e_valid_o = 1'b1;
        e_data_o = data_q; 
      end 
    endcase
  end 
  
  assign i_ready_o = (state == READY); 
  
  
  
  
    
endmodule
