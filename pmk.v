/*****************************************************************************

   FPGA SHA1 and WPA2 PMK generators 
	Fully unrolled; avg. 7000 ALM per instance with throughput of 1 SHA/clock 
	Tested with Cyclone V 5CSEBA6U23I7 and 5CGTFD9E5F35C7

*****************************************************************************/
////
//
//
//   Main PMK calculator module
//
//
/////


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module tapsv2 (
	clock,
	enable,
	shiftin,
	shiftout,
	lead_out);
	parameter N=128;
	parameter W=160;
	parameter reg_in = 0;
	parameter reg_out = 0;
	input	  clock;
	input enable;
	input	[W-1:0]  shiftin;
	output	[W-1:0]  shiftout;
	output [W-1:0] lead_out;
	wire [W-1:0] sub_wire0;
	//wire [W-1:0] sub_wire1;
	//wire [W-1:0] shiftout = sub_wire0[W-1:0];
	//wire [W-1:0] taps = sub_wire1[W-1:0];

	(* preserve, ramstyle="logic" *) reg[W-1:0] reg_input, last_reg;
	
	altshift_taps	ALTSHIFT_TAPS_component (
				.clock (clock),
				.shiftin (reg_in ? reg_input : shiftin),
				.shiftout (sub_wire0),
				.taps ()
				// synopsys translate_off
				,
				.aclr (),
				.clken (enable),
				.sclr ()
				// synopsys translate_on
				);
	defparam
		ALTSHIFT_TAPS_component.intended_device_family = "Cyclone V",
		ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=AUTO",
		ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
		ALTSHIFT_TAPS_component.number_of_taps = 1,
		ALTSHIFT_TAPS_component.tap_distance = N-reg_in-reg_out,
		ALTSHIFT_TAPS_component.width = W;
		
	assign shiftout = reg_out ? last_reg : sub_wire0;
	assign lead_out = sub_wire0;
	always @(posedge clock)
		begin
		if(reg_in && enable)
			reg_input<=shiftin;
		if(reg_out && enable)
			last_reg <= sub_wire0;
		end
endmodule

module ring_buffer_taps(core_clk,
	cycle, replace,
	in_data,
	out_data,
	lead_out);
	parameter Size=100;
	parameter W=160;
	parameter reg_in = 0;
	parameter reg_out = 0;
	input core_clk, cycle, replace;
	input wire [W-1:0] in_data;
	output wire [W-1:0] out_data;
	output wire [W-1:0] lead_out;
	wire[W-1:0] out_wire;
	assign out_data = out_wire;
		tapsv2 #(Size, W, reg_in, reg_out) tapobj(
			.clock(core_clk), 
			.shiftin(replace ? in_data : out_wire),
			.shiftout(out_wire),
			.enable(cycle),
			.lead_out(lead_out)
			);
endmodule




module pmk_calc_daisy(input core_clk, 
		input [159:0] data_in,
		input write_enable,
		output [159:0] data_out,
		input [1:0] ext_mode,
		output done
	);
	
	parameter N=100;
	parameter Niter=10;
	parameter instance_id=32'hFFFFFFFF;

	//parameter Niter=4096;
	parameter L=81;
	parameter NL=N-L;

	(* maxfan = 32, dont_merge *) reg[1:0] status=0;
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg[159:0] data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;

	reg pad_cycle=0, pad_replace=0;
	wire [159:0] pad_ring_out_data;
	wire [159:0] pad_ring_mid_data;
		
	reg acc_cycle=0, acc_replace=0;

	(* dont_merge *) reg[1:0] mode=0;
	(* dont_merge *) reg mode_1 = 0;
	(* dont_merge *) reg mode_0 = 0;
	
	(* dont_merge *) reg[15:0] loop_counter=0;
	(* dont_merge *) reg[10:0] inst_counter=0;
	
	parameter A0W = 32;

	wire[A0W-1:0] a0_buf_in, a0_buf_out, a0_buf_mid;

	wire [159:0] acc_ring_out_data;
	wire[159:0] acc_buf_lookahead;
	ring_buffer_taps #(N, 160, 0, 1)
	//ring_buffer_explicit #(N, 160)
		acc_buf(
			.core_clk(core_clk), 
			.replace(acc_replace),
			.cycle(mode_1 ? acc_cycle : write_enable),
			.in_data(mode_1 ? (acc_ring_out_data^data) : data_in),
			.out_data(acc_ring_out_data),
			.lead_out(acc_buf_lookahead)			
			);
	reg[31:0] a0_part1, a0_part2;
	wire[63:0] pad_pp;
	pad_preprocess64 pp(acc_buf_lookahead, pad_pp);
	assign a0_buf_in=a0_part1+a0_part2;

	always @(posedge core_clk)
		begin
			if(mode_1 ? acc_cycle : write_enable)
				{a0_part1,a0_part2}<=pad_pp;
		end

	parameter register_pad_taps = 1;
	
	wire[191:0] wire_pad_in; 
	assign wire_pad_in = {a0_buf_in, acc_ring_out_data};
	wire[191:0] wire_pad_out; 
	assign {a0_buf_out, pad_ring_out_data} = wire_pad_out;
	wire[191:0] wire_pad_mid; 
	assign {a0_buf_mid, pad_ring_mid_data} = wire_pad_mid;
	
	ring_buffer_taps #(N-2, 192, register_pad_taps, 0) pad_buf_part1(
			.core_clk(core_clk), 
			.in_data(pad_replace ? wire_pad_in : wire_pad_out),
			.out_data(wire_pad_mid),
			.cycle(mode_1 ? pad_cycle : write_enable),
			.replace(1'b1),
			.lead_out()
			);
			
	ring_buffer_taps #(N+2, 192, register_pad_taps, 0) pad_buf_part2(
			.core_clk(core_clk), 
			.in_data(wire_pad_mid),
			.out_data(wire_pad_out),
			.cycle(mode_1 ? pad_cycle : write_enable),
			.replace(1'b1),
			.lead_out()
			);
		
		/*
	parameter register_pad_taps = 1;
	ring_buffer_taps #(N-2, 160, register_pad_taps, 0) pad_buf_part1(
			.core_clk(core_clk), 
			.in_data(pad_replace ? acc_ring_out_data : pad_ring_out_data),
			.out_data(pad_ring_mid_data),
			.cycle(mode_1 ? pad_cycle : write_enable),
			.replace(1'b1),
			.lead_out()			);
			
	ring_buffer_taps #(N+2, 160, register_pad_taps, 0) pad_buf_part2(
			.core_clk(core_clk), 
			.in_data(pad_ring_mid_data),
			.out_data(pad_ring_out_data),
			.cycle(mode_1 ? pad_cycle : write_enable),
			.replace(1'b1),
			.lead_out()
			);

	parameter register_pad_a0 = 1;
	ring_buffer_taps #(2*N, A0W, register_pad_a0) a0_buf (
		.core_clk(core_clk), 
		.cycle(mode_1 ? pad_cycle : write_enable),
		.replace(pad_replace), 
		.in_data(a0_buf_in),
		.out_data(a0_buf_out),
		.lead_out()
		);
	*/
	reg data_cycle=0, data_replace=0;
	ring_buffer_taps #(NL) data_buf (
		.core_clk(core_clk), 
		.cycle(data_cycle),
		.replace(data_replace), 
		.in_data(out_ctx),
		.out_data(data_bare),
		.lead_out()
		);
		
	reg first_iter=0, second_iter=0, last_iter=0, first_pass=0;

	(* maxfan = 40 *) reg data_src_switch=0;
	
	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;
	assign data_out = mode_0 ? pad_ring_out_data : acc_ring_out_data;
	assign done = (status==2);

	reg[6:0] timer=0;
	
	
	SHA1_5x5_bare s55(core_clk, timer[6:0], a0_buf_out, pad_ring_out_data, data_sha_input, out_ctx);
	reg[31:0] job_count=0;
always @ (posedge core_clk)               
	begin					
		timer<=timer+7'h1;
		mode<=ext_mode;
		mode_1 <= (ext_mode==1);
		mode_0 <= (ext_mode==0);
		if(mode==3)
			status<=0;
			
		if(status==0)
			data_src_switch<=0;
		else if(second_iter && first_pass)
			data_src_switch<=1;
		case(status)	
		0:
			begin
			if(mode==0) // still filling
				begin
				acc_replace<=1;
				pad_replace<=1;
				end
			if(mode==1)	// all cores filled, kicking off
				begin
				$display("Core %d job %d filled", instance_id, job_count);
				//$display("%x %x %x", pad_buf.data[0], pad_buf.data[1], acc_buf.data[0]);
	//			counter <= N;
				loop_counter <= 0;
				inst_counter <= N;
				job_count<=(job_count!=32'hffffffff)?job_count+1:0;
				data_cycle<=1;
				data_replace<=1;
				status<=1;
				acc_cycle<=0;
				acc_replace<=0;
				pad_replace<=0;
				//data_src_switch<=0;
				last_iter<=0;
				first_iter<=1;
				second_iter<=0;
				end
			if(mode==2)	// something went wrong
				begin
				end
			end
		1:  
			begin
			/*
			if(instance_id==0 && (loop_counter==0 || !(inst_counter & 32'h3f) 
			
				|| (loop_counter==1 && inst_counter>=118 && inst_counter<=122)
				|| (loop_counter==1 && inst_counter>=238)
				|| (loop_counter==2 && inst_counter<=2)
				
				)
				)
	//			$display("%d %d %x %x", loop_counter, inst_counter, pad_ring_out_data[63:0], pad_ring_mid_data[63:0]);
				$display("%d %d %x %x %x %x", loop_counter, inst_counter, acc_ring_out_data[63:0], pad_ring_mid_data[63:0], pad_half_delayed[63:0], acc_ring_out_data[63:0]^data[63:0]);
	//			$display("%d %d %x %x", loop_counter, inst_counter, acc_ring_out_data[63:0], pad_ring_out_data[63:0]);
	*/
			pad_cycle<=1;
			pad_replace<=0;
			if(last_iter && first_pass)// fires when loop_counter is Niter and inst_counter is 0
				begin
				acc_cycle<=0;
				status<=2;
				$display("Core %d finished", instance_id);
				end
			else
				acc_cycle<=1;
			//if(second_iter && first_pass)
			//	data_src_switch<=1;

			acc_replace<=((!first_iter) && (inst_counter >= N))?1:0;
			
			last_iter <= (loop_counter==Niter-1);
//				counter<=counter+1;
			if(inst_counter == 2*N-1)
				begin
				loop_counter <= loop_counter+1;
				inst_counter <= 0;
				second_iter<=first_iter;
				first_iter<=0;
				first_pass<=1;
				end
			else
				begin
				inst_counter <= inst_counter+1;
				first_pass <= 0;
				end
			
			for(I=0; I<5; I=I+1)
				data[I*32+:32]<=data_bare[I*32+:32]+pad_half_delayed[I*32+:32];
			pad_half_delayed <= pad_ring_mid_data;
			end
		2:
			begin
			acc_replace<=1;
			pad_replace<=1;				
			case(mode)
			0: begin		// all cores drained, reset
				status<=0;
				end
			1: begin		// some cores still working, sit tight
				acc_cycle<=0;
				pad_cycle<=0;
				end
//			2: acc_replace<=1;	// drain
			endcase
			end
		endcase
	end
endmodule	


module ring_buffer_explicit(core_clk,
	mode,
	//cycle, 
	replace,
	in_data,
	out_data,
	lead_out,
	rden, wren, addr,
	write_data, read_data, read_ready
	);
	parameter Size=100;
	parameter W=160;
	parameter RegWrite=0;
//	parameter Mid=0;
	input core_clk;
	//input cycle;
	input replace;
	input [2:0] mode;
	input wire [W-1:0] in_data;
	output wire [W-1:0] out_data;
	output wire [W-1:0] lead_out;
	input rden, wren;
	input [11:0] addr;
	input [31:0] write_data;
	output [31:0] read_data;
	output read_ready;
	parameter LSize = $clog2(Size);
	parameter PaddedSize = 1<<LSize;
	
	reg[31:0] cycle_count=0;
	reg[31:0] I;
//	reg[W-1:0] data[PaddedSize-1:0];
	
	reg [31:0] reg_read_data=0;
	reg reg_read_ready=0;
	assign read_data = reg_read_data;
	assign read_ready = reg_read_ready;
	
	reg [LSize-1:0] counter=0, counter2=Size-2;
		
	reg[W-1:0] lookaheadQueue[1:0];
	
	assign out_data=lookaheadQueue[0];
	assign lead_out=lookaheadQueue[1];
	
	reg reg_wren=0, reg_rden=0;
	reg [LSize-1:0] row;
	reg [2:0] column;
	reg [31:0] reg_write_data;
	wire addr_valid;
	
	parameter nCol = W/32;

	wire[W-1:0] memory_return_line;
	reg [W-1:0] memory_input_line_reg;
	wire [W-1:0] memory_input_line_wire;
	reg [nCol-1:0] mem_wren;
	//wire[W-1:0] memory_input_line;
	reg [LSize-1:0] mem_wraddr, mem_rdaddr;
	assign memory_input_line_wire = mode[1] ? (replace ? in_data : lookaheadQueue[0]) : {5{reg_write_data}};
generate
	genvar g;
	for(g=0; g<nCol; g=g+1) begin: xx
		my_syncram #(32,PaddedSize) mem (
			core_clk,
			RegWrite ? memory_input_line_reg[g*32+:32] : memory_input_line_wire[g*32+:32],
			mem_rdaddr,
			mem_wraddr,
			mem_wren[g],
			memory_return_line[g*32+:32]);
	end
endgenerate

	assign addr_valid = (addr[11:3]<Size && addr[2:0]<nCol);

	reg[31:0] timer=0;	
	reg reg_rden_delay=0;
	reg [2:0] column_delay=0;
	reg cycle_delay=0;
always @(posedge core_clk)
	begin
		if(mode[0])
			begin
			counter<=RegWrite?4:3;
			counter2<=0;//Size-1;
			reg_rden_delay<=0;
			end
		reg_rden <= rden && addr_valid;
		reg_wren <= wren && addr_valid;
		reg_write_data <= write_data;
		row <= addr[11:3];
		column <= addr[2:0];
		column_delay <= column;
		reg_read_ready <= reg_rden_delay;
		reg_rden_delay <= reg_rden;
		mem_rdaddr<=mode[1] ? counter2 : addr[11:3];
		mem_wraddr<=mode[1] ? counter : addr[11:3];

		if(RegWrite)
			begin
			if(mode[1])
				memory_input_line_reg<=replace ? in_data : lookaheadQueue[0];
			else
				memory_input_line_reg<={5{write_data}};
			end
		
		if(reg_rden_delay)
			reg_read_data <= memory_return_line[column_delay*32+:32];
		
		lookaheadQueue[1] <= memory_return_line;//[counter>=2 ? counter-2 : counter-2+Size];
		lookaheadQueue[0] <= lookaheadQueue[1];
		for(I=0; I<nCol; I=I+1)
			mem_wren[I]<=(mode[2]) || (mode[0] && wren && addr[2:0]==I);
		if(mode[1])
			begin
			if(counter!=0)
				counter<=counter-1;
			else
				counter<=Size-1;
			if(counter2!=0)
				counter2<=counter2-1;
			else
				counter2<=Size-1;
			end
	end
endmodule


module ring_buffer_explicit_no_lead(core_clk,
	mode,
	//cycle, 
	replace,
	in_data,
	out_data,
//	lead_out,
	rden, wren, addr,
	write_data, read_data, read_ready
	);
	parameter Size=100;
	parameter W=160;
	parameter RegWrite=0;
	parameter RegRead=1;
//	parameter Mid=0;
	input core_clk;
	//input cycle;
	input replace;
	input [2:0] mode;
	input wire [W-1:0] in_data;
	output wire [W-1:0] out_data;
//	output wire [W-1:0] lead_out;
	input rden, wren;
	input [11:0] addr;
	input [31:0] write_data;
	output [31:0] read_data;
	output read_ready;
	parameter LSize = $clog2(Size);
	parameter PaddedSize = 1<<LSize;
	
	reg[31:0] cycle_count=0;
	reg[31:0] I;
//	reg[W-1:0] data[PaddedSize-1:0];
	
	reg [31:0] reg_read_data=0;
	reg reg_read_ready=0;
	assign read_data = reg_read_data;
	assign read_ready = reg_read_ready;
	
	reg [LSize-1:0] counter=0, counter2=Size-2;
		
	reg[W-1:0] lookaheadQueue;
	wire[W-1:0] memory_return_line;
	
	assign out_data=RegRead ? lookaheadQueue : memory_return_line;
	
	reg reg_wren=0, reg_rden=0;
	reg [LSize-1:0] row;
	reg [2:0] column;
	reg [31:0] reg_write_data;
	wire addr_valid;
	
	parameter nCol = W/32;

	reg [W-1:0] memory_input_line_reg;
	wire [W-1:0] memory_input_line_wire;
	reg [nCol-1:0] mem_wren;
	//wire[W-1:0] memory_input_line;
	reg [LSize-1:0] mem_wraddr, mem_rdaddr;
	assign memory_input_line_wire = mode[1] ? (replace ? in_data : out_data) : {5{reg_write_data}};
generate
	genvar g;
	for(g=0; g<nCol; g=g+1) begin: xx
		my_syncram #(32,PaddedSize) mem (
			core_clk,
			RegWrite ? memory_input_line_reg[g*32+:32] : memory_input_line_wire[g*32+:32],
			mem_rdaddr,
			mem_wraddr,
			mem_wren[g],
			memory_return_line[g*32+:32]);
	end
endgenerate

	assign addr_valid = (addr[11:3]<Size && addr[2:0]<nCol);

	reg[31:0] timer=0;	
	reg reg_rden_delay=0;
	reg [2:0] column_delay=0;
	reg cycle_delay=0;
always @(posedge core_clk)
	begin
		if(mode[0])
			begin
			counter<=RegWrite?4:3;
			counter2<=RegRead?1:2;//Size-1;
			reg_rden_delay<=0;
			end
		reg_rden <= rden && addr_valid;
		reg_wren <= wren && addr_valid;
		reg_write_data <= write_data;
		row <= addr[11:3];
		column <= addr[2:0];
		column_delay <= column;
		reg_read_ready <= reg_rden_delay;
		reg_rden_delay <= reg_rden;
		mem_rdaddr<=mode[1] ? counter2 : addr[11:3];
		mem_wraddr<=mode[1] ? counter : addr[11:3];

		if(RegWrite)
			begin
			if(mode[1])
				memory_input_line_reg<=replace ? in_data : out_data;
			else
				memory_input_line_reg<={5{write_data}};
			end
			
		if(reg_rden_delay)
			reg_read_data <= memory_return_line[column_delay*32+:32];
		
		if(RegRead)
			lookaheadQueue <= memory_return_line;//[counter>=2 ? counter-2 : counter-2+Size];
			
		for(I=0; I<nCol; I=I+1)
			mem_wren[I]<=mode[2] || (mode[0] && wren && addr[2:0]==I);
		if(mode[1])
			begin
			if(counter!=0)
				counter<=counter-1;
			else
				counter<=Size-1;
			if(counter2!=0)
				counter2<=counter2-1;
			else
				counter2<=Size-1;
			end
	end
endmodule



module ring_buffer_fulldpram(core_clk,
	mode,
	cycle, 
	out_data,
	mid_data,
	lead_out,
	rden, wren, addr,
	write_data, read_data, read_ready
	);
	parameter Size=100;
	parameter W=160;
	parameter Mid=0;
	input core_clk, cycle;
	input [1:0] mode;
	output wire [W-1:0] out_data;
	output wire [W-1:0] mid_data;
	output wire [W-1:0] lead_out;
	input rden, wren;
	input [11:0] addr;
	input [31:0] write_data;
	output [31:0] read_data;
	output read_ready;
	
	
	reg[31:0] cycle_count=0;
	reg[31:0] I;
	reg[W-1:0] data[Size-1:0];
	
	reg [31:0] reg_read_data=0;
	reg reg_read_ready=0;
	assign read_data = reg_read_data;
	assign read_ready = reg_read_ready;
	
	reg [9:0] counter=0, mid_counter=0;
		
	reg[W-1:0] lookaheadQueue[1:0];
	
	assign out_data=lookaheadQueue[0];
	assign lead_out=lookaheadQueue[1];
	
	reg[W-1:0] reg_mid_data;
	
	assign mid_data=reg_mid_data;
	
	reg reg_wren=0, reg_rden=0;
	reg [8:0] row;
	reg [2:0] column;
	reg [31:0] reg_write_data;
	wire addr_valid;
	
	assign addr_valid = (addr[11:3]<Size && addr[2:0]<W/32);
	
