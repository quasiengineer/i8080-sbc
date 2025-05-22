module i8080_controller( 
    input  wire clk,
    input  wire dev_rst,
    output wire rst,
    output reg i8080_clk_rst,

    // UART
    output reg          uart_tx_req,
    output reg [7:0]    uart_tx_data,
    input wire          uart_tx_busy,
    input wire          uart_rx_valid,
    input wire [7:0]    uart_rx_data,
    input wire          uart_rx_busy,
            
    // SRAM
    input  wire         sram_valid,
    input  wire  [7:0]  sram_datain,
    input  wire         sram_busy,
    output reg          sram_read,
    output reg          sram_write,
    output wire  [15:0] sram_addr,
    output wire  [7:0]  sram_dataout,
    output reg          sram_req,
    
    // i8080
    output reg          i8080_reset,
    input  wire         i8080_clk
);
    // output command opcodes
    localparam CMD_OUT_ACK = 8'h01, CMD_OUT_RESULT = 8'h02;
    
    // input command opcodes
    localparam CMD_IN_WRITE_DUMP = 8'h01, CMD_IN_WRITE_BYTE = 8'h02, CMD_IN_READ_BYTE = 8'h03, CMD_IN_RESET = 8'h04;

    // common command FSM
    localparam CMD_STATE_IDLE = 3'd0, CMD_STATE_READ_DATA = 3'd1, CMD_STATE_READY = 3'd2, CMD_STATE_FINISHED = 3'd3, CMD_STATE_ACKED = 3'd4;
    
    // FSM for READ_DATA command
    localparam CMD_READ_DATA_STATE_RAM_REQ = 4'd0, CMD_READ_DATA_STATE_DATA = 4'd1, 
        CMD_READ_DATA_STATE_UART_OPCODE = 4'd2, CMD_READ_DATA_STATE_UART_OPCODE_SENT = 4'd3, CMD_READ_DATA_STATE_UART_DATA = 4'd4, CMD_READ_DATA_STATE_UART_DATA_SENT = 4'd5;
        
    // FSM for WRITE_DATA command
    localparam CMD_WRITE_DATA_STATE_RAM_REQ = 4'd0, CMD_WRITE_DATA_STATE_DATA = 4'd1;
    
    // FSM for WRITE_DUMP command
    localparam CMD_WRITE_DUMP_STATE_READ_DATA = 4'd0, CMD_WRITE_DUMP_STATE_WRITE_MEM = 4'd1, CMD_WRITE_DUMP_STATE_WRITTEN = 4'd2;
            
    reg [2:0]  in_state;
    reg [3:0]  in_cmd_state;
    reg [7:0]  in_cmd_opcode;
    reg [15:0] in_cmd_addr;
    reg [7:0]  in_cmd_value;
    reg [1:0]  in_byte_count;
    
    reg [15:0] sram_addr_reg;
    reg [7:0]  sram_data_reg;
    
    // signals for RESET signal management for i8080
    reg        reset_i8080_resetting;
    reg [4:0]  reset_i8080_cnt;
    reg        reset_i8080_trigger, reset_i8080_ack, reset_i8080_ack_sync0, reset_i8080_ack_sync1;
    
    assign sram_dataout = sram_data_reg;
    assign sram_addr = sram_addr_reg;
    
    assign rst = !dev_rst;
    
    always @(posedge clk) begin
        if (rst) begin
            sram_read <= 0;
            sram_write <= 0;
            sram_req <= 0;
            uart_tx_data  <= 0;
            uart_tx_req <= 0;
            in_state <= CMD_STATE_IDLE;
            reset_i8080_trigger <= 0;
            i8080_clk_rst <= 1;
        end
        else begin
            case (in_state)
                CMD_STATE_IDLE: begin
                    in_byte_count <= 0;
                    // assume that first state for each command is idle state
                    in_cmd_state <= 0;
                    
                    if (uart_rx_valid) begin
                        in_cmd_opcode <= uart_rx_data;
                        sram_req <= 1;
                        
                        // commands without parameters
                        if (uart_rx_data == CMD_IN_RESET)
                            in_state <= CMD_STATE_READY;
                        else
                            in_state <= CMD_STATE_READ_DATA;
                    end
                end
                
                CMD_STATE_READ_DATA: begin
                    // WRITE_DUMP 0x01 size1 size0 data[N] data[N-1] .... data[1] data[0]
                    if (in_cmd_opcode == CMD_IN_WRITE_DUMP && in_byte_count == 2) begin
                        case (in_cmd_state)
                            CMD_WRITE_DUMP_STATE_READ_DATA: begin
                                if (uart_rx_valid) begin
                                    in_cmd_value <= uart_rx_data;
                                    in_cmd_addr <= in_cmd_addr - 1;
                                    in_cmd_state <= CMD_WRITE_DUMP_STATE_WRITE_MEM;
                                end
                            end
                            
                            CMD_WRITE_DUMP_STATE_WRITE_MEM: begin
                                sram_data_reg <= in_cmd_value;
                                sram_write <= 1;
                                sram_read <= 0;
                                sram_addr_reg <= in_cmd_addr;
                                if (sram_busy == 0) begin
                                    in_cmd_state <= CMD_WRITE_DUMP_STATE_WRITTEN;
                                end    
                            end
                            
                            CMD_WRITE_DUMP_STATE_WRITTEN: begin
                                sram_write <= 0;
                                
                                if (in_cmd_addr == 0)
                                    in_state <= CMD_STATE_FINISHED;
                                else 
                                    in_cmd_state <= CMD_WRITE_DUMP_STATE_READ_DATA;
                            end
                        endcase
                    end
                    else if (uart_rx_valid) begin
                        if (in_byte_count == 0)
                            in_cmd_addr[15:8] <= uart_rx_data;
                        else if (in_byte_count == 1) begin
                            in_cmd_addr[7:0] <= uart_rx_data;
                            if (in_cmd_opcode == CMD_IN_READ_BYTE)
                                in_state <= CMD_STATE_READY;
                        end
                        else begin
                            in_cmd_value <= uart_rx_data;
                            in_state <= CMD_STATE_READY;
                        end

                        in_byte_count <= in_byte_count + 1;
                    end
                end
                
                CMD_STATE_READY: begin
                    case (in_cmd_opcode)
                        // WRITE_BYTE 0x02 addr1 addr0 data0
                        CMD_IN_WRITE_BYTE: begin
                            case (in_cmd_state)
                                CMD_WRITE_DATA_STATE_RAM_REQ: begin
                                    sram_data_reg <= in_cmd_value;
                                    sram_write <= 1;
                                    sram_read <= 0;
                                    sram_addr_reg <= in_cmd_addr;
                                    if (sram_busy == 0) begin
                                        in_cmd_state <= CMD_WRITE_DATA_STATE_DATA;
                                    end                                
                                end
                                
                                CMD_WRITE_DATA_STATE_DATA: begin
                                    sram_write <= 0;
                                    in_state <= CMD_STATE_FINISHED;
                                end                                
                            endcase
                        end
                        
                        // READ_BYTE 0x03 addr1 addr0
                        CMD_IN_READ_BYTE: begin
                            case (in_cmd_state)
                                CMD_READ_DATA_STATE_RAM_REQ: begin
                                    if (sram_busy == 0) begin
                                        sram_addr_reg <= in_cmd_addr;
                                        sram_read <= 1;
                                        in_cmd_state <= CMD_READ_DATA_STATE_DATA;
                                    end                                    
                                end
                                
                                CMD_READ_DATA_STATE_DATA: begin
                                    if (sram_busy == 0 && sram_valid == 1) begin
                                        sram_read <= 0;
                                        in_cmd_value <= sram_datain;
                                        in_cmd_state <= CMD_READ_DATA_STATE_UART_OPCODE;
                                    end     
                                end
                                
                                CMD_READ_DATA_STATE_UART_OPCODE: begin
                                    if (!uart_tx_busy) begin
                                        uart_tx_data <= CMD_OUT_RESULT;
                                        uart_tx_req <= 1;
                                        in_cmd_state <= CMD_READ_DATA_STATE_UART_OPCODE_SENT;
                                    end
                                end
                                
                                CMD_READ_DATA_STATE_UART_OPCODE_SENT: begin
                                    uart_tx_req <= 0;
                                    in_cmd_state <= CMD_READ_DATA_STATE_UART_DATA;
                                end
                                
                                CMD_READ_DATA_STATE_UART_DATA: begin
                                    if (!uart_tx_busy) begin
                                        uart_tx_data <= in_cmd_value;
                                        uart_tx_req <= 1;
                                        in_cmd_state <= CMD_READ_DATA_STATE_UART_DATA_SENT;
                                    end
                                end
                                
                                CMD_READ_DATA_STATE_UART_DATA_SENT: begin
                                    uart_tx_req <= 0;
                                    in_state <= CMD_STATE_FINISHED;
                                end
                            endcase
                        end
                        
                        // RESET 0x04
                        CMD_IN_RESET: begin
                            i8080_clk_rst <= 0;
                            reset_i8080_trigger <= 1;
                            in_state <= CMD_STATE_FINISHED;
                        end                            
                    endcase
                end
                
                CMD_STATE_FINISHED: begin
                    if (!uart_tx_busy) begin
                        uart_tx_data <= CMD_OUT_ACK;
                        uart_tx_req <= 1;
                        in_state <= CMD_STATE_ACKED;
                    end
                end
                
                CMD_STATE_ACKED: begin
                    uart_tx_req <= 0;
                    sram_req <= 0;
                    in_state <= CMD_STATE_IDLE;
                end
            endcase
            
            if (reset_i8080_ack_sync1)
                reset_i8080_trigger <= 0;
        end
    end
    
    always @(posedge clk) begin
        reset_i8080_ack_sync0 <= reset_i8080_ack;
        reset_i8080_ack_sync1 <= reset_i8080_ack_sync0;
    end
    
    // keep RESET signal for 20 CLK1 pulses from i8080
    always @(posedge i8080_clk) begin
        if (rst) begin
            i8080_reset <= 0;
            reset_i8080_resetting <= 0;
            reset_i8080_ack <= 0;
        end 
        else begin
            if (!reset_i8080_resetting) begin
                if (reset_i8080_trigger) begin
                    reset_i8080_ack <= 1;
                    reset_i8080_cnt <= 0;
                    reset_i8080_resetting <= 1;
                    i8080_reset <= 1;
                end
            end
            else begin
                if (reset_i8080_cnt < 20)
                    reset_i8080_cnt <= reset_i8080_cnt + 1;
                else begin
                    i8080_reset <= 0;
                    reset_i8080_resetting <= 0;
                    reset_i8080_ack <= 0;
                end
            end
        end
    end
endmodule