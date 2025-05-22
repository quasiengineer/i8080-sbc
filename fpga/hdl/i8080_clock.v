module i8080_clock( 
    input wire clk, // expects 184.333 Mhz, one tick ~ 5.43ns
    input wire rst,
    
    // to i8080
    output reg CLK1,
    output reg CLK2,
    output reg READY
);

    reg [5:0]  counter;
    
    // 0 .. 59 = 320ns period = 3.125Mhz
    always @(posedge clk) begin
        if (rst)
            counter <= 0;
        else if (counter == 6'd59)
            counter <= 0;
        else
            counter <= counter + 1;
    end
    
    // phi1 high at [0, 50ns] clock interval
    always @(posedge clk) begin
        if (rst)
            CLK1 <= 1;
        else
            CLK1 <= (counter < 6'd9); // ~49ns
    end
  
    // phi2 high at [60ns, 210ns] clock interval
    always @(posedge clk) begin
        if (rst)
            CLK2 <= 1;
        else
            CLK2 <= ((counter >= 6'd11) && (counter < 6'd39)); // ~59ns ... ~206ns
    end

    assign READY = 1;
    
endmodule