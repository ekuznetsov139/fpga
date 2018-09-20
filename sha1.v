	
////
//
//
//   Exceedingly fancy SHA1 implementation
//
//
/////


// defined: use 8 internal registers to carry the state between steps (more registers, less combinatorial complexity, higher Fmax)
// undefined: use 6 registers
`define CARRY_8


// T24_INPUT: feed data from the permutation delay buffer straight into arithmetic (fewer registers, possibly lower Fmax)
// T13_INPUT: insert uniform 1-register delay (more registers, higher Fmax)
// T2_INPUT: insert a 2-register delay in x3 and x4 only

//`define T24_INPUT
`define T13_INPUT
//`define T2_INPUT


//`define PERMUTER8


module Round1(clk, va, x, outa, a0_precompute);
	input clk;
	input [159:0] va;
	input [159:0] x;
	input[31:0] a0_precompute;
	output [255:0] outa;
	parameter K1=32'h5A827999;
	reg [255:0] t1;
	wire[31:0] a, b, c, d, e;
	assign {e,d,c,b,a}=va;
	wire[31:0] br;
	assign br = (b<<30)|(b>>2);
	always @ (posedge clk)	
		begin
			t1[31:0] <= a0_precompute+x[31:0];
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;
			t1[191:160]<=(c^(a&(br^c)));			
			t1[223:192]<=d+K1+x[63:32];
			t1[255:224]<=c+K1;
		end
	assign outa = t1;
endmodule


module Round1_5x5(clk, va, x, outa);
	input clk;
	input [255:0] va;
	input [31:0] x;
	output wire [255:0] outa;
	parameter n=0;
	parameter m = (n+1)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, e, f, g, br, h;
	assign {h,g,f,e,d,c,b,a}=va;
	assign br = (b<<30)|(b>>2);
	assign x1 = (n<4) ? x //x[n*32+63:n*32+32] 
		: ((n==4) ? 32'h80000000 
		: ((n==14) ? 32'h2a0 
		: 0
		));
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
	
	always @ (posedge clk)	
		begin
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;
`ifdef CARRY_8
			t1[31:0] <= ((a<<5)|(a>>27))+f+g; // rot5(a) + FUN(b,c,d) + e + x1 + K1. For n>=4, x1 & K1 known
			t1[191:160]<=(c^(a&(br^c)));
			if(n<4)
				begin
				t1[223:192]<=h+x1;
				t1[255:224]<=c+K1;
				end
			else if(n!=14)
				begin
				t1[223:192]<=d+x1+K1;
				//t1[255:224]<=c+K1;
				end
			else
				begin
				t1[223:192]<=d+K1+x1;
				t1[255:224]<=c+K1;
				end
`else
			t1[31:0] <= ((a<<5)|(a>>27))+FUN(b,c,d,n)+g;
			t1[223:192]<=d+K1+x1;
`endif			
		end		

	assign outa = t1;
endmodule



module RoundN_4x(clk, va, outa, vx);
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
	rot5 = {x[26:0],x[31:27]};
	end
endfunction

function [31:0] rot30;
	input [31:0] x;
	begin
	rot30 = (x<<30)|(x>>2);
	end
endfunction

	wire [31:0] a0, b0, c0, d0, e0, f0, g0, h0;
	assign {h0,g0,f0,e0,d0,c0,b0,a0}=va;

	reg[31:0] a4, b4, c4, d4, e4, f4, g4, h4;
	reg[31:0] a1, b1, c1, h1, y10,  a2, b2, c2, y20, y21, y22, a3, b3, y30, y31, y32, y33, d2, d3;
`ifdef T2_INPUT
	reg[31:0] x1_t2, x3_t4;	
	wire[31:0] x2,x3_t2,x4_t2;
	reg[31:0] x3, x4_t3, x4;	
	assign {x4_t2,x3_t2,x2,x1_t2} = vx;
`elsif T13_INPUT	
	reg[31:0] x1_t2, x3_t4;	
	wire[31:0] x1, x2_t1, x3, x4_t3;
	reg[31:0] x2, x4;
	assign {x4_t3, x3, x2_t1, x1} = vx;
`elsif T24_INPUT
	wire[31:0] x1_t2, x2, x3_t4, x4;
	assign {x4, x3_t4, x2, x1_t2} = vx;
