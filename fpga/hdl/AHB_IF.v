///////////////////////////////////////////////////////////////////////////////////////////////////
//-------------------------------------------------------------------------------
//-- Title      : AHB Master Interface
//-------------------------------------------------------------------------------
//-- File       : AHB_IF.v
//-- Author     : Corporate Applications Engineering
//-- Company    : Microsemi Corporation
//-- Device     : IGLOO2
//-- Standard   : Verilog
//-------------------------------------------------------------------------------
//-- Description: This code implementes the AHB master logic to receive the read writes  
//--              from the FIC_0 and does the corresponding read or writes to other blocks.
//-------------------------------------------------------------------------------
//-- Copyright (c) 2013   Microsemi Corporation
//--                      All rights reserved.
//-------------------------------------------------------------------------------
//-- Revisions  : V1.0
//-------------------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////////////////////////////////// 

module AHB_IF_v1( 

// Generic Signals
input      wire         HCLK,
input      wire         HRESETn,

//AHB interface to Logic
input      wire         READ,
input      wire         WRITE,
input      wire  [31:0] ADDR,
input      wire  [7:0]  DATAIN,
output     reg   [7:0]  DATAOUT,


// AHB Side Interfacing with FIC 
output     reg   [31:0] HADDR,
output     reg   [1:0]  HTRANS,
output     reg          HWRITE,
output     wire  [2:0]  HSIZE,
output     wire  [2:0]  HBURST,
output     wire  [3:0]  HPROT,
output     reg   [31:0] HWDATA,

input      wire  [31:0] HRDATA,
input      wire         HREADY,
input      wire  [1:0]  HRESP,

output           [1:0]  RESP_err,
output     reg          AHB_BUSY,
output	   reg			VALID
);

// AHB FSM States
reg [2:0] ahb_fsm_current_state;
parameter [2:0] Idle_1 = 3'b000, Write_FIC_0 = 3'b001, Write_FIC_1 = 3'b010, Write_FIC_2 = 3'b011,
Read_FIC_0 = 3'b100, Read_FIC_1 = 3'b101, Read_FIC_2 = 3'b110;

reg   [7:0]  HWDATA_int; //temporary hold the data
reg   [1:0]  addr_low;

assign RESP_err = HRESP;

assign HBURST = 3'b000;  // single transfer
assign HPROT  = 4'b0011; // data access
assign HSIZE  = 3'b000;  // 8-bit

// FSM That Acts as Master on AHB Bus
// Assuming only Non-Sequential & Idle
always@(posedge HCLK, negedge HRESETn)
begin

	if(HRESETn  == 1'b0)
	    begin
	     HADDR               <=  32'h00000000;
	     HTRANS              <=  2'b00;  
	     HWRITE              <=  1'b0;
	     VALID				 <=	 1'b0;
	     HWDATA              <=  32'h00000000;
	     DATAOUT             <=  8'h00;
	     ahb_fsm_current_state   <=  Idle_1;
         AHB_BUSY                <=  1'b0;
	    end

	else
    	begin
	        case (ahb_fsm_current_state)
	      
	        Idle_1: //0x00
	            begin
					VALID				 <=	 1'b0;
                    
	                if ( WRITE  == 1'b1)
	                  begin
	                    ahb_fsm_current_state       <=  Write_FIC_0;
                        HADDR                       <=  ADDR;                        
                        addr_low                    <=  ADDR[1:0];
                        HWDATA_int                  <=  DATAIN;
                        AHB_BUSY                    <=  1'b1;
	                  end
	                else if ( READ  == 1'b1)
	                  begin
	                    ahb_fsm_current_state       <=  Read_FIC_0;
                        HADDR                       <=  ADDR;    
                        addr_low                    <= ADDR[1:0];
                        AHB_BUSY                    <=  1'b1;
	                  end
	                else
	                  begin
	                    ahb_fsm_current_state       <=  Idle_1;
	                  end
	            end

	        Write_FIC_0: //0x01  					//store the address+control signals and apply to coreahblite
	            begin
    	            HTRANS                     <=  2'b10;    	            
    	            HWRITE                     <=  1'b1;
    	            ahb_fsm_current_state      <=  Write_FIC_1;
	             end
	        
            Write_FIC_1: //0x02 
                 begin
                  if ( HREADY  == 1'b0) 			//keep the address+control signals when slave is not ready yet
                    begin
        	            HTRANS                 <=  2'b10;  
                        ahb_fsm_current_state  <=  Write_FIC_1;
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
                        ahb_fsm_current_state  <=  Write_FIC_2;
                    end
                 end
             Write_FIC_2: //0x03
    	         begin
                  if ( HREADY  == 1'b0) 			//keep the data when slave is not ready yet
                    begin
        	            ahb_fsm_current_state  <=  Write_FIC_2;
                        AHB_BUSY               <=  1'b1;
    	            end
                  else   							//finish the write transfer  
    	            begin 
    	                ahb_fsm_current_state  <=  Idle_1;
                        AHB_BUSY               <=  1'b0;
    	            end
	              end
	           
	
	
	         Read_FIC_0: //0x04 					//store the address+control signals and apply to coreahblite
	              begin
	                    HTRANS                  <=  2'b10; // NONSEQ transfer
	                    HWRITE                  <=  1'b0;
	                    ahb_fsm_current_state   <=  Read_FIC_1;
	              end
	         Read_FIC_1: //0x05
	              begin                   
	               if ( HREADY  == 1'b0) 			//keep the address+control signals when slave is not ready yet
                     begin
	                    ahb_fsm_current_state    <=  Read_FIC_1;
                     end 
                   else   
                     begin   						// go to next state
                        HADDR                    <=  32'h00000000;  //doesn't need to keep the address+other controls any more
                        HTRANS                   <=  2'b00;
	                    ahb_fsm_current_state    <=  Read_FIC_2;
                     end
                  end
             Read_FIC_2: //0x06                         
	              begin
                   if ( HREADY  == 1'b0)         	//waiting slave to be ready 
	                 begin
	                    ahb_fsm_current_state    <=  Read_FIC_2;
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
	                    ahb_fsm_current_state    <=  Idle_1;
                        AHB_BUSY                 <=  1'b0;
	                  end       
	              end 	   
     endcase
	end     
end

endmodule