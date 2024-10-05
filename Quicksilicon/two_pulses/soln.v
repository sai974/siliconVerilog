// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Two Pulses - RTL
// --------------------------------------------------------

module two_pulses (
  input   wire       clk,
  input   wire       reset,

  input   wire       x_i,
  input   wire       y_i,

  output  wire       p_o

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  reg  [1:0] y_count_q;
  reg  [1:0] nxt_y_count;

  reg        x_q;
  wire       x_en;

  wire       p;
  reg        p_q;
  wire       p_en;

  always @(posedge clk or posedge reset)
    if (reset)
      y_count_q <= 2'h0;
    else
      y_count_q <= nxt_y_count;

  always @* begin
    nxt_y_count = y_count_q;
    if (x_i) begin
      nxt_y_count = 2'(y_i);
    end else if (y_i) begin
      case (y_count_q)
        2'b00,
        2'b01,
        2'b10 : nxt_y_count = y_count_q + 2'b01;
        2'b11 : nxt_y_count = y_count_q;
      endcase
    end
  end

  always @(posedge clk or posedge reset)
    if (reset)
      x_q <= 1'b0;
    else if (x_en)
      x_q <= x_i;

  assign x_en = ~x_q & x_i;

  always @(posedge clk or posedge reset)
    if (reset)
      p_q <= 1'b0;
    else if (p_en)
      p_q <= p;

  assign p_en = x_i | y_i;

  assign p = ((x_q)          &        // Seen one pulse on x
             (x_i)           &        // Pulse on this cycle
             (y_count_q == 2'b10)) |  // Exactly two y pulses OR
             (p_q & ~y_i);            // Keep it asserted until
                                      // next y pulse

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign p_o = p;

endmodule