`else
	wire[31:0] x1, x2, x3, x4;
	assign {x4, x3, x2, x1} = vx;
`endif
	always @ (posedge clk)	
		begin
`ifdef T2_INPUT
		x3_t4 <= x3;
		x3 <= x3_t2;
		x4_t3 <= x4_t2;
		x4 <= x4_t3;
`elsif T13_INPUT
		x3_t4 <= x3;
		x1_t2 <= x1;
		x2 <= x2_t1;
		x4 <= x4_t3;
`elsif T24_INPUT
`else
		x3_t4 <= x3;
		x1_t2 <= x1;
`endif


		a1<=a0;
		b1<=b0;
		c1<=c0+getK(n+1);
		
`ifdef CARRY_8
		h1<=h0+FUN(a0, rot30(b0), c0, n);
		y10<=rot5(a0)+f0+g0;
`else		
		h1<=d0+FUN(a0, rot30(b0), c0, n)+getK(n);
		y10<=rot5(a0)+FUN(b0,c0,d0,n-1)+g0;
`endif
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
		g4<=y33+x4;
`ifdef CARRY_8
		f4<=FUN(y32,rot30(y31),y30,n+3);
		h4<=y30+getK(n+4);
`endif		
		end
	assign outa = {h4, g4, f4, e4, d4, c4, b4, a4};
//	assign outx = t0;
endmodule

module Round80(clk, va, outa);
	input clk;
	input [255:0] va;
	output wire [255:0] outa;
	reg [255:0] t1=0;
	wire[31:0] a, b, c, d, f, g, br, h;

	assign a=va[31:0];
	assign b=va[63:32];
	assign c=va[95:64];
	assign d=va[127:96];
	assign f=va[191:160];
	assign g=va[223:192];
	assign br = (b<<30)|(b>>2);
	
	always @ (posedge clk)	
		begin
`ifdef CARRY_8		
		t1[31:0] <= ((a<<5)|(a>>27))+f+g;
`else
		t1[31:0] <= ((a<<5)|(a>>27))+(b^c^d)+g;
`endif			
		t1[63:32]<=a;
		t1[95:64]<=br;
		t1[127:96]<=c;
		t1[159:128]<=d;
		end
	assign outa = t1;
endmodule



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
(* altera_attribute = "-name QII_AUTO_PACKED_REGISTERS OFF" *) module my_syncram (
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	q);
	
	parameter N=2048;
	parameter D=64;
	parameter logD=$clog2(D);
	input	  clock;
	input	[N-1:0]  data;
	input	[logD-1:0]  rdaddress;
	input	[logD-1:0]  wraddress;
	input	  wren;
	output [N-1:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [N-1:0] sub_wire0;
	wire [N-1:0] q = sub_wire0[N-1:0];

	altsyncram	altsyncram_component (
				.address_a (wraddress),
				.address_b (rdaddress),
				.clock0 (clock),
				.data_a (data),
				.wren_a (wren),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({N{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.maximum_depth = D,
		altsyncram_component.numwords_a = D,
		altsyncram_component.numwords_b = D,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.ram_block_type = "AUTO",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		//altsyncram_component.read_during_write_mode_mixed_ports = "NEW_DATA",
		altsyncram_component.widthad_a = logD,
		altsyncram_component.widthad_b = logD,
		altsyncram_component.width_a = N,
		altsyncram_component.width_b = N,
		altsyncram_component.width_byteena_a = 1;
endmodule


module pad_preprocess64(input [159:0] pad, output [63:0] a0);
	wire [31:0] a,b,c,d,e,ar;
	assign {e,d,c,b,a} = pad;
	assign ar = ((a<<5)|(a>>27));
	assign a0[63:32]=(d^(b&(c^d)))+32'h5A827999;
	assign a0[31:0]= e+ar;
endmodule

module SHA1_5x5_bare_v1(clk, ext_timer_signal, a0_precompute, ctx, data, out_ctx);
	input clk;
	input [6:0] ext_timer_signal;
	input [31:0] a0_precompute;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;

	wire[255:0] va[32:1];
	reg [7:0] I, J;	
	reg[159:0] xbuf1[15:1];	
	wire[159:0] vx[31:15];

	(* maxfan=8 *) reg[5:0] timer_signal;
	
	wire[2111:0] mem_input;
	wire[2047:0] mem_output;
	reg wren=1;

	//`define DPRAM simple_dpram
	//integer read_delay=0;

	`define DPRAM my_syncram
	integer read_delay=1;

genvar gi, gj;
generate
	wire[351:0] fixed={32'h2a0, 288'b0, 32'h80000000};
	wire[5:0] in_addresses[31:0];

/*
cell	in out
0		1	1
1		1	1
2		1	-1
3		1	-1
4		1	-3
5		1	-3
6		1	-5
7		1	-5
8		1	-7
9		1	-7
10		1	-9
11		1	-9
12		1	-11
13		1	-11
14		1	-13
15		1	-13
16		-1
...
59		-5	-57
60		-5	-59
61		-5	-59
62		-5	-61
63		-5	-61

*/
	reg[511:0] levels[3:0];
	wire[511:0] input_data;
//	reg[543:0] temp_data[3:0];
	
`ifdef T24_INPUT	
	assign input_data={fixed,xbuf1[14][159:0]};
