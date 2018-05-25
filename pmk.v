
module Round1(clk, va, x, outa, outx, sum1, sum2);
	input clk;
	input [159:0] va;
	input [511:0] x;
	input[31:0] sum1, sum2;
	output [255:0] outa;
	output [511:0] outx;
	parameter K1=32'h5A827999;
	reg [31:0] f;
	reg [255:0] t1;
	reg [511:0] t0;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, e;
	assign x0 = x[31:0];
	assign x1 = x[63:32];
	assign x2 = x[95:64];
	assign a=va[31:0];
	assign b=va[63:32];
	assign c=va[95:64];
	assign d=va[127:96];
	assign e=va[159:128];
	wire[31:0] b_;
	assign b_ = (b<<30)|(b>>2);
	wire[31:0] e_;
	
	//assign e_=((a<<5)|(a>>27))+e+(d^(b&(c^d)))+K1+x0;
	assign e_ = (d^(b&(c^d)))+sum1+sum2;
	always @ (posedge clk)	
		begin
			t0<=x;
			t1[31:0] <=e_;// ((a<<5)|(a>>27))+e+(d^(b&(c^d)))+K1+x0;
			t1[63:32]<=a;
			t1[95:64]<=b_;
			t1[127:96]<=c;
			t1[159:128]<=d;
			
			//t1[191:160]<=d+(c^(a&(b_^c)))+K1+x1;			
			//t1[223:192]<=c+K1+x2;
			
			t1[191:160]<=(c^(a&(b_^c)));			
			t1[223:192]<=d+K1+x1;
			t1[255:224]<=c+K1;
			//t1 <= ((a<<5)|(a>>27))+e+(b^c^d)+K2+t0;
			//t2 <= (b<<30)|(b>>2);
		end
	assign outa = t1;
	assign outx = t0;
endmodule


module RoundN_5x5(clk, va, x, outa, outx);
	input clk;
	input [255:0] va;
	input [511:0] x;
	output wire [255:0] outa;
	output wire [511:0] outx;
	parameter n=0;
	parameter m = (n+1)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	reg [511:0] t0;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, f, g, br, h;


function [31:0] fetch4;
	input [511:0] x;
	input [31:0] n;
	reg [31:0] xx0, xx, x0, x1, x2, x3;
	begin
		x0=x[n*32+:32];
		x1=x[((n+2)&15)*32+:32];
		x2=x[((n+8)&15)*32+:32];
		x3=x[((n+13)&15)*32+:32];
		xx0=(x0^x1^x2^x3);
		xx=(xx0>>31)|(xx0<<1);
		fetch4 = xx;
	end
endfunction

	assign a=va[31:0];
	assign b=va[63:32];
	assign c=va[95:64];
	assign d=va[127:96];
	assign f=va[191:160];
	assign g=va[223:192];
	assign h=va[255:224];
	assign br = (b<<30)|(b>>2);
	assign x1 = (n<4) ? x[n*32+63:n*32+32] 
		: ((n==4) ? 32'h80000000 
		: ((n==14) ? 32'h2a0 
		: ((n<14) ? 0 
		: fetch4(x, (n+1)&15)
		)));
	reg [31:0] I;

	
	always @ (posedge clk)	
		begin
			for(I=0; I<16; I=I+1)
				begin
					if(n>=15 && I==m)
						t0[I*32+:32]<=x1;
					else
						t0[I*32+:32]<=x[I*32+:32];
				end
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;

			// all these 
			t1[31:0] <= ((a<<5)|(a>>27))+f+g;
			if(n<19)
				t1[191:160]<=(c^(a&(br^c)));
			else if(n<39)
				t1[191:160]<=a^br^c;
			else if(n<59)
				t1[191:160]<=( a & br ) | ( c & ( a | br ) );
			else
				t1[191:160]<=a^br^c;
			t1[223:192]<=h+x1;
			t1[255:224]<=c+(n<18?K1:(n<38?K2:(n<58?K3:K4)));
		end
	assign outa = t1;
	assign outx = t0;
endmodule

