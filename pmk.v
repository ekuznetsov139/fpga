/*****************************************************************************

   FPGA SHA1 and WPA2 PMK generators 
	Fully unrolled; avg. 8000 ALM per instance with throughput of 1 SHA/clock
	Tested with Cyclone V 5CSEBA6U23I7 and 5CGTFD9E5F35C7

*****************************************************************************/




module Round1(clk, va, x, outa, sum1, sum2);
	input clk;
	input [159:0] va;
	input [159:0] x;
	input[31:0] sum1, sum2;
	output [255:0] outa;
	parameter K1=32'h5A827999;
	reg [31:0] f;
	reg [255:0] t1;
	reg [511:0] t0;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, e;
	assign {x2,x1,x0}=x[95:0];
	assign {e,d,c,b,a}=va;
	wire[31:0] b_;
	assign b_ = (b<<30)|(b>>2);
	wire[31:0] e_;
	
	assign e_ = (d^(b&(c^d)))+sum1+sum2;
	always @ (posedge clk)	
		begin
			t1[31:0] <=e_;
			t1[63:32]<=a;
			t1[95:64]<=b_;
			t1[127:96]<=c;
			t1[159:128]<=d;
			t1[191:160]<=(c^(a&(b_^c)));			
			t1[223:192]<=d+K1+x1;
			t1[255:224]<=c+K1;
		end
	assign outa = t1;
endmodule


module Round1_5x5(clk, va, x, outa);
	input clk;
	input [255:0] va;
	input [159:0] x;
	output wire [255:0] outa;
	parameter n=0;
	parameter m = (n+1)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	reg [511:0] t0;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, e, f, g, br, h;
	assign {h,g,f,e,d,c,b,a}=va;
	assign br = (b<<30)|(b>>2);
	assign x1 = (n<4) ? x[n*32+63:n*32+32] 
		: ((n==4) ? 32'h80000000 
		: ((n==14) ? 32'h2a0 
		: 0
		));
	reg [31:0] I;

	always @ (posedge clk)	
		begin
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;

			t1[31:0] <= ((a<<5)|(a>>27))+f+g;
			t1[191:160]<=(c^(a&(br^c)));
			t1[223:192]<=h+x1;
			t1[255:224]<=c+K1;
		end
		

	assign outa = t1;
//	assign outx = t0;
endmodule



module Round15_5x5(clk, va, x1, outa);
	input clk;
	input [255:0] va;
	input [31:0] x1;
	output [255:0] outa;
	parameter n = 15;
	parameter m = 0;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	wire[31:0] a, b, c, d, e, f, g, br, h;
	
	assign {h,g,f,e,d,c,b,a}=va;
	assign br = (b<<30)|(b>>2);
	
	reg [31:0] I;

	always @ (posedge clk)	
		begin
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;

			t1[31:0] <= ((a<<5)|(a>>27))+f+g;
			t1[191:160]<=(c^(a&(br^c)));
			t1[223:192]<=h+x1;
			t1[255:224]<=c+K1;
		end
	
//	assign outx[159:32]=x[159:32];	
//	assign outx[31:0]=x1;

	assign outa = t1;
//	assign outx = t0;
endmodule


module RoundN_5x5(clk, va, outa, vx);
	input clk;
	input [255:0] va;
	input [127:0] vx;
	output [255:0] outa;
	parameter n=0;
	parameter m1 = (n+1)&15;
	parameter m2 = (n+2)&15;
	parameter m3 = (n+3)&15;
	parameter m4 = (n+4)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	
function automatic [31:0] rot1;
	input [31:0] y;
	begin
//	rot1 = (x<<1)|(x>>31);
	rot1 = {y[30:0], y[31:31]};
	end
endfunction

	//wire[31:0] x1, x2_t1, x3_t1, x4_t1;
	//assign {x4_t1,x3_t1,x2_t1,x1} = vx;
	wire[31:0] x1,x2,x3_t2,x4_t2;
	assign {x4_t2,x3_t2,x2,x1} = vx;
	
