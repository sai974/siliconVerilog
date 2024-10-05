// --------------------------------------------------------
// LRU - RTL
// --------------------------------------------------------

module lru #(
  parameter NUM_WAYS = 4
)(
  input   logic                         clk,
  input   logic                         reset,

  input   logic                         ls_valid_i,
  input   logic [1:0]                   ls_op_i,
  input   logic [$clog2(NUM_WAYS)-1:0]  ls_way_i,

  output  logic                         lru_valid_o,
  output  logic [NUM_WAYS-1:0]          lru_way_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  localparam WAYS_LOG2 = $clog2(NUM_WAYS);

  // Enum for possible LS-operations
  typedef enum logic[1:0] {
    OP_LOAD       = 2'b01,
    OP_STORE      = 2'b10,
    OP_INVALIDATE = 2'b11
  } ls_op_t;

  logic                ls_rd_valid;
  logic                ls_wr_valid;

  logic                ls_inv_valid;
  logic [NUM_WAYS-1:0] ls_way_inv;

  logic [NUM_WAYS-1:0] ls_way_oldest;
  logic [NUM_WAYS-1:0] ls_way_sel;
  logic [NUM_WAYS-1:0] ls_way_read;

  logic [NUM_WAYS-1:0] way_avail_q;
  logic [NUM_WAYS-1:0] nxt_way_avail;
  logic [NUM_WAYS-1:0] way_valid;

  logic [NUM_WAYS-1:0] ls_way_active;

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
  always_ff @(posedge clk or posedge reset)
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
  logic [NUM_WAYS-1:0][NUM_WAYS-1:0] track_older ;

  for (genvar i=0; i<NUM_WAYS; i=i+1) begin : g_per_row
    for (genvar j=0; j<NUM_WAYS; j=j+1) begin : g_per_col
      if (i==j)
        assign track_older[i][j] = 1'b0;
      else if (i<j)
        assign track_older[i][j] = ~track_older[j][i];
      else begin
        logic  old_entry_q;
        logic  nxt_old_entry;

        // Set the row if most recent and clear the column
        assign nxt_old_entry = (ls_way_active[i] | track_older[i][j]) &
                               ~ls_way_active[j];

        always_ff @(posedge clk)
          if (|ls_way_active)
            old_entry_q <= nxt_old_entry;

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