`elsif T13_INPUT
	assign input_data={fixed,xbuf1[13][159:0]};
`elsif T2_INPUT
	assign input_data={fixed,xbuf1[14][159:0]};
`else
`error "No vx passing method specified"
`endif
	// a tricky way to get all 64 permute steps done in just 8 clocks with ~2k bit of internal storage,
	// with no more than 6 inputs/LUT at any point.
	// (A naive implementation would require dragging along full 512-bit buffer for 64 clocks, though 
	// some of that logic would hopefully be hidden in memory blocks.)
	// Then, since we don't need all that data so early, stick it into an altsyncram delay buffer and withdraw as needed.
	//
	permuter_x4 perm(clk, {levels[2], levels[1], levels[0], input_data}, {levels[3],levels[2], levels[1], levels[0]});
	/*
	permuter perm0(clk, input_data, levels[0]);
	permuter perm1(clk, levels[0], levels[1]);
	permuter perm2(clk, levels[1], levels[2]);
	permuter perm3(clk, levels[2], levels[3]);
	*/
	always @(posedge clk)
		begin
	end
	for(gi=0; gi<4; gi=gi+1) begin: a1
		assign mem_input[gi*512+:512]=levels[gi];
	end

	for(gi=0; gi<4; gi=gi+1) begin: a3
		for(gj=0; gj<8; gj=gj+1) begin: a4
				assign in_addresses[gj+gi*8]=(timer_signal+128-gi*2)&63;
		end
	end
	assign vx[15][63:0]=levels[0][63:0];
`ifdef T2_INPUT
	assign vx[15][127:64]=levels[0][127:64];
`endif

	for(gi=0; gi<16; gi=gi+1) begin : bbb
		for(gj=0; gj<4; gj=gj+1) begin : aaa
`ifndef T2_INPUT		
			if(gi*4+gj>=2)
`else
			if(gi*4+gj>=4)
`endif			
				assign vx[gi+15][gj*32+:32]=mem_output[(gi*4+gj)*32+:32];
		end
	end

	// need a combined port width of 32*4*16 = 2048 bit just to feed RoundN_4x with no overhead
	// therefore we'll be needing 64 M10K tiles to power this, at a depth of 64 or less
	// NOTE: can we get away with 32 tiles inside a true dual-port RAM module?
	for(gi=1; gi<32; gi=gi+1) begin: ccc
		localparam logd= (1+$clog2(gi+1));
		localparam d=1<<logd;
		
		wire[logd-1:0] out_addr;
`ifndef T2_INPUT
		assign out_addr=((timer_signal+128-gi*2+read_delay)&(d-1));
`else
		assign out_addr=((timer_signal+128-(gi&~1)*2+read_delay)&(d-1));
`endif
		`DPRAM #(64,d) inst(clk, mem_input[gi*64+:64], out_addr, in_addresses[gi][logd-1:0], wren, mem_output[gi*64+:64]);
	end

  for (gi=1; gi<4; gi=gi+1) begin : VR1
    Round1_5x5 #(gi) r(clk, va[gi], xbuf1[gi][(gi+1)*32+:32], va[gi+1]);
	end
  for (gi=4; gi<15; gi=gi+1) begin : VR2
    Round1_5x5 #(gi) r(clk, va[gi], 0, va[gi+1]);
  end
  for (gi=15; gi<31; gi=gi+1) begin : VR3
    RoundN_4x #(15 + (gi-15)*4) r(clk, va[gi], va[gi+1], vx[gi][127:0]);
  end