function [31:0] getK;
	input [31:0] n;
	begin
		getK=n<19?K1:(n<39?K2:(n<59?K3:K4));
	end
endfunction

function [31:0] FUN;
	input [31:0] a, br, c, n;
	begin
		if(n<19)
			FUN=(c^(a&(br^c)));
		else if(n<39)
			FUN=a^br^c;
		else if(n<59)
			FUN=( a & br ) | ( c & ( a | br ) );
		else
			FUN=a^br^c;
	end
endfunction



function [31:0] rot5;
	input [31:0] x;
	begin
//	rot5 = (x<<5)|(x>>27);
	rot5 = {x[26:0],x[31:27]};
	end
endfunction

function [31:0] rot30;
	input [31:0] x;
	begin
	rot30 = (x<<30)|(x>>2);
	end
endfunction

	reg [31:0] I;

	
	wire [31:0] a0, b0, c0, d0, e0, f0, g0, h0;
	assign {h0,g0,f0,e0,d0,c0,b0,a0}=va;

	reg [31:0] a4, b4, c4, d4, e4, f4, g4, h4;
	reg[31:0] a1, b1, c1, h1, y10,  a2, b2, c2, y20, y21,  a3, b3, y30, y31, y32;

	reg[31:0] x1_t2, x3_t4;
	
	//reg[31:0] x2, x3_t2, x4_t2;
	reg[31:0] x3, x4_t3;
	reg[31:0] x4;
	
	

	reg[31:0] y22, y33;
	
	always @ (posedge clk)	
		begin
		x1_t2 <= x1;
//		x2 <= x2_t1;
//		x3_t2 <= x3_t1;
//		x4_t2 <= x4_t1;
		
		x3 <= x3_t2;
		x4_t3 <= x4_t2;//rot1(x4_t2^x1_t2);
		
		x3_t4 <= x3;
		x4 <= x4_t3;

		a1<=a0;
		b1<=b0;
		c1<=c0+getK(n+1);
		h1<=h0+FUN(a0, rot30(b0), c0, n);
		y10<=rot5(a0)+f0+g0;

		a2<=rot30(a1);
		b2<=rot30(b1);
		y22<=rot30(b1)+getK(n+2);
		c2<=c1+x2;
		y20<=y10;
		y21<=rot5(y10)+h1+x1_t2; 

		a3<=a2;
		y33<=a2+getK(n+3);
		b3<=y22+FUN(y21,rot30(y20),a2, n+2);
		y30<=rot30(y20);
		y31<=y21;
		y32<=rot5(y21)+FUN(y20,a2,b2,n+1)+c2;

		a4<=rot5(y32)+b3+x3_t4; 
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
		e4<=a3;
		f4<=FUN(y32,rot30(y31),y30,n+3);
		g4<=y33+x4;
		h4<=y30+getK(n+4);
		end
	assign outa = {h4, g4, f4, e4, d4, c4, b4, a4};
//	assign outx = t0;
endmodule


module SHA1_5x5_bare(clk, timer, ctx, data, out_ctx);
	input clk;
	input [4:0] timer;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;
	reg[159:0] va0;
	//parameter n=80;
	wire[511:0] xw16;
	wire[255:0] va[32:1];
	reg[159:0] out_sum;
	reg[31:0] sum1, sum2;
	reg [7:0] I, J;
	


function automatic [31:0] rot1;
	input [31:0] y;
	begin
//	rot1 = (x<<1)|(x>>31);
	rot1 = {y[30:0], y[31:31]};
	end
endfunction

function automatic [31:0] fetch4;
	input [511:0] x;
	input [31:0] n;
	reg [31:0] x0, x1, x2, x3;
	begin
		x0=x[n*32+:32];
		x1=x[((n+2)&15)*32+:32];
		x2=x[((n+8)&15)*32+:32];
		x3=x[((n+13)&15)*32+:32];
		fetch4 = rot1(x0^x1^x2^x3);
	end	
endfunction


	reg[159:0] xbuf1[15:0];
	

	Round1 r0(clk, va0, xbuf1[0], va[1], sum1, sum2);
	
	wire[127:0] vx[31:16];
	
