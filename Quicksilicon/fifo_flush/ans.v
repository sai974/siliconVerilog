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

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  reg   [31:0]  fifo_data_q [3:0];
  wire  [3:0]   nxt_fifo_data;
  wire  [7:0]   fifo_wr_en;

  reg   [2:0]   wr_row_ptr_q;
  wire  [2:0]   nxt_wr_row_ptr;

  reg   [2:0]   wr_col_ptr_q;
  wire  [2:0]   nxt_wr_col_ptr;

  reg   [2:0]   rd_row_ptr_q;
  wire  [2:0]   nxt_rd_row_ptr;

  reg   [2:0]   wr_flush_row_ptr_q;
  wire  [2:0]   nxt_wr_flush_row_ptr;

  wire          wr_ptr_en;

  reg   [2:0]   wr_flush_col_ptr_q;
  wire  [2:0]   nxt_wr_flush_col_ptr;
  wire          wr_flush_ptr_en;
  wire          flush_entire_row;

  wire          nxt_fifo_flush;
  reg           fifo_flush_q;
  wire          fifo_flush_done;

  wire          fifo_data_avail;
  reg   [2:0]   fifo_data_cntr_q;
  wire  [2:0]   nxt_fifo_data_cntr;
  wire          incr_cntr;
  wire          decr_cntr;
  wire  [31:0]  fifo_rd_data;

  wire          fifo_full;
  wire          fifo_empty;
  genvar        i;

  // --------------------------------------------------------
  // Pointer management
  // --------------------------------------------------------
  assign nxt_rd_row_ptr = fifo_rd_valid_i ? rd_row_ptr_q + 3'h1 : rd_row_ptr_q;

  always @(posedge clk or posedge reset)
    if (reset) begin
      rd_row_ptr_q <= 3'h0;
    end else if(fifo_rd_valid_i) begin
      rd_row_ptr_q <= nxt_rd_row_ptr;
    end 

  assign flush_entire_row = wr_flush_ptr_en & (|wr_col_ptr_q | fifo_wr_valid_i);

  assign nxt_wr_col_ptr = flush_entire_row ? 3'h0 :
                          fifo_wr_valid_i  ? wr_col_ptr_q + 3'h1 :
                                             wr_col_ptr_q;

  assign nxt_wr_row_ptr = (fifo_wr_valid_i & (&wr_col_ptr_q)) |
                          (flush_entire_row)                  ? wr_row_ptr_q + 3'h1 :
                                                                wr_row_ptr_q;

  assign wr_ptr_en = wr_flush_ptr_en | fifo_wr_valid_i;

  always @(posedge clk or posedge reset)
    if (reset) begin
      wr_row_ptr_q <= 3'h0;
      wr_col_ptr_q <= 3'h0;
    end else if(wr_ptr_en) begin
      wr_row_ptr_q <= nxt_wr_row_ptr;
      wr_col_ptr_q <= nxt_wr_col_ptr;
    end

  // --------------------------------------------------------
  // Fifo write data
  // --------------------------------------------------------
  assign nxt_fifo_data = fifo_wr_data_i;

  for (i=0; i<8; i=i+1) begin
    assign fifo_wr_en[i] = fifo_wr_valid_i & (wr_col_ptr_q[2:0] == i);
  end

  for (i=0; i<8; i=i+1) begin
    always @(posedge clk)
      if (fifo_wr_en[i]) begin
        fifo_data_q[wr_row_ptr_q[1:0]][i*4+:4] <= nxt_fifo_data[3:0];
      end
  end

  // --------------------------------------------------------
  // Fifo flush pointers
  // --------------------------------------------------------
  assign nxt_wr_flush_row_ptr = (flush_entire_row) ? wr_row_ptr_q :
                                                     wr_row_ptr_q - 3'h1;
  assign nxt_wr_flush_col_ptr = (fifo_wr_valid_i & (~&wr_col_ptr_q)) ? wr_col_ptr_q + 3'h1 :
                                (flush_entire_row)                   ? wr_col_ptr_q        :
                                                                       3'h7;
  assign nxt_fifo_flush = fifo_flush_i & ~fifo_flush_done;

  always @(posedge clk or posedge reset)
    if (reset)
      fifo_flush_q <= 1'b0;
    else
      fifo_flush_q <= nxt_fifo_flush;

  assign wr_flush_ptr_en = fifo_flush_i & ~fifo_flush_q;

  always @(posedge clk or posedge reset)
    if (reset) begin
      wr_flush_row_ptr_q <= 3'h0;
      wr_flush_col_ptr_q <= 3'h0;
    end else if (wr_flush_ptr_en) begin
      wr_flush_row_ptr_q <= nxt_wr_flush_row_ptr;
      wr_flush_col_ptr_q <= nxt_wr_flush_col_ptr;
    end

  assign fifo_flush_done = (fifo_flush_q) & (fifo_rd_valid_i) &
                           (rd_row_ptr_q[2:0] == wr_flush_row_ptr_q[2:0]);

  // --------------------------------------------------------
  // Fifo empty and full flags
  // --------------------------------------------------------
  assign fifo_empty = (rd_row_ptr_q[2:0] == wr_row_ptr_q[2:0]) &
                      (~|wr_col_ptr_q[2:0]);

  assign fifo_full  = (rd_row_ptr_q[1:0] == wr_row_ptr_q[1:0]) &
                      (rd_row_ptr_q[2]   != wr_row_ptr_q[2])   &
                      (                   ~|wr_col_ptr_q[2:0]);

  // --------------------------------------------------------
  // Fifo data available and fifo read
  // --------------------------------------------------------
  always @(posedge clk or posedge reset)
    if (reset)
      fifo_data_cntr_q <= 3'h0;
    else
      fifo_data_cntr_q <= nxt_fifo_data_cntr;

  assign nxt_fifo_data_cntr  = (incr_cntr & decr_cntr) ? fifo_data_cntr_q :
                               (incr_cntr            ) ? fifo_data_cntr_q + 3'h1 :
                               (decr_cntr            ) ? fifo_data_cntr_q - 3'h1 :
                                                         fifo_data_cntr_q;

  assign incr_cntr = ((&wr_col_ptr_q) & fifo_wr_valid_i);
  assign decr_cntr = ((|fifo_data_cntr_q) & fifo_rd_valid_i);
                                
  assign fifo_data_avail = |fifo_data_cntr_q |
                           (fifo_flush_q & (~fifo_empty | ~fifo_flush_done));

  for (i=0; i<8; i=i+1) begin
    assign fifo_rd_data[i*4+:4] = fifo_flush_q ?
                                        ((rd_row_ptr_q[2:0] == wr_flush_row_ptr_q[2:0]) &
                                         (wr_flush_col_ptr_q <= i)                      &
                                        ~(&wr_flush_col_ptr_q)) ?
                                          4'hC                                   :
                                          fifo_data_q[rd_row_ptr_q[1:0]][i*4+:4] :
                                    fifo_data_q[rd_row_ptr_q[1:0]][i*4+:4];
  end



  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign fifo_data_avail_o = fifo_data_avail;
  assign fifo_rd_data_o    = fifo_rd_data;
  assign fifo_flush_done_o = fifo_flush_done;
  assign fifo_full_o       = fifo_full;
  assign fifo_empty_o      = fifo_empty;

endmodule