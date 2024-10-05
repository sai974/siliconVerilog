module atomic_counters (
  input                   clk,
  input                   reset,
  input                   trig_i,
  input                   req_i,
  input                   atomic_i,
  output logic            ack_o,
  output logic[31:0]      count_o
);

  // --------------------------------------------------------
  // DO NOT CHANGE ANYTHING HERE
  // --------------------------------------------------------
  logic [63:0] count_q;
  logic [63:0] count;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      count_q[63:0] <= 64'h0;
    else
      count_q[63:0] <= count;
  // --------------------------------------------------------

  // Write your logic here...
  assign count = count_q + {63'b0, trig_i};
  
	localparam INIT = 2'b0;
  localparam REQ0 = 2'b01;
  localparam REQ1 = 2'b10;
  
  logic [1:0] state_q, state_d;
  logic [31:0] saved_count_q, saved_count_d; 
  
  always_ff @(posedge clk or posedge reset) begin 
    if (reset) begin 
      state_q <= INIT;
      saved_count_q <= 32'b0;
    end else begin 
      state_q <= state_d;
      saved_count_q <= saved_count_d;
    end
  end
  
  always_comb begin 
    state_d = state_q;
    count_o = 32'b0;
    //ack_o = 1'b0;
    saved_count_d = saved_count_q;
    case (state_q) 
      INIT : begin 
        if (req_i) begin 
          //saved_count_d = count_q;
          if (atomic_i) begin
          	state_d = REQ0;  
        	end
        end
      end
      REQ0 : begin 
        count_o = count_q[31:0]; 
        saved_count_d = count_q[63:32];
        if (req_i) begin 
          if (atomic_i) begin
          	state_d = REQ0;  
        	end else begin 
          	state_d = REQ1;
          end
        end else begin
          state_d = INIT; 
        end
        //ack_o = 1'b1;
      end
      REQ1 : begin 
        count_o = saved_count_q; 
        if (req_i) begin 
          if (atomic_i) begin
          	state_d = REQ0;  
        	end else begin 
          	state_d = REQ1;
          end
        end else begin
          state_d = INIT; 
        end
        
        //ack_o = 1'b1;
  		end
      default: begin
        state_d = INIT;
      end
    endcase 
  end
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      ack_o <= 1'b0; 
    else
      ack_o <= req_i;
  end
  
endmodule

