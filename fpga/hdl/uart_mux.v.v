module uart_mux(
    input  wire [7:0]  data0,
    input  wire        req0,
    input  wire [7:0]  data1,
    input  wire        req1,
    
    output reg  [7:0]  uart_data,
    output reg         uart_req
);

    always @(*) begin
        if (req0) begin
            uart_data = data0;
            uart_req = 1;
        end 
        else if (req1) begin
            uart_data = data1;
            uart_req = 1;
        end
        else
            uart_req = 0;
    end

endmodule