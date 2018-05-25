

/*****
	
	
	Simple implementation of communication between a FPGA chip and a LCD character display module via the I2C protocol 
	
	
	DISCLAIMER
	
	Not guaranteed to operate correctly or even not to burn out your LCD or your board. Use at your own risk. YMMV.
	
	SETUP INSTRUCTIONS
	
	Tested with a DE10-Nano dev kit and a Newhaven Display NHD-0216K3Z LCD display module 
	(https://www.newhavendisplay.com/specs/NHD-0216K3Z-FL-GBW.pdf)
	
	Wiring:
	
	LCD 6/6 <- VCC5 
	LCD 5/6 <- GND
	LCD 4/6 <- Arduino_IO8
	LCD 3/6 <- Arduino_IO9
	
	Can connect LCD 6/6 and 5/6 to pins 5/8 and 6/8 (counting from the left) of the bottom-left Arduino header
		
	The module seems unable to accept more than ~4 bytes at a time, including the address (so, 3 letters or 1 special + 1 letter).
	
	Although LCD display docs claim that the display can go up to 100 kHz, the highest I've been able to get without occasional errors 
		is 40 kHz (n=160). 
	It seems necessary to insert a long delay after issuing a screen-erase command. Anything less than ~1.2 ms results in lost chars.

	
	Must use SystemVerilog to compile (or replace update_clock() below with a manually unrolled loop)
	
	MODULE INSTRUCTIONS
	
		State 0: Idle. Sets SDA and SCL high and does nothing otherwise. data/len ignored.
		State 1: Feeding. Supply 1+ bytes of data and set 'len' to the number of bytes.
			Automatically emits the start condition if the module was in a closed state.
			Automatically inserts ACK bits after each byte (and ignores responses).
			When done, will pulse 'done' once. You can replace data or change state in response.
		State 2: Waiting. Sets SDA and SCL low and does nothing. data/len ignored.
		State 3: Closing. Emits stop condition. data/len ignored. 
			You may reopen by setting the state to 1 after waiting at least 8*n clocks.
		
	Output rate = input clock / (8*n) where n is the module parameter.	
****/
module i2c_sym(clk,sda,scl,data,len,state, done, n);
input clk;
output reg sda, scl;
input [127:0] data;
input [31:0] len;
input [7:0] state;
output done;

input [31:0] n;

reg[31:0] counter;
reg[31:0] ci;

reg status=0;
reg started=0;
reg stopped=0;

reg[7:0] last_state=0;

reg[31:0] nbyte=0, nbit=0, phase=0;

wire [31:0] START_DELAY, STOP_DELAY;
assign START_DELAY=4*n;
assign STOP_DELAY=4*n;

always @(posedge clk)
begin
	if(state!=last_state
		|| state==0
		|| state==2
		|| (state==1 && nbyte>=len)
		|| (state==3 && stopped))
		begin
			counter<=0;
			ci<=0;
			nbyte<=0;
			nbit<=0;
			phase<=0;
			last_state<=state;
		end
	else if(state==1 && !started)
		begin
			if(counter>=START_DELAY)
				begin
					counter<=0;
					started<=1;
				end
			else
				counter<=counter+1;
		end
	else if(state==3 && !stopped)
		begin
			if(counter>=STOP_DELAY)
				begin
					counter<=0;
					stopped<=1;
				end
			else
				counter<=counter+1;	
		end
	else if(state==1 && nbyte<len)
		begin
			if(counter>=n)
				begin
					ci<=ci+1;
					counter<=0;
					
					phase<=ci & 7;
					if(phase==7) // it just changed to 0
						begin
							if(nbit==8)
								begin
									nbit<=0;
									nbyte<=nbyte+1;
								end
								else
								begin
									nbit<=nbit+1;
								end
						end					
				end
			else
				counter<=counter+1;
		end

	if(state==0)
		begin
			sda<=1;
			scl<=1;
			started<=0;
			stopped<=0;
			status<=0;
		end
	else if(state==2)
		begin
			sda<=0;
			scl<=0;
			stopped<=0;
			status<=0;
		end
	else if(state==3)
		begin
			scl<=1;
			sda<=stopped?1:0;
			started<=0;
		end
	else if(!started)
		begin
			status<=0;
			sda<=0;
			scl<=1;
		end
	else if(nbyte<len)
		begin
			status<=0;
			begin
				scl<=(phase>=3&&phase<=4)?1:0;
				if(nbit==8)
					sda<=0;
				else
					sda<=data[(len-nbyte)*8-nbit-1] & ((phase>=2&&phase<=5) ? 1 : 0);
			end
		end
	else
		begin
			status<=1;
			stopped<=0;
			sda<=0;
			scl<=0;
		end	
end
assign done=status;
endmodule


