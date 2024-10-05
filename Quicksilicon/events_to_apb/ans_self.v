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
  
  // Write your logic here
  
  localparam IDLE = 3'b0;
  localparam SETUP = 3'b01;
  localparam WAIT = 3'b10;
  //localparam IDLE = 3'b11;
  
  logic [31:0] count_a, nextCount_a; 
  logic [31:0] count_b, nextCount_b;
  logic [31:0] count_c, nextCount_c; 
  
  logic a_sel, b_sel, c_sel;
  logic is_anyPend, is_aPend, is_bPend, is_cPend;
  logic is_apbIdle;
  logic [31:0] txn_addr, txn_data,txn_dataReg, txn_addrReg;
  logic [2:0] currState, nextState;
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      count_a <= 32'b0;
    	count_b <= 32'b0;
    	count_c <= 32'b0;
    end else begin
        count_a <= nextCount_a;
        count_b <= nextCount_b;
        count_c <= nextCount_c;
    end
  end
  
  assign is_anyPend = is_aPend || is_bPend || is_cPend;
  assign is_aPend = !(count_a == 32'b0);
  assign is_bPend = !(count_b == 32'b0);
  assign is_cPend = !(count_c == 32'b0);
  assign is_apbIdle = (currState == IDLE);
  assign load_txn = is_anyPend && is_apbIdle;

  always_comb begin
    priority case (1'b1)
      is_aPend : begin 
        a_sel = is_apbIdle ? 1'b1 : 1'b0;
        {b_sel, c_sel} = 2'b0;
      end
      is_bPend : begin
        b_sel = is_apbIdle ? 1'b1 : 1'b0;
        {a_sel, c_sel} = 2'b0;
      end
      is_cPend : begin
        c_sel = is_apbIdle ? 1'b1 : 1'b0;
      	{b_sel, a_sel} = 2'b0;
      end
      default: 
      {c_sel, b_sel, a_sel} = 3'b0;
    endcase
  end
  
  assign nextCount_a = nextCount(a_sel, event_a_i, load_txn, count_a);
  assign nextCount_b = nextCount(b_sel, event_b_i, load_txn, count_b);
  assign nextCount_c = nextCount(c_sel, event_c_i, load_txn, count_c);

  always_comb begin
    txn_data = 32'b0;
    txn_addr = 32'b0;
    
    unique case (1'b1)
      a_sel: begin
        txn_data = count_a; 
        txn_addr = 32'hABBA0000; 
      end
      b_sel: begin
        txn_data = count_b; 
        txn_addr = 32'hBAFF0000; 
    	end
      c_sel: begin
        txn_data = count_c; 
        txn_addr = 32'hCAFE0000; 
    		end
    endcase
  end



  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      currState <= IDLE;
    	txn_addrReg <= 32'b0;
    	txn_dataReg <= 32'b0;
    end
    else begin
      currState <= nextState;
      if (load_txn) begin
        txn_addrReg <= txn_addr;
        txn_dataReg <= txn_data;
      end
    end
  end

  always_comb begin
    apb_psel_o = 1'b0;
    apb_penable_o = 1'b0;
    apb_pwrite_o = 1'b0;
    apb_pwdata_o =  32'b0;
    apb_paddr_o = 'b0;
    
    nextState = currState;

    case (currState)
      IDLE  : nextState = is_anyPend ? SETUP : IDLE;
      SETUP : begin
        nextState = WAIT;
        apb_psel_o = 1'b1;
        apb_pwrite_o = 1'b1;
        apb_pwdata_o = txn_dataReg;
        apb_paddr_o = txn_addrReg;
      end
      WAIT  : begin
        nextState = (apb_pready_i == 1'b1) ? IDLE : WAIT;
        apb_penable_o = 1'b1;
        apb_psel_o = 1'b1;
        apb_pwrite_o = 1'b1;
        apb_pwdata_o = txn_dataReg;
        apb_paddr_o = txn_addrReg;
      end
      default: 
        nextState = IDLE;
    endcase
  end

  function [31:0] nextCount(input logic sel, input logic event_i, input logic loadtxn, input logic [31:0] count);
    if (loadtxn)
      if (sel) return ({{31{1'b0}}, event_i});
    else return (count + {{31{1'b0}}, event_i});
    else
      return (count + {{31{1'b0}}, event_i});
  endfunction 
endmodule
