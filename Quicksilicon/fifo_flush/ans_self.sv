module fifo_flush (
  input   logic         clk,
  input   logic         reset,

  input   logic         fifo_wr_valid_i,
  input   logic [3:0]   fifo_wr_data_i,

  output  logic         fifo_data_avail_o,
  input   logic         fifo_rd_valid_i,
  output  logic [31:0]  fifo_rd_data_o,

  input   logic         fifo_flush_i,
  output  logic         fifo_flush_done_o,

  output  logic         fifo_empty_o,
  output  logic         fifo_full_o
);

  // Write your logic here...
  logic  [3:0]  fifo [31:0];
  logic  [5:0]  wr_cntr, next_wr_cntr, wr_cntr_flush, wr_cntr_ref, wr_cntr_flush_ref;
  logic  [5:0]  rd_cntr, next_rd_cntr;
  logic         fifo_flush_prev; 
  logic         fifo_flush_start, fifo_flush_start_delay;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fifo_flush_prev <= '0; 
      fifo_flush_start_delay <= '0;
    end else begin
    	fifo_flush_prev <= fifo_flush_i; 
      fifo_flush_start_delay <= fifo_flush_start;
    end 
  end
          // this one need to move up to cause error 
  assign wr_cntr_flush_ref = (fifo_flush_start) ? wr_cntr_ref : wr_cntr_flush; 
  
  assign fifo_flush_start = fifo_flush_i && !fifo_flush_prev;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      wr_cntr <= '0; 
    	rd_cntr <= '0;
      wr_cntr_flush <= '0;
    end else begin
      wr_cntr <= next_wr_cntr; 
      rd_cntr <= next_rd_cntr;
      wr_cntr_flush <= wr_cntr_ref;
  	end
  end
  

  
  always_comb begin
    next_wr_cntr = wr_cntr; 
    next_rd_cntr = rd_cntr; 
    wr_cntr_ref = wr_cntr_flush; 
    
    if (fifo_flush_start) begin
      if (fifo_wr_valid_i) begin
        next_wr_cntr = (wr_cntr[2:0] == 3'd7) ? (wr_cntr + 1'b1) : {wr_cntr[5:3] + 1'b1, 3'b0};
        wr_cntr_ref  = wr_cntr;
      end
      else begin
        next_wr_cntr = (wr_cntr[2:0] == 3'd0) ? wr_cntr : {wr_cntr[5:3] + 1'b1, 3'b0};
        wr_cntr_ref = wr_cntr - 1'b1; 
      end
    end else if (fifo_wr_valid_i) begin
      next_wr_cntr = wr_cntr + 1'b1; 
    end
    
    if (fifo_rd_valid_i) begin
      next_rd_cntr = {rd_cntr[5:3] + 1'b1, 3'b0}; // if read valid move to next 32 bit
  	end
  end


  
  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      for (int i = 0; i < 32; i = i + 1) begin
        fifo[i[4:0]] <= 4'b0;
      end
    end else begin
      if (fifo_wr_valid_i) begin
        fifo[wr_cntr[4:0]] <= fifo_wr_data_i; 
      end
    end
      

  
  assign fifo_data_avail_o = !fifo_empty_o; //(wr_cntr[5:3] != rd_cntr[5:3]);
  assign fifo_empty_o = (wr_cntr[5:0] == rd_cntr[5:0]);
  assign fifo_full_o = (wr_cntr[4:3] == rd_cntr[4:3]) && (wr_cntr[5] != rd_cntr[5]);
  assign fifo_flush_done_o = fifo_flush_i && (rd_cntr[5:3] == wr_cntr_ref[5:3]);
   

  
  always_comb begin
    fifo_rd_data_o = {8{4'hC}};
    if (fifo_flush_i) begin
      
      if (rd_cntr[5:3] == wr_cntr_flush_ref[5:3]) begin
      	for (int i = 0; i <= 7; i=i+1) begin
          if (i <= wr_cntr_flush[2:0]) begin
            fifo_rd_data_o[i*4+:4] = fifo[{rd_cntr[4:3], i[2:0]}];
          end
        end
      end else begin
      	for (int i = 0; i <= 7; i=i+1) begin
          fifo_rd_data_o[i*4+:4] = fifo[{rd_cntr[4:3], i[2:0]}];
        end
      end
      
    end else begin
      for (int i = 0; i <= 7; i=i+1'b1) begin
        fifo_rd_data_o[i*4+:4] = fifo[{rd_cntr[4:3], i[2:0]}];
      end
    end
  end
  

  
endmodule