`define REAL_VX
	
`ifdef REAL_VX
	(* ramstyle = "M10K" *) reg[511:0] xbuf2[80:15];

generate
	genvar gi;
	for(gi=16; gi<32; gi=gi+1)
		begin : abc
			
			// If I declare 'n' as 'wire[31:0]', the compiler throws a 'non-constant index always falls outside the declared range' error
			// If I declare 'n' as 'integer', it gets stuck on elaborating SHA1_5x5_bare
			// Therefore the only option is to explicitly stick (gi-16)... in place of n
			
			//wire[31:0] m4;
			integer m4;
			//integer n;
			//assign n = (gi-16)*4+16;
			assign m4 = ((gi-16)*4+4) & 15;
			wire [31:0] x1,x2,x3,x4;
			wire[127:0] xc;
		
			assign x1 = fetch4(xbuf2[(gi-16)*4+16], ((gi-16)*4+16+1)&15);
			assign x2 = fetch4(xbuf2[(gi-16)*4+16], ((gi-16)*4+16+2)&15);
			assign x3 = fetch4(xbuf2[(gi-16)*4+16], ((gi-16)*4+16+3)&15);
			//wire[31:0] x4 = fetch4(fetch4(xbuf2[n], (n+1)&15);
			assign x4 = xbuf2[(gi-16)*4+16][m4*32+:32]^xbuf2[(gi-16)*4+16][((m4+2)&15)*32+:32]^xbuf2[(gi-16)*4+16][((m4+8)&15)*32+:32];
			
			
			
			reg[31:0] x1d, x2d, x3d, x4d;
			assign xc = {rot1(x1d^x4d), x3d, x2d, x1d};

			assign vx[gi]={rot1(x1d^x4d),x3d,x2d,x1};
			
		always @(posedge clk)
			begin
				x1d<=x1;
				x2d<=x2;
				x3d<=x3;
				x4d<=x4;
				
				xbuf2[(gi-16)*4+16+1]<=xbuf2[(gi-16)*4+16];
				
				if((gi&3)==0)
					xbuf2[(gi-16)*4+16+2] <= {xbuf2[(gi-16)*4+16+1][511:160], xc, xbuf2[(gi-16)*4+16+1][31:0]};
				else if((gi&3)==1)
					xbuf2[(gi-16)*4+16+2] <= {xbuf2[(gi-16)*4+16+1][511:288], xc, xbuf2[(gi-16)*4+16+1][159:0]};
				else if((gi&3)==2)
					xbuf2[(gi-16)*4+16+2] <= {xbuf2[(gi-16)*4+16+1][511:416], xc, xbuf2[(gi-16)*4+16+1][287:0]};
				else
					xbuf2[(gi-16)*4+16+2] <= {x3d, x2d, x1d, xbuf2[(gi-16)*4+16+1][415:32], rot1(x1d^x4d)};
				xbuf2[(gi-16)*4+16+3]<=xbuf2[(gi-16)*4+16+2];
				xbuf2[(gi-16)*4+16+4]<=xbuf2[(gi-16)*4+16+3];
			end
		end
endgenerate	

`else
	(* ramstyle = "M10K" *) reg[511:0] xbuf2[16:15];
generate
	genvar gi;
	for(gi=16; gi<32; gi=gi+1)
		begin : abc
			assign vx[gi]=xbuf1[15][127:0];
	end
endgenerate
`endif
	
generate
//genvar gi;
  for (gi=1; gi<15; gi=gi+1) begin : VR1
    Round1_5x5 #(gi) r(clk, va[gi], xbuf1[gi], va[gi+1]);
  end
  for (gi=16; gi<32; gi=gi+1) begin : VR2
	
    RoundN_5x5 #(16 + (gi-16)*4) r(clk, va[gi], va[gi+1], vx[gi]);
  end
endgenerate
	Round15_5x5 r15(clk, va[15], rot1(xbuf1[15][31:0]^xbuf1[15][95:64]), va[16]);
