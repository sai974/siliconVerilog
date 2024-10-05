module buffering (
  input   logic        clk,
  input   logic        reset,

  // Incoming AXI Stream interface
  input   logic        req_tvalid_i,
  input   logic [2:0]  req_tid_i,
  input   logic [15:0] req_tdata_i,
  output  logic        req_tready_o,

  // Outgoing valid-ready interface
  output  logic        dev_valid_o,
  output  logic [18:0] dev_addr_o,
  output  logic [15:0] dev_data_o,
  input   logic        dev_ready_i,

  // Device status interface
  input   logic        dev_opmode_i
);

  localparam bit [2:0] WAIT=3'd0; 
  localparam bit [2:0] DATA_NBUF=3'd1; 
  localparam bit [2:0] DATA_BUF=3'd2; 
  localparam bit [2:0] DEV_5=3'd3; 
  
  logic [2:0] state, next_state;
  logic push, pop, empty, full; 
  logic [15:0] push_data, pop_data, push_addr, pop_addr;
  logic [18:0] dev_addr_q, dev_addr_d;
  logic [15:0] dev_data_q, dev_data_d; 
  logic first_clk; 
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= WAIT;
      first_clk <= 1'b0; 
    end else begin
      state <= next_state;
      first_clk <= (state != next_state); // to indicate the firts time we ar ein the state
    end
  end

  always_comb begin
    next_state = state; 
    req_tready_o =1'b0; 
    case (state) 
      WAIT: begin
        next_state = (!empty && dev_opmode_i) ? DEV_5 : 
        (!req_tvalid_i) ? WAIT : 
        (req_tid_i != 3'd5) ? DATA_NBUF : DATA_BUF ;
        
        req_tready_o = (full) ? (1'b0) : 
        (empty) ? 1'b1 : (!dev_opmode_i); 
      end 
      DATA_NBUF: begin
        next_state = (dev_ready_i) ? WAIT : DATA_NBUF;
        req_tready_o = first_clk; 
      end 
      DATA_BUF: begin
        next_state = WAIT; 
        req_tready_o = 1'b1; 
      end 
      DEV_5: begin
        next_state = (dev_ready_i) ? WAIT : DEV_5; 
        req_tready_o = 1'b0; 
      end 
    endcase 
  end 
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      dev_addr_q <= '0; 
      dev_data_q <= '0; 
    end 
    else begin
      dev_addr_q <= dev_addr_d; 
      dev_data_q <= dev_data_d; 
    end 
  end 
  
  always_comb begin
    dev_addr_d = dev_addr_q; 
    dev_data_d = dev_data_q; 
    case (state)
      WAIT: begin
        dev_addr_d = (req_tvalid_i) ? {req_tdata_i, req_tid_i} : dev_addr_q; 
      end 
      DATA_NBUF: begin
        dev_data_d = (req_tvalid_i && first_clk) ? req_tdata_i : dev_data_q; 
      end
      DATA_BUF: begin
        dev_data_d = (req_tvalid_i && first_clk) ? req_tdata_i : dev_data_q; 
      end
      DEV_5: begin
        dev_addr_d = first_clk ? {pop_addr, 3'd5} : dev_addr_q; 
        dev_data_d = first_clk ? pop_data : dev_data_q;
      end 
    endcase
  end
  
  always_comb begin
    push = 1'b0; 
    pop = 1'b0; 
    push_data = 16'b0; 
    push_addr = 16'b0;
    
    case (state) 
      DATA_BUF: begin
        push = 1'b1; 
        push_data = dev_data_d; 
        push_addr = dev_addr_q[18:3]; 
      end 
      DEV_5: begin
        pop = first_clk;
      end
    endcase 
    
  end
  
  always_comb begin
    dev_valid_o = 1'b0; 
    dev_addr_o = 19'b0; 
    dev_data_o = 16'b0; 
    
    case (state) 
      DATA_NBUF: begin
        dev_valid_o = 1'b1; 
        dev_addr_o = dev_addr_q; 
        dev_data_o = dev_data_d; 
      end 
      DEV_5: begin
        dev_valid_o = 1'b1; 
        dev_addr_o = dev_addr_d;
        dev_data_o = dev_data_d; 
      end
    endcase
  end 

  
  qs_fifo #(.DATA_W(16), .DEPTH(8)) u_data_fifo 
  ( .clk,
    .reset,
   .push_i(push),
   .push_data_i(push_data),
   .pop_i(pop),
   .pop_data_o(pop_data),
   .empty_o(empty),
   .full_o(full)
  );
  
  logic empty_dummy, full_dummy; 
  
  qs_fifo #(.DATA_W(16), .DEPTH(8)) u_addr_fifo 
  ( .clk,
    .reset,
   .push_i(push),
   .push_data_i(push_addr),
   .pop_i(pop),
   .pop_data_o(pop_addr),
   .empty_o(empty_dummy),
   .full_o(full_dummy)
  );
  
  
endmodule