module SHA1_5x5(clk, ctx, data, out_ctx);
	input clk;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;
	reg[511:0] x0;
	reg[159:0] va0;
	parameter n=80;
	wire[511:0] x[n:1];
	wire[255:0] va[n:1];
	reg[159:0] delay_ctx[n+1:1];
	reg[159:0] out_sum;
	reg[31:0] sum1, sum2;
	reg [7:0] I;
	Round1 r0(clk, va0, x0, va[1], x[1], sum1, sum2);
generate
genvar gi;
  for (gi=1; gi<n; gi=gi+1) begin : VR1
    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
  end
endgenerate
always @ (posedge clk)
	begin
		va0<=ctx;
		delay_ctx[1]<=ctx;
		for(I=1; I<=n; I=I+1)
			delay_ctx[I+1]<=delay_ctx[I];
		x0[159:0]<=data;
		x0[191:160]<=32'h80000000;
		x0[479:192]<=0;
		x0[511:480]<=32'h2a0;
		sum1<=((ctx[31:0]<<5)|(ctx[31:0]>>27))+ctx[159:128];
		sum2<=data[31:0]+32'h5A827999;
	
		out_sum[31:0]<=delay_ctx[n+1][31:0]+va[n][31:0];	
		out_sum[63:32]<=delay_ctx[n+1][63:32]+va[n][63:32];	
		out_sum[95:64]<=delay_ctx[n+1][95:64]+va[n][95:64];	
		out_sum[127:96]<=delay_ctx[n+1][127:96]+va[n][127:96];	
		out_sum[159:128]<=delay_ctx[n+1][159:128]+va[n][159:128];	
	end

	assign out_ctx = out_sum;
endmodule 