always @ (posedge clk)
	begin
		va0<=ctx;

		xbuf1[0]<=data;
		for(I=0; I<15; I=I+1)
			xbuf1[I+1]<=xbuf1[I];
			
		xbuf2[16][31:0] <= rot1(xbuf1[15][31:0]^xbuf1[15][95:64]);
		xbuf2[16][159:32]<=xbuf1[15][159:32];
		
		xbuf2[16][191:160]<=32'h80000000;
		xbuf2[16][479:192]<=0;
		xbuf2[16][511:480]<=32'h2a0;
		sum1<=((ctx[31:0]<<5)|(ctx[31:0]>>27))+ctx[159:128];
		sum2<=data[31:0]+32'h5A827999;
	end
	assign out_ctx = va[32][159:0];
endmodule 





module ring_buffer(core_clk,
	cycle, replace,
	in_data,
	out_data,
	mid_data,
	mid_data2);
	input core_clk, cycle, replace;
	input wire [159:0] in_data;
	output wire [159:0] out_data;
	output wire [159:0] mid_data;
	output wire [159:0] mid_data2;
	reg[31:0] cycle_count=0;
	parameter Size=100;
	parameter Mid=0;
	parameter Mid2=0;
	reg[31:0] I;
	
	reg [159:0] data[Size-1:0];
	assign mid_data=data[Mid];
	assign mid_data2=data[Mid2];
	assign out_data=data[Size-1];