always @(posedge core_clk)
	begin	
		if(mode==0)
			begin
			counter<=0;
			mid_counter<=Mid;
			end
		reg_rden <= rden && addr_valid;
		reg_wren <= wren && addr_valid;
		reg_write_data <= write_data;
		row <= addr[11:3];
		column <= addr[2:0];

		reg_read_ready <= reg_rden;

		if(cycle && (reg_rden || reg_wren))
			$display("WARNING : ring buffer unexpected state");
		

		if(reg_rden)
			reg_read_data <= data[row][column*32+:32];
		else if(cycle)
			lookaheadQueue[1] <= data[counter>=2 ? counter-2 : counter-2+Size];

		if(reg_wren)
			data[row][column*32+:32]<=reg_write_data;
		else 
			reg_mid_data<=data[mid_counter];		
			
		if(reg_wren)
			begin
			if(row==0)
				lookaheadQueue[0][column*32+:32]<=reg_write_data;
			if(row==Size-1)
				lookaheadQueue[1][column*32+:32]<=reg_write_data;
			end
			
		if(cycle)
			begin
			lookaheadQueue[0] <= lookaheadQueue[1];
			if(counter!=0)
				counter<=counter-1;
			else
				counter<=Size-1;
			if(mid_counter!=0)
				mid_counter<=mid_counter-1;
			else
				mid_counter<=Size-1;
			end
	end
endmodule


module pmk_calc_direct_feed(input core_clk, 
		input [12:0] wire_addr,
		input wire_rden,
		input wire_wren,
		input [31:0] wire_data_in,
		output reg [31:0] data_out,
		output reg readdatavalid,
		
		input [1:0] ext_mode,
		(* maxfan = 32, dont_merge *) output reg[1:0] status
	);
	
	parameter N=100;
	parameter Niter=10;
	parameter instance_id=32'hFFFFFFFF;

	//parameter Niter=4096;
	parameter L=81;
	parameter NL=N-L;

initial begin
	status<=0;
end
	//(* maxfan = 32, dont_merge *) reg[1:0] status=0;
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg[159:0] data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;

	wire [159:0] pad_ring_out_data;
	wire [159:0] pad_ring_mid_data;
		
	reg acc_replace=0;

	(* dont_merge *) reg[1:0] mode=0;
	(* dont_merge *) reg mode_1 = 0;
	(* dont_merge *) reg mode_0 = 0;
	
	(* dont_merge *) reg[15:0] loop_counter=0;
	(* dont_merge *) reg[10:0] inst_counter=0;
	
	wire[31:0] a0_buf_out, a0_buf_mid;
	wire [159:0] acc_ring_out_data;
	wire[159:0] pad_buf_lookahead;
	
	(* dont_merge *) reg reg_rden_acc, reg_wren_acc, 
		reg_wren_pad1,
		reg_wren_pad2;
	(* dont_merge *) reg[31:0] reg_write_data;
	
	(* dont_merge *) reg [11:0] reg_mm_addr;
	
		reg [12:0] addr;
		reg rden;
		reg wren;
		reg [31:0] data_in;
		
	always @(posedge core_clk)
		begin
		addr <= wire_addr;
		rden <= wire_rden;
		wren <= wire_wren;
		data_in <= wire_data_in;
		
		reg_rden_acc <= rden && (addr[12]==0);
		reg_wren_acc <= wren && (addr[12]==0);
`ifndef ONE_PAD_BUF		
		reg_wren_pad1 <= wren && addr[12] && (addr[11:3]<N-2);
		reg_wren_pad2 <= wren && addr[12] && (addr[11:3]>=N-2);
		reg_mm_addr <= (addr[12]==0 || addr[11:3]<N-2) ? addr[11:0] : (addr[11:0]-8*(N-2));
`else
		reg_wren_pad1 <= wren && addr[12];
		reg_wren_pad2 <= 0;
		reg_mm_addr <= addr[11:0];
`endif		
		reg_write_data <= data_in;		
		end

	(* maxfan = 32 *) reg[1:0] ring_status=0;	
	(* maxfan = 32, dont_merge *) reg[2:0] ring_status2_1=1;
	(* maxfan = 32, dont_merge *) reg[2:0] ring_status2_2=1;
	(* maxfan = 32, dont_merge *) reg[2:0] ring_status2_3=1;
	//(* maxfan = 32, dont_merge *) reg[2:0] ring_status2_3=1;
//`define LEAD_ACC
	
`ifndef LEAD_ACC
	ring_buffer_explicit_no_lead #(N, 160, 1, 1) 
`else
	wire[159:0] acc_ring_lead_out;
	ring_buffer_explicit #(N, 160, 1) 
`endif
		acc_buf(
			.core_clk(core_clk), 
			.mode(ring_status2_1),
			.replace(acc_replace),
			.in_data(acc_ring_out_data^data),
			.out_data(acc_ring_out_data),
`ifdef LEAD_ACC			
			.lead_out(acc_ring_lead_out),
`endif			
			.rden(reg_rden_acc),
			.wren(reg_wren_acc),
			.addr(reg_mm_addr),
			.write_data(reg_write_data),
			.read_data(data_out),
			.read_ready(readdatavalid)
			);
			
	reg[31:0] a0_part1, a0_part2;
	wire[63:0] pad_pp;
	
	pad_preprocess64 pp(pad_buf_lookahead[159:0], pad_pp);
	
	wire [31:0] a0_buf_in;
	assign a0_buf_in=a0_part1+a0_part2;
	always @(posedge core_clk)
		{a0_part1,a0_part2}<=pad_pp;

	reg pad_replace=0;
`ifdef ONE_PAD_BUF	
// not implemented
	ring_buffer_fulldpram #(2*N, 160, N-3) pad_buf(
			.core_clk(core_clk), 
			.mode(status),
			.mid_data(pad_ring_mid_data),
			.out_data(pad_ring_out_data),
			.cycle(pad1_cycle),
			.lead_out(pad_buf_lookahead),
			.rden(1'b0),
			.wren(reg_wren_pad1),
			.addr(reg_mm_addr),
			.write_data(reg_write_data),
			.read_data(),
			.read_ready()
			);
`else
	ring_buffer_explicit_no_lead #(N-2, 160, 0, 1) pad_buf_part1(
			.core_clk(core_clk), 
			.mode(ring_status2_2),
			.in_data(pad_ring_out_data),
			.out_data(pad_ring_mid_data),
			.replace(pad_replace),
			//.lead_out(),
			.rden(1'b0),
			.wren(reg_wren_pad1),
			.addr(reg_mm_addr),
			.write_data(reg_write_data),
			.read_data(),
			.read_ready()
			);
			
	ring_buffer_explicit #(N+2, 160, 1) pad_buf_part2(
			.core_clk(core_clk), 
			.mode(ring_status2_3),
			.in_data(pad_ring_mid_data),
			.out_data(pad_ring_out_data),
			.replace(pad_replace),
			.lead_out(pad_buf_lookahead),
			.rden(1'b0),
			.wren(reg_wren_pad2),
			.addr(reg_mm_addr),
			.write_data(reg_write_data),
			.read_data(),
			.read_ready()
			);
`endif

	reg data_cycle=0, data_replace=0;
	(* altera_attribute = "-name QII_AUTO_PACKED_REGISTERS OFF" *) 
		ring_buffer_taps #(NL, 160, 0, 1) data_buf (
		.core_clk(core_clk), 
		.cycle(data_cycle),
		.replace(data_replace), 
		.in_data(out_ctx),
		.out_data(data_bare),
		.lead_out()
		);
		
	reg first_iter=0, second_iter=0, last_iter=0, first_pass=0, last_pass=0;

	reg data_src_switch_lead = 0;
	(* maxfan = 40 *) reg data_src_switch=0;

`ifdef LEAD_ACC
	assign data_sha_input = data;
`else	
	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;
`endif
	//assign out_status=status;

	(* dont_merge *) reg[6:0] timer=0;
	//(* altera_attribute = "-name OPTIMIZE_HOLD_TIMING OFF" *)
`ifdef SHA_V2
	SHA1_5x5_bare_v2 
`else
	SHA1_5x5_bare 
`endif	
		s55(core_clk, timer[6:0], a0_buf_in, pad_ring_out_data, data_sha_input, out_ctx);
	
	reg[31:0] job_count=0;
	reg[2:0] ring_init_count;
	
	reg[1:0] reg_ext_mode=0;
always @ (posedge core_clk)               
	begin					
		timer<=timer+7'h1;
		reg_ext_mode<=ext_mode;
		mode<=reg_ext_mode;
		mode_1 <= (reg_ext_mode==1);
		mode_0 <= (reg_ext_mode==0);
`ifdef LEAD_ACC
		for(I=0; I<5; I=I+1)
			data[I*32+:32]<=data_src_switch_lead ? data_bare[I*32+:32]+pad_half_delayed[I*32+:32] : acc_ring_lead_out[I*32+:32];
`else
		for(I=0; I<5; I=I+1)
			data[I*32+:32]<=data_bare[I*32+:32]+pad_half_delayed[I*32+:32];
`endif
		pad_half_delayed <= pad_ring_mid_data;

		//if(mode==3 || mode_0)
		if(status==0 && mode_0)
			begin
			ring_status2_1<=1;
			ring_status2_2<=1;
			ring_status2_3<=1;
			end
		else if(status==0 && mode_1 && ring_status==0)
			begin
			ring_status2_1<=3'b010;
			ring_status2_2<=3'b010;
			ring_status2_3<=3'b010;
			end
		else if(status==0 && mode_1 && ring_status==1 && ring_init_count == 0)
			begin
			ring_status2_1<=3'b110;
			ring_status2_2<=3'b110;
			ring_status2_3<=3'b110;
			end
		else if(status==1 && last_iter && first_pass)// fires when loop_counter is Niter and inst_counter is 0
			begin
			ring_status2_1<=0;
			ring_status2_2<=0;
			ring_status2_3<=0;
			end

			
		if(mode==3 || mode==0)
			begin
			status<=0;
			ring_status<=0;
			end
			
		if(status==0)
			data_src_switch<=0;
		else if(second_iter && first_pass)
			data_src_switch<=1;

		if(status==0)
			data_src_switch_lead<=0;
		else if(first_iter && last_pass)
			data_src_switch_lead<=1;
			
		if(status==0 && mode==1 && ring_status==0)
			begin
			ring_status<=1;
			ring_init_count<=3;
			end
			
		if(status==0 && mode==1 && ring_status==1)
			begin
			ring_init_count <= ring_init_count-1;
			if(ring_init_count == 0)
				begin
				$display("Core %d job %d filled", instance_id, job_count);
				//$display("%x %x %x", pad_buf.data[0], pad_buf.data[1], acc_buf.data[0]);
	//			counter <= N;
				loop_counter <= 0;
				inst_counter <= N;
				job_count<=(job_count!=32'hffffffff)?job_count+1:0;

				
				pad_replace<=0;
				data_cycle<=1;
				data_replace<=1;
				status<=1;
				ring_status<=2;
//				ring_status2_1<=3'b110;
//				ring_status2_2<=3'b110;
				acc_replace<=0;
				//data_src_switch<=0;
				last_iter<=0;
				first_iter<=1;
				second_iter<=0;
				end
			end
			
		if(status==1)	
			begin
	
			pad_replace<=1;
//			if(
//				(loop_counter==0 && (inst_counter<N+5 || inst_counter>2*N-5))
//					|| (loop_counter==1 && inst_counter<3))
//					$display("%x %x", pad_ring_mid_data, pad_ring_out_data);
			if(last_iter && first_pass)// fires when loop_counter is Niter and inst_counter is 0
				begin
				status<=2;
				ring_status<=3;
				$display("Core %d finished", instance_id);
				end

			acc_replace<=((!first_iter) && (inst_counter >= N))?1:0;
			
			last_iter <= (loop_counter==Niter-1);
			
			last_pass <= (inst_counter == 2*N-2);
			
			if(inst_counter == 2*N-1)
				begin
				loop_counter <= loop_counter+1;
				inst_counter <= 0;
				second_iter<=first_iter;
				first_iter<=0;
				first_pass<=1;
				end
			else
				begin
				inst_counter <= inst_counter+1;
				first_pass <= 0;
				end
		
			end

		if(status==2 && mode==0)
			begin
			status<=0;
			ring_status<=0;
//			ring_status2_1<=3'b001;
//			ring_status2_2<=3'b001;
			end
	end
endmodule	

module pmk_calc_direct_feed_multicore(input core_clk, 
		input [16:0] addr,
		input rden,
		input wren,
		input [31:0] data_in,
		output [31:0] data_out,
		output readdatavalid,
		
		input [1:0] ext_mode,
		output done,
		output [31:0] disp_status);

	parameter Ncores=3;
	parameter N=100;
	parameter Niter=10;
	
	reg[3:0] inst;
	
	(* dont_merge *) reg[12:0] disp_addr[Ncores-1:0];
	reg[Ncores-1:0] disp_rden;
	reg[Ncores-1:0] disp_wren;
	reg[31:0] disp_data_in;
	wire[32*Ncores-1:0] disp_data_out;
	wire[Ncores-1:0] disp_readdatavalid;
	wire[2*Ncores-1:0] core_status;
	wire[Ncores-1:0] core_done;
	
	reg[31:0] reg_data_out;
	reg reg_readdatavalid;
	reg reg_done=0;
	reg[31:0] I;	
	assign data_out = reg_data_out;
	assign readdatavalid = reg_readdatavalid;
	assign done = reg_done;
	reg[1:0] reg_ext_mode=0;
generate
genvar g;
	for(g=0; g<Ncores; g=g+1) begin: cores
		pmk_calc_direct_feed #(N, Niter, g) inst(
		.core_clk(core_clk),
		.wire_addr(disp_addr[g]),
		.wire_rden(disp_rden[g]),
		.wire_wren(disp_wren[g]),
		.wire_data_in(disp_data_in),
		.data_out(disp_data_out[g*32+:32]),
		.readdatavalid(disp_readdatavalid[g]),
		.ext_mode(reg_ext_mode),
		.status(core_status[2*g+:2])
		);
		assign core_done[g] = (core_status[2*g+:2]!=2);
	end
endgenerate
		
wire[31:0] all_ones=32'hFFFFFFFF;		

assign disp_status[2*Ncores-1:0]=core_status;

always @(posedge core_clk)
begin
	inst<=addr[16:13];
	disp_data_in<=data_in;
	reg_ext_mode<=ext_mode;
	reg_done<=(core_done==0);
	
	reg_readdatavalid<=(disp_readdatavalid!=0);
	
	for(I=0; I<Ncores; I=I+1)
		begin
		disp_addr[I]<=addr[12:0];
		disp_rden[I]<=rden && (addr[16:13]==I);
		disp_wren[I]<=wren && (addr[16:13]==I);
		if(disp_readdatavalid[I])
			reg_data_out<=disp_data_out[I*32+:32];
		end
end
endmodule		

// Takes in a 32-bit feed and repacks it into a 160-bit feed 
module packer_32_to_160(clk, write_32_wren, write_32_full, write_32_data,
	write_160_wren, write_160_full, write_160_data, reset);
	input clk;
   input write_32_wren;
   output write_32_full;
   input [31:0] write_32_data;

   output write_160_wren;
   input write_160_full;
   output [159:0] write_160_data;
	input reset;
	
	parameter Nlines=100;
	reg[15:0] lines_written=0;
	reg[2:0] dwords_written=0;
		
	reg write_160_enable=0;
	assign write_160_wren = write_160_enable;

	reg is_full=0;
//	assign write_32_full = is_full;
	assign write_32_full = write_160_full;
	
	reg[159:0] input_line=0;
	assign write_160_data = input_line;

   always @(posedge clk)
     begin
//		if(lines_written<10 && write_32_wren)
//			$display("%d %d %x", lines_written, dwords_written, write_32_data);
//		if(lines_written<10 && write_160_enable)
//			$display("%x", input_line);
//		if(is_full != write_160_full)
//			$display("Error: full mismatch %d %d", is_full, write_160_full);
		if(reset)
			begin
			dwords_written<=0;
			lines_written<=0;
			is_full<=0;
			end
		//else 
		if(write_32_wren)
			begin
				input_line[159:128]<=write_32_data;
				input_line[127:0]<=input_line[159:32];
				if(dwords_written==4)
					begin
						write_160_enable<=1;
						lines_written<=lines_written+1;
						if(lines_written==Nlines-1)
							is_full<=1;
						dwords_written<=0;
					end
				else
					begin
						write_160_enable<=0;		
						dwords_written<=dwords_written+1;
					end
			end
		else
			begin
//			if(!write_160_full)
//				is_full<=0;
			write_160_enable<=0;
			end
			
	end
endmodule

// Takes in a 160-bit source and exposes it as a 32-bit source
module unpacker_160_to_32(clk, user_r_read_32_rden,
	user_r_read_32_empty, user_r_read_32_data,
	read_160_rden, read_160_empty,
	read_160_data,	reset);
	input clk;
	input user_r_read_32_rden;
	output user_r_read_32_empty;
	output [31:0] user_r_read_32_data;
	output read_160_rden;
	input read_160_empty;
	input [159:0] read_160_data;
	
//	parameter Nlines=128;
	
	input reset;
	reg is_empty=1, line_valid=0, next_line_valid=0;
	reg[1:0] loading=0;
	reg[159:0] line, next_line;
	reg[3:0] read_pos=0;
	assign user_r_read_32_empty = is_empty;
	(* maxfan = 64 *) reg reg_rd160en=0;
	assign read_160_rden = reg_rd160en;
	
//	reg[31:0] timer=0;
//	reg[31:0] line_count=0;
//	assign user_r_read_32_data=line[read_pos*32+:32];
	assign user_r_read_32_data=line[31:0];
   always @(posedge clk)
     begin
//		timer<=timer+1;
//		next_line<=read_160_data;
//	if(line_count<10 && !read_160_empty && (line_count>0 || user_r_read_32_rden || loading>0))
//		if (line_count>=250 && line_count<=260 && user_r_read_32_rden) 
//	if((timer>=10128 && timer<=10150) || (timer>=11150 && timer<=11160) || (timer>=13200 && timer<=13220))
//			$display("%d: line_count %d, read_pos %d, current %x, next %x, wire %x, read_32_rden %d, read_160_empty %d, read_160_rden %d, next_line_valid %d, loading %d, empty %d",
//				timer, line_count, read_pos, line, next_line, read_160_data, user_r_read_32_rden, read_160_empty, reg_rd160en, next_line_valid, loading, is_empty);
		if(reset)
			begin
			read_pos<=0;
			loading<=0;
			next_line_valid<=0;
			line_valid<=0;
			reg_rd160en<=0;
			is_empty<=1;
			end
		else if(user_r_read_32_rden && !is_empty)
			begin
				reg_rd160en<=user_r_read_32_rden && (read_pos==4);
				line<={next_line[31:0],line[159:32]};
//				next_line<={read_160_data[read_pos*32+:32], next_line[159:32]};
				next_line_valid<=!read_160_empty;
				if(read_pos<4)
					begin
					next_line<={32'b0,next_line[159:32]};
					read_pos<=read_pos+1;
					end
				else
					begin
					next_line<=read_160_data;
					//line_count<=line_count+1;
					read_pos<=0;
					line_valid<=next_line_valid;
					is_empty<=!line_valid;
					end
			end
		else if(is_empty && !read_160_empty && loading==0)
			begin
			line<=read_160_data;
			loading<=2;
			reg_rd160en<=1;
			end
		else if(loading!=0)
			begin
			next_line<=read_160_data;
			next_line_valid<=1;
			line_valid<=1;
			if(loading==1)
				begin
				is_empty<=0;
				reg_rd160en<=0;
				end
			loading<=loading-1;
			end		
		else
			reg_rd160en<=0;
     end
endmodule


/****
Works correctly in a simulator or when interfaced to PCIe via pmk_dispatcher_dualclock.
I've been unable to get it to work on DE10-Nano when hooked directly into the DDR3 read/write loop
(data comes out in well-formed 160-bit chunks, but it is all wrong, and I only get 10-15 copies of 
the same line out of each core before starting to getting copies of the DEADC0DE info line.)
There is some sort of obscure bug and it's hard to track down when you can't simulate the toplevel entity
and when each recompile takes 30 minutes.
NOTE: Could be consistent with internal failure of tapsv2.
*****/
module pmk_dispatcher_daisy(clk, read_32_rden,
	read_32_empty, read_32_data,
	write_32_wren, write_32_full, write_32_data, ext_reset, out_status);
	input clk;
	input read_32_rden;
	output read_32_empty;
	output [31:0] read_32_data;
	input write_32_wren;
	output write_32_full;
	input [31:0] write_32_data;	
	input ext_reset;
	output [31:0] out_status;
	
	parameter N=2;
	parameter Njobs=100;
	parameter Niter=4096;
	parameter debug=0;
	parameter dataSize=$clog2(Njobs*3); // Njobs 100: dataSize=ceil(log2(300))=9
	
	reg[159:0] daisy_chain_input;
	wire[159:0] packer_out;
	
	reg[159:0] daisy_chain_output;

	(* dont_merge *) reg[N-1:0] worker_status=0;
	wire[N-1:0] wire_worker_status;
	
	//reg[9:0] job_count=0,
	
	//reg[dataSize-1:0] count=0, wcount=0;
	
	reg[dataSize-1:0] count_hi=0;
	reg[3:0] count_lo=0;
	reg[dataSize-1:0] wcount_hi=0;
	reg[3:0] wcount_lo=0;
	reg last_row=0, wlast_row=0, wlast_col=0;
	reg wlast_row2=0, wlast_col2=0;
	
	(* dont_merge, maxfan=4 *) reg[1:0] mode=0;	
	(* dont_merge *) reg mode_0=1;
	reg mode2_just_up=0;
	
	reg filler_reset=0, drainer_reset=0;
	reg[1:0] mode_delay=0;
	wire[160*N-1:0] temp_wires;
	wire packer_request, unpacker_request;
	//wire write_enable = mode_0 ? packer_request : unpacker_request;	
	//(* maxfan = 80 *) 
	(* dont_merge *) reg write_enable[N-1:0], reg_wren;
	reg[31:0] I;
	reg[159:0] spacers[N-1:0];
	
	assign out_status={count_hi, count_lo, unpacker_request, packer_request, mode, worker_status};
	
generate
genvar gi;
	for(gi=0; gi<N-1; gi=gi+1) begin: workers
		pmk_calc_daisy #(Njobs,Niter, debug ? gi : 32'hFFFFFFFF) 
			worker(clk, 
			gi==0 ? daisy_chain_input : spacers[gi-1],//temp_wires[(gi-1)*160+:160],
			write_enable[gi],
			temp_wires[gi*160+:160],
			//spacers[gi],
			mode,
			wire_worker_status[gi]			
		);
		end
endgenerate	
		pmk_calc_daisy #(Njobs,Niter, debug ? N-1 : 32'hFFFFFFFF) 
			last_worker(clk, 
			//temp_wires[(N-2)*160+:160],
			spacers[N-2],
			write_enable[N-1],
			temp_wires[(N-1)*160+:160],
			//daisy_chain_output,
			//spacers[N-1],
			mode,
			wire_worker_status[N-1]);			

	reg empty=1;
	packer_32_to_160 #(N*Njobs*3+N) packer(
		.clk(clk), 
		.write_32_wren(write_32_wren), 
		.write_32_full(write_32_full), 
		.write_32_data(write_32_data),
		.write_160_wren(packer_request), 
		.write_160_full(!mode_0), 
		.write_160_data(packer_out), 
		.reset(filler_reset)
		);
		
	unpacker_160_to_32 unpacker(
		.clk(clk), 
		.user_r_read_32_rden(read_32_rden),
		.user_r_read_32_empty(read_32_empty),
		.user_r_read_32_data(read_32_data), 
		.read_160_rden(unpacker_request), 
		.read_160_empty(empty),
		.read_160_data(daisy_chain_output),
		.reset(drainer_reset)
		);
	reg open_prev=0;
	reg reset=0;
	reg read_delay2=0;
	
	reg [15:0] timer_lo=0, timer_hi=0;
	reg timer_wrap=0;
	reg[159:0] info_state=0;
	reg all_done=0;
	reg worker_mask=0;
	
	always @(posedge clk)
		begin
		
		if(ext_reset)
			reset<=1;
		
		if(timer_lo!=16'hFFFF)
			begin
			timer_lo<=timer_lo+1;
			timer_wrap<=0;
			end
		else
			begin
			timer_lo<=0;
			timer_wrap<=1;
			end
			
		if(timer_wrap)
			begin
			if(timer_hi!=16'hFFFF)
				timer_hi<=timer_hi+1;
			else
				timer_hi<=0;
			end

		
		if(packer_request)
			daisy_chain_input<=packer_out;
		else if(mode==2)
			daisy_chain_input<=info_state;
			
//`define DEBUG
			
