module ahb_mux (
    input wire        clk,
    input wire        resetn,

    // Sources (2 modules requesting access)
    input wire [31:0] addr_0,
    input wire [7:0]  data_0,
    input wire        write_0, read_0, req_0,
    input wire [31:0] addr_1,
    input wire [7:0]  data_1,
    input wire        write_1, read_1, req_1,

    // Outputs to AHB Master
    output reg [31:0] ahb_addr,
    output reg [7:0]  ahb_data_out,
    output reg        ahb_write,
    output reg        ahb_read
);

    // Priority-based arbitration (Source 0 has higher priority)
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            ahb_addr     <= 32'b0;
            ahb_data_out <= 8'b0;
            ahb_write    <= 1'b0;
            ahb_read     <= 1'b0;
        end else begin
            if (req_1) begin
                ahb_addr     <= addr_1;
                ahb_data_out <= data_1;
                ahb_write    <= write_1;
                ahb_read     <= read_1;
            end else if (req_0) begin
                ahb_addr     <= addr_0;
                ahb_data_out <= data_0;
                ahb_write    <= write_0;
                ahb_read     <= read_0;
            end else begin
                ahb_write <= 1'b0;
                ahb_read  <= 1'b0;
            end
        end
    end

endmodule