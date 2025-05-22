module i8080_output(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,
    input  wire       valid,
    
    // interface with UART module
    output reg        uart_req,
    output reg  [7:0] uart_data
);
    localparam IDLE        = 2'b00;
    localparam SEND_OPCODE = 2'b01;
    localparam OPCODE_SENT = 2'b10;
    localparam SEND_DATA   = 2'b11;
    
    reg [1:0] state = IDLE;
    reg [7:0] data_latch;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            uart_req <= 0;
        end else begin
            case (state)
                IDLE: begin
                    uart_req <= 0;
                    
                    if (valid) begin
                        data_latch <= data;
                        state <= SEND_OPCODE;
                    end
                end
                
                SEND_OPCODE: begin
                    uart_req <= 1;
                    uart_data <= 8'h03;
                    state <= OPCODE_SENT;
                end
                
                OPCODE_SENT: begin
                    uart_req <= 0;
                    state <= SEND_DATA;
                end
                
                SEND_DATA: begin
                    uart_req <= 1;
                    uart_data <= data_latch;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule