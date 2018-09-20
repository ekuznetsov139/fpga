


// Exposes a small amount (32 dwords) of on-chip RAM through the HPS->FPGA bridge
// Anything written into it would be visible on the HPS side through /dev/mem starting at C000_0000
module mmap_buffer(clk, rden, wren, addr, writedata, readdata, data_valid, 
	local_contents, current_contents, local_mask);

	parameter N=32;
	input clk;
	input rden;
	input wren;
	input [7:0] addr;
	input [31:0] writedata;
	output [31:0] readdata;
	output data_valid;
	input [32*N-1:0] local_contents;
	output [32*N-1:0] current_contents;
	input [N-1:0] local_mask;
	
	reg[31:0] storage[N-1:0];
	reg[31:0] response=0;
	reg response_valid=0;
	assign data_valid = response_valid;
	assign readdata = response; 
	
	generate
	genvar g;
	for(g=0; g<N; g=g+1) begin : xx
		assign current_contents[g*32+:32]=storage[g];
	end
	endgenerate
	
	reg write_request=0;
	reg[31:0] write_remote_data=0;
	reg[4:0] write_remote_dword=0;
	
	reg[9:0] I;
	initial begin
		for(I=0; I<N; I=I+1)
			storage[I]<=0;
	end
	reg reg_rden;
	(* maxfan=64 *) reg[$clog2(N)-1:0] reg_addr;
	(* maxfan=64 *) reg[$clog2(N)-3:0] reg_addr_2;

	
	reg [31:0] part_response[7:0];
	reg reg_rden_2=0;
	
	always@(posedge clk)
	begin
	
		if(wren && addr<N)
			begin
			write_request<=1;
			write_remote_data<=writedata;
			write_remote_dword<=addr[4:0];
			end
		else
			write_request<=0;
		
		for(I=0; I<N; I=I+1)
			if(local_mask[I])
				storage[I] <= local_contents[32*I+:32];
			else if(write_request && I==write_remote_dword)
				storage[I] <= write_remote_data;
					
		reg_rden<=rden;
		reg_addr<=addr[$clog2(N)-1:0];
		
		for(I=0; I<8; I=I+1)
			part_response[I]<=storage[I*4+(reg_addr & 3)];
		
		reg_addr_2 <= reg_addr >> 2;
		reg_rden_2 <= reg_rden;
		
		response <= part_response[reg_addr_2];
		response_valid <= reg_rden_2;
		
		//response<=storage[reg_addr];
		//response_valid<=reg_rden;
	end
endmodule



module pmk_de10_nano(

	//////////// CLOCK //////////
	input 		          		FPGA_CLK1_50,
	input 		          		FPGA_CLK2_50,
	input 		          		FPGA_CLK3_50,

	//////////// HDMI //////////
	inout 		          		HDMI_I2C_SCL,
	inout 		          		HDMI_I2C_SDA,
	inout 		          		HDMI_I2S,
	inout 		          		HDMI_LRCLK,
	inout 		          		HDMI_MCLK,
	inout 		          		HDMI_SCLK,
	output		          		HDMI_TX_CLK,
	output		    [23:0]		HDMI_TX_D,
	output		          		HDMI_TX_DE,
	output		          		HDMI_TX_HS,
	input 		          		HDMI_TX_INT,
	output		          		HDMI_TX_VS,

	//////////// HPS //////////
	inout 		          		HPS_CONV_USB_N,
	output		    [14:0]		HPS_DDR3_ADDR,
	output		     [2:0]		HPS_DDR3_BA,
	output		          		HPS_DDR3_CAS_N,
	output		          		HPS_DDR3_CK_N,
	output		          		HPS_DDR3_CK_P,
	output		          		HPS_DDR3_CKE,
	output		          		HPS_DDR3_CS_N,
	output		     [3:0]		HPS_DDR3_DM,
	inout 		    [31:0]		HPS_DDR3_DQ,
	inout 		     [3:0]		HPS_DDR3_DQS_N,
	inout 		     [3:0]		HPS_DDR3_DQS_P,
	output		          		HPS_DDR3_ODT,
	output		          		HPS_DDR3_RAS_N,
	output		          		HPS_DDR3_RESET_N,
	input 		          		HPS_DDR3_RZQ,
	output		          		HPS_DDR3_WE_N,
	output		          		HPS_ENET_GTX_CLK,
	inout 		          		HPS_ENET_INT_N,
	output		          		HPS_ENET_MDC,
	inout 		          		HPS_ENET_MDIO,
	input 		          		HPS_ENET_RX_CLK,
	input 		     [3:0]		HPS_ENET_RX_DATA,
	input 		          		HPS_ENET_RX_DV,
	output		     [3:0]		HPS_ENET_TX_DATA,
	output		          		HPS_ENET_TX_EN,
	inout 		          		HPS_GSENSOR_INT,
	inout 		          		HPS_I2C0_SCLK,
	inout 		          		HPS_I2C0_SDAT,
	inout 		          		HPS_I2C1_SCLK,
	inout 		          		HPS_I2C1_SDAT,
	inout 		          		HPS_KEY,
	inout 		          		HPS_LED,
	inout 		          		HPS_LTC_GPIO,
	output		          		HPS_SD_CLK,
	inout 		          		HPS_SD_CMD,
	inout 		     [3:0]		HPS_SD_DATA,
	output		          		HPS_SPIM_CLK,
	input 		          		HPS_SPIM_MISO,
	output		          		HPS_SPIM_MOSI,
	inout 		          		HPS_SPIM_SS,
	input 		          		HPS_UART_RX,
	output		          		HPS_UART_TX,
	input 		          		HPS_USB_CLKOUT,
	inout 		     [7:0]		HPS_USB_DATA,
	input 		          		HPS_USB_DIR,
	input 		          		HPS_USB_NXT,
	output		          		HPS_USB_STP,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [7:0]		LED,
	
	//////////// ARDUINO //////////
	inout 		    [15:0]		ARDUINO_IO,
	inout 		          		ARDUINO_RESET_N,


	//////////// SW //////////
	input 		     [3:0]		SW
);

	



