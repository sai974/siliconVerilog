// --------------------------------------------------------
// Buffering - RTL
// --------------------------------------------------------

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

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  typedef enum logic [1:0] {ST_IDLE, ST_DATA, ST_XFER} state_t;
  state_t              state_q;
  state_t              nxt_state;

  logic                buf_push;
  logic                buf_pop;
  logic [15:0]         buf_pop_data;
  logic                buf_empty;
  logic                buf_drain;
  logic                buf_drain_q;

  logic [15:0]         buf2dev_tdata;
  logic [2:0]          buf2dev_tid;
  logic                buf2dev_xfer;

  logic                buf2req_tready;

  logic                req_tready;

  logic [18:0]         nxt_addr;
  logic [18:0]         addr_q;

  logic [15:0]         nxt_data;
  logic [15:0]         data_q;

  // --------------------------------------------------------
  // Implement a fifo to buffer the requests
  // --------------------------------------------------------
  qs_fifo #(.DEPTH(8), .DATA_W(16)) req_buf (
    .clk          (clk),
    .reset        (reset),

    .push_i       (buf_push),
    .push_data_i  (req_tdata_i),

    .pop_i        (buf_pop),
    .pop_data_o   (buf_pop_data),

    .full_o       (),
    .empty_o      (buf_empty)
  );

  // Push into fifo whenever the current access is seen to
  // a device ID 5 and when in sleep mode
  assign buf_push = req_tvalid_i & (~dev_opmode_i &
                                   (req_tid_i[2:0] == 3'h5));

  // Pop from fifo whenever downstream is free and fifo isn't
  // empty and device is awake
  assign buf_drain = ((state_q == ST_IDLE) &        // Downstream is free
                      (~buf_empty)         &        // Buffer isn't empty
                      (dev_opmode_i))      |        // Device is awake
                      (buf_drain_q         &        // Continue to drain the
                      ~buf_empty);                  // buffer until empty
                                                    

  always_ff @(posedge clk or posedge reset)
    if (reset)
      buf_drain_q <= 1'b0;
    else
      buf_drain_q <= buf_drain;

  assign buf_pop = buf_drain & req_tready;

  // --------------------------------------------------------
  // Route correct data to state machine
  // --------------------------------------------------------
  assign buf2dev_tdata = buf_drain ? buf_pop_data : req_tdata_i;
  assign buf2dev_tid   = buf_drain ? 3'h5         : req_tid_i;

  assign buf2dev_xfer  = (req_tvalid_i & req_tready & ~buf_push) |
                          buf_pop;

  assign buf2req_tready = (buf_push) |
                          (~buf_drain & req_tready);

  // --------------------------------------------------------
  // State machine to convert stream into valid-ready
  // --------------------------------------------------------
  always_comb begin
    nxt_state = state_q;
    nxt_addr  = addr_q;
    nxt_data  = data_q;
    case (state_q)
      ST_IDLE: begin
        req_tready = 1'b1;
        if (buf2dev_xfer) begin
          nxt_state = ST_DATA;
          nxt_addr = {buf2dev_tdata, buf2dev_tid};
        end
      end
      ST_DATA: begin
        req_tready = 1'b1;
        if (buf2dev_xfer) begin
          nxt_state = ST_XFER;
          nxt_data = buf2dev_tdata;
        end
      end
      ST_XFER: begin
        req_tready = 1'b0;
        if (dev_ready_i) nxt_state = ST_IDLE;
      end
      default: nxt_state = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk or posedge reset)
    if (reset)
      state_q <= ST_IDLE;
    else
      state_q <= nxt_state;

  always_ff @(posedge clk) begin
    addr_q <= nxt_addr;
    data_q <= nxt_data;
  end

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign dev_valid_o = (state_q == ST_XFER);
  assign dev_addr_o  = addr_q;
  assign dev_data_o  = data_q;

  assign req_tready_o = buf2req_tready;

endmodule