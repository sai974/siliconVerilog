// --------------------------------------------------------
// Low Power Channel - RTL
// --------------------------------------------------------

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

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic               wr_fifo_push;
  logic               wr_fifo_pop;
  logic [7:0]         wr_fifo_pop_data;
  logic               wr_fifo_full;
  logic               wr_fifo_empty;

  typedef enum {ST_Q_RUN, ST_Q_REQUEST, ST_Q_STOPPED, ST_Q_EXIT} state_t;

  state_t             state_q;
  state_t             nxt_state;

  logic               wr_flush_q;
  logic               nxt_wr_flush;

  logic [7:0]         rd_payload;

  logic               nxt_qaccept;
  logic               nxt_qacceptn;
  logic               qacceptn_en;
  logic               qacceptn_q;

  logic               nxt_qactive;
  logic               qactive_q;

  // --------------------------------------------------------
  // Implement a fifo to buffer the requests
  // --------------------------------------------------------
  qs_fifo #(.DEPTH(6), .DATA_W(8)) wr_fifo (
    .clk          (clk),
    .reset        (reset),

    .push_i       (wr_fifo_push),
    .push_data_i  (wr_payload_i),

    .pop_i        (wr_fifo_pop),
    .pop_data_o   (wr_fifo_pop_data),

    .full_o       (wr_fifo_full),
    .empty_o      (wr_fifo_empty)
  );

  // Push into fifo when a valid write request is seen
  assign wr_fifo_push = wr_valid_i;
  // Pop from fifo when a valid read request is seen
  assign wr_fifo_pop = rd_valid_i;
  // Read payload would be the popped data
  assign rd_payload = wr_fifo_pop_data;

  // --------------------------------------------------------
  // QACTIVE
  // --------------------------------------------------------
  assign nxt_qactive = ~wr_fifo_empty | wr_valid_i | rd_valid_i;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      qactive_q <= 1'b0;
    else
      qactive_q <= nxt_qactive;

  // --------------------------------------------------------
  // LPC State machine
  // --------------------------------------------------------
  always_comb begin
    nxt_state = state_q;
    case (state_q)
      ST_Q_RUN      : if (~qreqn_i)       nxt_state = ST_Q_REQUEST;
      ST_Q_REQUEST  : if (~qacceptn_q)    nxt_state = ST_Q_STOPPED;
      ST_Q_STOPPED  : if (qreqn_i)        nxt_state = ST_Q_EXIT;
      ST_Q_EXIT     : if (qacceptn_q)     nxt_state = ST_Q_RUN;
    endcase
  end

  always_ff @(posedge clk or posedge reset)
    if (reset)
      state_q <= ST_Q_RUN;
    else
      state_q <= nxt_state;

  // --------------------------------------------------------
  // QACCEPTn
  // --------------------------------------------------------
  assign nxt_qaccept  = (wr_done_i      &   // Upstream is idle
                         wr_fifo_empty) &   // Fifo has drained
                        (~qreqn_i);         // QREQn goes low

  assign nxt_qacceptn = ~nxt_qaccept;

  assign qacceptn_en = (state_q == ST_Q_REQUEST) |
                       (state_q == ST_Q_EXIT);

  // Deassert QACCEPTn out-of-reset
  always_ff @(posedge clk or posedge reset)
    if (reset)
      qacceptn_q <= 1'b1;
    else if (qacceptn_en)
      qacceptn_q <= nxt_qacceptn;

  // Flush data from upstream when in ST_Q_REQUEST state
  // or there is an on-going flush which hasn't completed
  assign nxt_wr_flush = ((state_q == ST_Q_REQUEST) | wr_flush_q) &
                         (~wr_done_i);

  always_ff @(posedge clk or posedge reset)
    if (reset)
      wr_flush_q <= 1'b0;
    else
      wr_flush_q <= nxt_wr_flush;

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign qactive_o  = qactive_q | if_wakeup_i;
  assign qacceptn_o = qacceptn_q;

  assign wr_flush_o = wr_flush_q;

  assign rd_payload_o = rd_payload;

endmodule