/****
   
	Straight copy & paste of the Terasic golden top module

// ============================================================================
// Copyright (c) 2015 by Terasic Technologies Inc.
// ============================================================================

****/
module DE10_Nano_golden_top(

      ///////// ADC /////////
      output             ADC_CONVST,
      output             ADC_SCK,
      output             ADC_SDI,
      input              ADC_SDO,

      ///////// ARDUINO /////////
      inout       [15:0] ARDUINO_IO,
      inout              ARDUINO_RESET_N,

      ///////// FPGA /////////
      input              FPGA_CLK1_50,
      input              FPGA_CLK2_50,
      input              FPGA_CLK3_50,

      ///////// GPIO /////////
      inout       [35:0] GPIO_0,
      inout       [35:0] GPIO_1,

      ///////// HDMI /////////
      inout              HDMI_I2C_SCL,
      inout              HDMI_I2C_SDA,
      inout              HDMI_I2S,
      inout              HDMI_LRCLK,
      inout              HDMI_MCLK,
      inout              HDMI_SCLK,
      output             HDMI_TX_CLK,
      output      [23:0] HDMI_TX_D,
      output             HDMI_TX_DE,
      output             HDMI_TX_HS,
      input              HDMI_TX_INT,
      output             HDMI_TX_VS,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C0_SCLK,
      inout              HPS_I2C0_SDAT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// KEY /////////
      input       [1:0]  KEY,

      ///////// LED /////////
      output      [7:0]  LED,

      ///////// SW /////////
      input       [3:0]  SW
);


reg[47:0] clock_range=48'h999995959999;
reg[47:0] curtime=0;

task update_clock;
	input [7:0] m, n;
	reg[31:0] I;
	for(I=m; I<n; I=I+1)
		begin
			if(curtime[I*4+:4]<clock_range[I*4+:4])
				begin
					curtime[I*4+:4]<=curtime[I*4+:4]+1;
					break;
				end							
					else
						curtime[I*4+:4]<=0;
				end	
endtask

reg[31:0] lcd_counter=0;
reg[31:0] lcd_refreshes=0;

reg[127:0] word=0;
reg[31:0] len=4;
reg[7:0] state=0;

reg[31:0] counter=0;

reg[31:0] minute_counter=0;

reg[31:0] hour_counter=0;
reg[31:0] hours=0;
wire done;

reg[31:0] progress=0;
reg[127:0] phrase=0;
reg[127:0] fixed_phrase="I CAN SEE YOU =)";

// with i2c_clk 352, stop signal pause 5000: works at 786k, fails at 655k
//
reg[31:0] interval=2000000;


// start/stop 4N: correct at 352; losing the 'I' at 192..320; losing the 'I C' at 160
// with lag 20k, have correct text at 288
// with lag 40k, start/stop 4N: have correct text at 192; occasional glitches at 128
// with lag 60k, start/stop 2N: occasional glitches at 160, bad at 128
// with lag 60k, start/stop 2N: seemingly correct at 160, glitches at 128
reg[31:0] i2c_clk=160;
reg[31:0] stop_signal=0;

i2c_sym i2c(FPGA_CLK1_50,ARDUINO_IO[8],ARDUINO_IO[9],word,len,state,done, i2c_clk);

always @(posedge FPGA_CLK1_50)
	begin
		if(lcd_refreshes==0)
		begin
			if(progress==0)
				begin
					word<=32'h50FE51; // erase display
					len<=3;
				end
			else if(progress<=8)
			begin
				word[23:16]<=8'h50;
				word[15:0]<=fixed_phrase[(7-(progress-1))*16+:16];						
				len<=3;
			end
		end
	else
		begin
			if(progress==0)
				begin
					word[31:8]<=24'h50FE45; // move cursor to row 2 column 1
					word[7:0]<=8'h40;
					len<=4;
				end
			else if(progress<=8)
				begin
					word[23:16]<=8'h50;
					word[15:0]<=phrase[(7-(progress-1))*16+:16];						
					len<=3;
				end
		end
		
	if(state==1 && done)
		begin
			state<=3;
			stop_signal<=0;
		end
	if(progress<8 && state==3)
		begin
			stop_signal<=stop_signal+1;
			if(stop_signal>=((lcd_refreshes==0 && progress==0) ? 60000 : (i2c_clk<<3)))
				begin
					progress<=progress+1;
					state<=1;
				end
		end


//	i2c_clk <= (SW+1)<<5;
	
	if(lcd_counter>=interval-1)
		begin
			lcd_counter<=0;
			progress<=0;
			state<=1;
			if(lcd_refreshes>=127)
				lcd_refreshes<=0;
			else
				lcd_refreshes<=lcd_refreshes+1;
		end
	else
		lcd_counter<=lcd_counter+1;
	
	counter<=counter+1;
	if(counter>=50000-1)
		begin
			counter<=0;
			
			minute_counter<=minute_counter+1;
			if(minute_counter>=59999)				
				begin
					minute_counter<=0;					
					update_clock(5,7);
					hour_counter<=hour_counter+1;
					if(hour_counter>=59)
						begin
							hour_counter<=0;
							update_clock(7,12);
						end
				end
		
			update_clock(0,5);
		end
		
		begin
			phrase[127:120]<=48+curtime[47:44];			
			phrase[119:112]<=48+curtime[43:40];			
			phrase[111:104]<=48+curtime[39:36];			
			phrase[103:96]<=48+curtime[35:32];
			phrase[95:88]<=48+curtime[31:28];
			phrase[87:80]<=8'h3a;
			phrase[79:72]<=48+curtime[27:24];
			phrase[71:64]<=48+curtime[23:20];
			phrase[63:56]<=8'h3a;
			phrase[55:48]<=48+curtime[19:16];
			phrase[47:40]<=48+curtime[15:12];					
			phrase[39:32]<=8'h3a;
			phrase[31:24]<=48+curtime[11:8];
			phrase[23:16]<=48+curtime[7:4];
			phrase[15:8]<=48+curtime[3:0];
			phrase[7:0]<=8'h20;
		end
	end
		
assign LED=worker_status;


endmodule