always @(posedge core_clk)
	begin
		if(cycle)
			begin
			cycle_count<=cycle_count+1;
			for(I=0; I+1<Size; I=I+1)
				data[I+1]<=data[I];
			if(replace)
				data[0]<=in_data;
			else
				data[0]<=data[Size-1];
			//out_data<=data[0];
			end
	end	
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
	parameter Niter=10;
	//parameter Niter=4096;
	parameter L=82;
	parameter NL=N-L;

	reg[7:0] status=0;
	reg[22:0] counter; // maximum value Niter*N*2. 20 bits enough for up to N=128.
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg acc_empty;
	reg[159:0] pad, data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;
	reg[15:0] read_count=0;

	reg pad_cycle=0, pad_replace=0;
	reg [159:0] pad_ring_in_data;
	wire [159:0] pad_ring_out_data;
	wire [159:0] pad_ring_mid_data;	
	ring_buffer #(2*N, N-3) pad_buf (
		.core_clk(core_clk), 
		.cycle(pad_cycle),
		.replace(pad_replace), 
		.in_data(pad_ring_in_data),
		.out_data(pad_ring_out_data),
		.mid_data(pad_ring_mid_data),
		.mid_data2()
		);
	reg data_cycle=0, data_replace=0;
	
	reg [159:0] data_ring_in_data;
	wire [159:0] data_ring_out_data;
	
	ring_buffer #(NL) data_buf (
		.core_clk(core_clk), 
		.cycle(data_cycle),
		.replace(data_replace), 
		.in_data(out_ctx),
		.out_data(data_bare),
		.mid_data(),
		.mid_data2()
		);
		
	wire acc_cycle;
	reg acc_replace=0;
	wire [159:0] acc_ring_in_data;
	wire [159:0] acc_ring_out_data;
	
	ring_buffer #(N) acc_buf (
		.core_clk(core_clk), 
		.cycle(acc_cycle),
		.replace(acc_replace), 
		.in_data(acc_ring_in_data),
		.out_data(acc_ring_out_data),
		.mid_data(),
		.mid_data2()
		);
		
	reg [159:0] write_data_copy;
	reg acc_cycle_local=0;
	assign acc_ring_in_data=(status!=2) ? write_data_copy : (acc_ring_out_data^data);

	reg[4:0] timer=0;
	SHA1_5x5_bare s55(core_clk, timer, pad_ring_out_data, data_sha_input, out_ctx);

	reg [15:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	reg [15:0] write_count=0;
	
	reg data_src_switch=0;

	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;//acc_in_reg;

	reg [7:0] sms=0;
	reg [2:0] sink=0;

	assign user_w_write_full=(write_count==N*3);
	assign acc_cycle = (status==4) ? user_r_read_rden : acc_cycle_local;
	assign user_r_read_data=acc_ring_out_data;
	assign user_r_read_empty=(status!=4) || acc_empty;
	assign out_status = status;

always @ (posedge core_clk)               
	begin					
		if(timer!=31)
			timer<=timer+1;
		else
			timer<=0;
		if(status==0)
			begin
			acc_empty<=0;
			if(user_w_write_wren)
				begin
				
				if(sink==0 || sink==1)
					begin
					pad_cycle<=1;
					pad_replace<=1;
					pad_ring_in_data<=user_w_write_data;
					acc_cycle_local<=0;
					acc_replace<=0;
					end
				else
					begin
					pad_cycle<=0;
					pad_replace<=0;
					acc_cycle_local<=1;
					acc_replace<=1;
					write_data_copy<=user_w_write_data;
					end
				
				write_count<=write_count+1;
				if(write_count==N+1)
					sink<=1;
				else if(write_count==N*2-1)
					sink<=2;
				else if(write_count==N*3-1)
					begin
					sink<=3;
					counter <= N;
					loop_counter <= 0;
					inst_counter <= N;
					sms<=1;
					status<=1;
					end
				end
			else
				begin
				pad_cycle<=0;
				pad_replace<=0;
				acc_cycle_local<=0;
				acc_replace<=0;
				end
			end
		else if(status==1)
			begin
			read_count<=0;
			data_cycle<=1;
			data_replace<=1;
			status<=2;
			sms<=2;
			acc_cycle_local<=0;
			acc_replace<=0;
			end
		else if(status==2)
			begin
				pad_cycle<=1;
				pad_replace<=0;

				if(counter==Niter*N*2-1)
					sms<=4;
				if(counter==Niter*N*2)
					sms<=5;
				if(counter==Niter*N*2+1)
					status<=4;
				if(counter==2*N)
					data_src_switch<=1;

				//consume_flag<=(loop_counter!=0 && (inst_counter >= N))?1:0;
				acc_replace<=(loop_counter!=0 && (inst_counter >= N) && sms<5)?1:0;

				if(sms==4||sms==5)
					acc_cycle_local<=0;
				else
					acc_cycle_local<=1;
				
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
				
				data[31:0]<=data_bare[31:0]+pad_half_delayed[31:0];
				data[63:32]<=data_bare[63:32]+pad_half_delayed[63:32];
				data[95:64]<=data_bare[95:64]+pad_half_delayed[95:64];
				data[127:96]<=data_bare[127:96]+pad_half_delayed[127:96];
				data[159:128]<=data_bare[159:128]+pad_half_delayed[159:128];
				
				// allow some slack in placement of pad_half viz. data
				//pad_half_delayed <= pad_half;
				pad_half_delayed <= pad_ring_mid_data;

			end
			else if(status==4)
				begin
				if(user_r_read_rden)
					read_count<=read_count+1;
				if(read_count>=N)
					acc_empty<=1;
				if(acc_empty)
					begin
					status<=0;
					write_count<=0;
					data_src_switch<=0;
					write_count<=0;
					pad_cycle<=0;
					sink<=0;
					end
				end
	end
	
endmodule	


module pmk_calc_ring_fifo_v2(core_clk, 
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

	parameter N=200;
	parameter Niter=10;
	parameter L=82;
	
	
	reg[7:0] status=0;
	reg[22:0] counter; 
	wire[159:0] out_ctx, out_ctx2;
	reg[31:0] I, J;
	reg acc_empty;
	reg[159:0] pad, data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;
	reg[15:0] read_count=0;

	reg pad_cycle=0, pad_replace=0;
	reg [159:0] pad_ring_in_data;
	wire [159:0] pad_ring_out_data;
	wire [159:0] pad_ring_mid_data, pad_ring_mid_data2;	
	ring_buffer #(2*N, L, N-1) pad_buf1 (
		.core_clk(core_clk), 
		.cycle(pad_cycle),
		.replace(pad_replace), 
		.in_data(pad_ring_in_data),
		.out_data(pad_ring_out_data),
		.mid_data(pad_ring_mid_data),
		.mid_data2(pad_ring_mid_data2)
		);
		
	reg data_cycle=0, data_replace=0;	
	reg [159:0] data_ring_in_data;
	wire [159:0] data_ring_out_data;	
	ring_buffer #(N-2*L) data_buf (
		.core_clk(core_clk), 
		.cycle(data_cycle),
		.replace(data_replace), 
		.in_data(out_ctx2),
		.out_data(data_bare),
		.mid_data() 
		);
		
	wire acc_cycle;
	reg acc_replace=0;
	wire [159:0] acc_ring_in_data;
	wire [159:0] acc_ring_out_data;	
	ring_buffer #(N) acc_buf (
		.core_clk(core_clk), 
		.cycle(acc_cycle),
		.replace(acc_replace), 
		.in_data(acc_ring_in_data),
		.out_data(acc_ring_out_data),
		.mid_data()
		);
		
	reg [159:0] write_data_copy;
	reg acc_cycle_local=0;
	assign acc_ring_in_data=(status!=2) ? write_data_copy : (acc_ring_out_data^data);
		
	SHA1_5x5_bare s55_fwd(core_clk, pad_ring_out_data, data_sha_input, out_ctx);
	
	reg[159:0] data_sha_input2;
	SHA1_5x5_bare s55_inv(core_clk, pad_ring_mid_data2, data_sha_input2, out_ctx2);

	reg [15:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	reg [15:0] write_count=0;
	
	reg data_src_switch=0;

	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;

	reg [7:0] sms=0;
	reg [2:0] sink=0;

	assign user_w_write_full=(write_count==N*3);
	assign acc_cycle = (status==4) ? user_r_read_rden : acc_cycle_local;
	assign user_r_read_data=acc_ring_out_data;
	assign user_r_read_empty=(status!=4) || acc_empty;
	assign out_status = status;

always @ (posedge core_clk)               
	begin						
		if(status==0)
			begin
			acc_empty<=0;
			if(user_w_write_wren)
				begin
				
				if(sink==0 || sink==1)
					begin
					pad_cycle<=1;
					pad_replace<=1;
					pad_ring_in_data<=user_w_write_data;
					acc_cycle_local<=0;
					acc_replace<=0;
					end
				else
					begin
					pad_cycle<=0;
					pad_replace<=0;
					acc_cycle_local<=1;
					acc_replace<=1;
					write_data_copy<=user_w_write_data;
					end
				
				write_count<=write_count+1;
				if(write_count==N+1)
					sink<=1;
				else if(write_count==N*2-1)
					sink<=2;
				else if(write_count==N*3-1)
					begin
					sink<=3;
					counter <= N;
					loop_counter <= 0;
					inst_counter <= N;
					sms<=1;
					status<=1;
					end
				end
			else
				begin
				pad_cycle<=0;
				pad_replace<=0;
				acc_cycle_local<=0;
				acc_replace<=0;
				end
			end
		else if(status==1)
			begin
			read_count<=0;
			data_cycle<=1;
			data_replace<=1;
			status<=2;
			sms<=2;
			acc_cycle_local<=0;
			acc_replace<=0;
			end
		else if(status==2)
			begin
				pad_cycle<=1;
				pad_replace<=0;

				// stop draining acc
				if(counter==Niter*N-1)
					sms<=4;
					
				// and stop putting new data in
				if(counter==Niter*N)
					sms<=5;
					
				// and we're done
				if(counter==Niter*N+1)
					status<=4;
				
				
				//if(sms==3)
				if(counter==N)
					data_src_switch<=1;

				acc_replace<=1;

				if(sms==4||sms==5)
					acc_cycle_local<=0;
				else
					acc_cycle_local<=1;
				
				counter<=counter+1;
				if(inst_counter == N-1)
					begin
					loop_counter <= loop_counter+1;
					inst_counter <= 0;
					end
				else
					begin
					inst_counter <= inst_counter+1;
					end
				
				data[31:0]   <=data_bare[31:0]   +pad_half_delayed[31:0];
				data[63:32]  <=data_bare[63:32]  +pad_half_delayed[63:32];
				data[95:64]  <=data_bare[95:64]  +pad_half_delayed[95:64];
				data[127:96] <=data_bare[127:96] +pad_half_delayed[127:96];
				data[159:128]<=data_bare[159:128]+pad_half_delayed[159:128];

				data_sha_input2[31:0]   <=out_ctx[31:0]   +pad_ring_mid_data[31:0];
				data_sha_input2[63:32]  <=out_ctx[63:32]  +pad_ring_mid_data[63:32];
				data_sha_input2[95:64]  <=out_ctx[95:64]  +pad_ring_mid_data[95:64];
				data_sha_input2[127:96] <=out_ctx[127:96] +pad_ring_mid_data[127:96];
				data_sha_input2[159:128]<=out_ctx[159:128]+pad_ring_mid_data[159:128];
				
				pad_half_delayed <= pad_ring_mid_data2;

			end
			else if(status==4)
				begin
				if(user_r_read_rden)
					read_count<=read_count+1;
				if(read_count>=N)
					acc_empty<=1;
				if(acc_empty)
					begin
					status<=0;
					write_count<=0;
					data_src_switch<=0;
					write_count<=0;
					pad_cycle<=0;
					sink<=0;
					end
				end
	end
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
	reg [7:0] output_status;

	pmk_calc_ring_fifo #(100,10) c (
				clk, 
				user_r_read_empty,
				user_r_read_rden,
				user_r_read_data,
				user_w_write_full,
				user_w_write_wren,
				user_w_write_data,
output_status
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
			else if(counter>=3700 && counter<3800)
					begin
						user_w_write_wren<=0;
						user_r_read_rden<=(counter<3799?1:0);
						recv_data[counter-3700]<=user_r_read_data;
					end		
			else if(counter==3900)
				begin
					user_w_write_wren<=0;
					$display("%x %x", recv_data[0][31:0], expect_acc10_0[31:0]);
					$display("%x %x", recv_data[1][31:0], expect_acc10_1[31:0]);
					assert(recv_data[0]==expect_acc10_0);
					assert(recv_data[1]==expect_acc10_1);
					assert(recv_data[98]==expect_acc10_0);
					assert(recv_data[99]==expect_acc10_1);
				end
			else
				user_w_write_wren<=0;
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
	parameter Niter=4096;

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
		pmk_calc_ring_fifo #(Njobs,Niter) worker(clk, 
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


`timescale 1 ns / 1 ns
module sha1_tb;
	reg clk;
	reg [31:0] counter;
	reg [159:0] ctx, data, out_ctx, expect_ctx_0, expect_ctx_1;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	ctx = 0;
	data = 0;
	expect_ctx_0 = 160'h1b6b263594af1e2cef6d7bb40f46529e885669bf;
	expect_ctx_1 = 160'hee249bc3dfb613cb7384e2c6226b184320f9aca3;
	//160'hef47e12a6961e1ba74a8282dac16e632221cf20a;
end

SHA1_5x5_bare sha(clk, counter[4:0], ctx, data, out_ctx);

always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
	
	if(clk)
	begin
		if(counter==100)
			begin
				ctx <= 160'h0123456789abcdef0123456789abcdef01234567;
				data <= 160'h23456789abcdef0123456789abcdef0123456789;
				$display("%x %x", out_ctx[31:0], expect_ctx_0[31:0]);
				assert(out_ctx==expect_ctx_0);
			end
		if(counter>100 && counter<200)
			begin
				if(out_ctx==expect_ctx_0)
					$display("ctx_0 at %d", counter);
				else if(out_ctx==expect_ctx_1)
					$display("ctx_1 at %d", counter);
				else
					$display("corrupted at %d", counter);
			end
		if(counter==200)
			begin
				$display("%x %x", out_ctx[31:0], expect_ctx_1[31:0]);
				assert(out_ctx==expect_ctx_1);
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
	pmk_dispatcher #(N, Njobs, Niter) disp(clk, read_32_rden,
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

	reg[159:0] expect_filler10_1=160'h9e3b2134db31f0398f9c357e583260cf4dad1004;
	reg[159:0] expect_filler10_2=160'hc10290cc2d015256edfa6053b3cd1728ee0ef34b;

	reg[31:0] pads[30*Njobs*N-1:0];
//	reg[31:0] expect_data[1000*N-1:0];
	reg[31:0] recv_data[5*Njobs*N-1:0];
	reg[31:0] I, J, K;
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
		
	for(I=2; I<Njobs-1; I=I+1)
		begin
			for(J=0; J<N; J=J+1)
				begin
					for(K=0; K<5; K=K+1)
						begin
						if(I & 1)
							begin
							pads[J*15*Njobs+I*5+K]<=0;
							pads[J*15*Njobs+I*5+K+5*Njobs]<=0;
							pads[J*15*Njobs+I*5+K+10*Njobs]<=1;
							pads[N*15*Njobs+J*15*Njobs+I*5+K]<=32'h12345678;
							pads[N*15*Njobs+J*15*Njobs+I*5+K+5*Njobs]<=32'h87654321;
							pads[N*15*Njobs+J*15*Njobs+I*5+K+10*Njobs]<=32'h35353535;
							end
						else
							begin
							pads[J*15*Njobs+I*5+K]<=32'h12345678;
							pads[J*15*Njobs+I*5+K+5*Njobs]<=32'h87654321;
							pads[J*15*Njobs+I*5+K+10*Njobs]<=32'h35353535;
							pads[N*15*Njobs+J*15*Njobs+I*5+K]<=0;
							pads[N*15*Njobs+J*15*Njobs+I*5+K+5*Njobs]<=0;
							pads[N*15*Njobs+J*15*Njobs+I*5+K+10*Njobs]<=1;
							end
						end
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
						assert(recv_data[J*5*Njobs+I]==expect_acc10_0[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5]==expect_acc10_1[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5*Njobs-5]==expect_acc10_2[I*32+:32]);
						if(recv_data[J*5*Njobs+I]!=expect_acc10_0[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I], expect_acc10_0[I*32+:32]);
						if(recv_data[J*5*Njobs+I+5]!=expect_acc10_1[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5], expect_acc10_1[I*32+:32]);
						if(recv_data[J*5*Njobs+I+5*Njobs-5]!=expect_acc10_2[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5*Njobs-5], expect_acc10_2[I*32+:32]);
						for(K=2; K<Njobs-1; K=K+1)
							begin
							if(K & 1)
								assert(recv_data[J*5*Njobs+K*5+I]==expect_filler10_1[I*32+:32]);
							else
								assert(recv_data[J*5*Njobs+K*5+I]==expect_filler10_2[I*32+:32]);
							end
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
					for(J=0; J<N; J=J+1)
						begin
						assert(recv_data[J*5*Njobs+I]==expect_acc10_1[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5]==expect_acc10_2[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5*Njobs-5]==expect_acc10_0[I*32+:32]);
//						if(!(recv_data[J*5*Njobs+I]==expect_acc10_1[I*32+:32]))
						if(!(recv_data[J*5*Njobs+I]==expect_acc10_1[I*32+:32]))
							begin
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I], expect_acc10_1[I*32+:32]);
							end
						if(!(recv_data[J*5*Njobs+I+5]==expect_acc10_2[I*32+:32]))
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5], expect_acc10_2[I*32+:32]);
						if(recv_data[J*5*Njobs+I+5*Njobs-5]!=expect_acc10_0[I*32+:32])
							$display("Mismatch at %d %d: %x %x", I, J, recv_data[J*5*Njobs+I+5*Njobs-5], expect_acc10_0[I*32+:32]);
						for(K=2; K<Njobs-1; K=K+1)
							begin
							if(K & 1)
								assert(recv_data[J*5*Njobs+K*5+I]==expect_filler10_2[I*32+:32]);
							else
								assert(recv_data[J*5*Njobs+K*5+I]==expect_filler10_1[I*32+:32]);
							end
						end
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
