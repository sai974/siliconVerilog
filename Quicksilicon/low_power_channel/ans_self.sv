module low_power_channel (
  input   logic          clk,
  input   logic          reset,

  // Wakeup interface
  input   logic          if_wakeup_i,

  // Write interface
  input   logic          wr_valid_i,
  input   logic [7:0]    wr_payload_i,

  // Upstream flush interface
  output  logic          wr_flush_o,
  input   logic          wr_done_i,

  // Read interface
  input   logic          rd_valid_i,
  output  logic [7:0]    rd_payload_o,

  // Q-channel interface
  input   logic          qreqn_i,
  output  logic          qacceptn_o,
  output  logic          qactive_o

);

  // Write your logic here
  localparam bit [2:0] LOW_POWER = 3'd0; 
  localparam bit [2:0] NORMAL    = 3'd1; 
  localparam bit [2:0] REQ_FLUSH = 3'd2; 
  localparam bit [2:0] WAIT_EMPTY = 3'd3; 
  
  logic [2:0] state, next_state;
  logic fifo_wr_active, fifo_rd_active;
  logic empty; 
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) 
      state <= NORMAL; 
    else 
      state <= next_state; 
  end
  
  always_comb begin 
    next_state = state; 
    qactive_o = 1'b1; 
    qacceptn_o = 1'b1; 
  	fifo_wr_active = 1'b0; 
    fifo_rd_active = 1'b0; 
    wr_flush_o = 1'b0; 
    
    case (state)
      LOW_POWER: begin
        next_state = (qreqn_i && if_wakeup_i) ? NORMAL : LOW_POWER;
        qactive_o = if_wakeup_i;
        qacceptn_o = if_wakeup_i; 
      end 
      NORMAL: begin
        next_state = (!qreqn_i) ? REQ_FLUSH : NORMAL; 
        qactive_o = !empty;
        fifo_wr_active = 1'b1; 
        fifo_rd_active = 1'b1; 
      end 
      REQ_FLUSH: begin
        next_state = (wr_done_i) ? WAIT_EMPTY : REQ_FLUSH; 
				wr_flush_o = 1'b1; 
        qactive_o = !empty; 
        fifo_wr_active = 1'b1;
        fifo_rd_active = 1'b1; 
      end
      WAIT_EMPTY: begin
        next_state = (empty) ? LOW_POWER : WAIT_EMPTY;
        qactive_o = !empty; 
        fifo_rd_active = 1'b1;
      end
    endcase
  
  end
  
  qs_fifo #(.DATA_W(8),
            .DEPTH(6))
   u_fifo  (
 		.clk,
		.reset,

    .push_i(fifo_wr_active && wr_valid_i),
    .push_data_i(wr_payload_i),

    .pop_i(fifo_rd_active &&  rd_valid_i),
    .pop_data_o(rd_payload_o),

    .empty_o(empty),
    .full_o()
	);
  
  
  
  
  

endmodule
