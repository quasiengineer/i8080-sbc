module i8080_memory( 
    input wire clk,
    input wire rst,
    
    // i8080 interface
    inout  wire [7:0]  i8080_data,
    input  wire [15:0] i8080_addr,
    input  wire        i8080_sync,
    input  wire        i8080_dbin,
    input  wire        i8080_wr,
    input  wire        i8080_clk2,
    
    // sram
    input  wire        sram_valid,
    input  wire [7:0]  sram_datain,
    input  wire        sram_busy,
    output reg         sram_read,
    output reg         sram_write,
    output wire [15:0] sram_addr,
    output wire [7:0]  sram_dataout,
    output reg         sram_req,
    
    // IO output
    output reg         output_valid,
    output reg [7:0]   output_data,
    
    // test outputs
    output reg         tst0
);
    // main FSM states
    localparam STATE_IDLE                       = 4'b0000;
    localparam STATE_WAIT_STATUS                = 4'b0001;
    localparam STATE_READ_SRAM                  = 4'b0010;
    localparam STATE_LATCH_SRAM_DATA            = 4'b0011;
    localparam STATE_SEND_DATA_TO_CPU           = 4'b0100;
    localparam STATE_FREE_DATA_BUS              = 4'b0101;
    localparam STATE_LATCH_DATA_TO_WRITE        = 4'b0110;
    localparam STATE_WRITE_DATA_START           = 4'b0111;
    localparam STATE_WRITE_DATA_FINISH          = 4'b1000;
    localparam STATE_OUTPUT_DATA_START          = 4'b1001;
    localparam STATE_OUTPUT_DATA_FINISH         = 4'b1010;
    localparam STATE_CHECK_STATUS               = 4'b1011;
        
    reg [3:0]  state;

    reg [7:0]  sram_data_latched;
    reg [15:0] i8080_addr_latched;
    reg [7:0]  i8080_data_latched;
    reg [7:0]  i8080_status_latched;
    reg        data_output_enable;
    reg [39:0] clocks;

    assign i8080_data = data_output_enable ? sram_data_latched : 8'bZ;
    assign sram_addr = i8080_addr_latched;
    assign sram_dataout = i8080_data_latched;
    
    // even if i8080_clk2 from same clock domain, worth to sync it
    reg clk2_sync;
    always @(posedge clk) begin
        clk2_sync <= i8080_clk2;
    end
    
    // synchronization of external signals from i8080 via two flip-flops
    reg i8080_sync_1tick_before, i8080_sync_2tick_before;
    reg i8080_dbin_sync0, i8080_dbin_sync1;
    reg i8080_wr_sync0, i8080_wr_sync1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i8080_sync_1tick_before <= 0;
            i8080_sync_2tick_before <= 0;
            i8080_dbin_sync0 <= 0;
            i8080_dbin_sync1 <= 0;
            i8080_wr_sync0 <= 0;
            i8080_wr_sync1 <= 0;
        end else begin
            i8080_sync_1tick_before <= i8080_sync; 
            i8080_sync_2tick_before <= i8080_sync_1tick_before;
            i8080_dbin_sync0 <= i8080_dbin; 
            i8080_dbin_sync1 <= i8080_dbin_sync0;
            i8080_wr_sync0 <= i8080_wr; 
            i8080_wr_sync1 <= i8080_wr_sync0;
        end
    end

    wire i8080_sync_rise = i8080_sync_1tick_before && !i8080_sync_2tick_before;
    wire i8080_clk2_rise = i8080_clk2 && !clk2_sync;
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            clocks <= 0;
        else if (i8080_clk2_rise)
            clocks <= clocks + 1;
    end
    
    // main FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            output_valid <= 0;
            data_output_enable <= 0;
        end
        else
            case (state)
                STATE_IDLE: begin
                    if (i8080_sync_rise)
                        state <= STATE_WAIT_STATUS;
                end
                
                STATE_WAIT_STATUS: begin
                    if (!clk2_sync) begin
                        i8080_status_latched <= i8080_data;
                        i8080_addr_latched <= i8080_addr;
                        state <= STATE_CHECK_STATUS;
                    end
                end
                
                STATE_CHECK_STATUS: begin
                    if (i8080_status_latched[3] == 1) // HLTA
                        state <= STATE_IDLE;
                    else if (i8080_status_latched[7] == 1) // memory read
                        state <= STATE_READ_SRAM;
                    else if (i8080_status_latched[1] == 0) // memory write or output
                        state <= STATE_LATCH_DATA_TO_WRITE;
                    else
                        state <= STATE_IDLE;
                end
                
                STATE_READ_SRAM: begin
                    if (i8080_addr_latched == 16'hF880 || i8080_addr_latched == 16'hF881 || i8080_addr_latched == 16'hF882 || i8080_addr_latched == 16'hF883 || i8080_addr_latched == 16'hF884) begin
                        state <= STATE_LATCH_SRAM_DATA;
                    end else if (sram_busy == 0) begin
                        sram_read <= 1;
                        sram_req <= 1;
                        sram_write <= 0;
                        state <= STATE_LATCH_SRAM_DATA;
                    end   
                end
                
                STATE_LATCH_SRAM_DATA: begin
                    case (i8080_addr_latched)
                        16'hF880: begin
                            sram_data_latched <= clocks[7:0];
                            state <= STATE_SEND_DATA_TO_CPU;
                        end
                        
                        16'hF881: begin
                            sram_data_latched <= clocks[15:8];
                            state <= STATE_SEND_DATA_TO_CPU;
                        end
                        
                        16'hF882: begin
                            sram_data_latched <= clocks[23:16];
                            state <= STATE_SEND_DATA_TO_CPU;
                        end
                        
                        16'hF883: begin
                            sram_data_latched <= clocks[31:24];
                            state <= STATE_SEND_DATA_TO_CPU;
                        end
                        
                        16'hF884: begin
                            sram_data_latched <= clocks[39:32];
                            state <= STATE_SEND_DATA_TO_CPU;
                        end

                        default:
                            if (sram_busy == 0 && sram_valid == 1) begin
                                sram_read <= 0;
                                sram_req <= 0;
                                sram_data_latched <= sram_datain;
                                state <= STATE_SEND_DATA_TO_CPU;
                            end  
                    endcase   
                end
                
                STATE_SEND_DATA_TO_CPU: begin
                    if (i8080_dbin_sync1) begin
                        data_output_enable <= 1;
                        state <= STATE_FREE_DATA_BUS;
                    end
                end
                
                STATE_FREE_DATA_BUS: begin
                    if (!i8080_dbin_sync1) begin
                        data_output_enable <= 0;
                        state <= STATE_IDLE;
                    end
                end
                
                STATE_LATCH_DATA_TO_WRITE: begin
                    if (!i8080_wr_sync1) begin
                        i8080_data_latched <= i8080_data;
                        state <= i8080_status_latched[4] == 1 ? STATE_OUTPUT_DATA_START : STATE_WRITE_DATA_START;
                    end
                end
                
                STATE_WRITE_DATA_START: begin
                    if (sram_busy == 0) begin
                        sram_req <= 1;
                        sram_read <= 0;
                        sram_write <= 1;
                        state <= STATE_WRITE_DATA_FINISH;
                    end
                end
                
                STATE_WRITE_DATA_FINISH: begin
                    sram_write <= 0;
                    sram_req <= 0;
                    state <= STATE_IDLE;
                end
                
                STATE_OUTPUT_DATA_START: begin
                    output_valid <= 1;
                    output_data <= i8080_data_latched;
                    state <= STATE_OUTPUT_DATA_FINISH;
                end
                                
                STATE_OUTPUT_DATA_FINISH: begin
                    output_valid <= 0;
                    state <= STATE_IDLE;
                end
            endcase
    end
endmodule