`ifdef DEBUG
/*
		if((unpacker_request && !read_delay2) || mode2_just_up)
			daisy_chain_output[127:8]<=spacers[N-1][127:8];
		else if(unpacker_request && read_delay2)
			daisy_chain_output[127:8]<=temp_wires[(N-1)*160+8+:120];
		daisy_chain_output[0]<=mode_0;
		daisy_chain_output[1]<=unpacker_request;
		daisy_chain_output[2]<=reg_wren;
		daisy_chain_output[3]<=read_delay2;			
		daisy_chain_output[7:4]<=daisy_chain_output[3:0];
		*/
		daisy_chain_output[31:0]<={daisy_chain_output[30:0],write_enable[0]};
		daisy_chain_output[63:32]<=temp_wires[351:320];
		daisy_chain_output[95:64]<=temp_wires[191:160];
		daisy_chain_output[127:96]<=temp_wires[31:0];
		daisy_chain_output[159:128]<={timer_hi, timer_lo};
`else			
		if((unpacker_request && !read_delay2) || mode2_just_up)
			daisy_chain_output<=spacers[N-1];
		else if(unpacker_request && read_delay2)
			daisy_chain_output<=temp_wires[(N-1)*160+:160];
`endif
			
		reg_wren <= mode2_just_up || (mode_0 ? packer_request : unpacker_request);	
		for(I=0; I<N; I=I+1)
			write_enable[I]<=reg_wren;
			//write_enable[I] <= mode2_just_up || (mode_0 ? packer_request : unpacker_request);	
		read_delay2 <= unpacker_request;
		
		for(I=0; I<N; I=I+1)
			if(write_enable[I])
				spacers[I] <= temp_wires[160*I+:160];
			
		if(packer_request && mode!=0)
			$display("Warning: packer request in mode %d", mode);
		if(unpacker_request && mode!=2)
			$display("Warning: unpacker request in mode %d", mode);
		
		worker_status <= wire_worker_status;
		
//		open_prev <= write_32_open;
		
		mode_delay<=mode;//[1:0];
		worker_mask <= (worker_status == (1<<N)-1);
//		if(write_32_open && !open_prev)
//			reset<=1;
			
//		reset<=0;
		case(mode)
		0:
			begin
			empty<=1;
			mode2_just_up<=0;
			//  #inputs: Njobs*N*3 + N
			//if(packer_request)// && mode==0)
			if(reg_wren)
				begin
				//count<=count+1;
				if(count_lo==N-1)
					begin
					count_lo<=0;
					count_hi<=count_hi+1;
					last_row<=(count_hi==3*Njobs-1);
					end
				else
					begin
					count_lo<=count_lo+1;
					end
				end
			
			//if(packer_request && last_row && (count_lo==N-1))
			if(reg_wren && last_row && (count_lo==N-1))
				begin
				$display("pmk_dispatcher_daisy: transition to state 1");
				mode<=1;
				drainer_reset<=1;
				mode_0<=0;
				all_done<=0;
				info_state[0]<=0;
				info_state[7:1]<=0;
				info_state[23:8]<=timer_lo;
				info_state[39:24]<=timer_hi;
				end
			else if(reset)
				begin
				mode<=3;
				mode_0<=0;
				end
			end
		1:
			begin
			drainer_reset<=0;
			all_done <= worker_mask;
			if(all_done)
				begin
				$display("pmk_dispatcher_daisy: transition to state 2");
				filler_reset<=1;
				//wcount<=0;
				wcount_lo<=0;
				wcount_hi<=0;
				wlast_row<=0;
				wlast_col<=0;
				wlast_row2<=0;
				wlast_col2<=0;
				mode<=2;
				mode2_just_up<=1;				
				info_state[40]<=0;
				info_state[47:41]<=0;
				info_state[63:48]<=timer_lo;
				info_state[79:64]<=timer_hi;
				info_state[95:80]<=Njobs;
				info_state[103:96]<=N;
				info_state[135:104]<=32'hDEADC0DE;
				info_state[159:136]<=0;
				//empty<=0;
				end
			else if(reset)
				mode<=3;
			end
		2:
			begin
			filler_reset<=0;
			mode2_just_up<=0;
				begin
				//if(unpacker_request)// && mode==2)
				if(reg_wren && !mode2_just_up)
					begin
					if(wcount_lo==N-1)
						begin
						wcount_lo<=0;
						wcount_hi<=wcount_hi+1;
						wlast_row<=(wcount_hi==Njobs);
						wlast_col<=wlast_row;
						wlast_row2<=(wcount_hi==Njobs);
						wlast_col2<=wlast_row2;
						end
					else
						begin
						wcount_lo<=wcount_lo+1;
						if(!wlast_col2)
							wlast_col2<=wlast_row2 && (wcount_lo==N-2);
						//wlast_col<=wlast_row && (wcount_lo==N-1);
						end
					end
				//if(unpacker_request && wlast_row && wcount_lo==N-1)
				//if(unpacker_request && wlast_col)
//				if(reg_wren && wlast_col2)
//					empty<=1;
				if(reg_wren && wlast_col)
					begin
					$display("pmk_dispatcher_daisy: transition to state 0");
					//count<=0;
					count_lo<=0;
					count_hi<=0;
					last_row<=0;
					mode<=0;
					mode_0<=1;
					empty<=1;
					end
				else if(mode_delay==2) // hold off starting the read until all cores got communicated new status
					empty<=wlast_col2;
				else if(reset)
					mode<=3;					
				end
			end
		3:
			begin
			reset<=0;
			if(mode_delay==3)
				begin
				filler_reset<=0;
				drainer_reset<=0;
				mode2_just_up<=0;
				count_lo<=0;
				count_hi<=0;
				mode_0<=1;
				mode<=0;
				all_done<=0;
				end
			else
				begin
				filler_reset<=1;
				drainer_reset<=1;
				end
			end
		endcase
		end
endmodule


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module myfifo (
	data,
	rdclk,
	rdreq,
	wrclk,
	wrreq,
	q,
	rdempty,
	wrfull,
	reset);
	
	parameter showahead = 0;//"OFF";
	
	input	[31:0]  data;
	input	  rdclk;
	input	  rdreq;
	input	  wrclk;
	input	  wrreq;
	output	[31:0]  q;
	output	  rdempty;
	output	  wrfull;
	input reset;
	wire [31:0] sub_wire0;
	wire  sub_wire1;
	wire  sub_wire2;
	wire [31:0] q = sub_wire0[31:0];
	wire  rdempty = sub_wire1;
	wire  wrfull = sub_wire2;
	reg[1:0] eccstatus;
	dcfifo	dcfifo_component (
				.data (data),
				.rdclk (rdclk),
				.rdreq (rdreq),
				.wrclk (wrclk),
				.wrreq (wrreq),
				.q (sub_wire0),
				.rdempty (sub_wire1),
				.wrfull (sub_wire2),
				.aclr (reset),
				.eccstatus (),
				.rdfull (),
				.rdusedw (),
				.wrempty (),
				.wrusedw ());
	defparam
		dcfifo_component.intended_device_family = "Cyclone V",
		dcfifo_component.lpm_numwords = 2048,
		dcfifo_component.lpm_showahead = showahead ? "ON" : "OFF",
		dcfifo_component.lpm_type = "dcfifo",
		dcfifo_component.lpm_width = 32,
		dcfifo_component.lpm_widthu = 11,
		dcfifo_component.overflow_checking = "ON",
		dcfifo_component.rdsync_delaypipe = 5,
		dcfifo_component.underflow_checking = "ON",
		dcfifo_component.use_eab = "ON",
		dcfifo_component.wrsync_delaypipe = 5;
endmodule



module pmk_dispatcher_dualclock(core_clk, bus_clk, read_32_rden,
	read_32_empty, read_32_data,
	write_32_wren, write_32_full, write_32_data, ext_reset);
	input core_clk, bus_clk;
	input read_32_rden;
	output read_32_empty;
	output [31:0] read_32_data;
	input write_32_wren;
	output write_32_full;
	input [31:0] write_32_data;	
	input ext_reset;
	parameter N=2;
	parameter Njobs=100;
	parameter Niter=4096;

	wire core_input_empty;
	wire dispatcher_full, dispatcher_empty;
	wire f2c_full, c2f_empty;

	reg reset=0;
	always @(posedge bus_clk)
		reset<=ext_reset;

	wire f2c_request;
	assign f2c_request = !f2c_full && !dispatcher_empty;
	wire c2f_request;
	assign c2f_request = !c2f_empty && !dispatcher_full;
	wire[31:0] core_input_data;
	myfifo  #(1) cpu_to_fpga_crosser(
		write_32_data,   // pcie data incoming into fifo (bus_clk)
		core_clk,
		//core_rdreq,	// core request to pull one word from fifo into fpga (clkintop_p)
		c2f_request,
		bus_clk,
		write_32_wren,	// pcie request to push one word into fifo (bus_clk)
		core_input_data,			// data coming out of fifo into core (clkintop_p)
		c2f_empty,			// fifo signaling the core that it's empty (clkintop_p)
		write_32_full,  // fifo signaling pcie that it's full (bus_clk)
		reset);
		
	wire[31:0] core_return_data;

	myfifo fpga_to_cpu_crosser(
		core_return_data,
		bus_clk,
		read_32_rden,
		core_clk,
		f2c_request,
		read_32_data,
		read_32_empty,
		f2c_full,
		reset);

	pmk_dispatcher_daisy #(N, Njobs, Niter, 1) disp(core_clk, 
		f2c_request,
		dispatcher_empty, 
		core_return_data,
		c2f_request,
		dispatcher_full, 
		core_input_data,
		reset
		);

endmodule


