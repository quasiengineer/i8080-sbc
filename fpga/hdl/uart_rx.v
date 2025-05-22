module uart_rx #(
    parameter CLK_FREQ  = 184333000,   // Input clock frequency in Hz
    parameter BAUD_RATE = 115200      // Desired baud rate
)(
    input  wire       clk,    // system clock
    input  wire       rst,    // synchronous reset, active high
    input  wire       rx,     // serial RX input
    output reg [7:0]  data,   // received data byte
    output reg        valid,  // high for one clock when a byte is received correctly
    output reg        busy    // high while reception is in progress
);

  // Calculate baud rate divider.
  localparam integer BAUD_DIV = CLK_FREQ / BAUD_RATE; // 11-bit
  // For sampling the start bit in its center, use half the baud divider.
  localparam integer HALF_BAUD_DIV = BAUD_DIV >> 1;   // 10-bit

  // UART protocol state definitions
  localparam STATE_IDLE  = 2'd0;
  localparam STATE_START = 2'd1;
  localparam STATE_DATA  = 2'd2;
  localparam STATE_STOP  = 2'd3;

  // Internal signals
  reg [1:0]  state;
  reg [15:0] baud_counter;  // counter for baud timing
  reg [3:0]  bit_index;     // index for the 8 data bits (0 to 7)

  always @(posedge clk) begin
    if (rst) begin
      state        <= STATE_IDLE;
      baud_counter <= 16'd0;
      bit_index    <= 4'd0;
      data         <= 8'd0;
      valid        <= 1'b0;
      busy         <= 1'b0;
    end
    else begin
      // Default: valid is a one-clock pulse when a byte is received
      valid <= 1'b0;
      case (state)
        STATE_IDLE: begin
          busy <= 1'b0;
          baud_counter <= 16'd0;
          bit_index <= 4'd0;
          // Wait for start bit (rx goes low)
          if (rx == 1'b0) begin
            busy <= 1'b1;
            state <= STATE_START;
            baud_counter <= 16'd0;
          end
        end

        STATE_START: begin
          busy <= 1'b1;
          // Wait half a baud period to sample the middle of the start bit
          if (baud_counter < HALF_BAUD_DIV - 1) begin
            baud_counter <= baud_counter + 1;
          end
          else begin
            baud_counter <= 16'd0;
            // If still low, it is a valid start bit
            if (rx == 1'b0)
              state <= STATE_DATA;
            else
              state <= STATE_IDLE;  // false start, return to idle
          end
        end

        STATE_DATA: begin
          busy <= 1'b1;
          // Wait a full baud period before sampling each data bit.
          if (baud_counter < BAUD_DIV - 1) begin
            baud_counter <= baud_counter + 1;
          end
          else begin
            baud_counter <= 16'd0;
            // Sample the data bit into the corresponding bit of 'data'
            data[bit_index] <= rx;
            if (bit_index < 7)
              bit_index <= bit_index + 1;
            else begin
              bit_index <= 0;
              state <= STATE_STOP;
            end
          end
        end

        STATE_STOP: begin
          busy <= 1'b1;
          // Wait one baud period for the stop bit.
          if (baud_counter < BAUD_DIV - 1) begin
            baud_counter <= baud_counter + 1;
          end
          else begin
            baud_counter <= 16'd0;
            // Sample the stop bit; it should be high.
            if (rx == 1'b1)
              valid <= 1'b1; // reception is successful
            // Otherwise, you might flag a framing error here.
            state <= STATE_IDLE;
            busy <= 1'b0;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule