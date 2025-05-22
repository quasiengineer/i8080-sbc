// Multiplexer + clock domain coupler

module esram_controller (
    input  wire        clk,         // 184.333MHz
    input  wire        clk_ahb,     // 55.3MHz
    input  wire        rst,         
    
    // mux for 2 sources
    input  wire [15:0] addr_0,
    input  wire [7:0]  data_0,
    input  wire        write_0, read_0, req_0,
    input  wire [15:0] addr_1,
    input  wire [7:0]  data_1,
    input  wire        write_1, read_1, req_1,
    output reg         busy,
    output reg         valid,

    // interface with ahb master
    output reg [31:0] ahb_addr,
    output reg [7:0]  ahb_data_out,
    output reg        ahb_write,
    output reg        ahb_read,
    input  wire       ahb_valid,
    input  wire       ahb_busy
);
    // signals from fast clock domain to slow AHB clock domain, handshaking mechanic
    reg write_latch, write_ack, write_sync;
    reg read_latch, read_ack, read_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ahb_addr     <= 0;
            ahb_data_out <= 0;
            write_latch  <= 0;
            read_latch   <= 0;
        end 
        else begin
            if (req_1) begin
                ahb_addr        <= 32'h20000000 + addr_1;
                ahb_data_out    <= data_1;
                // latch fast signal
                if (write_1)
                    write_latch <= 1;
                if (read_1)
                    read_latch <= 1;
            end else if (req_0) begin
                ahb_addr        <= 32'h20000000 + addr_0;
                ahb_data_out    <= data_0;
                // latch fast signal
                if (write_0)
                    write_latch <= 1;
                if (read_0)
                    read_latch <= 1;
            end
            
            // clear after acknowledge
            if (write_ack)
                write_latch <= 0;
                
            if (read_ack)
                read_latch <= 0;
        end
    end


    always @(posedge clk_ahb or posedge rst) begin
        if (rst) begin
            ahb_write  <= 0;
            ahb_read   <= 0;
            write_sync <= 0;
            read_sync  <= 0;
            write_ack  <= 0;
            read_ack   <= 0;
        end else begin
            write_sync <= write_latch;
            read_sync  <= read_latch;

            // generate one-cycle pulse in slow domain
            ahb_write <= write_sync & ~write_ack;
            ahb_read  <= read_sync & ~read_ack;

            // acknowledge reception
            if (ahb_write) 
                write_ack <= 1;
            if (ahb_read)  
                read_ack  <= 1;

            // reset acknowledgment after one cycle
            if (!write_sync) 
                write_ack <= 0;
            if (!read_sync)  
                read_ack  <= 0;
        end
    end

    // signals from AHB slow clock domain to fast clock domain, two-flip-flop mechanic
    reg ahb_busy_sync1, ahb_busy_sync2;
    reg ahb_valid_sync1, ahb_valid_sync2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ahb_busy_sync1  <= 0;
            ahb_busy_sync2  <= 0;
            ahb_valid_sync1 <= 0;
            ahb_valid_sync2 <= 0;
        end else begin
            ahb_busy_sync1  <= ahb_busy;
            ahb_busy_sync2  <= ahb_busy_sync1;
            ahb_valid_sync1 <= ahb_valid;
            ahb_valid_sync2 <= ahb_valid_sync1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy  <= 0;
            valid <= 0;
        end else begin
            busy  <= ahb_busy_sync2;
            valid <= ahb_valid_sync2;
        end
    end
endmodule
