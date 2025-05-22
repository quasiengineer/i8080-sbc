module ahb_master( 
    input  wire         clk,
    input  wire         resetn,

    // logic interface
    input  wire         ahb_read,
    input  wire         ahb_write,
    input  wire  [31:0] ahb_addr,
    input  wire  [7:0]  ahb_datain,
    output reg   [7:0]  ahb_dataout,
    output reg			ahb_valid,
    output wire  [1:0]  ahb_resp,
    output reg          ahb_busy,


    // FIC interface
    output reg   [31:0] HADDR,
    output reg   [1:0]  HTRANS,
    output reg          HWRITE,
    output wire  [2:0]  HSIZE,
    output wire  [2:0]  HBURST,
    output wire  [3:0]  HPROT,
    output reg   [31:0] HWDATA,
    input  wire  [31:0] HRDATA,
    input  wire         HREADY,
    input  wire  [1:0]  HRESP
);

    reg [2:0] current_state;
    
    localparam [2:0] STATE_IDLE = 3'b000, 
        STATE_WRITE_0 = 3'b001, STATE_WRITE_1 = 3'b010, STATE_WRITE_2 = 3'b011, 
        STATE_READ_0 = 3'b100, STATE_READ_1 = 3'b101, STATE_READ_2 = 3'b110;

    reg [7:0] datain;
    reg [1:0] addr_low;

    assign ahb_resp = HRESP;

    assign HBURST = 3'b000;  // single transfer
    assign HPROT  = 4'b0011; // data access
    assign HSIZE  = 3'b000;  // 8-bit

    always@(posedge clk, negedge resetn)
    begin
        if (resetn == 0) begin
            HADDR <= 32'h00000000;
            HTRANS <= 2'b00;  
            HWRITE <= 0;
            HWDATA <= 32'h00000000;
            DATAOUT <= 8'h00;
            current_state <= STATE_IDLE;
            
            ahb_busy <= 0;
            ahb_valid <= 0;
        end

        else
            begin
                case (current_state)
              
                Idle_1: //0x00
                    begin
                        VALID				 <=	 1'b0;
                        
                        if ( WRITE  == 1'b1)
                          begin
                            current_state       <=  Write_FIC_0;
                            HADDR                       <=  ADDR;                        
                            addr_low                    <=  ADDR[1:0];
                            HWDATA_int                  <=  DATAIN;
                            AHB_BUSY                    <=  1'b1;
                          end
                        else if ( READ  == 1'b1)
                          begin
                            current_state       <=  Read_FIC_0;
                            HADDR                       <=  ADDR;    
                            addr_low                    <= ADDR[1:0];
                            AHB_BUSY                    <=  1'b1;
                          end
                        else
                          begin
                            current_state       <=  Idle_1;
                          end
                    end

                Write_FIC_0: //0x01  					//store the address+control signals and apply to coreahblite
                    begin
                        HTRANS                     <=  2'b10;    	            
                        HWRITE                     <=  1'b1;
                        current_state      <=  Write_FIC_1;
                     end
                
                Write_FIC_1: //0x02 
                     begin
                      if ( HREADY  == 1'b0) 			//keep the address+control signals when slave is not ready yet
                        begin
                            HTRANS                 <=  2'b10;  
                            current_state  <=  Write_FIC_1;
                        end
                      else  							//send the data+go to next state, doesn't need to keep the address+other controls active
                        begin
                            case (addr_low)
                                2'b00: HWDATA <= {24'b0, HWDATA_int}; 
                                2'b01: HWDATA <= {16'b0, HWDATA_int, 8'b0};
                                2'b10: HWDATA <= {8'b0, HWDATA_int, 16'b0};
                                2'b11: HWDATA <= {HWDATA_int, 24'b0}; 
                            endcase
                            HADDR                  <=  32'h00000000; 
                            HTRANS                 <=  2'b00;
                            HWRITE                 <=  1'b0;
                            current_state  <=  Write_FIC_2;
                        end
                     end
                 Write_FIC_2: //0x03
                     begin
                      if ( HREADY  == 1'b0) 			//keep the data when slave is not ready yet
                        begin
                            current_state  <=  Write_FIC_2;
                            AHB_BUSY               <=  1'b1;
                        end
                      else   							//finish the write transfer  
                        begin 
                            current_state  <=  Idle_1;
                            AHB_BUSY               <=  1'b0;
                        end
                      end
                   
        
        
                 Read_FIC_0: //0x04 					//store the address+control signals and apply to coreahblite
                      begin
                            HTRANS                  <=  2'b10; // NONSEQ transfer
                            HWRITE                  <=  1'b0;
                            current_state   <=  Read_FIC_1;
                      end
                 Read_FIC_1: //0x05
                      begin                   
                       if ( HREADY  == 1'b0) 			//keep the address+control signals when slave is not ready yet
                         begin
                            current_state    <=  Read_FIC_1;
                         end 
                       else   
                         begin   						// go to next state
                            HADDR                    <=  32'h00000000;  //doesn't need to keep the address+other controls any more
                            HTRANS                   <=  2'b00;
                            current_state    <=  Read_FIC_2;
                         end
                      end
                 Read_FIC_2: //0x06                         
                      begin
                       if ( HREADY  == 1'b0)         	//waiting slave to be ready 
                         begin
                            current_state    <=  Read_FIC_2;
                            AHB_BUSY                 <=  1'b1;
                         end
                       else  							//read the data+finish the read transfer
                         begin
                            case (addr_low)
                                2'b00: DATAOUT <= HRDATA[7:0];
                                2'b01: DATAOUT <= HRDATA[15:8];
                                2'b10: DATAOUT <= HRDATA[23:16];
                                2'b11: DATAOUT <= HRDATA[31:24];
                            endcase
                            
                            VALID				 	 <=	 1'b1;                       
                            current_state    <=  Idle_1;
                            AHB_BUSY                 <=  1'b0;
                          end       
                      end 	   
         endcase
        end     
    end

endmodule