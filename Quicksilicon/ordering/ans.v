// --------------------------------------------------------
// Ordering - RTL
// --------------------------------------------------------

module ordering (
  input   wire        clk,
  input   wire        reset,

  // RX side interface
  input   wire        rx_valid_i,
  input   wire [2:0]  rx_id_i,
  input   wire [15:0] rx_payload_i,
  input   wire        rx_order_i,
  output  wire        rx_ready_o,

  // RX retire interface
  input   wire        rx_ret_i,
  input   wire [2:0]  rx_ret_id_i,

  // TX side interface
  output  wire        tx_valid_o,
  output  wire [2:0]  tx_id_o,
  output  wire [15:0] tx_payload_o,
  input   wire        tx_ready_i

);

  // --------------------------------------------------------
  // Internal wire and regs
  // --------------------------------------------------------


  reg  [7:0][2:0]  rx_entry_q_id;
  reg  [7:0][15:0] rx_entry_q_payload;
  reg  [7:0]       rx_entry_q_retired;
  reg  [7:0]       rx_entry_q_inorder;

  wire [7:0][2:0]  nxt_rx_entry_id;
  wire [7:0][15:0] nxt_rx_entry_payload;
  wire [7:0]       nxt_rx_entry_retired;
  wire [7:0]       nxt_rx_entry_inorder;

  wire [7:0]       nxt_rx_entry_avail;
  reg  [7:0]       rx_entry_avail_q;
  wire [7:0]       rx_entry_sel;
  wire [7:0]       rx_entry_valid;
  wire [7:0]       rx_oldest;

  wire             ordered_entry;

  wire [7:0]       rx_entry_read;
  wire [7:0]       rx_retired;

  reg  [2:0]       tx_payload_id;
  reg  [15:0]      tx_payload_payload;
  reg              tx_payload_ready;
  reg              tx_payload_inorder;

  // --------------------------------------------------------
  // Implement a table to buffer the requests
  // --------------------------------------------------------
  assign ordered_entry = rx_valid_i & rx_order_i;

  for (genvar i=0; i<8; i=i+1) begin : g_req_table
    wire  rx_entry_en;

    assign rx_oldest[i]             = ~|(track_older[i] & rx_entry_valid);
    assign rx_entry_en              = rx_entry_sel[i] | rx_retired[i] | rx_oldest[i];

    assign nxt_rx_entry_id[i]       = rx_entry_sel[i] ? rx_id_i       : rx_entry_q_id[i];
    assign nxt_rx_entry_payload[i]  = rx_entry_sel[i] ? rx_payload_i  : rx_entry_q_payload[i];
    assign nxt_rx_entry_retired[i]  = (rx_retired[i] | rx_entry_q_retired[i])  & ~rx_entry_sel[i];
    assign nxt_rx_entry_inorder[i]  = (rx_oldest[i] | rx_entry_q_inorder[i]) & ~rx_entry_sel[i];

    always@(posedge clk)
      if (rx_entry_en) begin
        rx_entry_q_id[i]      <= nxt_rx_entry_id[i];
        rx_entry_q_payload[i] <= nxt_rx_entry_payload[i];
        rx_entry_q_retired[i] <= nxt_rx_entry_retired[i];
        rx_entry_q_inorder[i] <= nxt_rx_entry_inorder[i];
      end

  end

  // --------------------------------------------------------
  // Next valid entry
  // --------------------------------------------------------
  always @(posedge clk or posedge reset)
    if (reset)
      rx_entry_avail_q <= 8'hFF;
    else
      rx_entry_avail_q <= nxt_rx_entry_avail;

  assign rx_entry_sel[0] = rx_valid_i & rx_entry_avail_q[0];

  for (genvar i=1; i<8; i=i+1) begin : g_first_avail_entry
    assign rx_entry_sel[i] = rx_valid_i & ~|rx_entry_sel[i-1:0] & rx_entry_avail_q[i];
  end

  assign nxt_rx_entry_avail = (rx_entry_avail_q & ~rx_entry_sel) |
                              (rx_entry_read    & {8{tx_ready_i}});

  // --------------------------------------------------------
  // Read entry logic
  // --------------------------------------------------------
  assign rx_entry_valid = ~rx_entry_avail_q;

  assign rx_entry_read[0] = (rx_entry_valid[0] &
                            (rx_entry_q_retired[0] & rx_oldest[0]));
  for (genvar i=1; i<8; i=i+1) begin : g_read_req_table
    assign rx_entry_read[i] = (rx_entry_valid[i] &
                              (rx_entry_q_retired[i] & rx_oldest[i])) &
                              (~|rx_entry_read[i-1:0]);
  end

  // Read data from table
  always @(*) begin
    case (rx_entry_read)
      8'b0000_0001: begin
                      tx_payload_id      = rx_entry_q_id[0];
                      tx_payload_payload = rx_entry_q_payload[0];
                    end
      8'b0000_0010: begin
                      tx_payload_id      = rx_entry_q_id[1];
                      tx_payload_payload = rx_entry_q_payload[1];
                    end
      8'b0000_0100: begin
                      tx_payload_id      = rx_entry_q_id[2];
                      tx_payload_payload = rx_entry_q_payload[2];
                    end
      8'b0000_1000: begin
                      tx_payload_id      = rx_entry_q_id[3];
                      tx_payload_payload = rx_entry_q_payload[3];
                    end
      8'b0001_0000: begin
                      tx_payload_id      = rx_entry_q_id[4];
                      tx_payload_payload = rx_entry_q_payload[4];
                    end
      8'b0010_0000: begin
                      tx_payload_id      = rx_entry_q_id[5];
                      tx_payload_payload = rx_entry_q_payload[5];
                    end
      8'b0100_0000: begin
                      tx_payload_id      = rx_entry_q_id[6];
                      tx_payload_payload = rx_entry_q_payload[6];
                    end
      8'b1000_0000: begin
                      tx_payload_id      = rx_entry_q_id[7];
                      tx_payload_payload = rx_entry_q_payload[7];
                    end
      default:      begin
                      tx_payload_id      = 'b0;
                      tx_payload_payload = 'b0;
                    end
    endcase
  end

  qs_skid_buffer #(.DATA_W(19)) tx_skid_buffer (
    .clk        (clk),
    .reset      (reset),

    .i_valid_i  (|rx_entry_read),
    .i_data_i   ({tx_payload_id, tx_payload_payload}),
    .i_ready_o  (tx_ready),

    .e_valid_o  (tx_valid_o),
    .e_data_o   ({tx_id_o, tx_payload_o}),
    .e_ready_i  (tx_ready_i)

  );

  // --------------------------------------------------------
  // Order tracking structure
  // --------------------------------------------------------
  wire [7:0] track_older [7:0];
  wire       track_older_en;

   assign track_older_en = |rx_entry_sel;

  for (genvar i=0; i<8; i=i+1) begin : g_per_row
    for (genvar j=0; j<8; j=j+1) begin : g_per_col
      if (i==j)
        assign track_older[i][j] = 1'b0;
      else begin
        reg   old_entry_q;
        wire  nxt_old_entry;

        // Set the row if ordered, clear the column
        assign nxt_old_entry = (rx_entry_sel[i] & ordered_entry)  |
                                track_older[i][j]                 &
                               ~rx_entry_sel[j];

        always @(posedge clk)
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
                          (rx_entry_q_id[i] == rx_ret_id_i);
  end

  // --------------------------------------------------------
  // Output Assignments
  // --------------------------------------------------------
  assign rx_ready_o   = |rx_entry_avail_q;

endmodule