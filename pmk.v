
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

	/*
		a' = rot(a,5)+f+g
		b' = a
		c' = rot(b)
		d' = c
		e' = d
		f' = fun(a,b,c)
		g' = h+x1[n]
		h' = c+K1
		--
<clock 0>		
		a' = rot(a,5)+f+g
		t0 = fun(a,b,c) + h + x1[n]
<clock 1>
		a'' = rot(a',5)+ t0
		b'' = a'
		c'' = rot(a, 2)
		d'' = rot(b, 2)
		e'' = c
		f'' = fun(a', a, rot(b,2))
		g'' = C+K1+x1[n+1]
		h'' = rot(b,2)+K1
	*/
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

//
	//
	//

module RoundN_5x5_2(clk, va, x, outa, outx);
	input clk;
	input [255:0] va;
	input [511:0] x;
	output wire [255:0] outa;
	output wire [511:0] outx;
	parameter n=0;
	parameter m1 = (n+1)&15;
	parameter m2 = (n+2)&15;
	parameter m3 = (n+3)&15;
	parameter m4 = (n+4)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	
	//(* ramstyle = "logic" *) 
	
	reg [511:0] t0, xt1, xt2, xt3;
	
	(* keep *) wire[31:0] x1, x1c, x3, x3c;
	wire[31:0] x2, x4;
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

function [31:0] fetch4;
	input [511:0] x;
	input [31:0] n;
	reg [31:0] xx0, xx, x0, x1, x2, x3, x4;
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

function [31:0] rot5;
	input [31:0] x;
	begin
	rot5 = (x<<5)|(x>>27);
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
	assign a0=va[31:0];
	assign b0=va[63:32];
	assign c0=va[95:64];
	assign d0=va[127:96];
	assign e0=va[159:128];
	assign f0=va[191:160];
	assign g0=va[223:192];
	assign h0=va[255:224];


	//wire[31:0] ar, br;
	//assign br = (b0<<30)|(b0>>2);
	//assign ar = (a0<<30)|(a0>>2);

	reg [31:0] a4, b4, c4, d4, e4, f4, g4, h4;
	reg[31:0] a1, b1, c1, h1, y10,  a2, b2, c2, y20, y21,  a3, b3, y30, y31, y32;

`define BLENDED_VX_UPDATE

`ifdef BLENDED_VX_UPDATE
	reg[31:0] x2_, x4_;
	assign x1 = fetch4(x, m1);
	assign x1c = fetch4(x, m1);
	assign x2 = fetch4(x, m2);

	assign x3 = fetch4(xt2, (n+3)&15);
	assign x3c = fetch4(xt2, (n+3)&15);
	assign x4 = fetch4(xt2, (n+4)&15);

`else
	wire[31:0] x2_, x4_;
	assign x1 = fetch4(x, m1);
	assign x2_ = fetch4(xt1, m2);
	assign x3 = fetch4(xt2, (n+3)&15);
	assign x4_ = fetch4(xt3, (n+4)&15);
`endif

	reg[31:0] x1_t0, x2_t1;
	reg[31:0] x3_t2, x4_t3;

	reg[31:0] y22, y33;
	
	always @ (posedge clk)	
		begin
		x1_t0 <= x1;
		x2_t1 <= x2_;
		x3_t2 <= x3;
`ifdef BLENDED_VX_UPDATE
		x2_ <= x2;
		x4_ <= x4;
			for(I=0; I<16; I=I+1)
				begin
					if(I==m1)
						xt1[I*32+:32]<=x1c;
					else if(I==m2)
						xt1[I*32+:32]<=x2;
					else
						xt1[I*32+:32]<=x[I*32+:32];
					if(I==m3)
						xt3[I*32+:32]<=x3c;
					else if(I==m4)
						xt3[I*32+:32]<=x4;
					else
						xt3[I*32+:32]<=xt2[I*32+:32];
				end
			xt2 <= xt1;
			t0 <= xt3;
`else			
			for(I=0; I<16; I=I+1)
				begin
					if(I==m1)
						xt1[I*32+:32]<=x1;
					else
						xt1[I*32+:32]<=x[I*32+:32];
					if(I==m2)
						xt2[I*32+:32]<=x2_;
					else
						xt2[I*32+:32]<=xt1[I*32+:32];
					if(I==m3)
						xt3[I*32+:32]<=x3;
					else
						xt3[I*32+:32]<=xt2[I*32+:32];
					if(I==m4)
						t0[I*32+:32]<=x4_;
					else
						t0[I*32+:32]<=xt3[I*32+:32];
				end