endgenerate
	Round1 r0(clk, ctx, data, va[1], a0_precompute);
	Round80 r80(clk, va[31], va[32]);

always @ (posedge clk)
	begin
		timer_signal <= ext_timer_signal[5:0];
		xbuf1[1]<=data;
		for(I=1; I<14; I=I+1)
			xbuf1[I+1]<=xbuf1[I];
		end
	assign out_ctx = va[32][159:0];
endmodule 


module SHA1_5x5_bare_v2(clk, ext_timer_signal, a0_precompute, ctx, data, out_ctx);
	input clk;
	input [6:0] ext_timer_signal;
	input [31:0] a0_precompute;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;

	wire[255:0] va[32:1];
	wire[127:0] vx[30:15];

	reg[159:0] xbuf1;
	reg[63:0] xbuf2;
	reg[31:0] xbuf3;

	(* maxfan=8 *) reg[6:0] timer_signal;
	
	wire[2111:0] mem_input;
	wire[2047:0] mem_output;
	wire[351:0] fixed={32'h2a0, 288'b0, 32'h80000000};
	wire[6:0] in_addresses[31:0];
	reg[511:0] levels[3:0];


`ifndef T13_INPUT
`error "Currently b0rked"	
`endif


	(* dont_merge *) reg[6:0] local_timers[31:0];
	
genvar gi, gj;


`ifdef PERMUTER8
	permuter perm0(clk, {fixed,xbuf1}, levels[0]);
	permuter perm1(clk, levels[0], levels[1]);
	permuter perm2(clk, levels[1], levels[2]);
	permuter perm3(clk, levels[2], levels[3]);
generate
	// we write into the delay buffer from 'levels'
	for(gi=0; gi<4; gi=gi+1) begin: a1
		assign mem_input[gi*512+:512]=levels[gi];
	end
	// at these addresses 
	for(gi=0; gi<4; gi=gi+1) begin: a3
		for(gj=0; gj<8; gj=gj+1) begin: a4
				assign in_addresses[gj+gi*8]=(local_timers[gj+gi*8]+128-gi*2)&127;
		end
	end
	
`else
	permuter_6b_series perm(clk, {fixed,xbuf1}, mem_input[2047:0]);
generate
	for(gi=0; gi<=10; gi=gi+1) begin: a3
		for(gj=0; gj<3; gj=gj+1) begin: a4
			if(gj+gi*3<32)
				assign in_addresses[gj+gi*3]=(local_timers[gj+gi*3]+128-gi+1)&127;
		end
	end
`endif

	
	// and then feed the retrieved data into 'vx'
	for(gi=0; gi<16; gi=gi+1) begin : bbb
		for(gj=0; gj<4; gj=gj+1) begin : aaa
			assign vx[gi+15][gj*32+:32]=mem_output[(gi*4+gj)*32+:32];
		end
	end

	for(gi=0; gi<32; gi=gi+1) begin: ccc
		localparam logd= $clog2(2*(gi+1)+13);
		localparam d=1<<logd;
		
		wire[logd-1:0] out_addr;
		assign out_addr=((local_timers[gi]+128-gi*2-12+1)&(d-1));
		my_syncram #(64,d) inst(clk, mem_input[gi*64+:64], out_addr, in_addresses[gi][logd-1:0], 1'b1, mem_output[gi*64+:64]);
	end

  for (gi=4; gi<15; gi=gi+1) begin : VR2
    Round1_5x5 #(gi) r(clk, va[gi], 0, va[gi+1]);
  end
  for (gi=15; gi<31; gi=gi+1) begin : VR3
    RoundN_4x #(15 + (gi-15)*4) r(clk, va[gi], va[gi+1], vx[gi]);
  end
endgenerate

   Round1_5x5 #(1) r1(clk, va[1], xbuf1[95:64], va[2]);
   Round1_5x5 #(2) r2(clk, va[2], xbuf2[31:0], va[3]);
   Round1_5x5 #(3) r3(clk, va[3], xbuf3, va[4]);

	Round1 r0(clk, ctx, data, va[1], a0_precompute);
	Round80 r80(clk, va[31], va[32]);
	reg[31:0] I;


initial begin
		for(I=0; I<32; I=I+1)
			local_timers[I] <= 0;
end
	
always @ (posedge clk)
	begin
		for(I=0; I<32; I=I+1)
			local_timers[I] <= local_timers[I]+1;//ext_timer_signal[6:0];
		timer_signal <= ext_timer_signal[6:0];
		xbuf1<=data;
		xbuf2<=xbuf1[159:96];
		xbuf3<=xbuf2[63:32];
		end
	assign out_ctx = va[32][159:0];
endmodule 


module ternary_add (a,b,c,o);

parameter WIDTH=8;
parameter SIGN_EXT = 1'b0;

input [WIDTH-1:0] a,b,c;
output [WIDTH+1:0] o;
wire [WIDTH+1:0] o;

generate 
if (!SIGN_EXT)
	assign o = a+b+c;
else
	assign o = {a[WIDTH-1],a[WIDTH-1],a} +
			   {b[WIDTH-1],b[WIDTH-1],b} +
			   {c[WIDTH-1],c[WIDTH-1],c};
endgenerate

endmodule

//`define THREE_TERM_ADD

module Round1_5x5_test(clk, va, x, xn, outa);
	input clk;
	input [255:0] va;
	input [31:0] x, xn;
	output wire [255:0] outa;
	parameter n=0;
	parameter m = (n+1)&15;
	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	
	reg [255:0] t1;
	wire[31:0] x0, x1, x2;
	wire[31:0] a, b, c, d, e, f, g, br, h;
	assign {h,g,f,e,d,c,b,a}=va;
	assign br = (b<<30)|(b>>2);
	assign x1 = (n<4) ? x //x[n*32+63:n*32+32] 
		: ((n==4) ? 32'h80000000 
		: ((n==14) ? 32'h2a0 
		: 0
		));
	assign x2 = (n<3 || n==14) ? xn //x[n*32+63:n*32+32] 
		: ((n==3) ? 32'h80000000 
		: ((n==13) ? 32'h2a0 
		: 0
		));
	
//	(n==14) ? xn : 0;
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

	wire[33:0] t1w, t2w;
	ternary_add #(32) add1(c, x2, K1, t1w);
`ifdef THREE_TERM_ADD
	ternary_add #(32) add2({a[26:0],a[31:27]}, f, g, t2w);
`endif
	
	always @ (posedge clk)	
		begin
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;
`ifndef THREE_TERM_ADD
			if(n==1)
			//	t1[31:0] <= ((a<<5)|(a>>27))+FUN(b,c,d,n)+g;
				t1[31:0] <= ((a<<5)|(a>>27))+f+g;
			else
				t1[31:0] <= ((a<<5)|(a>>27))+g;
			t1[223:192]<=h+FUN(a,br,c,n);			
`else
			t1[31:0] <= t2w;
			if(n==14)
				t1[223:192]<=h+FUN(a,br,c,n);
			else
				begin
				t1[191:160]<=h;
				t1[223:192]<=FUN(a,br,c,n);		
				end
`endif			
			t1[255:224]<=t1w;
		end		

	assign outa = t1;
endmodule


module RoundN_4x_test(clk, va, outa, vx);
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
	rot5 = {x[26:0],x[31:27]};
	end
endfunction

function [31:0] rot30;
	input [31:0] x;
	begin
	rot30 ={x[1:0],x[31:2]};// (x<<30)|(x>>2);
	end
endfunction


	wire [31:0] a0, b0, c0, d0, e0, f0, g0, h0;
	assign {h0,g0,f0,e0,d0,c0,b0,a0}=va;

	reg[31:0] a4, b4, c4, d4, e4, f4, g4, h4;
	reg[31:0] a1, b1, c1, h1, y10,  a2, b2, c2, y20, y21, y22, a3, b3, y30, y31, y32, y33, d2, d3;
	//reg[31:0] x1_t2, x3_t4;	
	//wire[31:0] x1, x2_t1, x3, x4_t3, x5;
	//reg[31:0] x2, x4, x2_t3, 
	reg[31:0] t2, t1, t3;
	reg[31:0] f1,f2,f3;
	wire [31:0] x2, x3, x4, x5;
//`define XN_DELAY	
	
	assign {x5, x4, x3, x2} = vx;
	reg[31:0] x2d, x3d, x4d, x5d;
`ifdef XN_DELAY		
	wire[33:0] t1w, t2w, t3w, t4w;
	ternary_add #(32) add1(x2d, c0, getK(n+1), t1w);
	ternary_add #(32) add2(x3d, b1, getK(n+2), t2w);
	ternary_add #(32) add3(x4d, a2, getK(n+3), t3w);
	ternary_add #(32) add4(x5d, y30, getK(n+4), t4w);
`endif
	
	always @ (posedge clk)
		begin
`ifdef XN_DELAY		
		x2d <= x2;
		x3d <= x3;
		x4d <= x4;
		x5d <= x5;
		t1 <= t1w[31:0];
		t2 <= t2w[31:0];
		t3 <= t3w[31:0];
		h4 <= t4w[31:0];
		/*
		t1 <= x2d + c0 + getK(n+1);
		t2 <= x3d + b1 + getK(n+2);
		t3 <= x4d + a2 + getK(n+3);
		h4 <= x5d + y30 + getK(n+4);
		*/
`else	
		t1 <= x2 + c0 + getK(n+1);
		t2 <= x3 + b1 + getK(n+2);
		t3 <= x4 + a2 + getK(n+3);
		h4 <= x5 + y30 + getK(n+4);
`endif
		
		y10<=rot5(a0)+g0;		
		a1<=a0;
		b1<=rot30(b0);
		
`ifndef THREE_TERM_ADD
		h1<=FUN(a0, rot30(b0), c0, n) + h0;//(x1 + d0 + getK(n));
		
		y21<=rot5(y10)+h1;
		a2<=rot30(a1);
		b2<=b1;
		y20<=y10;
		y22<=FUN(y10,rot30(a1),b1,n+1)+t1;
		
		y32<=rot5(y21)+y22;
		a3<=a2;
		y30<=rot30(y20);
		y31<=y21;
		b3<=FUN(y21,rot30(y20), a2, n+2)+t2;

		a4<=rot5(y32) + b3;
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
//		e4<=a3;
		g4<=FUN(y32,rot30(y31),y30,n+3)+t3;
`else
		f1<=FUN(a0, rot30(b0), c0, n);
		h1<=h0;
		
		y21<=rot5(y10)+f1+h1;
		a2<=rot30(a1);
		b2<=b1;
		y20<=y10;
		f2<=FUN(y10,rot30(a1),b1,n+1);
		y22<=t1;
		
		y32<=rot5(y21)+f2+y22;
		a3<=a2;
		y30<=rot30(y20);
		y31<=y21;
		f3<=FUN(y21,rot30(y20), a2, n+2);
		b3<=t2;

		a4<=rot5(y32) + f3 + b3;
		b4<=y32;
		c4<=rot30(y31);
		d4<=y30;
//		e4<=a3;
		g4<=FUN(y32,rot30(y31),y30,n+3)+t3;
`endif
		end
	assign outa = {h4, g4, f4, e4, d4, c4, b4, a4};
//	assign outx = t0;
endmodule

module Round80_test(clk, va, outa);
	input clk;
	input [255:0] va;
	output wire [255:0] outa;
	reg [255:0] t1=0;
	wire[31:0] a, b, c, d, f, g, br, h;

	assign a=va[31:0];
	assign b=va[63:32];
	assign c=va[95:64];
	assign d=va[127:96];
	assign f=va[191:160];
	assign g=va[223:192];
	assign br = (b<<30)|(b>>2);
	
	always @ (posedge clk)	
		begin
		t1[31:0] <= ((a<<5)|(a>>27))+g;
		t1[63:32]<=a;
		t1[95:64]<=br;
		t1[127:96]<=c;
		t1[159:128]<=d;
		end
	assign outa = t1;
endmodule


module Round1_test(clk, va, x, outa, a0_precompute);
	input clk;
	input [159:0] va;
	input [159:0] x;
	input[31:0] a0_precompute;
	output [255:0] outa;
	parameter K1=32'h5A827999;
	reg [255:0] t1;
	wire[31:0] a, b, c, d, e;
	assign {e,d,c,b,a}=va;
	wire[31:0] br;
	assign br = (b<<30)|(b>>2);
	
	wire[33:0] t1w, t2w;
	ternary_add #(32) add1(d, x[63:32], K1, t1w);
	ternary_add #(32) add2(c, x[95:64], K1, t2w);
	
	always @ (posedge clk)	
		begin
			t1[31:0] <= a0_precompute+x[31:0];
			t1[63:32]<=a;
			t1[95:64]<=br;
			t1[127:96]<=c;
			t1[159:128]<=d;
			t1[191:160]<=(c^(a&(br^c)));			
			t1[223:192]<=t1w[31:0];
			t1[255:224]<=t2w[31:0];
		end
	assign outa = t1;
endmodule


module SHA1_5x5_bare(clk, ext_timer_signal, a0_precompute, ctx, data, out_ctx);
	input clk;
	input [6:0] ext_timer_signal;
	input [31:0] a0_precompute;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;

	wire[255:0] va[32:1];
	wire[127:0] vx[30:15];

	reg[159:0] xbuf1;
	reg[63:0] xbuf2;
	reg[31:0] xbuf3;

	//(* maxfan=8 *) reg[6:0] timer_signal;
	
	wire[2111:0] mem_input;
	wire[2111:0] mem_output;
	wire[351:0] fixed={32'h2a0, 288'b0, 32'h80000000};
	wire[6:0] in_addresses[63:0];
	//reg[511:0] levels[3:0];


	(* dont_merge *) reg[6:0] local_timers[63:0];
	
genvar gi, gj;


	permuter_6b_series perm(clk, {fixed,xbuf1}, mem_input[2047:0]);
generate
	for(gi=0; gi<=10; gi=gi+1) begin: a3
		for(gj=0; gj<6; gj=gj+1) begin: a4
			if(gj+gi*6<64)
				assign in_addresses[gj+gi*6]=(local_timers[gj+gi*6]+128-gi)&127;
		end
	end

	
	// and then feed the retrieved data into 'vx'
	for(gi=0; gi<16; gi=gi+1) begin : bbb
		for(gj=0; gj<4; gj=gj+1) begin : aaa
			assign vx[gi+15][gj*32+:32]=mem_output[(gi*4+gj+1)*32+:32];
		end
	end

	for(gi=0; gi<64; gi=gi+1) begin: ccc
		localparam logd= $clog2(gi+1+13);
		localparam d=1<<logd;
		
		wire[logd-1:0] out_addr;
`ifdef XN_DELAY		
		assign out_addr=((local_timers[gi]+128-gi-12+2)&(d-1));
`else
		assign out_addr=((local_timers[gi]+128-gi-12+1)&(d-1));
`endif		
		my_syncram #(32,d) inst(clk, mem_input[gi*32+:32], out_addr, in_addresses[gi][logd-1:0], 1'b1, mem_output[gi*32+:32]);
	end

  for (gi=4; gi<14; gi=gi+1) begin : VR2
    Round1_5x5_test #(gi) r(clk, va[gi], 0, 0, va[gi+1]);
  end
  
  reg[31:0] x15;
`ifdef XN_DELAY		  
  Round1_5x5_test #(14) r(clk, va[14], 32'b0, x15, va[15]);
 `else
  Round1_5x5_test #(14) r(clk, va[14], 32'b0, mem_output[31:0], va[15]);
 `endif
  for (gi=15; gi<31; gi=gi+1) begin : VR3
    RoundN_4x_test #(15 + (gi-15)*4) r(clk, va[gi], va[gi+1], vx[gi]);
  end
endgenerate

   Round1_5x5_test #(1) r1(clk, va[1], xbuf1[95:64], xbuf1[127:96],  va[2]);
   Round1_5x5_test #(2) r2(clk, va[2], xbuf2[31:0], xbuf2[63:32], va[3]);
   Round1_5x5_test #(3) r3(clk, va[3], xbuf3, 32'b0, va[4]);

	Round1_test r0(clk, ctx, data, va[1], a0_precompute);
	Round80_test r80(clk, va[31], va[32]);
	reg[31:0] I;
//	reg[31:0] h4_15;
//	parameter K1=32'h5A827999;
//	assign va[15][255:224]=h4_15;
initial begin
		for(I=0; I<64; I=I+1)
			local_timers[I] <= 0;
end
always @ (posedge clk)
	begin
		x15 <= mem_output[31:0];
	//	h4_15 <= mem_output[31:0] + va[14][127:96] + K1;//(x1 + d0 + getK(n));
		for(I=0; I<64; I=I+1)
			local_timers[I] <= local_timers[I]+1;//ext_timer_signal[6:0];
		//timer_signal <= ext_timer_signal[6:0];
		xbuf1<=data;
		xbuf2<=xbuf1[159:96];
		xbuf3<=xbuf2[63:32];
		end
	assign out_ctx = va[32][159:0];
endmodule 

