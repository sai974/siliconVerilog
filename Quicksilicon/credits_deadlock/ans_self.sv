module credit_n_deadlock (
  input   logic        clk,
  input   logic        reset,

  // RX side interface
  input   logic        rx_valid_i,
  input   logic [2:0]  rx_id_i,
  input   logic [4:0]  rx_payload_i,
  input   logic        rx_credit_i,
  output  logic        rx_ready_o,
  output  logic        rx_retry_o,

  // TX side interface
  output  logic        tx_valid_o,
  output  logic [2:0]  tx_id_o,
  output  logic [4:0]  tx_payload_o,
  input   logic        tx_ready_i,

  // Credit interface
  output  logic        credit_gnt_o,
  output  logic [2:0]  credit_id_o

);

  logic push_dfifo, push_rfifo, pop_rfifo, pop_dfifo;
  logic [7:0] pop_data_dfifo;
  logic [2:0] pop_data_rfifo; 
  logic empty_dfifo, empty_rfifo, full_dfifo, full_rfifo; 
  
  // Write your logic here
  qs_fifo #(.DATA_W(8), .DEPTH(4)) u_dfifo
  (.clk, 
   .reset, 
   .push_i     (push_dfifo), 
   .push_data_i({rx_id_i, rx_payload_i}), 
   .pop_i      (pop_dfifo), 
   .pop_data_o (pop_data_dfifo), 
   .empty_o    (empty_dfifo), 
   .full_o     (full_dfifo)
  ); 
  
  qs_fifo #(.DATA_W(3), .DEPTH(2)) u_rfifo
  (.clk, 
   .reset, 
   .push_i     (push_rfifo), 
   .push_data_i(rx_id_i), 
   .pop_i      (pop_rfifo), 
   .pop_data_o (pop_data_rfifo), 
   .empty_o    (empty_rfifo), 
   .full_o     (full_rfifo)
  ); 
  
  localparam logic [1:0] R_IDLE  = 2'd0; 
  localparam logic [1:0] R_CNT   = 2'd1; 
  localparam logic [1:0] R_RETRY = 2'd2; 
  
  logic [1:0] r_state, r_next_state; 
  always_ff @(posedge clk, posedge reset) begin
    if (reset) 
      r_state <= R_IDLE; 
    else begin
      r_state <= r_next_state; 
    end
  end
  
  always_comb begin
    r_next_state = r_state; 
    rx_retry_o = 1'b0; 
    push_rfifo = 1'b0; 
    
    case (r_state) 
      R_IDLE: begin
        r_next_state = (rx_valid_i && !rx_ready_o) ? R_CNT : R_IDLE; 
      end
      R_CNT: begin
        r_next_state = (rx_valid_i && !rx_ready_o) ? R_RETRY : R_IDLE; 
      end
      R_RETRY: begin
        r_next_state = R_IDLE;
        rx_retry_o = 1'b1; 
        push_rfifo = !full_rfifo; 
      end
    endcase
      
  end
  
  localparam logic C_IDLE  = 1'b0; 
  localparam logic C_GNT   = 1'b1; 
  
  logic c_state, c_next_state; 
  always_ff @(posedge clk, posedge reset) begin
    if (reset) 
      c_state <= C_IDLE; 
    else begin
      c_state <= c_next_state; 
    end
  end
  
  always_comb begin
    c_next_state = c_state; 
    credit_gnt_o = 1'b0; 
    credit_id_o  = 3'd0; 
    pop_rfifo = 1'b0; 
    case (c_state) 
      C_IDLE: begin
        c_next_state = (!full_dfifo && !empty_rfifo) ? C_GNT : C_IDLE; 
      end
      C_GNT: begin
        c_next_state = (!full_dfifo && !empty_rfifo) ? C_GNT : C_IDLE;
        credit_gnt_o = 1'b1;
        pop_rfifo = 1'b1; 
        credit_id_o = pop_data_rfifo;
      end
    endcase
      
  end
  
  localparam logic [1:0] T_IDLE = 2'd0; 
  localparam logic [1:0] T_LOAD = 2'd1; 
  localparam logic [1:0] T_WAIT = 2'd2; 
  
  logic [1:0] t_state, t_next_state; 
  always_ff @(posedge clk, posedge reset) begin
    if (reset)
      t_state <= T_IDLE; 
    else begin
      t_state <= t_next_state; 
    end
  end
  
  logic t_load; 
  logic [4:0] t_load_data; 
  logic [2:0] t_load_id; 
  
  always_comb begin
    t_next_state = t_state; 
    t_load = 1'b0; 
    t_load_data = 5'd0; 
    t_load_id = 3'd0; 
    pop_dfifo = 1'b0;
    push_dfifo = 1'b0; 
    case (t_state)
      T_IDLE: begin
        t_next_state = (rx_valid_i) ?  T_WAIT : T_IDLE; 
        t_load = 1'b1; 
        {t_load_id, t_load_data} = {rx_id_i, rx_payload_i}; 
        t_load_id = rx_id_i;
        push_dfifo = 1'b0; 
      end
      T_WAIT: begin
        if (!tx_ready_i) begin
          t_next_state = T_WAIT; 
          push_dfifo = rx_valid_i && !full_dfifo; 
        end 
        else if (!empty_dfifo) begin
          t_next_state = T_WAIT; 
          t_load = 1'b1; 
          {t_load_id, t_load_data} = pop_data_dfifo; 
          pop_dfifo = 1'b1; 
          push_dfifo = rx_valid_i && !full_dfifo; 
        end 
        else if (rx_valid_i) begin
          t_next_state = T_WAIT; 
          t_load = 1'b1; 
          t_load_data = rx_payload_i;
          t_load_id = rx_id_i; 
          push_dfifo = 1'b0;  
        end 
        else begin
          t_next_state = T_IDLE;
          t_load = 1'b1; 
          push_dfifo = 1'b0; 
        end 
      end
    endcase 
  end
    
  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      tx_id_o <= 3'b0; 
      tx_payload_o <= 5'b0;
    end 
    else begin
      tx_id_o <= (t_load) ? (t_load_id) : tx_id_o; 
      tx_payload_o <= (t_load) ? (t_load_data) : tx_payload_o;
    end 
  end
  assign tx_valid_o = (t_state != T_IDLE);
	assign rx_ready_o = !full_dfifo; 

  
  
  
  
  

endmodule