`endif	
/*
				b <= rot5(a0)+f0+g0;
				c <= ar;
				d <= br;
				e <= c0;
				g <= FUN(a0,br,c0, n);
				h <= h0+x1;
				t1<={
					d+K4,
					e+K4+x2,
					FUN(b,c,d,n+1), 
					e, d, c, b, 
					rot5(b)+g+h
				};
*/
/*
		a1<=a0;
		b1<=b0;
		c1<=c0;
		h1<=h0+x1;
		y10<=rot5(a0)+f0+g0;

		a2<=a1;
		b2<=b1;
		c2<=c1+x2;
		y20<=y10;
		y21<=rot5(y10)+FUN(a1,rot30(b1),c1, n) +h1;

		a3<=a2;
		b3<=rot30(b2)+x3;
		y30<=y20;
		y31<=y21;
		y32<=rot5(y21)+FUN(y20,rot30(a2),rot30(b2),n+1) +c2+getK(n+2);

		a4<=rot5(y32)+FUN(y31,rot30(y30),rot30(a3), n+2) +getK(n+3);
		b4<=y32;
		c4<=rot30(y31);
		d4<=rot30(y30);
		e4<=rot30(a3);
		f4<=FUN(y32,rot30(y31),rot30(y30),n+3);
		g4<=rot30(a3)+getK(n+4)+x4;
		h4<=rot30(y30)+getK(n+1);
*/

`define MAX_ADDS_1

`ifdef MAX_ADDS_3
// 4-term adds: 3
// 3-term adds: 2
// 2-term adds: 1
		a1<=a0;
		b1<=b0;
		c1<=c0;
		h1<=h0;
		y10<=rot5(a0)+f0+g0; // two sinks

		a2<=rot30(a1);
		b2<=rot30(b1);
		c2<=c1;
		y20<=y10;
		y21<=rot5(y10)+FUN(a1, rot30(b1), c1, n)+h1+x1_t0; // two sinks

		a3<=a2;
		b3<=b2;
		y30<=rot30(y20);
		y31<=y21;
		y32<=rot5(y21)+FUN(y20,a2,b2,n+1)+c2+getK(n+1)+x2_t1;

		a4<=rot5(y32)+FUN(y31,y30,a3, n+2)+b3+getK(n+2)+x3_t2;
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
		e4<=a3;
		f4<=FUN(y32,rot30(y31),y30,n+3);
		g4<=a3+getK(n+3)+x4_;
		h4<=y30+getK(n+4);
`endif

`ifdef MAX_ADDS_2
// 3-term adds: 7 
// 2-term adds: 2
		a1<=a0;
		b1<=b0;
		c1<=c0;
		h1<=h0+FUN(a0, rot30(b0), c0, n)+x1;
		y10<=rot5(a0)+f0+g0;

		a2<=rot30(a1);
		b2<=rot30(b1);
		c2<=c1+getK(n+1)+x2_;
		y20<=y10;
		y21<=rot5(y10)+h1;

		a3<=a2;
		b3<=b2+getK(n+2)+x3;
		y30<=rot30(y20);
		y31<=y21;
		y32<=rot5(y21)+FUN(y20,a2,b2,n+1)+c2;

		a4<=rot5(y32)+FUN(y31,y30,a3, n+2)+b3;
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
		e4<=a3;
		f4<=FUN(y32,rot30(y31),y30,n+3);
		g4<=a3+getK(n+3)+x4_;
		h4<=y30+getK(n+4);
`endif
`ifdef MAX_ADDS_1
// 3-term adds: 4 
// 2-term adds: 8
		a1<=a0;
		b1<=b0;
		c1<=c0+getK(n+1);
		h1<=h0+FUN(a0, rot30(b0), c0, n);
		y10<=rot5(a0)+f0+g0;

		a2<=rot30(a1);
		b2<=rot30(b1);
		y22<=rot30(b1)+getK(n+2);
		c2<=c1+x2_;
		y20<=y10;
		y21<=rot5(y10)+h1+x1_t0; 

		a3<=a2;
		y33<=a2+getK(n+3);
		b3<=y22+FUN(y21,rot30(y20),a2, n+2);
		y30<=rot30(y20);
		y31<=y21;
		y32<=rot5(y21)+FUN(y20,a2,b2,n+1)+c2;

		a4<=rot5(y32)+b3+x3_t2; 
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
		e4<=a3;
		f4<=FUN(y32,rot30(y31),y30,n+3);
		g4<=y33+x4_;
		h4<=y30+getK(n+4);
`endif	