//=======================================================
//  REG/WIRE declarations
//=======================================================
  wire  hps_fpga_reset_n;
  wire [6:0]  fpga_led_internal=0;
  wire [2:0]  hps_reset_req;
  wire        hps_cold_reset=0;
  wire        hps_warm_reset;
  wire        hps_debug_reset;
  wire [27:0] stm_hw_events;
  assign stm_hw_events    = {{15{1'b0}}, SW, fpga_led_internal, 2'b0};

  wire proc_clk;

  reg[63:0] counter=0; 
  reg[63:0] active_counter=0;


wire mm_bridge_2_s0_waitrequest;
wire [31:0] mm_bridge_2_s0_readdata;
wire        mm_bridge_2_s0_readdatavalid;
reg [31:0] mm_bridge_2_s0_writedata=0;
reg [31:0] mm_bridge_2_s0_address=0;
reg mm_bridge_2_s0_write=0;
reg mm_bridge_2_s0_read=0;
//reg mm_bridge_2_s0_read_requested=0;
//reg mm_bridge_2_s0_write_requested=0;

reg[31:0] fifo_read_offset= 32'h20000000;
reg[26:0] fifo_read_address=0;

reg[31:0] fifo_write_offset=32'h28000000;
reg[26:0] fifo_write_address=0;

wire status_mm_write;
wire status_mm_read;
wire[7:0] status_mm_address;
wire[31:0] status_mm_readdata, status_mm_writedata;
wire status_mm_readdatavalid;


reg[255:0] extra_data=0;
reg[1:0] ext_mode=0;

wire[1023:0] local_contents, current_contents;

mmap_buffer #(32) cfg(
	.clk(proc_clk),
	.rden(status_mm_read),
	.wren(status_mm_write),
	.addr(status_mm_address),
	.readdata(status_mm_readdata),
	.writedata(status_mm_writedata),
	.data_valid(status_mm_readdatavalid),
	.local_contents(local_contents),
	.current_contents(current_contents),
	.local_mask(32'b111111111111000111)
		);
	
reg[31:0] pll_counter=0;
reg pll_led=0;

always @(posedge proc_clk)
	begin
	if(pll_counter!=200000000)
		pll_counter<=pll_counter+1;
	else
		begin
		pll_counter<=0;
		pll_led<=~pll_led;
		end
	end

assign LED[0]=pll_led;

wire[31:0] disp_status; 

/*
reg pmk_reset=0;
reg user_r_read_32_rden;
reg user_w_write_32_wren;
(* preserve *) reg [31:0] user_w_write_32_data;

wire user_r_read_32_empty;
wire [31:0] user_r_read_32_data;
wire user_w_write_32_full;

pmk_dispatcher_daisy #(3,240) disp(proc_clk, 
		user_r_read_32_rden,
		user_r_read_32_empty, 
		user_r_read_32_data,
		user_w_write_32_wren, 
		user_w_write_32_full, 
		user_w_write_32_data,
		pmk_reset,
		disp_status
		);
*/
	
	
parameter N=4;
parameter Njobs=120;

reg[31:0] core_addr, core_data_in;
wire[31:0] core_data_out;
reg core_rden, core_wren;
wire core_readdatavalid, core_done;

reg[31:0] I;

initial begin
	core_addr<=0;
	core_rden<=0;
	core_wren<=0;
end

assign LED[7]=core_done;

pmk_calc_direct_feed_multicore #(N,Njobs,4096) core(
		.core_clk(proc_clk), 
		.addr(core_addr[16:0]),
		.rden(core_rden),
		.wren(core_wren),
		.data_in(core_data_in),
		.data_out(core_data_out),
		.readdatavalid(core_readdatavalid),
		.ext_mode(ext_mode),
		.done(core_done),
		.disp_status(disp_status)
		);

reg[3:0] write_inst=0;
reg[1:0] write_comp=0;
reg[7:0] write_row=0;
reg[2:0] write_col=0;

parameter NWCoreIn = N*Njobs*3*5;
parameter NWCoreOut = N*Njobs*5;
parameter logNW = $clog2(NWCoreIn);
reg[logNW-1:0] write_count=0, ddr_read_count=0;
reg core_full=0, core_full_delay=0, source_empty=0;

reg[3:0] read_inst=0;
reg[7:0] read_row=0;
reg[2:0] read_col=0;
reg[31:0] read_count=0;
reg queued_request=0;
reg core_empty=0;
reg source_memory_empty=0;
reg full_reset=0;
reg[3:0] full_reset_count = 0;

reg mm_bridge_2_s0_writedata_valid=0;

reg [2:0] mm_bridge_2_s0_burstcount=0;

assign local_contents = {
				448'b0,
				extra_data, active_counter, counter, 96'b0, 
				disp_status[23:0],
				queued_request, ext_mode,
				1'b0, mm_bridge_2_s0_waitrequest, 1'b0,
				mm_bridge_2_s0_read, mm_bridge_2_s0_write,
				5'b0, fifo_read_address, 5'b0, fifo_write_address};

				
				
always @(posedge proc_clk)
	begin

	if(current_contents[99:96]!=full_reset_count)
		begin
		full_reset<=1;
		ext_mode<=3;
		//source_memory_empty<=0;
		full_reset_count<=current_contents[99:96];
		end
	
		counter<=counter+1;
		if(ext_mode==1)
			active_counter<=active_counter+1;
		source_memory_empty<=(fifo_read_address >= Njobs*N*60*1000);
		
		extra_data[31:0] <= ddr_read_count;
		extra_data[63:32] <= write_count;
		extra_data[95:64] <= read_count;
		extra_data[127:96]<={28'b0,full_reset_count};
		if(ext_mode==0)
			begin
			if(!source_empty && !mm_bridge_2_s0_waitrequest)
				begin
				mm_bridge_2_s0_read<=1;
				mm_bridge_2_s0_burstcount<=4;
				mm_bridge_2_s0_address<=fifo_read_offset|{5'b0,fifo_read_address};
				fifo_read_address<=fifo_read_address+16;
				ddr_read_count<=ddr_read_count+4;
				source_empty<=(ddr_read_count==NWCoreIn-4);
				end
			else if(!mm_bridge_2_s0_waitrequest)
				mm_bridge_2_s0_read<=0;

			if(mm_bridge_2_s0_readdatavalid && !core_full)
				begin
				core_data_in <= mm_bridge_2_s0_readdata;
				core_wren<=1;
				
				core_addr[16:13] <= write_inst[3:0];
				core_addr[12] <= (write_comp!=0) ? 1 : 0;
				core_addr[2:0] <= write_col;
				core_addr[11:3] <= (write_comp==2) ? (write_row+Njobs) : write_row;
				write_count<=write_count+1;
				if(write_col!=4)
					write_col<=write_col+1;
				else if(write_col==4 && write_row!=Njobs-1)
					begin
					write_col<=0;
					write_row<=write_row+1;
					end
				else
					begin
					write_col<=0;
					write_row<=0;
					if(write_comp!=2)
						write_comp<=write_comp+1;
					else
						begin
						write_comp<=0;
						write_inst<=write_inst+1;
						end
					end
				core_full <= (write_count==NWCoreIn-1);
				end
			else
				core_wren<=0;
			end
		else
			begin
			mm_bridge_2_s0_read<=0;
			core_wren<=0;
			end
			
		core_full_delay <= core_full;
		if(ext_mode==0 && core_full_delay)
			ext_mode<=1;
			
		if(ext_mode==1 && core_done)
			ext_mode<=2;
			
		if(ext_mode==2)
			begin
			if(read_count==NWCoreOut && !source_memory_empty && !queued_request)
				ext_mode<=3;
			if(!core_empty && !queued_request)
				begin
				queued_request<=1;
				core_rden <= 1;
				core_addr <= read_inst*8192 + read_row*8 + read_col;
				read_count<=read_count+1;
				core_empty <= (read_count==NWCoreOut-1);
				if(read_col==4)
					begin
					read_col<=0;
					if(read_row!=Njobs-1)
						read_row<=read_row+1;
					else
						begin
						read_row<=0;
						read_inst<=read_inst+1;						
						end
					end		
				else
					read_col<=read_col+1;						
				end
			else
				core_rden<=0;

			if(core_readdatavalid)	
				mm_bridge_2_s0_writedata <= core_data_out;
				
			if(!mm_bridge_2_s0_waitrequest)
				begin
				if(core_readdatavalid || mm_bridge_2_s0_writedata_valid)
					begin
					mm_bridge_2_s0_write<=1;
					mm_bridge_2_s0_burstcount<=1;
					mm_bridge_2_s0_address<=fifo_write_offset|{5'b0,fifo_write_address};
					fifo_write_address<=fifo_write_address+4;
					mm_bridge_2_s0_writedata_valid <=0;
					end
				else 
					mm_bridge_2_s0_write<=0;
				if(mm_bridge_2_s0_write)
					queued_request<=0;
				end
			else  if(core_readdatavalid)	
				begin
				mm_bridge_2_s0_writedata_valid<=1;
				end

			end
		else
			begin
			core_rden<=0;
			mm_bridge_2_s0_write<=0;
			end

		if(ext_mode==3)
			begin
			if(full_reset)
				begin
				fifo_read_address<=0;
				fifo_write_address<=0;				
				end
			full_reset<=0;
			//partial_reset<=0;
			core_full<=0;
			core_full_delay<=0;
			source_empty<=0;
			source_memory_empty<=0;
			core_empty<=0;
			read_row<=0;
			read_col<=0;
			read_count<=0;
			write_count<=0;
			write_comp<=0;
			write_row<=0;
			write_col<=0;
			read_inst<=0;
			write_inst<=0;
			ddr_read_count<=0;
			queued_request<=0;
			mm_bridge_2_s0_writedata_valid<=0;
			ext_mode<=0;
			end	
	end
 
	
//=======================================================
//  Structural coding
//=======================================================
soc_system u0 (
		//Clock&Reset
	  .clk_clk                               (FPGA_CLK1_50 ),                               //                            clk.clk
	  .reset_reset_n                         (hps_fpga_reset_n ),                         //                          reset.reset_n
	  //HPS ddr3
	  .memory_mem_a                          ( HPS_DDR3_ADDR),                       //                memory.mem_a
	  .memory_mem_ba                         ( HPS_DDR3_BA),                         //                .mem_ba
	  .memory_mem_ck                         ( HPS_DDR3_CK_P),                       //                .mem_ck
	  .memory_mem_ck_n                       ( HPS_DDR3_CK_N),                       //                .mem_ck_n
	  .memory_mem_cke                        ( HPS_DDR3_CKE),                        //                .mem_cke
	  .memory_mem_cs_n                       ( HPS_DDR3_CS_N),                       //                .mem_cs_n
	  .memory_mem_ras_n                      ( HPS_DDR3_RAS_N),                      //                .mem_ras_n
	  .memory_mem_cas_n                      ( HPS_DDR3_CAS_N),                      //                .mem_cas_n
	  .memory_mem_we_n                       ( HPS_DDR3_WE_N),                       //                .mem_we_n
	  .memory_mem_reset_n                    ( HPS_DDR3_RESET_N),                    //                .mem_reset_n
	  .memory_mem_dq                         ( HPS_DDR3_DQ),                         //                .mem_dq
	  .memory_mem_dqs                        ( HPS_DDR3_DQS_P),                      //                .mem_dqs
	  .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N),                      //                .mem_dqs_n
	  .memory_mem_odt                        ( HPS_DDR3_ODT),                        //                .mem_odt
	  .memory_mem_dm                         ( HPS_DDR3_DM),                         //                .mem_dm
	  .memory_oct_rzqin                      ( HPS_DDR3_RZQ),                        //                .oct_rzqin                                  
	  //HPS ethernet		
	  .hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK),       //                             hps_0_hps_io.hps_io_emac1_inst_TX_CLK
	  .hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),   //                             .hps_io_emac1_inst_TXD0
	  .hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),   //                             .hps_io_emac1_inst_TXD1
	  .hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),   //                             .hps_io_emac1_inst_TXD2
	  .hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),   //                             .hps_io_emac1_inst_TXD3
	  .hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),   //                             .hps_io_emac1_inst_RXD0
	  .hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),         //                             .hps_io_emac1_inst_MDIO
	  .hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),         //                             .hps_io_emac1_inst_MDC
	  .hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV),         //                             .hps_io_emac1_inst_RX_CTL
	  .hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN),         //                             .hps_io_emac1_inst_TX_CTL
	  .hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK),        //                             .hps_io_emac1_inst_RX_CLK
	  .hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),   //                             .hps_io_emac1_inst_RXD1
	  .hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),   //                             .hps_io_emac1_inst_RXD2
	  .hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),   //                             .hps_io_emac1_inst_RXD3		  
	  //HPS SD card 
	  .hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD    ),           //                               .hps_io_sdio_inst_CMD
	  .hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0]     ),      //                               .hps_io_sdio_inst_D0
	  .hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1]     ),      //                               .hps_io_sdio_inst_D1
	  .hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK   ),            //                               .hps_io_sdio_inst_CLK
	  .hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2]     ),      //                               .hps_io_sdio_inst_D2
	  .hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3]     ),      //                               .hps_io_sdio_inst_D3
	  //HPS USB 		  
	  .hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0]    ),      //                               .hps_io_usb1_inst_D0
	  .hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1]    ),      //                               .hps_io_usb1_inst_D1
	  .hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2]    ),      //                               .hps_io_usb1_inst_D2
	  .hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3]    ),      //                               .hps_io_usb1_inst_D3
	  .hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4]    ),      //                               .hps_io_usb1_inst_D4
	  .hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5]    ),      //                               .hps_io_usb1_inst_D5
	  .hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6]    ),      //                               .hps_io_usb1_inst_D6
	  .hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7]    ),      //                               .hps_io_usb1_inst_D7
	  .hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT    ),       //                               .hps_io_usb1_inst_CLK
	  .hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP    ),          //                               .hps_io_usb1_inst_STP
	  .hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_DIR    ),          //                               .hps_io_usb1_inst_DIR
	  .hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT    ),          //                               .hps_io_usb1_inst_NXT
		//HPS SPI 		  
	  .hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK  ),           //                               .hps_io_spim1_inst_CLK
	  .hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),           //                               .hps_io_spim1_inst_MOSI
	  .hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),           //                               .hps_io_spim1_inst_MISO
	  .hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS   ),             //                               .hps_io_spim1_inst_SS0
		//HPS UART		
	  .hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX   ),          //                               .hps_io_uart0_inst_RX
	  .hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX   ),          //                               .hps_io_uart0_inst_TX
		//HPS I2C1
	  .hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C0_SDAT  ),        //                               .hps_io_i2c0_inst_SDA
	  .hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C0_SCLK  ),        //                               .hps_io_i2c0_inst_SCL
		//HPS I2C2
	  .hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C1_SDAT  ),        //                               .hps_io_i2c1_inst_SDA
	  .hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C1_SCLK  ),        //                               .hps_io_i2c1_inst_SCL
		//GPIO 
	  .hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N ),  //                               .hps_io_gpio_inst_GPIO09
	  .hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N ),  //                               .hps_io_gpio_inst_GPIO35
	  .hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO   ),  //                               .hps_io_gpio_inst_GPIO40
	  .hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED   ),  //                               .hps_io_gpio_inst_GPIO53
	  .hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY   ),  //                               .hps_io_gpio_inst_GPIO54
	  .hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT ),  //                               .hps_io_gpio_inst_GPIO61
		//FPGA Partion
	  .hps_0_h2f_reset_reset_n  ( hps_fpga_reset_n ),                //                hps_0_h2f_reset.reset_n
	  .hps_0_f2h_cold_reset_req_reset_n      (~hps_cold_reset ),      //       hps_0_f2h_cold_reset_req.reset_n
     .hps_0_f2h_stm_hw_events_stm_hwevents  (stm_hw_events ),  //        hps_0_f2h_stm_hw_events.stm_hwevents
	  
	   // FPGA->HPS access wires
		.mm_bridge_2_s0_waitrequest(mm_bridge_2_s0_waitrequest),            //                 mm_bridge_1_s0.waitrequest
		.mm_bridge_2_s0_readdata(mm_bridge_2_s0_readdata),               //                               .readdata
		.mm_bridge_2_s0_readdatavalid(mm_bridge_2_s0_readdatavalid),          //                               .readdatavalid
		.mm_bridge_2_s0_burstcount(mm_bridge_2_s0_burstcount),             //                               .burstcount
		.mm_bridge_2_s0_writedata(mm_bridge_2_s0_writedata),              //                               .writedata
		.mm_bridge_2_s0_address(mm_bridge_2_s0_address),                //                               .address
		.mm_bridge_2_s0_write(mm_bridge_2_s0_write),                  //                               .write
		.mm_bridge_2_s0_read(mm_bridge_2_s0_read),                   //                               .read
		.mm_bridge_2_s0_byteenable(4'hf),             //                               .byteenable
		.mm_bridge_2_s0_debugaccess(1'b0),            //                               .debugaccess

		// HPS->FPGA access wires
		.status_mm_waitrequest(1'b0),             //                 status_mm.waitrequest
		.status_mm_readdata(status_mm_readdata),                   //                          .readdata
		.status_mm_readdatavalid(status_mm_readdatavalid),         //                          .readdatavalid
		.status_mm_burstcount(),                 //                          .burstcount
		.status_mm_writedata(status_mm_writedata),                 //                          .writedata
		.status_mm_address(status_mm_address),                    //                          .address
		.status_mm_write(status_mm_write),                      //                          .write
		.status_mm_read(status_mm_read),                       //                          .read
		.status_mm_byteenable(),                 //                          .byteenable
		.status_mm_debugaccess(),		//                          .debugaccess
		
		.pll_clk_clk(proc_clk),

		// hookups for the 16x2 LCD module
		.pio_export(ARDUINO_IO[9:2])
 );
  
	

endmodule
	