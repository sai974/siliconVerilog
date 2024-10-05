module events_to_apb (
  input   logic         clk,
  input   logic         reset,

  input   logic         event_a_i,
  input   logic         event_b_i,
  input   logic         event_c_i,

  output  logic         apb_psel_o,
  output  logic         apb_penable_o,
  output  logic [31:0]  apb_paddr_o,
  output  logic         apb_pwrite_o,
  output  logic [31:0]  apb_pwdata_o,
  input   logic         apb_pready_i

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  typedef enum logic[1:0] {ST_IDLE, ST_SETUP, ST_ACCESS} apb_state_t;
  typedef enum logic[31:0] {
    EVENT_A_ADDR = 32'hABBA_0000,
    EVENT_B_ADDR = 32'hBAFF_0000,
    EVENT_C_ADDR = 32'hCAFE_0000} apd_addr_t;

  logic       apb_psel;
  logic       apb_penable;
  logic[31:0] apb_paddr;
  logic       apb_pwrite;
  logic[31:0] apb_pwdata;

  logic[31:0] apb_pwdata_q;

  logic[31:0] paddr_q;
  logic[31:0] nxt_paddr;

  apb_state_t state_q;
  apb_state_t nxt_state;
  logic       apb_state_setup;
  logic       apb_state_access;

  logic       event_seen;

  logic [3:0] event_a_count_q;
  logic [3:0] nxt_event_a_count;

  logic [3:0] event_b_count_q;
  logic [3:0] nxt_event_b_count;

  logic [3:0] event_c_count_q;
  logic [3:0] nxt_event_c_count;

  logic       event_a_sel;
  logic       event_b_sel;
  logic       event_c_sel;

  assign event_seen = |{event_a_i, event_b_i, event_c_i,
                        event_a_count_q, event_b_count_q, event_c_count_q};

  always_ff @(posedge clk or posedge reset)
    if (reset)
      state_q <= ST_IDLE;
    else
      state_q <= nxt_state;

  // --------------------------------------------------------
  // APB state machine
  // --------------------------------------------------------
  always_comb begin
    nxt_paddr = paddr_q;
    case (state_q)
      ST_IDLE: begin
        if (event_seen) begin
          nxt_state = ST_SETUP;
          nxt_paddr = (event_a_i | (|event_a_count_q)) ? EVENT_A_ADDR :
                      (event_b_i | (|event_b_count_q)) ? EVENT_B_ADDR :
                                                         EVENT_C_ADDR;
        end else begin
          nxt_state = ST_IDLE;
        end
      end
      ST_SETUP: begin
        nxt_state = ST_ACCESS;
      end
      ST_ACCESS: begin
        if (apb_pready_i)
          nxt_state = ST_IDLE;
        else
          nxt_state = ST_ACCESS;
      end
      default: nxt_state = ST_IDLE;
    endcase
  end

  assign apb_state_setup  = (state_q == ST_SETUP);
  assign apb_state_access = (state_q == ST_ACCESS);

  assign apb_psel    = apb_state_setup | apb_state_access;
  assign apb_penable = apb_state_access;
  assign apb_pwrite  = 1'b1;

  // --------------------------------------------------------
  // APB Address
  // --------------------------------------------------------
  always_ff @(posedge clk or posedge reset)
    if (reset)
      paddr_q <= EVENT_A_ADDR;
    else
      paddr_q <= nxt_paddr;

  assign apb_paddr = {32{apb_state_access}} & paddr_q;

  assign event_a_sel = apb_state_setup & (paddr_q == EVENT_A_ADDR);
  assign event_b_sel = apb_state_setup & (paddr_q == EVENT_B_ADDR);
  assign event_c_sel = apb_state_setup & (paddr_q == EVENT_C_ADDR);

  // --------------------------------------------------------
  // APB Write Data
  // --------------------------------------------------------
  always_ff @(posedge clk or posedge reset)
    if (reset) begin
      event_a_count_q <= 4'h0;
      event_b_count_q <= 4'h0;
      event_c_count_q <= 4'h0;
    end else begin
      event_a_count_q <= nxt_event_a_count;
      event_b_count_q <= nxt_event_b_count;
      event_c_count_q <= nxt_event_c_count;
    end

  assign nxt_event_a_count = event_a_sel ? {3'h0, event_a_i} :
                              event_a_count_q + {3'h0, event_a_i};

  assign nxt_event_b_count = event_b_sel ? {3'h0, event_b_i} :
                              event_b_count_q + {3'h0, event_b_i};

  assign nxt_event_c_count = event_c_sel ? {3'h0, event_c_i} :
                              event_c_count_q + {3'h0, event_c_i};

  assign apb_pwdata = (event_a_sel) ? 32'(event_a_count_q) :
                      (event_b_sel) ? 32'(event_b_count_q) :
                      (event_c_sel) ? 32'(event_c_count_q) :
                                                    32'h0;
  always_ff @(posedge clk or posedge reset)
    if (reset)
      apb_pwdata_q <= 32'h0;
    else if (apb_state_setup)
      apb_pwdata_q <= apb_pwdata;

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign apb_psel_o     = apb_psel;
  assign apb_penable_o  = apb_penable;
  assign apb_paddr_o    = apb_paddr;
  assign apb_pwrite_o   = apb_pwrite;
  assign apb_pwdata_o   = apb_pwdata_q;


endmodule