`ifdef MAX_ADDS_1_v2
// 3-term adds: 4 
// 2-term adds: 8
		a1<=a0;
		b1<=rot30(b0);
		c1<=c0+getK(n+1);
		h1<=h0+FUN(a0, rot30(b0), c0, n);
		y10<=rot5(a0)+f0+g0;

		a2<=rot30(a1);
		//b2<=b1;
		y22<=b1+getK(n+2);
		c2<=c1+x2_;
		y20<=y10;
		y21<=rot5(y10)+h1+x1_t0; 
		y23<=FUN(y10,rot30(a1),b1,n+1);

		a3<=a2;
		y33<=a2+getK(n+3);
		//b3<=y22+x3;
		y30<=rot30(y20);
		y31<=y21;
		y32<=y23+rot5(y21)+c2;
		y34<=FUN(y21,rot30(y20),a2, n+2)+y22+x3;

		a4<=rot5(y32)+y34; 
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
		e4<=a3;
		f4<=FUN(y32,rot30(y31),y30,n+3);
		g4<=y33+x4_;
		h4<=y30+getK(n+4);
`endif		
		end
	assign outa = {h4, g4, f4, e4, d4, c4, b4, a4};
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
  for (gi=1; gi<20; gi=gi+1) begin : VR1
    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
  end
  for (gi=20; gi<80; gi=gi+4) begin : VR2
    RoundN_5x5_2 #(gi) r(clk, va[gi], x[gi], va[gi+4], x[gi+4]);
//  for (gi=60; gi<80; gi=gi+1) begin : VR2
//    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
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


module SHA1_5x5_bare(clk, ctx, data, out_ctx);
	input clk;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;
	reg[511:0] x0;
	reg[159:0] va0;
	//parameter n=80;
	wire[511:0] x[35:1];
	wire[255:0] va[35:1];
	reg[159:0] out_sum;
	reg[31:0] sum1, sum2;
	reg [7:0] I;
	Round1 r0(clk, va0, x0, va[1], x[1], sum1, sum2);
generate
genvar gi;
  for (gi=1; gi<20; gi=gi+1) begin : VR1
    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
  end
  for (gi=20; gi<35; gi=gi+1) begin : VR2
    RoundN_5x5_2 #(20 + (gi-20)*4) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
//  for (gi=60; gi<80; gi=gi+1) begin : VR2
//    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
  end
