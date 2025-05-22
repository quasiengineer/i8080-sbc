module uart_tx #(
    parameter CLK_FREQ  = 184333000,  // Input clock frequency in Hz
    parameter BAUD_RATE = 115200      // Desired baud rate
)(
    input  wire        clk,      // system clock
    input  wire        rst,      // synchronous reset, active high
    input  wire [7:0]  data,     // byte to transmit
    input  wire        valid,    // start transmission when high (one-cycle pulse)
    output reg         tx,       // serial TX output
    output reg         busy      // high while transmission is in progress
);

  // Calculate the baud rate divider.
  localparam integer BAUD_DIV = CLK_FREQ / BAUD_RATE;

  // UART protocol state definitions
  localparam STATE_IDLE  = 2'd0;
  localparam STATE_START = 2'd1;
  localparam STATE_DATA  = 2'd2;
  localparam STATE_STOP  = 2'd3;

  // Internal signals
  reg [1:0]   state;
  reg [15:0]  baud_counter;  // counter for baud timing
  reg [3:0]   bit_index;     // index for the 8 data bits (0 to 7)
  reg [7:0]   shift_reg;     // shift register to hold data during transmission

  // State machine for UART transmission
  always @(posedge clk) begin
    if (rst) begin
      state        <= STATE_IDLE;
      baud_counter <= 16'd0;
      bit_index    <= 4'd0;
      shift_reg    <= 8'd0;
      tx           <= 1'b1; // TX idle state is high
      busy         <= 1'b0;
    end
    else begin
      case (state)
        STATE_IDLE: begin
          tx   <= 1'b1; // idle line
          busy <= 1'b0;
          // When valid is asserted, load data and start transmission.
          if (valid) begin
            busy        <= 1'b1;
            shift_reg   <= data;
            baud_counter<= 16'd0;
            state       <= STATE_START;
          end
        end

        STATE_START: begin
          // Transmit start bit (logic 0)
          tx <= 1'b0;
          if (baud_counter < BAUD_DIV - 1)
            baud_counter <= baud_counter + 1;
          else begin
            baud_counter <= 16'd0;
            bit_index    <= 4'd0;
            state        <= STATE_DATA;
          end
        end

        STATE_DATA: begin
          // Transmit LSB first.
          tx <= shift_reg[0];
          if (baud_counter < BAUD_DIV - 1)
            baud_counter <= baud_counter + 1;
          else begin
            baud_counter <= 16'd0;
            shift_reg    <= shift_reg >> 1; // shift right to get next bit
            if (bit_index < 7)
              bit_index <= bit_index + 1;
            else
              state <= STATE_STOP;
          end
        end

        STATE_STOP: begin
          // Transmit stop bit (logic 1)
          tx <= 1'b1;
          if (baud_counter < BAUD_DIV - 1)
            baud_counter <= baud_counter + 1;
          else begin
            baud_counter <= 16'd0;
            state        <= STATE_IDLE;
            busy         <= 1'b0;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule