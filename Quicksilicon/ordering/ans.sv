// --------------------------------------------------------
// Ordering - RTL
// --------------------------------------------------------

module ordering (
  input   logic        clk,
  input   logic        reset,

  // RX side interface
  input   logic        rx_valid_i,
  input   logic [2:0]  rx_id_i,
  input   logic [15:0] rx_payload_i,
  input   logic        rx_order_i,
  output  logic        rx_ready_o,

  // RX retire interface
  input   logic        rx_ret_i,
  input   logic [2:0]  rx_ret_id_i,

  // TX side interface
  output  logic        tx_valid_o,
  output  logic [2:0]  tx_id_o,
  output  logic [15:0] tx_payload_o,
  input   logic        tx_ready_i

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------
  typedef struct packed {
    logic [2:0]   id;
    logic [15:0]  payload;
    logic         retired;
    logic         inorder;
  } rx_table_t;

  rx_table_t [7:0] nxt_rx_entry;
  rx_table_t [7:0] rx_entry_q;

  logic      [7:0] nxt_rx_entry_avail;
  logic      [7:0] rx_entry_avail_q;
  logic      [7:0] rx_entry_sel;
  logic      [7:0] rx_entry_valid;
  logic      [7:0] rx_oldest;

  logic            ordered_entry;

  logic      [7:0] rx_entry_read;
  logic      [7:0] rx_retired;

  rx_table_t       tx_payload;
  logic            tx_ready;

  // --------------------------------------------------------
  // Implement a table to buffer the requests
  // --------------------------------------------------------
  assign ordered_entry = rx_valid_i & rx_order_i;

  for (genvar i=0; i<8; i=i+1) begin : g_req_table
    logic  rx_entry_en;

    assign rx_oldest[i]             = ~|(track_older[i] & rx_entry_valid);
    assign rx_entry_en              = rx_entry_sel[i] | rx_retired[i] | rx_oldest[i];

    assign nxt_rx_entry[i].id       = rx_entry_sel[i] ? rx_id_i       : rx_entry_q[i].id;
    assign nxt_rx_entry[i].payload  = rx_entry_sel[i] ? rx_payload_i  : rx_entry_q[i].payload;
    assign nxt_rx_entry[i].retired  = (rx_retired[i] | rx_entry_q[i].retired)  & ~rx_entry_sel[i];
    assign nxt_rx_entry[i].inorder  = (rx_oldest[i] | rx_entry_q[i].inorder) & ~rx_entry_sel[i];

    always_ff @(posedge clk)
      if (rx_entry_en)
        rx_entry_q[i] <= nxt_rx_entry[i];
  end

  // --------------------------------------------------------
  // Next valid entry
  // --------------------------------------------------------
  always_ff @(posedge clk or posedge reset)
    if (reset)
      rx_entry_avail_q <= 8'hFF;
    else
      rx_entry_avail_q <= nxt_rx_entry_avail;

  assign rx_entry_sel[0] = rx_valid_i & rx_entry_avail_q[0];

  for (genvar i=1; i<8; i=i+1) begin : g_first_avail_entry
    assign rx_entry_sel[i] = rx_valid_i & ~|rx_entry_sel[i-1:0] & rx_entry_avail_q[i];
  end

  assign nxt_rx_entry_avail = (rx_entry_avail_q & ~rx_entry_sel) |
                              (rx_entry_read    & {8{tx_ready}});

  // --------------------------------------------------------
  // Read entry logic
  // --------------------------------------------------------
  assign rx_entry_valid = ~rx_entry_avail_q;

  assign rx_entry_read[0] = (rx_entry_valid[0] &
                            (rx_entry_q[0].retired & rx_oldest[0]));
  for (genvar i=1; i<8; i=i+1) begin : g_read_req_table
    assign rx_entry_read[i] = (rx_entry_valid[i] &
                              (rx_entry_q[i].retired & rx_oldest[i])) &
                              (~|rx_entry_read[i-1:0]);
  end

  // Read data from table
  always_comb begin
    case (rx_entry_read)
      8'b0000_0001: tx_payload = rx_entry_q[0];
      8'b0000_0010: tx_payload = rx_entry_q[1];
      8'b0000_0100: tx_payload = rx_entry_q[2];
      8'b0000_1000: tx_payload = rx_entry_q[3];
      8'b0001_0000: tx_payload = rx_entry_q[4];
      8'b0010_0000: tx_payload = rx_entry_q[5];
      8'b0100_0000: tx_payload = rx_entry_q[6];
      8'b1000_0000: tx_payload = rx_entry_q[7];
      default:      tx_payload = '0;
    endcase
  end

  qs_skid_buffer #(.DATA_W(19)) tx_skid_buffer (
    .clk        (clk),
    .reset      (reset),

    .i_valid_i  (|rx_entry_read),
    .i_data_i   ({tx_payload.id, tx_payload.payload}),
    .i_ready_o  (tx_ready),

    .e_valid_o  (tx_valid_o),
    .e_data_o   ({tx_id_o, tx_payload_o}),
    .e_ready_i  (tx_ready_i)

  );

  // --------------------------------------------------------
  // Order tracking structure
  // --------------------------------------------------------
  logic [7:0] track_older [7:0];
  logic       track_older_en;

  assign track_older_en = |rx_entry_sel;

  for (genvar i=0; i<8; i=i+1) begin : g_per_row
    for (genvar j=0; j<8; j=j+1) begin : g_per_col
      if (i==j)
        assign track_older[i][j] = 1'b0;
      else begin
        logic  old_entry_q;
        logic  nxt_old_entry;

        // Set the row if ordered, clear the column
        assign nxt_old_entry = (rx_entry_sel[i] & ordered_entry)  |
                                track_older[i][j]                 &
                               ~rx_entry_sel[j];

        always_ff @(posedge clk)
          if (track_older_en)
            old_entry_q <= nxt_old_entry;

        assign track_older[i][j] = old_entry_q;
      end
    end
  end

  // --------------------------------------------------------
  // Entry retired
  // --------------------------------------------------------
  for (genvar i=0; i<8; i=i+1) begin : g_entry_retired
    assign rx_retired[i] = rx_ret_i & rx_entry_valid[i] &
                          (rx_entry_q[i].id == rx_ret_id_i);
  end

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign rx_ready_o   = |rx_entry_avail_q;

endmodule