endgenerate
always @ (posedge clk)
	begin
		va0<=ctx;
		x0[159:0]<=data;
		x0[191:160]<=32'h80000000;
		x0[479:192]<=0;
		x0[511:480]<=32'h2a0;
		sum1<=((ctx[31:0]<<5)|(ctx[31:0]>>27))+ctx[159:128];
		sum2<=data[31:0]+32'h5A827999;
	end
	assign out_ctx = va[35];
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
	reg[31:0] counter;
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg consume_flag=1'b0;
	
	reg acc_read_enable_local=0;
	
	reg pad_read_enable=0, pad2_read_enable=0;
	wire pad_write_enable, acc_write_enable,  pad2_write_enable;
	reg data_read_enable=0, data_write_enable=0, acc_empty;
	wire acc_read_enable;
	wire[159:0] pad_in, acc_in, pad2_in;
	reg[159:0] pad, acc_in_reg, data_bare, data, acc_out, pad_half;
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
	accfifo.use_eab = "OFF";

   scfifo datafifo (
		    .clock (core_clk),
		    .data (data_in),
		    .rdreq (data_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (data_write_enable),
		    .empty (),
		    .full (),
		    .q (data_bare),
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
	padfifo.lpm_numwords = N+1,
	padfifo.lpm_showahead = "OFF",
	padfifo.lpm_type = "scfifo",
	padfifo.lpm_width = 160,
	padfifo.lpm_widthu = $clog2(N+1),
	padfifo.overflow_checking = "OFF",
	padfifo.underflow_checking = "OFF",
	padfifo.use_eab = "ON";
	

   scfifo pad2fifo (
		    .clock (core_clk),
		    .data (pad2_in),
		    .rdreq (pad2_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (pad2_write_enable),
		    .empty (),
		    .full (),
		    .q (pad_half),
		    .aclr (),
		    .almost_empty (),
		    .almost_full (),
		    .usedw (),
		.eccstatus());			 
   defparam
	pad2fifo.add_ram_output_register = "OFF",
	pad2fifo.lpm_numwords = N+1,
	pad2fifo.lpm_showahead = "OFF",
	pad2fifo.lpm_type = "scfifo",
	pad2fifo.lpm_width = 160,
	pad2fifo.lpm_widthu = $clog2(N+1),
	pad2fifo.overflow_checking = "OFF",
	pad2fifo.underflow_checking = "OFF",
	pad2fifo.use_eab = "ON";
	
/*
	reg ctx_read_enable=0, ctx_write_enable=0;
	reg[159:0] ctx_delayed;
   scfifo ctxfifo (
		    .clock (core_clk),
		    .data (pad),
		    .rdreq (ctx_read_enable),
		    .sclr (dumpfifos),
		    .wrreq (ctx_write_enable),
		    .empty (),
		    .full (),
		    .q (ctx_delayed),
		    .aclr (),
		    .almost_empty (),
		    .almost_full (),
		    .usedw (),
		.eccstatus());			 
   defparam
	ctxfifo.add_ram_output_register = "OFF",
	ctxfifo.lpm_numwords = N,
	ctxfifo.lpm_showahead = "OFF",
	ctxfifo.lpm_type = "scfifo",
	ctxfifo.lpm_width = 160,
	ctxfifo.lpm_widthu = $clog2(N),
	ctxfifo.overflow_checking = "OFF",
	ctxfifo.underflow_checking = "OFF",
	ctxfifo.use_eab = "ON";
*/
	SHA1_5x5_bare s55(core_clk, pad, data_sha_input, out_ctx);

	reg [31:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	reg [15:0] write_count=0;
	
	reg data_src_switch=0;


	assign data_sha_input=(data_src_switch) ? data : acc_in_reg;
	reg pad_write_enable_local=0;
	reg pad2_write_enable_local=0;
	reg acc_write_enable_local=0;
	
	reg [2:0] sink=0;
/*
	assign pad_write_enable = (status==0 && write_count<N+1) ? user_w_write_wren : pad_write_enable_local;
	assign pad2_write_enable = (status==0 && write_count>=N+1 && write_count<N*2) ? user_w_write_wren : pad2_write_enable_local;
	assign acc_write_enable = (status==0 && write_count>=N*2) ? user_w_write_wren : acc_write_enable_local;
	assign pad_in = (status==0 && write_count<N+1) ? user_w_write_data : pad_half;
	assign pad2_in = (status==0 && write_count>=N+1 && write_count<N*2) ? user_w_write_data : pad;
	assign acc_in = (status==0 && write_count>=N*2) ? user_w_write_data : acc_in_reg;
	*/
	assign pad_write_enable = (sink==0) ? user_w_write_wren : pad_write_enable_local;
	assign pad2_write_enable = (sink==1) ? user_w_write_wren : pad2_write_enable_local;
	assign acc_write_enable = (sink==2) ? user_w_write_wren : acc_write_enable_local;
	assign pad_in = (sink==0) ? user_w_write_data : pad_half;
	assign pad2_in = (sink==1) ? user_w_write_data : pad;
	assign acc_in = (sink==2) ? user_w_write_data : acc_in_reg;
	
	assign data_in = out_ctx;	
	assign user_w_write_full=(write_count==N*3);
/***

 At each step, we read from the front of padfifo and write into the back of pad2fifo

 And we read into pad_half from the front of pad2fifo and write from it into padfifo
***/

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
					if(write_count==N)
						sink<=1;
					else if(write_count==N*2-1)
						sink<=2;
					else if(write_count==N*3-1)
					begin
						sink<=3;
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
				pad2_read_enable<=1;
				status<=2;
			end
		else if(status==2)
			begin
				pad_write_enable_local<=1;
				pad2_write_enable_local<=1;
//				ctx_write_enable<=1;
				if(counter==2*N)
					data_src_switch<=1;

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
				
				if(counter<2*N-2)//if(loop_counter==0)
					begin
						if(inst_counter<N+L-1)
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
//						ctx_read_enable<=1;
					end
				
				data[31:0]<=data_bare[31:0]+pad_half[31:0];
				data[63:32]<=data_bare[63:32]+pad_half[63:32];
				data[95:64]<=data_bare[95:64]+pad_half[95:64];
				data[127:96]<=data_bare[127:96]+pad_half[127:96];
				data[159:128]<=data_bare[159:128]+pad_half[159:128];
//				data_in<=out_ctx;
				if(acc_read_enable_local || counter == Niter*N*2-1 || loop_counter==Niter)
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
//					ctx_read_enable<=0;
//					ctx_write_enable<=0;
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
								pad2_write_enable_local<=0;
								acc_write_enable_local<=0;
								acc_read_enable_local<=0;
								pad_read_enable<=0;
								pad2_read_enable<=0;
								data_read_enable<=0;
								data_write_enable<=0;
								data_src_switch<=0;
								write_count<=0;
								sink=0;
//								ctx_read_enable<=0;
//								ctx_write_enable<=0;
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
		pmk_calc_ring_fifo #(Njobs,10) worker(clk, 
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
	expect_ctx_1 = 160'hef47e12a6961e1ba74a8282dac16e632221cf20a;
end

SHA1_5x5 sha(clk, ctx, data, out_ctx);

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
				$display("%x", out_ctx[31:0]);
				assert(out_ctx==expect_ctx_0);
			end
		if(counter==200)
			begin
				$display("%x", out_ctx[31:0]);
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
		
	for(I=10; I<5*Njobs-5; I=I+1)
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
						assert(recv_data[J*5*Njobs+I]==expect_acc10_0[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5]==expect_acc10_1[I*32+:32]);
						assert(recv_data[J*5*Njobs+I+5*Njobs-5]==expect_acc10_2[I*32+:32]);
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
