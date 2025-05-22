module uart_fifo_simple #(
    parameter DEPTH = 128
)(
    input  wire clk,
    input  wire rst,
    
    // write interface
    input  wire [7:0] data_in,
    input  wire       write_req,
    
    // interface with UART module
    output reg [7:0]  data_out,
    output reg        valid_out,
    input  wire       uart_busy
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [7:0]            queue[0:DEPTH - 1];
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH-1:0] read_ptr;
    reg [ADDR_WIDTH:0]   count;

    wire empty = (count == 0);
    wire full = (count == DEPTH);
    wire read_en = !empty && !uart_busy && !valid_out;
    
    always @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0;
            read_ptr <= 0;
            data_out <= 0;
            count <= 0;
            valid_out <= 0;
        end else begin
            case ({write_req && !full, read_en})
                2'b01: count <= count - 1;
                2'b10: count <= count + 1;
                // for read and write operation at the same time we don't need to update count
            endcase
        
            if (write_req && !full) begin
                queue[write_ptr] <= data_in;
                write_ptr <= (write_ptr == DEPTH - 1) ? 0 : write_ptr + 1;
            end
        
            if (read_en) begin
                data_out <= queue[read_ptr];
                valid_out <= 1;
                read_ptr <= (read_ptr == DEPTH - 1) ? 0 : read_ptr + 1;
            end else if (!uart_busy) begin
                // clear valid after one cycle
                valid_out <= 0;
            end
        end
    end
endmodule