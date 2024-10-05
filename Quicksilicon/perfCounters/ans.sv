// --------------------------------------------------------
// Copyright (C) quicksilicon.io - All Rights Reserved
//
// Unauthorized copying of this file, via any medium is
// strictly prohibited
// Proprietary and confidential
// --------------------------------------------------------

// --------------------------------------------------------
// Performance Counters - RTL
// --------------------------------------------------------

module perf_counters #(
  parameter CNT_W = 4
) (
  input                   clk,
  input                   reset,
  input                   sw_req_i,
  input                   cpu_trig_i,
  output logic[CNT_W-1:0] p_count_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [CNT_W-1:0] count_q;
  logic [CNT_W-1:0] count;

  always_ff @(posedge clk or posedge reset)
    if (reset)
      count_q[CNT_W-1:0] <= {CNT_W{1'b0}};
    else
      count_q[CNT_W-1:0] <= count;

  always_comb begin
    count[CNT_W-1:0] = sw_req_i ? {{CNT_W-1{1'b0}}, cpu_trig_i} :
                                  count_q + {{CNT_W-1{1'b0}}, cpu_trig_i};
  end

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign p_count_o[CNT_W-1:0] = sw_req_i ? count_q[CNT_W-1:0]: {CNT_W{1'b0}};

endmodule