module pmk_calc_ring_fifo(core_clk, 
		user_r_read_empty,
		user_r_read_rden,
		user_r_read_data,
		user_w_write_full,
		user_w_write_wren,
		user_w_write_data,
		out_status
	);
	
	input core_clk;
	output user_r_read_empty;
	input user_r_read_rden;	
	output [159:0] user_r_read_data;
	
	input user_w_write_wren;
	output user_w_write_full;
	input [159:0] user_w_write_data;
	
	output [7:0] out_status;
	
	parameter N=100;
	parameter L=82;
	parameter NL=N-L;

	//parameter Niter=10;
	parameter Niter=4096;
	reg[7:0] status=0;
	reg[31:0] counter;
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg consume_flag=1'b0;
	
	reg acc_read_enable_local=0;
	
	reg pad_read_enable=0;
	wire pad_write_enable, acc_write_enable;
	reg data_read_enable=0, data_write_enable=0, acc_empty;
	wire acc_read_enable;
	wire[159:0] pad_in, acc_in;
	reg[159:0] pad, acc_in_reg, data, acc_out;
	wire[159:0] data_sha_input, data_in;
	
	reg dumpfifos=0;
 
   scfifo accfifo (
		    .clock (core_clk),
		    .data (acc_in),
		    .rdreq (acc_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (acc_write_enable),
		    .empty (acc_empty),
		    .full (),
		    .q (acc_out),
		    .aclr (),
		    .almost_empty (),
		    .almost_full (),
		    .usedw (),
			.eccstatus()
		);
	defparam
	accfifo.add_ram_output_register = "OFF",
	accfifo.lpm_numwords = N,
	accfifo.lpm_showahead = "OFF",
	accfifo.lpm_type = "scfifo",
	accfifo.lpm_width = 160,
	accfifo.lpm_widthu = $clog2(N),
	accfifo.overflow_checking = "OFF",
	accfifo.underflow_checking = "OFF",
	accfifo.use_eab = "ON";

   scfifo datafifo (
		    .clock (core_clk),
		    .data (data_in),
		    .rdreq (data_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (data_write_enable),
		    .empty (),
		    .full (),
		    .q (data),
		    .aclr (),
		    .almost_empty (),
		    .almost_full (),
		    .usedw (),
		.eccstatus());
	defparam
	datafifo.add_ram_output_register = "OFF",
	datafifo.lpm_numwords = NL,
	datafifo.lpm_showahead = "OFF",
	datafifo.lpm_type = "scfifo",
	datafifo.lpm_width = 160,
	datafifo.lpm_widthu = $clog2(NL),
	datafifo.overflow_checking = "OFF",
	datafifo.underflow_checking = "OFF",
	datafifo.use_eab = "ON";

	
   scfifo padfifo (
		    .clock (core_clk),
		    .data (pad_in),
		    .rdreq (pad_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (pad_write_enable),
		    .empty (),
		    .full (),
		    .q (pad),
		    .aclr (),
		    .almost_empty (),
		    .almost_full (),
		    .usedw (),
		.eccstatus());			 
   defparam
	padfifo.add_ram_output_register = "OFF",
	padfifo.lpm_numwords = 2*N,
	padfifo.lpm_showahead = "OFF",
	padfifo.lpm_type = "scfifo",
	padfifo.lpm_width = 160,
	padfifo.lpm_widthu = $clog2(2*N),
	padfifo.overflow_checking = "OFF",
	padfifo.underflow_checking = "OFF",
	padfifo.use_eab = "ON";

	SHA1_5x5 s55(core_clk, pad, data_sha_input, out_ctx);

	reg [31:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	reg [31:0] write_count=0;
	reg [31:0] read_count=0;
	
	assign data_sha_input=(counter>=2*N+1) ? data : acc_in_reg;
	reg pad_write_enable_local=0;
	reg acc_write_enable_local=0;

	assign pad_write_enable = (status==0 && write_count<N*2) ? user_w_write_wren : pad_write_enable_local;
	assign acc_write_enable = (status==0 && write_count>=N*2) ? user_w_write_wren : acc_write_enable_local;
	assign pad_in = (status==0 && write_count<N*2) ? user_w_write_data : pad;
	assign acc_in = (status==0 && write_count>=N*2) ? user_w_write_data : acc_in_reg;
	assign data_in = out_ctx;
	assign user_w_write_full=(write_count==N*3);

always @ (posedge core_clk)               
	begin						
		if(status==0)
			begin
			dumpfifos<=0;
			data_write_enable<=0;
			data_read_enable<=0;
			if(user_w_write_wren)
				begin
					write_count<=write_count+1;
					if(write_count==N*3-1)
					begin
						counter <= N;
						loop_counter <= 0;
						inst_counter <= N;
//						acc_write_enable_local<=1;
						acc_read_enable_local<=1;
						pad_write_enable_local<=0;
						acc_write_enable_local<=0;
						status<=1;		
					end
				end
			end
/**
	int_0 appears in out_ctx at counter=0xB7
	data_read_enable set at 0xC7
	int_0 goes back in at counter 0xC9
	ctx_0 appears in out_ctx at counter 0x11B
	ctx_0 appears in data_sha_input at counter 0x12D
**/
		else if(status==1)// 1 clock for acc_read_enable to kick in
			begin
				pad_read_enable<=1;
				status<=2;
			end
		else if(status==2)
			begin
				pad_write_enable_local<=1;

				if(counter >= Niter*N*2-1)
					begin
						acc_read_enable_local<=0;
						acc_write_enable_local<=1;
					end
				else if(counter!=N*2+2)
					begin
						acc_read_enable_local<=1;
						acc_write_enable_local<=1;
					end
				else
					begin
						acc_read_enable_local<=0;
						acc_write_enable_local<=0;
					end
				counter<=counter+1;
				if(inst_counter == 2*N-1)
					begin
						loop_counter <= loop_counter+1;
						inst_counter <= 0;
					end
				else
					begin
						inst_counter <= inst_counter+1;
					end
				
				if(counter<2*N-1)//if(loop_counter==0)
					begin
						if(inst_counter<N+L)
							begin
								data_write_enable<=0;
								data_read_enable<=0;
							end
						else
							begin
								data_write_enable<=1;
								data_read_enable<=0;
							end
					end
				else
					begin
						data_write_enable<=1;
						data_read_enable<=1;
					end
				

//				data_in<=out_ctx;
				if(acc_read_enable_local || counter >= Niter*N*2-1)
					begin
						if(consume_flag)
							acc_in_reg<=acc_out^data;
						else
							acc_in_reg<=acc_out;
					end
				consume_flag<=(loop_counter!=0 && (inst_counter >= N))?1:0;
				if(loop_counter==Niter && inst_counter==0)
					status<=3;
			end
			else if(status==3)
				begin
					//acc_in_reg<=acc_out;//acc_in_reg<=acc_out^data;
					acc_read_enable_local<=1;
					acc_write_enable_local<=0;
					//acc_empty<=0;
					if(acc_read_enable_local==1)
						status<=4;
				end
			else if(status==4)
				begin
						if(acc_empty)
							begin
								status<=0;
								write_count<=0;
								dumpfifos<=1;
								pad_write_enable_local<=0;
								acc_write_enable_local<=0;
								acc_read_enable_local<=0;
								pad_read_enable<=0;
								data_read_enable<=0;
								data_write_enable<=0;
								read_count<=0;
								write_count<=0;
							end
				end
	end
	
	assign acc_read_enable=(status==4) ? user_r_read_rden : acc_read_enable_local;
	assign user_r_read_data=acc_out;
	assign user_r_read_empty=(status!=4) || acc_empty;
	assign out_status = status;
endmodule	


// test bench for the bare pmk_calc_ring_fifo
`timescale 1 ns / 1 ns
module pmk_calc_tb;

reg clk;
reg [31:0] counter;
wire [7:0] out;
	wire user_r_read_empty;
	reg user_r_read_rden=0;
	wire [159:0] user_r_read_data;
	wire user_w_write_full;
	reg user_w_write_wren=0;
	reg [159:0] user_w_write_data;


	pmk_calc_ring_fifo c (
				clk, 
				user_r_read_empty,
				user_r_read_rden,
				user_r_read_data,
				user_w_write_full,
				user_w_write_wren,
				user_w_write_data
			);

	reg[159:0] ipad_0=160'hdd703e0b119e9000de162d2be611b157a562a2e5;
	reg[159:0] opad_0=160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40;
	reg[159:0] data_0=160'hfe4e9708a46b0012fb850d0c87d0b1216b4a0528;
	reg[159:0] expect_int1_0=160'h66ed4af39c89a114b097e4feabd8ab01ac44780e;
	reg[159:0] expect_ctx1_0=160'h8427f3038b329cc9adb58fc8b3527b28aaf7f0ce;
	reg[159:0] expect_acc1_0=160'h7a69640b2f599cdb563082c43482ca09c1bdf5e6;
	reg[159:0] expect_acc4096_0=160'h90ac65510acd595160d1481235ed6efd8a87a4d2;
	
	reg[159:0] ipad_1=160'hdd703e0b119e9000de162d2be611b157a562a2e5;
	reg[159:0] opad_1=160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40;
	reg[159:0] data_1=160'hbd40b2ce6e1fc59622b4455559265902aa6b088c;
	reg[159:0] expect_ctx1_1=160'hbb8130829d637dfaf8127597b21b9c766a494df6;
	reg[159:0] expect_acc1_1=160'h06c1824cf37cb86cdaa630c2eb3dc574c022457a;
	reg[159:0] expect_acc4096_1=160'h8c0866ac1688a0fc1e82c064fab26f0fdb121096;

	reg[159:0] expect_acc10_0=160'h96c7329c2a3c45511891af4ac1204c4eb4925e3e;//produced with a constant '9' in the code
	reg[159:0] expect_acc10_1=160'hc9f5a0d851d9aaf405b75f4e3204e0f47b5fe086;
	
	reg[159:0] recv_data[99:0];
	reg[31:0] I;
	reg[31:0] recv_count=0;
initial
begin
	clk=1'b0;
	counter = 32'b0;
end
	
always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
	
	if(clk)
		begin
			if(counter<300)
					begin
						user_w_write_wren<=1;
						case(counter)
						0: user_w_write_data<=ipad_0;
						1: user_w_write_data<=ipad_1;
						98: user_w_write_data<=ipad_0;
						99: user_w_write_data<=ipad_1;
						100: user_w_write_data<=opad_0;
						101: user_w_write_data<=opad_1;
						198: user_w_write_data<=opad_0;
						199: user_w_write_data<=opad_1;
						200: user_w_write_data<=data_0;
						201: user_w_write_data<=data_1;
						298: user_w_write_data<=data_0;
						299: user_w_write_data<=data_1;
						default:user_w_write_data<=0;
						endcase
					end

//10-iteration subset
			else if(counter>=3700 && counter<=3800)
					begin
						user_r_read_rden<=(counter<3800?1:0);
						if(counter>3700)
							recv_data[counter-3701]<=user_r_read_data;
					end		
			else if(counter==3900)
				begin
					recv_data[0]<=recv_data[0]^expect_acc10_0;
					recv_data[1]<=recv_data[1]^expect_acc10_1;
					recv_data[98]<=recv_data[98]^expect_acc10_0;
					recv_data[99]<=recv_data[99]^expect_acc10_1;
				end
			end
/*
// full 4096: done around counter 820604
			else if(counter>=820700 && counter<=820800)
					begin
						user_r_read_rden<=1;
						if(counter>820700)
							recv_data[counter-820701]<=user_r_read_32_data;
					end			
			else if(counter==820900)
					begin
					recv_data[0]<=recv_data[0]^expect_acc4096_0;
					recv_data[1]<=recv_data[1]^expect_acc4096_1;
					end
				end
	*/	
end

endmodule


module packer_32_to_160(clk, write_32_wren, write_32_full, write_32_data,
	write_160_wren, write_160_full, write_160_data, worker_status);
   // Wires related to /dev/xillybus_write_32
	input clk;
   input write_32_wren;
   output write_32_full;
   input [31:0] write_32_data;

   output write_160_wren;
   input write_160_full;
   output [159:0] write_160_data;
	input [7:0] worker_status;
	
	reg write_160_enable=0;
	wire write_160_full;
	
	reg[159:0] input_line=0;
	reg[31:0] dwords_written=0;
		
	assign write_160_wren = write_160_enable;
	assign write_32_full = write_160_full;
	assign write_160_data = input_line;
/*	
	pmk_calc_ring_fifo worker(bus_clk, 
		read_160_empty,
		read_160_enable,
		output_line,
		user_w_write_32_full,
		write_160_enable,
		input_line,
		out_status
	);

	assign user_r_read_32_empty = read_32_empty;
	*/
   always @(posedge clk)
     begin
		if(worker_status!=0)
			dwords_written<=0;
			
		if(write_32_wren)
			begin
				input_line[159:128]<=write_32_data;
				input_line[127:0]<=input_line[159:32];
				if(dwords_written==4)
					begin
						write_160_enable<=1;
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
				write_160_enable<=0;
			end
	end
endmodule

/**
 If read_32_rden is signaled, on the next clock read_32 should point at the dword with current data
 Which means that we don't really have time to pull it on demand, it has to be there already
 Rather, read_32_rden signals that we should start replacing the content of read_32_data 
***/

module unpacker_160_to_32(clk, user_r_read_32_rden,
	user_r_read_32_empty, user_r_read_32_data,
	read_160_rden, read_160_empty,
	read_160_data,	worker_status);
	input clk;
	input user_r_read_32_rden;
	output user_r_read_32_empty;
	output reg [31:0] user_r_read_32_data;
	output read_160_rden;
	input read_160_empty;
	input [159:0] read_160_data;
	
	input [7:0] worker_status;

	reg read_160_enable=0;
	reg is_empty=0;
	reg[31:0] out32;
	reg[159:0] save_line;
	wire[159:0] line;
	reg[31:0] read_pos=0;
	reg[31:0] deadbeef=32'hDEADBEEF;
	assign user_r_read_32_empty = is_empty;
//	assign user_r_read_32_data = out32;
	assign read_160_rden = user_r_read_32_rden && (read_pos==4);
  	assign line=read_160_data;

   always @(posedge clk)
     begin
//  	line<=read_160_data;
	if(worker_status==4)
		save_line<=line;
	user_r_read_32_data<=(worker_status==4) ? line[read_pos*32+:32] : save_line[read_pos*32+:32];
	if(user_r_read_32_rden)
		begin
		is_empty<=(worker_status!=4 && read_pos==4);
		if(read_pos<4)
			begin
//			if(worker_status==4)
			read_pos<=read_pos+1;
			read_160_enable<=0;							
			end
		else	
			begin
			read_pos<=0;
			read_160_enable<=1;
			end
		end
	else
		begin
		read_160_enable<=0;
		end
     end
endmodule


// wrapper for pmk_calc_ring_fifo with an arbitrary number of stamps and automatic 32-bit I/O marshalling
// TODO: does not signal read_32_empty / write_32_full correctly
module pmk_dispatcher(clk, read_32_rden,
	read_32_empty, read_32_data,
	write_32_wren, write_32_full, write_32_data);
	input clk;
	input read_32_rden;
	output read_32_empty;
	output [31:0] read_32_data;
	input write_32_wren;
	output write_32_full;
	input [31:0] write_32_data;	
	parameter N=2;
	parameter Njobs=100;

	reg[31:0] progress=0, inst=0, state=0;

	wire read_160_empty[N-1:0], read_160_enable[N:0], write_160_wren[N:0], write_160_full[N-1:0];
	wire[159:0] write_160_data, read_160_data[N-1:0];
	wire[7:0] out_status[N-1:0];

//	assign read_160_empty[N]=read_160_empty[inst];
//	assign write_160_full[N]=write_160_full[inst];
//	assign read_160_data[N]=read_160_data[inst];
generate
genvar gi;
	for(gi=0; gi<N; gi=gi+1) begin: ass1
		assign write_160_wren[gi]=write_160_wren[N] && (inst==gi);
		end
	for(gi=0; gi<N; gi=gi+1) begin: ass2
		assign read_160_enable[gi]=read_160_enable[N] && (inst==gi);
		end
	for(gi=0; gi<N; gi=gi+1) begin: workers
		pmk_calc_ring_fifo #(Njobs) worker(clk, 
			read_160_empty[gi],
			read_160_enable[gi],
			read_160_data[gi],
			write_160_full[gi],
			write_160_wren[gi],
			write_160_data,
			out_status[gi]
		);
		end
endgenerate

	packer_32_to_160 packer(clk, write_32_wren, write_32_full, write_32_data,
		write_160_wren[N], write_160_full[inst], write_160_data, out_status[inst]);
	unpacker_160_to_32 unpacker(clk, read_32_rden, read_32_empty, read_32_data, 
		read_160_enable[N], read_160_empty[inst], read_160_data[inst], out_status[inst]);

	//assign out_status[N]=out_status[inst];
always @ (posedge clk)
	begin
	if(N>1)
			begin
				if(state==0)
					begin
					if(write_160_wren[N])
						begin
						assert(!write_160_full[inst]);
						assert(out_status[inst]==0);
						progress <= progress+1;
						end
					else if(progress>=3*Njobs)
						begin
						progress<=0;
						if(inst<N-1)
							begin
							inst<=inst+1;
							end
						else
							begin
							inst<=0;
							state<= state^1;
							end
						end
	
					end	
				else
					begin
						if(read_32_rden) 
							begin
							// this assertion fails at transition between cores, safe to ignore
							//assert(!user_r_read_32_empty);
							assert(out_status[inst]!=2);
							if(progress>=5*Njobs-1)
								begin
								progress<=0;
								if(inst<N-1)
									begin
									inst<=inst+1;
									end
								else
									begin
									inst<=0;
									state<= state^1;
									end
								end
							else
								progress <= progress+1;
							end
					end
			end
	end
endmodule


// test bench for pmk_dispatcher
`timescale 1 ns / 1 ns
module pmk_calc_32_tb;

	reg clk;
	reg [31:0] counter;
	wire [7:0] out;
	wire read_32_empty;
	reg read_32_rden=0;
	wire [31:0] read_32_data;
	wire write_32_full;
	reg write_32_wren=0;
	reg [31:0] write_32_data;

	parameter N=2;
	parameter Njobs=128;
	parameter Niter=10;
	pmk_dispatcher #(N, Njobs) disp(clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data);
	
	/*
	wire read_160_empty, read_160_enable, write_160_wren, write_160_full;
	wire[159:0] write_160_data, read_160_data;
	wire[7:0] out_status;
	
	pmk_calc_ring_fifo worker(clk, 
		read_160_empty,
		read_160_enable,
		read_160_data,
		write_160_full,
		write_160_wren,
		write_160_data,
		out_status
	);

	packer_32_to_160 packer(clk, user_w_write_32_wren, user_w_write_32_full, user_w_write_32_data,
		write_160_wren, write_160_full, write_160_data, out_status);	
	unpacker_160_to_32 unpacker(clk, user_r_read_32_rden, user_r_read_32_empty, user_r_read_32_data, 
		read_160_enable, read_160_empty, read_160_data,	out_status);
	*/	

	reg[159:0] ipad_0=160'hdd703e0b119e9000de162d2be611b157a562a2e5;
	reg[159:0] opad_0=160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40;
	reg[159:0] data_0=160'hfe4e9708a46b0012fb850d0c87d0b1216b4a0528;
	reg[159:0] expect_int1_0=160'h66ed4af39c89a114b097e4feabd8ab01ac44780e;
	reg[159:0] expect_ctx1_0=160'h8427f3038b329cc9adb58fc8b3527b28aaf7f0ce;
	reg[159:0] expect_acc1_0=160'h7a69640b2f599cdb563082c43482ca09c1bdf5e6;
	reg[159:0] expect_acc10_0=160'h96c7329c2a3c45511891af4ac1204c4eb4925e3e;//produced with a constant '9' in the code
	reg[159:0] expect_acc4096_0=160'h90ac65510acd595160d1481235ed6efd8a87a4d2;
	
	reg[159:0] ipad_1=160'hdd703e0b119e9000de162d2be611b157a562a2e5;
	reg[159:0] opad_1=160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40;
	reg[159:0] data_1=160'hbd40b2ce6e1fc59622b4455559265902aa6b088c;
	reg[159:0] expect_ctx1_1=160'hbb8130829d637dfaf8127597b21b9c766a494df6;
	reg[159:0] expect_acc1_1=160'h06c1824cf37cb86cdaa630c2eb3dc574c022457a;
	reg[159:0] expect_acc10_1=160'hc9f5a0d851d9aaf405b75f4e3204e0f47b5fe086;
	reg[159:0] expect_acc4096_1=160'h8c0866ac1688a0fc1e82c064fab26f0fdb121096;

	reg[159:0] ipad_2=160'h51da39b7abb93a9512b3d4483e02457747588185;
	reg[159:0] opad_2=160'h242d564083cf6d7346d2d8a2059405571367cfec;
	reg[159:0] data_2=160'h6ae229b8aded0e8b9974d9fce62d02375b19c584;
	reg[159:0] expect_acc10_2=160'h21aefd2a1419cfcd9a76c615da5f96e253094569;
	reg[159:0] expect_acc4096_2=160'hc3cd9902b1d20fe443902c0b3404b2b19295aceb;
	
	reg[31:0] pads[30*Njobs*N-1:0];
//	reg[31:0] expect_data[1000*N-1:0];
	reg[31:0] recv_data[5*Njobs*N-1:0];
	reg[31:0] I, J;
	reg[31:0] recv_count=0;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	for(I=0; I<5; I=I+1)
		begin
			for(J=0; J<N; J=J+1)
				begin
					pads[J*15*Njobs+I] <= ipad_0[I*32+:32];
					pads[J*15*Njobs+I+5] <= ipad_1[I*32+:32];
					pads[J*15*Njobs+I+5*Njobs-5] <= ipad_2[I*32+:32];
					pads[J*15*Njobs+I+5*Njobs] <= opad_0[I*32+:32];
					pads[J*15*Njobs+I+5*Njobs+5] <= opad_1[I*32+:32];
					pads[J*15*Njobs+I+10*Njobs-5] <= opad_2[I*32+:32];
					pads[J*15*Njobs+I+10*Njobs] <= data_0[I*32+:32];
					pads[J*15*Njobs+I+10*Njobs+5] <= data_1[I*32+:32];
					pads[J*15*Njobs+I+15*Njobs-5] <= data_2[I*32+:32];

					pads[N*15*Njobs+J*15*Njobs+I] <= ipad_1[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+5] <= ipad_2[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+5*Njobs-5] <= ipad_0[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+5*Njobs] <= opad_1[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+5*Njobs+5] <= opad_2[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+10*Njobs-5] <= opad_0[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+10*Njobs] <= data_1[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+10*Njobs+5] <= data_2[I*32+:32];
					pads[N*15*Njobs+J*15*Njobs+I+15*Njobs-5] <= data_0[I*32+:32];
				end
		end
		
	for(I=10; I<495; I=I+1)
		begin
			for(J=0; J<N; J=J+1)
				begin
					pads[J*15*Njobs+I]<=0;//1+(I>>2);
					pads[J*15*Njobs+I+5*Njobs]<=0;//1+(I>>2);
					pads[J*15*Njobs+I+10*Njobs]<=1;
					pads[N*15*Njobs+J*15*Njobs+I]<=0;//1+(I>>2);
					pads[N*15*Njobs+J*15*Njobs+I+5*Njobs]<=0;//1+(I>>2);
					pads[N*15*Njobs+J*15*Njobs+I+10*Njobs]<=1;
				end
		end
end
	
	wire[31:0] first_write, first_read, second_write, second_read, work_time;
	assign first_write=0;
	assign work_time=2*Njobs*Niter+200;
	// assumes 10 iterations only (with 4096, takes something like 30 min for ModelSim to complete the run)
	assign first_read=15*Njobs*N+work_time;
	assign second_write=20*Njobs*N+work_time+200;
	assign second_read=35*Njobs*N+2*work_time+200;
always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
	
	if(clk)
	begin
	
			if(counter>=first_write && counter<first_write+15*Njobs*N)
					begin
						write_32_wren<=1;
						write_32_data<=pads[counter-first_write];
					end
			else if(counter>=second_write && counter<second_write+15*Njobs*N)
					begin
						write_32_wren<=1;
						write_32_data<=pads[15*Njobs*N+counter-second_write];
					end
			else
					write_32_wren<=0;

			if(counter==first_write+15*Njobs*N+10)
				begin
					$display("All modules loaded");
/*
					for(I=0; I<N; I=I+1)
						begin
							$display("Module %d status %d", I, out_status[I]);
							assert(out_status[I]!=0);
						end
*/
				end
			if(counter>=first_read && counter<=first_read+5*Njobs*N)
					begin
					read_32_rden<=(counter<first_read+5*Njobs*N ? 1 : 0);
					if(counter>first_read)
						recv_data[counter-first_read-1]<=read_32_data;
					end			
			else if(counter==first_read+5*Njobs*N+100)
				begin
				$display("First read done");
				read_32_rden<=0;
				for(I=0; I<5; I=I+1)
					begin
					for(J=0; J<N; J=J+1)
						begin
						if(recv_data[J*5*Njobs+I]!=expect_acc10_0[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I], expect_acc10_0[I*32+:32]);
						if(recv_data[J*5*Njobs+I+5]!=expect_acc10_1[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5], expect_acc10_1[I*32+:32]);
						if(recv_data[J*5*Njobs+I+5*Njobs-5]!=expect_acc10_2[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5*Njobs-5], expect_acc10_2[I*32+:32]);
						end
					end
				end
			else if(counter>=second_read && counter<=second_read+5*Njobs*N)
					begin
					read_32_rden<=(counter<second_read+5*Njobs*N ? 1 : 0);
					if(counter>second_read)
						recv_data[counter-second_read-1]<=read_32_data;
					end			
			else if(counter==second_read+5*Njobs*N+100)
				begin
				read_32_rden<=0;
				$display("Second read done");
				for(I=0; I<5; I=I+1)
					begin
					assert(recv_data[I]==expect_acc10_1[I*32+:32]);
					assert(recv_data[I+5]==expect_acc10_2[I*32+:32]);
					assert(recv_data[I+5*Njobs-5]==expect_acc10_0[I*32+:32]);
					end
				end
			else if(counter==second_read+5*Njobs*N+200)
				begin
				$display("Finished!");
				read_32_rden<=0;
				end
			else
				read_32_rden<=0;
		end
end


endmodule
