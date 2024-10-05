// --------------------------------------------------------
// LRU - RTL
// --------------------------------------------------------

module lru #(
  parameter NUM_WAYS = 4
)(
  input                            clk,
  input                            reset,

  input                            ls_valid_i,
  input    [1:0]                   ls_op_i,
  input    [$clog2(NUM_WAYS)-1:0]  ls_way_i,

  output                           lru_valid_o,
  output   [NUM_WAYS-1:0]          lru_way_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  localparam WAYS_LOG2 = $clog2(NUM_WAYS);

  // Local Parameters for possible LS-operations

  localparam OP_LOAD       = 2'b01;
  localparam OP_STORE      = 2'b10;
  localparam OP_INVALIDATE = 2'b11;



  wire                ls_rd_valid;
  wire                ls_wr_valid;

  wire                ls_inv_valid;
  wire [NUM_WAYS-1:0] ls_way_inv;

  wire [NUM_WAYS-1:0] ls_way_oldest;
  wire [NUM_WAYS-1:0] ls_way_sel;
  wire [NUM_WAYS-1:0] ls_way_read;

  reg  [NUM_WAYS-1:0] way_avail_q;
  wire [NUM_WAYS-1:0] nxt_way_avail;
  wire [NUM_WAYS-1:0] way_valid;

  wire [NUM_WAYS-1:0] ls_way_active;

  // --------------------------------------------------------
  // Read operation
  // --------------------------------------------------------
  assign ls_rd_valid = ls_valid_i & (ls_op_i == OP_LOAD);


  // --------------------------------------------------------
  // Calculate the cache way being read
  // --------------------------------------------------------
  for (genvar w=0; w<NUM_WAYS; w=w+1) begin : g_way_read
    assign ls_way_read[w] = ls_rd_valid & (ls_way_i == w[WAYS_LOG2-1:0]);
  end

  // --------------------------------------------------------
  // Write operation
  // --------------------------------------------------------
  assign ls_wr_valid = ls_valid_i & (ls_op_i == OP_STORE);

  // --------------------------------------------------------
  // Invalidate operation
  // --------------------------------------------------------
  assign ls_inv_valid = ls_valid_i & (ls_op_i == OP_INVALIDATE);

  for (genvar w=0; w<NUM_WAYS; w=w+1) begin : g_way_invalidation
    assign ls_way_inv[w] = ls_inv_valid & (ls_way_i == w[WAYS_LOG2-1:0]);
  end

  // --------------------------------------------------------
  // Way available
  // --------------------------------------------------------

  always @(posedge clk or posedge reset)
    if (reset)
      way_avail_q <= {NUM_WAYS{1'b1}};
    else
      way_avail_q <= nxt_way_avail;

  assign nxt_way_avail = (way_avail_q & ~ls_way_sel) | ls_way_inv;
  assign way_valid     = ~way_avail_q;

  // --------------------------------------------------------
  // Next available way for writes
  // --------------------------------------------------------
  assign ls_way_oldest[0] = ~|(track_older[0] & way_valid);
  assign ls_way_sel[0]    = ls_wr_valid & 
                           (way_avail_q[0] |
                           (~|way_avail_q & ls_way_oldest[0]));

  for (genvar w=1; w<NUM_WAYS; w=w+1) begin : g_first_avail_way
    assign ls_way_oldest[w] = ~|(track_older[w] & way_valid);
    assign ls_way_sel[w]    = ls_wr_valid       &
                            ~|ls_way_sel[w-1:0] &
                             (way_avail_q[w]    |
                             (~|way_avail_q & ls_way_oldest[w]));
  end
  
  // --------------------------------------------------------
  // Way active signal
  // Active on reads and writes to the selected way
  // On invalidation the avail signal would be asserted marking
  // entry as available.
  // --------------------------------------------------------

  assign ls_way_active = ls_way_read | ls_way_sel;

  // --------------------------------------------------------
  // Order tracking structure
  // --------------------------------------------------------
  wire [NUM_WAYS-1:0][NUM_WAYS-1:0] track_older ;

  for (genvar i=0; i<NUM_WAYS; i=i+1) begin : g_per_row
    for (genvar j=0; j<NUM_WAYS; j=j+1) begin : g_per_col
      if (i==j)
        assign track_older[i][j] = 1'b0;
      else if (i<j)
        assign track_older[i][j] = ~track_older[j][i];
      else begin
        reg   old_entry_q;
        wire  nxt_old_entry;

        // Set the row if ordered, clear the column
        assign nxt_old_entry = (ls_way_active[i] | track_older[i][j]) &
                               ~ls_way_active[j];

        always @(posedge clk) begin
          if (|ls_way_active)
            old_entry_q <= nxt_old_entry;
        end

        assign track_older[i][j] = old_entry_q;
      end
    end
  end

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign lru_valid_o = |ls_wr_valid;
  assign lru_way_o   = ls_way_sel;

endmodule