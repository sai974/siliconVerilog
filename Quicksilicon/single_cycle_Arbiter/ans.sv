// --------------------------------------------------------
// Single Cycle Arbiter - RTL
// --------------------------------------------------------

module single_cycle_arbiter #(
  parameter N = 32
) (
  input   logic          clk,
  input   logic          reset,
  input   logic [N-1:0]  req_i,
  output  logic [N-1:0]  gnt_o
);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  logic [N-1:0] priority_req;

  // --------------------------------------------------------
  // Arbitration logic
  // --------------------------------------------------------
  // Port[0] has the highest priority hence will always be
  // serviced first.
  assign priority_req[0] = 1'b0;
  if (N>0) begin
    for (genvar i=0; i<N-1; i++) begin
      // Port[0] has highest priority. Keep priority of next
      // port asserted if a lower port number request is
      // valid.
      assign priority_req[i+1] = priority_req[i] | req_i[i];
    end
  end

  // -------------------------------------------------------
  // Output assignments
  // --------------------------------------------------------
  assign gnt_o[N-1:0] = req_i[N-1:0] & ~priority_req[N-1:0];

endmodule