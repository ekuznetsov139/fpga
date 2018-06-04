/*****************************************************************************

   FPGA SHA1 and WPA2 PMK generators 
	Fully unrolled; avg. 7000 ALM per instance with throughput of 1 SHA/clock 
	Tested with Cyclone V 5CSEBA6U23I7 and 5CGTFD9E5F35C7

*****************************************************************************/

`define FULL_TB_CHECKS
	
`define PRECALC_WRFULL
`define REGISTER_OUTPUT
`define REGISTERED_GATHER

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

// defined: perform K1/K2/K3/K4 addition before storing x_n in the permutation delay buffer
// (more registers, higher Fmax)
//`define K_ABSORB

// slightly different versions of the permutation code
// #1 does the job with 16 temporary registers, but requires LUT chaining behind the scenes
// #2 uses 17 registers and should be unchained (potentially higher Fmax)
// #3 uses 17 registers and chaining but uses the simplest logic

//`define PERMUTE_TYPE1 
`define PERMUTE_TYPE2
//`define PERMUTE_TYPE3

module Round1(clk, va, x, outa, sum1, sum2);
	input clk;
	input [159:0] va;
	input [159:0] x;
	input[31:0] sum1, sum2;
	output [255:0] outa;
	parameter K1=32'h5A827999;
	reg [255:0] t1;
	wire[31:0] a, b, c, d, e;
	assign {e,d,c,b,a}=va;
	wire[31:0] br;
	assign br = (b<<30)|(b>>2);
	always @ (posedge clk)	
		begin
			t1[31:0] <=(d^(b&(c^d)))+sum1+sum2;
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
	input [159:0] x;
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
	assign x1 = (n<4) ? x[n*32+63:n*32+32] 
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
			t1[31:0] <= ((a<<5)|(a>>27))+f+g;
			t1[191:160]<=(c^(a&(br^c)));
			t1[223:192]<=h+x1;
			t1[255:224]<=c+K1;
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
`ifdef K_ABSORB
		getK=0;
`else		
		getK=n<19?K1:(n<39?K2:(n<59?K3:K4));
`endif
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


`ifdef K_ABSORB
		a1<=a0;
		b1<=b0;
		c1<=c0;
		
		h1<=d0+FUN(a0, rot30(b0), c0, n);
`ifdef CARRY_8
		y10<=rot5(a0)+f0+g0;
`else		
		y10<=rot5(a0)+FUN(b0,c0,d0,n-1)+g0;
`endif

		a2<=rot30(a1);
		b2<=rot30(b1);
		c2<=c1+x2;
		d2<=y10;
		y21<=rot5(y10)+h1+x1_t2; 

		a3<=a2;
		b3<=b2+FUN(y21,rot30(d2),a2, n+2);
		d3<=rot30(d2);
		y31<=y21;
		y32<=c2+rot5(y21)+FUN(d2,a2,b2,n+1);

		a4<=rot5(y32)+b3+x3_t4;
		b4<=y32;
		c4<=rot30(y31);
		d4<=d3;
		e4<=a3;
		g4<=a3+x4;
`ifdef CARRY_8
		f4<=FUN(y32,rot30(y31),d3,n+3);
`endif		

`else
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
module my_dpram (
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

	altdpram	altdpram_component (
				.data (data),
				.inclock (clock),
				.outclock (clock),
				.rdaddress (rdaddress),
				.wraddress (wraddress),
				.wren (wren),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.outclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.maximum_depth = D,
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = N,
		altdpram_component.widthad = logD,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
endmodule

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module my_syncram (
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



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module dp_dpram (
	address_a,
	address_b,
	clock,
	data_a,
	data_b,
	rden_a,
	rden_b,
	wren_a,
	wren_b,
	q_a,
	q_b);

	parameter N=2048;
	parameter D=64;
	parameter logD=$clog2(D);
	
	input	[logD-1:0]  address_a;
	input	[logD:0]  address_b;
	input	  clock;
	input	[N-1:0]  data_a;
	input	[N-1:0]  data_b;
	input	  rden_a;
	input	  rden_b;
	input	  wren_a;
	input	  wren_b;
	output	[N-1:0]  q_a;
	output	[N-1:0]  q_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  clock;
	tri1	  rden_a;
	tri1	  rden_b;
	tri0	  wren_a;
	tri0	  wren_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [N-1:0] sub_wire0;
	wire [N-1:0] sub_wire1;
	wire [N-1:0] q_a = sub_wire0[N-1:0];
	wire [N-1:0] q_b = sub_wire1[N-1:0];

	altsyncram	altsyncram_component (
				.address_a (address_a),
				.address_b (address_b),
				.clock0 (clock),
				.data_a (data_a),
				.data_b (data_b),
				.rden_a (rden_a),
				.rden_b (rden_b),
				.wren_a (wren_a),
				.wren_b (wren_b),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
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
				.eccstatus ());
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = D,
		altsyncram_component.numwords_b = D,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "CLOCK0",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = logD,
		altsyncram_component.widthad_b = logD,
		altsyncram_component.width_a = N,
		altsyncram_component.width_b = N,
		altsyncram_component.width_byteena_a = 1,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";
endmodule


module SHA1_5x5_bare(clk, ext_timer_signal, ctx, data, out_ctx);
	input clk;
	input [6:0] ext_timer_signal;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;

	wire[255:0] va[32:1];
	wire[31:0] sum1, sum2;
	reg [7:0] I, J;	
	reg[159:0] xbuf1[15:1];	
	wire[159:0] vx[31:15];

	(* maxfan=8 *) reg[5:0] timer_signal;
	
function automatic [31:0] rot1;
	input [31:0] y;
	begin
	rot1 = {y[30:0], y[31:31]};
	end
endfunction

function automatic [31:0] rot2;
	input [31:0] y;
	begin
	rot2 = {y[29:0], y[31:30]};
	end
endfunction

function automatic [31:0] rot3;
	input [31:0] y;
	begin
	rot3 = {y[28:0], y[31:29]};
	end
endfunction

function automatic [31:0] rot4;
	input [31:0] y;
	begin
	rot4 = {y[27:0], y[31:28]};
	end
endfunction

function automatic [31:0] rot5;
	input [31:0] y;
	begin
	rot5 = {y[26:0], y[31:27]};
	end
endfunction

function automatic [31:0] rot31;
	input [31:0] y;
	begin
	rot31 = {y[0:0], y[31:1]};
	end
endfunction

function [31:0] fetch1;
	input [511:0] x;
	input [31:0] n;
	begin
		fetch1=x[(n&15)*32+:32];
	end
endfunction

function automatic [31:0] fetch4;
	input [511:0] x;
	input [31:0] n;
	reg [31:0] x0, x1, x2, x3;
	begin
		x0=x[(n&15)*32+:32];
		x1=x[((n+2)&15)*32+:32];
		x2=x[((n+8)&15)*32+:32];
		x3=x[((n+13)&15)*32+:32];
		fetch4 = rot1(x0^x1^x2^x3);
	end	
endfunction

function automatic [191:0] fetch6;
	input [511:0] x;
	input [31:0] n;
	reg [31:0] x0, x1, x2;
	begin		
		x0=fetch4(x, n);
		x1=fetch4(x, n+1);
		x2=fetch4(x, n+2);
		fetch6={
		rot1(x2^fetch1(x,n+5)^fetch1(x,n+7)^fetch1(x,n+13)), 
		rot1(x1^fetch1(x,n+4)^fetch1(x,n+6)^fetch1(x,n+12)), 
		rot1(x0^fetch1(x,n+3)^fetch1(x,n+5)^fetch1(x,n+11)), 
		x2, x1, x0};
	end
endfunction


/*
inputs:
		x0_, x1_, x2_
	[2-part]	
		s = rot1(x8 x10) rot2(x0 x2 x5 x7 x8) rot3 (x2 x4 x10 x15) // 11 terms
			= rot1(x8 x10) rot2(x0 x2 x5 x7 x8) rot2(x2_)
			= rot1(x8 x10) rot2(x5 x7 x13) rot1(x0_) rot2(x2_)
			= rot1(x8 x10) rot1(x0_) rot2(x2_ c2)
		m3 = x6 x8 x14 rot1(x3 x5 x11)
		m4 = rot1(x4 x6 x12)
		c1 = x15 rot1(x12 x14) rot2(x9 x11)
		c2 = x5 x7 x13
		c3 = x6 x8 x14 
		c4 = x7 x9 x15		
		d9 = x9 x11
		d10 = x10 x12
		d11 = x11 x13 

		x13
		x14
		x15		
derived & inlined:		
		m = m3 rot1(x0_) 

		x4_ = m4 rot1(x1_)
		p = c4 x4
		q = c1 rot2(x1_) rot3(m) // 4
equations:
		x3 = c3 m3 rot1(x0_)
		x8_ = c3 d11 s;
		x11_ = rot1(m s);
		x14_ = rot1(x14 x0_) rot2(s);
		
		x5_ = rot1(c2) rot1(x2_);
		x6_ = rot1(m);
		x7_ = rot1(p);
		x9_ = rot1(d9 x1_) rot2(m);
		x10_ = rot1(d10 x2_) rot2(p);

		x12_ = q x15 rot1(x4_); // 6
		x13_ = rot1(x13 x15) rot2(c2 d10) rot3(p);
		x15_ = rot1(q x1_) rot2(c2); // 6

*/		

function [543:0] permute_v2_step1;
		input [511:0] x;

		reg[31:0] x0, x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,
			s1_p1, s1_p2, m3, m4, c1, c2, c3, c4, d9, d10, d11;
		reg [31:0] x0_, x1_, x2_;
	begin
		x0=fetch1(x,0);
		x1=fetch1(x,1);
		x2=fetch1(x,2);
		x3=fetch1(x,3);
		x4=fetch1(x,4);
		x5=fetch1(x,5);
		x6=fetch1(x,6);
		x7=fetch1(x,7);
		x8=fetch1(x,8);
		x9=fetch1(x,9);
		x10=fetch1(x,10);
		x11=fetch1(x,11);
		x12=fetch1(x,12);
		x13=fetch1(x,13);
		x14=fetch1(x,14);
		x15=fetch1(x,15);


	x0_ = rot1(x0^x2^x8^x13);
	x1_ = rot1(x1^x3^x9^x14);
	x2_ = rot1(x2^x4^x10^x15);

	//x3_ = rot1(x3^x5^x11)^rot1(x0_)

	s1_p1 = (x6^x8^x14) ^ (x11^x13);
	s1_p2 = rot1(x8^x10) ^ rot2(x5^x7^x13);

	m3 = x6^x8^x14^rot1(x3^x5^x11);
	m4 = rot1(x4^x6^x12);
	c1 = x15^rot1(x12^x14) ^ rot2(x9^x11);
	c2 = x5^x7^x13^x10^x12;
	c3 = x6^x8^x14;
	c4 = x7^x9^x15;
	d9 = x9^x11;
	d10 = x10^x12;
	d11 = x11^x13;

		permute_v2_step1={
		x0_, x1_, x2_, 
		s1_p1, s1_p2, m3, m4, 
		c1, c2, c3, c4,
		d9, d10, d11,
		x13, x14, x15};
		end
endfunction

		
function [511:0] permute_v2_step2;
		input [543:0] x;
		reg[31:0] x0_, x1_,x2_,x13,x14,x15,
			s1_p1, s1_p2, m3, m4, c1, c2, c3, c4, d9, d10, d11;
//		reg[31:0] s, p, q;
		reg[31:0] x3_, x4_, x5_, x6_, x7_, x8_, x9_, x10_, x11_, x12_, x13_, x14_, x15_;
	begin
		{x0_, x1_, x2_, 
		s1_p1, s1_p2, m3, m4, 
		c1, c2, c3, c4,
		d9, d10, d11,
		x13, x14, x15}=x;
	x3_ = c3^m3^rot1(x0_);		// 3
	x4_ = m4^rot1(x1_);			// 2
	x8_ = c3^d11^s1_p1 ^ s1_p2 ^rot1(x0_) ^ rot2(x2_);	// 6
	x11_ = rot1(m3^rot1(x0_) ^ s1_p1 ^ s1_p2 ^rot1(x0_) ^ rot2(x2_));	 // 6
	x14_ = rot1(x14^x0_) ^ rot2(s1_p1 ^ s1_p2 ^rot1(x0_) ^ rot2(x2_));	// 6

	x5_ = rot1(c2 ^ d10 ^ x2_);		// 3
	x6_ = rot1(m3^rot1(x0_));		// 2
	x7_ = rot1(c4^m4^rot1(x1_));		// 3
	x9_ = rot1(d9^x1_) ^ rot2(m3^rot1(x0_));		// 4
	x10_ = rot1(d10^x2_) ^ rot2(c4^m4^rot1(x1_));	// 5

	x12_ = c1 ^ rot3(m3) ^ rot4(x0_) ^ x15^rot1(m4); // 6
	x13_ = rot1(x13^x15) ^ rot2(c2) ^ rot3(c4^m4) ^ rot4(x1_); // 6
	x15_ = rot1(c1^x1_) ^ rot2(c4) ^ rot3(x1_) ^ rot4(m3) ^ rot5(x0_);	// 6

		permute_v2_step2={x15_,x14_,x13_,x12_,x11_,x10_,x9_,x8_,x7_,x6_,x5_,x4_,x3_,x2_,x1_,x0_};
	end
endfunction


function [511:0] permute_step1;
		input [511:0] x;

		reg[31:0] x0, x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,
		t0,t1,t2,t3,t4;
		reg [31:0] x0_, x1_, x2_, x3_, x4_, x5_;
	begin
		x0=fetch1(x,0);
		x1=fetch1(x,1);
		x2=fetch1(x,2);
		x3=fetch1(x,3);
		x4=fetch1(x,4);
		x5=fetch1(x,5);
		x6=fetch1(x,6);
		x7=fetch1(x,7);
		x8=fetch1(x,8);
		x9=fetch1(x,9);
		x10=fetch1(x,10);
		x11=fetch1(x,11);
		x12=fetch1(x,12);
		x13=fetch1(x,13);
		x14=fetch1(x,14);
		x15=fetch1(x,15);
	
		x0_=rot1(x0^x2^x8^x13);
		x1_=rot1(x1^x3^x9^x14);
		x2_=rot1(x2^x4^x10^x15);
/*		
		x5_ = rot1(x2_^x5^x7^x13); 
		x4_ = rot1(x1_^x4^x6^x12);
		x3_ = rot1(x0_^x3^x5^x11);
*/
		x5_ = rot1(x5^x7^x13)^rot2(x2^x4^x10^x15); 
		x4_ = rot1(x4^x6^x12)^rot2(x1^x3^x9^x14);
		x3_ = rot1(x3^x5^x11)^rot2(x0^x2^x8^x13);
		
		// Don't ask
		t0 = x6^x8^x14;
		t1 = rot1(x12)^rot2(x9^x11)^rot3(x6^x8^x14);
		t2 = x7^x9^x15;
		t3 = x11^rot1(x8^x10)^rot2(x0^x2^x8^x13);
		t4 = x15^rot1(x10^x12);

		permute_step1={
		x0_, x1_, x2_, x3_, x4_, x5_,
		t0, t1, t2, t3, t4,
		x9, x11, x13, x14, x15};
		end
endfunction

function [511:0] permute_step2;
	input [511:0] temp;
	
	reg[31:0] x0_, x1_, x2_, x3_, x4_, x5_,
		t0, t1, t2, t3, t4,
		x9, x11, x13, x14, x15;
		reg[31:0] x6_, x7_, x8_, x9_, x10_, x11_, x12_, x13_, x14_, x15_;
		
	begin
	{x0_, x1_, x2_, x3_, x4_, x5_,
		t0, t1, t2, t3, t4,
		x9, x11, x13, x14, x15} = temp;
		
		x6_ = rot1(t0^x3_);
		x7_ = rot1(t2^x4_);
		x8_ = x11^t3^rot1(x5_);
		x9_ = rot1(x9^x11^x1_)^rot2(t0^x3_);
		x10_ = x15^t4^rot1(x2_)^rot2(t2^x4_);
		x11_ = rot1(x13^t3^x3_)^rot2(x5_);
		x12_ = t1^rot1(x14^x4_)^rot2(x1_)^rot3(x3_);
		x13_ = rot1(x13^t4^x5_)^rot2(x2_)^rot3(t2^x4_);
		x14_ = rot1(x14^x0_)^rot2(t0^t3^x13)^rot3(x5_);
		x15_ = rot1(t1^x1_^x15)^rot2(t2^x14)^rot3(x1_)^rot4(x3_);
		permute_step2={x15_,x14_,x13_,x12_,x11_,x10_,x9_,x8_,x7_,x6_,x5_,x4_,x3_,x2_,x1_,x0_};
		end

endfunction



function [543:0] permute_v3_step1;
		input [511:0] x;

		reg[31:0] x0, x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,
			s1_p1, s1_p2, m3, m4, c1, c2, c3, c4, d9, d10, d11;
		reg [31:0] x0_, x1_, x2_;
	begin
		x0=fetch1(x,0);
		x1=fetch1(x,1);
		x2=fetch1(x,2);
		x3=fetch1(x,3);
		x4=fetch1(x,4);
		x5=fetch1(x,5);
		x6=fetch1(x,6);
		x7=fetch1(x,7);
		x8=fetch1(x,8);
		x9=fetch1(x,9);
		x10=fetch1(x,10);
		x11=fetch1(x,11);
		x12=fetch1(x,12);
		x13=fetch1(x,13);
		x14=fetch1(x,14);
		x15=fetch1(x,15);
		

	x0_ = rot1(x0^x2^x8^x13);
	x1_ = rot1(x1^x3^x9^x14);
	x2_ = rot1(x2^x4^x10^x15);

	//x3_ = rot1(x3^x5^x11)^rot1(x0_)
	m4 = rot1(x4^x6^x12);
	c1 = rot1(x12^x14) ^ rot2(x9^x11);
	c2 = x5^x7^x13^x10^x12;
	c3 = x6^x8^x14;
	c4 = x7^x9^x15;
	d11 = x11^x13;

	s1_p1 = c3 ^ d11;
	s1_p2 = rot1(x8^x10) ^ rot2(x5^x7^x13);

	m3 = c3^rot1(x3^x5^x11);
	d9 = x9^x11;
	d10 = x10^x12;
		
		permute_v3_step1={x0_, x1_, x2_, m3, m4, c1, c2, c3, c4, d9, d10, d11, s1_p1, s1_p2, x13, x14, x15};
	end
	endfunction

	
function [511:0] permute_v3_step2;
		input [543:0] x;
		reg[31:0] x0_, x1_,x2_,x13,x14,x15,
			s1_p1, s1_p2, m3, m4, c1, c2, c3, c4, d9, d10, d11;
		reg[31:0] s, p, q, m5, m6;
		reg[31:0] x3_, x4_, x5_, x6_, x7_, x8_, x9_, x10_, x11_, x12_, x13_, x14_, x15_;
	begin
		{x0_, x1_, x2_, m3, m4, c1, c2, c3, c4, d9, d10, d11, s1_p1, s1_p2, x13, x14, x15}=x;

	m5 = m3^rot1(x0_);
	m6 = c4^m4^rot1(x1_);

	s = s1_p1 ^ s1_p2 ^rot1(x0_) ^ rot2(x2_);
	q = c1 ^ rot1(c4) ^ rot2(x1_);
	
	x3_ = c3^m5;		// 3
	x4_ = c4^m6;			// 2
	x8_ = c3^d11^s;		// 6
	x11_ = rot1(m5 ^ s);	 // 6
	x14_ = rot1(x14^x0_) ^ rot2(s);	// 6

	x5_ = rot1(c2 ^ d10 ^ x2_);		// 3
	x6_ = rot1(m5);		// 2
	x7_ = rot1(m6);		// 3
	x9_ = rot1(d9^x1_) ^ rot2(m5);		// 4
	x10_ = rot1(d10^x2_) ^ rot2(m6);	// 5

	x12_ = q ^rot1(m6) ^ rot3(m3) ^ rot4(x0_); // 6
	x13_ = rot1(x13^x15) ^ rot2(c2) ^ rot3(m6); // 6
	x15_ = rot1(x15^q^x1_) ^ rot4(m5);	// 6

		permute_v3_step2={x15_,x14_,x13_,x12_,x11_,x10_,x9_,x8_,x7_,x6_,x5_,x4_,x3_,x2_,x1_,x0_};
	end
endfunction
	

	parameter K1=32'h5A827999;
	parameter K2=32'h6ED9EBA1;	
	parameter K3=32'h8F1BBCDC;	
	parameter K4=32'hCA62C1D6;	

function [31:0] getK;
	input [31:0] n;
	begin
		getK=n<19?K1:(n<39?K2:(n<59?K3:K4));
	end
endfunction
	
	wire[2111:0] mem_input;
	wire[2047:0] mem_output;
	reg wren=1;

	//`define DPRAM my_dpram
	//integer read_delay=0;

	`define DPRAM my_syncram
	integer read_delay=1;

	reg[191:0] vxt1;
	reg[511:0] vxt[10:2];

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
`ifdef PERMUTE_TYPE1
	reg[511:0] temp_data[3:0];
`else
	reg[543:0] temp_data[3:0];
`endif
	
`ifdef T24_INPUT	
	assign input_data={fixed,xbuf1[14][159:0]};
`elsif T13_INPUT
	assign input_data={fixed,xbuf1[13][159:0]};
`elsif T2_INPUT
	assign input_data={fixed,xbuf1[14][159:0]};
`else
`error "No vx passing method specified"
`endif
	// a tricky way to get all 64 permute steps done in just 8 clocks with 2048 bit of internal storage,
	// with no more than 7 inputs/LUT at any point.
	// (A naive implementation would require dragging along full 512-bit buffer for 64 clocks, though 
	// some of that logic would hopefully be hidden in memory blocks.)
	// Then, since we don't need all that data so early, stick it into an altsyncram delay buffer and withdraw as needed.
	//
	//	The compiler still ends up chaining LUTs, but going to max. 6 inputs/LUT seems to offer no benefit 
	//  in terms of either timing or resources.
	//
	always @(posedge clk)
		begin
`ifdef PERMUTE_TYPE1
		temp_data[0]<=permute_step1(input_data);
		levels[0]<=permute_step2(temp_data[0]);
		temp_data[1]<=permute_step1(levels[0]);
		levels[1]<=permute_step2(temp_data[1]);
		temp_data[2]<=permute_step1(levels[1]);
		levels[2]<=permute_step2(temp_data[2]);
		temp_data[3]<=permute_step1(levels[2]);		
		levels[3]<=permute_step2(temp_data[3]);
`elsif PERMUTE_TYPE2
		temp_data[0]<=permute_v2_step1(input_data);
		levels[0]<=permute_v2_step2(temp_data[0]);
		temp_data[1]<=permute_v2_step1(levels[0]);
		levels[1]<=permute_v2_step2(temp_data[1]);
		temp_data[2]<=permute_v2_step1(levels[1]);
		levels[2]<=permute_v2_step2(temp_data[2]);
		temp_data[3]<=permute_v2_step1(levels[2]);		
		levels[3]<=permute_v2_step2(temp_data[3]);
`elsif PERMUTE_TYPE3
		temp_data[0]<=permute_v3_step1(input_data);
		levels[0]<=permute_v3_step2(temp_data[0]);
		temp_data[1]<=permute_v3_step1(levels[0]);
		levels[1]<=permute_v3_step2(temp_data[1]);
		temp_data[2]<=permute_v3_step1(levels[1]);
		levels[2]<=permute_v3_step2(temp_data[2]);
		temp_data[3]<=permute_v3_step1(levels[2]);		
		levels[3]<=permute_v3_step2(temp_data[3]);
`else
`error "No permute mode specified"
`endif
	end
`ifdef K_ABSORB	
	for(gi=0; gi<4; gi=gi+1) begin: a1
		for(gj=0; gj<16; gj=gj+1) begin: a2
			assign mem_input[(gi*16+gj)*32+:32]=levels[gi][gj*32+:32]+getK(gi*16+gj+15);
		end
	end
`else
	for(gi=0; gi<4; gi=gi+1) begin: a1
		assign mem_input[gi*512+:512]=levels[gi];
	end
`endif	

	for(gi=0; gi<4; gi=gi+1) begin: a3
		for(gj=0; gj<8; gj=gj+1) begin: a4
				assign in_addresses[gj+gi*8]=(timer_signal+128-gi*2)&63;
		end
	end
`ifdef K_ABSORB	
	assign vx[15][31:0]=levels[0][31:0]+getK(15);
	assign vx[15][63:32]=levels[0][63:32]+getK(16);
`ifdef T2_INPUT
	assign vx[15][127:96]=levels[0][127:96]+getK(18);
	assign vx[15][95:64]=levels[0][95:64]+getK(17);
`endif
`else	
	assign vx[15][63:0]=levels[0][63:0];
`ifdef T2_INPUT
	assign vx[15][127:64]=levels[0][127:64];
`endif
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


  for (gi=1; gi<15; gi=gi+1) begin : VR1
    Round1_5x5 #(gi) r(clk, va[gi], xbuf1[gi], va[gi+1]);
  end
  for (gi=15; gi<31; gi=gi+1) begin : VR2
    RoundN_4x #(15 + (gi-15)*4) r(clk, va[gi], va[gi+1], vx[gi][127:0]);
  end
endgenerate
	Round1 r0(clk, ctx, data, va[1], sum1, sum2);
	Round80 r80(clk, va[31], va[32]);

	assign sum1=((ctx[31:0]<<5)|(ctx[31:0]>>27))+ctx[159:128];
	assign sum2=data[31:0]+32'h5A827999;
	
always @ (posedge clk)
	begin
		timer_signal <= ext_timer_signal[5:0];
		xbuf1[1]<=data;
		for(I=1; I<15; I=I+1)
			xbuf1[I+1]<=xbuf1[I];
		end
	assign out_ctx = va[32][159:0];
endmodule 


////
//
//
//   Original (naive) SHA1 implementation
//
//
/////



module Round1_old(clk, va, x0, x1, outa);
	input clk;
	input [159:0] va;
	input [31:0] x0, x1;
	output [255:0] outa;
	parameter K1=32'h5A827999;
	reg [31:0] f;
	reg [255:0] t1;
	wire[31:0] a, b, c, d, e;
	assign a=va[31:0];
	assign b=va[63:32];
	assign c=va[95:64];
	assign d=va[127:96];
	assign e=va[159:128];
	wire[31:0] b_;
	assign b_ = (b<<30)|(b>>2);
	wire[31:0] e_;
	assign e_=((a<<5)|(a>>27))+e+(d^(b&(c^d)))+K1+x0;
	always @ (posedge clk)	
		begin
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



module SHA1_5x5_bare_trivial(clk, ext_timer_signal, ctx, data, out_ctx);
	input clk;
	input [6:0] ext_timer_signal;
	input [159:0] ctx, data;
	output wire[159:0] out_ctx;

	reg[511:0] x0;
	reg[159:0] va0;
	parameter n=80;
	wire[511:0] x[n:1];
	wire[255:0] va[n:1];
	reg[159:0] out_sum;
	reg [7:0] I;
	Round1_old r0(clk, ctx, data[31:0], data[63:32], va[1]);
generate
genvar gi;
  for (gi=1; gi<n; gi=gi+1) begin : VR1
    RoundN_5x5 #(gi) r(clk, va[gi], x[gi], va[gi+1], x[gi+1]);
  end
endgenerate
	assign x[1]=x0;
always @ (posedge clk)
	begin
		x0<={32'h2a0, 288'b0, 32'h80000000, data};
		va0<=ctx;
	end

	assign out_ctx = va[n];
endmodule 



////
//
//
//   Main PMK calculator module
//
//
/////




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
	
	reg[159:0] data[Size-1:0];
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


module pmk_calc_dummy(core_clk, 
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
	parameter instance_id=32'hFFFFFFFF;
	
	reg pad_cycle=0, pad_replace=0;
	reg[15:0] write_count=0, read_count=0, hold_count=0;
	reg [159:0] pad_ring_in_data;
	wire [159:0] pad_ring_out_data;
	wire pad_cycle_wire;
	ring_buffer #(3*N) pad_buf (
		.core_clk(core_clk), 
		.cycle(pad_cycle_wire),
		.replace(pad_replace), 
		.in_data(pad_ring_in_data),
		.out_data(pad_ring_out_data),
		.mid_data(),
		.mid_data2()
		);
	reg full=0, empty=1;
	reg [7:0] status=0;
	assign user_r_read_empty=empty;
	assign user_w_write_full=full;
	assign user_r_read_data=pad_ring_out_data;
	assign out_status=status;
	assign pad_cycle_wire = (status==4) ? user_r_read_rden : pad_cycle;
	always @(posedge core_clk)
		begin
			if(status==0)
				begin
				full<=0;
				empty<=1;				
				if(user_w_write_wren)
					begin
					pad_ring_in_data<=user_w_write_data;
					write_count<=write_count+1;
					pad_cycle<=1;
					pad_replace<=1;
					if(write_count==3*N-1)
						begin
						$display("Core instance %d full", instance_id);
						status<=2;
						hold_count<=0;
						end
					else
						begin
						end
					end
				else
					pad_cycle<=0;
				end
			else if(status==2)
				begin				
				pad_cycle<=1;
				pad_replace<=0;
				full<=1;
				empty<=1;				
				hold_count<=hold_count+1;
				if(hold_count==3*N)
					begin
					status<=4;
					read_count<=0;
					empty<=0;
					$display("Core instance %d done", instance_id);
					end
				end
			else if(status==4)
				begin
				full<=1;
				if(user_r_read_rden)
					begin
					read_count<=read_count+1;
					empty <= (read_count>=3*N-2) ? 1 : 0;
					if(read_count==3*N-2)
						status<=5;
					end
				else
					pad_cycle<=0;
				end	
			else
				begin
				empty<=1;
				full<=0;
				read_count<=0;
				write_count<=0;
				status<=0;
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
	parameter instance_id=32'hFFFFFFFF;

	//parameter Niter=4096;
	parameter L=81;
	parameter NL=N-L;
	parameter logN=$clog2(3*N);

	(* maxfan = 32 *) reg[7:0] status=0;
	reg[22:0] counter; // maximum value Niter*N*2. 20 bits enough for up to N=128.
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg acc_empty, acc_empty_delay1, acc_empty_delay2;
	reg[159:0] data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;
	reg[logN-1:0] read_count=0;

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
		
	(* dont_merge *) reg [159:0] write_data_copy;
	reg acc_cycle_local=0;
	assign acc_ring_in_data=(status!=2) ? write_data_copy : (acc_ring_out_data^data);

	reg[31:0] timer=0;
	SHA1_5x5_bare s55(core_clk, timer[6:0], pad_ring_out_data, data_sha_input, out_ctx);
	//SHA1_5x5_bare_trivial s55(core_clk, timer[6:0], pad_ring_out_data, data_sha_input, out_ctx);
	reg [15:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	reg [logN:0] write_count=0;
	
	reg data_src_switch=0;

	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;//acc_in_reg;

	reg [7:0] sms=0;
	reg [2:0] sink=0;

	(* ramstyle = "logic", dont_merge *) reg [159:0] write_data_delay1, write_data_delay2, read_data_delay1, read_data_delay2;
	reg write_full=0;
	assign user_w_write_full=write_full;
	assign acc_cycle = (status==4) ? user_r_read_rden : acc_cycle_local;
	assign user_r_read_data=read_data_delay2;//acc_ring_out_data;
	assign user_r_read_empty=(status!=4) || acc_empty;
	assign out_status = status;
	
	reg write_wren_delay1=0, write_wren_delay2=0;
	reg[31:0] job_count=0;
	
	reg loaded=0;
	
/*
	wire[159:0] buffers={pad_buf.data[0][31:0],pad_buf.data[N*2-2][31:0],pad_buf.data[N*2-1][31:0],
			acc_buf.data[N-3][31:0],acc_buf.data[N-2][31:0]};
	reg[159:0] buffers_expected_0={32'h1367cfec,32'ha562a2e5,32'ha562a2e5,32'haa6b088c,32'h6b4a0528};
	reg[159:0] buffers_expected_1=160'h61e87c4047588185a562a2e55b19c584aa6b088c;
	wire[159:0] buffers_expected = (job_count==1) ? buffers_expected_1 : buffers_expected_0;
*/
always @ (posedge core_clk)               
	begin					
	
		write_wren_delay1 <= user_w_write_wren;
		write_wren_delay2 <= write_wren_delay1;
		write_data_delay1 <= user_w_write_data;
		write_data_delay2 <= write_data_delay1;
		
		if(timer!=32'hffffffff)
			timer<=timer+1;
		else
			timer<=0;
		if(status==0 && !loaded)
			begin
			acc_empty<=0;
			acc_empty_delay1<=0;
			acc_empty_delay2<=0;
			if(write_wren_delay2)
				begin
				if(sink==0 || sink==1)
					begin
					pad_cycle<=1;
					pad_replace<=1;
					pad_ring_in_data<=write_data_delay2;
					acc_cycle_local<=0;
					acc_replace<=0;
					end
				else
					begin
					pad_cycle<=0;
					pad_replace<=0;
					acc_cycle_local<=1;
					acc_replace<=1;
					write_data_copy<=write_data_delay2;
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
//					status<=1;
					write_full<=1;
					loaded<=1;
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
		else if(loaded)
			begin
				$display("Core %d job %d filled", instance_id, job_count);
				$display("%x %x %x", pad_buf.data[0], pad_buf.data[1], acc_buf.data[0]);
/*				
			if((instance_id==0 || instance_id==1) && job_count<2)
				begin
					if(buffers[159:64]!=buffers_expected[159:64])
							$display("Pad buffer mismatch: observing %x %x %x", 
								pad_buf.data[0][31:0], pad_buf.data[N*2-2][31:0], pad_buf.data[N*2-1][31:0]);
					if(buffers[63:0]!=buffers_expected[63:0])
							$display("Acc buffer mismatch: observing %x %x", acc_buf.data[N-3][31:0], acc_buf.data[N-2][31:0]);
				end
*/				
			job_count<=(job_count!=32'hffffffff)?job_count+1:0;
			read_count<=0;
			data_cycle<=1;
			data_replace<=1;
			status<=2;
			sms<=2;
			acc_cycle_local<=0;
			acc_replace<=0;
			loaded<=0;
			end
		else if(status==2)
			begin
				pad_cycle<=1;
				pad_replace<=0;

				if(counter==Niter*N*2-1)
					sms<=4;
				if(counter==Niter*N*2+0)
					sms<=5;
				if(counter==Niter*N*2+2)
					sms<=6;
				if(counter==Niter*N*2+3)
					begin
					status<=4;
					$display("Core %d finished", instance_id);
					end
				if(counter==2*N)
					data_src_switch<=1;

				//consume_flag<=(loop_counter!=0 && (inst_counter >= N))?1:0;
				acc_replace<=(loop_counter!=0 && (inst_counter >= N) && sms<5)?1:0;

				if(sms==4||sms==6)
					acc_cycle_local<=0;
				else
					acc_cycle_local<=1;
				read_data_delay1 <= acc_ring_out_data;
				read_data_delay2 <= read_data_delay1;
				
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
					begin
					read_count<=read_count+1;
					read_data_delay1 <= acc_ring_out_data;
					read_data_delay2 <= read_data_delay1;
					acc_empty_delay2 <= acc_empty_delay1;
					acc_empty_delay1 <= acc_empty;
					acc_empty <= (read_count>=N-2) ? 1 : 0;
					if(read_count==N-2)
						status<=5;
					end
				end
			else if(status==5)
					begin
					status<=0;
					write_count<=0;
					data_src_switch<=0;
					write_count<=0;
					pad_cycle<=0;
					sink<=0;
					write_full<=0;
					loaded<=0;
					end
	end
endmodule	




module switching_ring_buffer(core_clk, cycle, selector, replace, in_data, out_data, mid_data, mid_data2);
	parameter Size=100;
	parameter switchCycle=1;
	parameter switchInput=0;
	parameter Mid=0;
	parameter Mid2=0;

	input core_clk;
	input [switchCycle:0] cycle;
	input selector;
	input replace;
	input [(switchInput+1)*160-1:0] in_data;
	output [159:0] out_data;
	output [159:0] mid_data;
	output [159:0] mid_data2;
	
	reg[31:0] cycle_count=0;
	reg[31:0] I;
	
	reg[159:0] data[Size-1:0];
	assign mid_data=data[Mid];
	assign mid_data2=data[Mid2];
	assign out_data=data[Size-1];
always @(posedge core_clk)
	begin
		if(cycle[switchCycle ? selector : 0])
			begin
			cycle_count<=cycle_count+1;
			for(I=0; I+1<Size; I=I+1)
				data[I+1]<=data[I];
			if(replace)
				data[0]<=switchInput ? in_data[selector*160+:160] : in_data;
			else
				data[0]<=data[Size-1];
			//out_data<=data[0];
			end
	end	
endmodule


module pmk_calc_daisy(input core_clk, 
		input [159:0] data_in,
		input write_enable,
		output [159:0] data_out,
		input [2:0] mode,
		output done
	);
	
	parameter N=100;
	parameter Niter=10;
	parameter instance_id=32'hFFFFFFFF;

	//parameter Niter=4096;
	parameter L=81;
	parameter NL=N-L;
	parameter logN=$clog2(3*N);

	(* maxfan = 32 *) reg[7:0] status=0;
	reg[22:0] counter; // maximum value Niter*N*2. 20 bits enough for up to N=128.
	wire[159:0] out_ctx;
	reg[31:0] I, J;
	reg[159:0] data;
	reg[159:0] pad_half_delayed;
	wire[159:0] data_sha_input, data_bare;

	reg pad_cycle=0, pad_replace=0;
	wire [159:0] pad_ring_in_data;
	wire [159:0] pad_ring_out_data;
	wire [159:0] pad_ring_mid_data;	
	switching_ring_buffer #(2*N, 1, 0, N-3) pad_buf (
		.core_clk(core_clk), 
		.cycle({write_enable, pad_cycle}),
		.selector(mode!=1),
		.replace(pad_replace), 
		.in_data(pad_ring_in_data),
		.out_data(pad_ring_out_data),
		.mid_data(pad_ring_mid_data),
		.mid_data2()
		);
	reg data_cycle=0, data_replace=0;

	ring_buffer #(NL) data_buf (
		.core_clk(core_clk), 
		.cycle(data_cycle),
		.replace(data_replace), 
		.in_data(out_ctx),
		.out_data(data_bare),
		.mid_data(),
		.mid_data2()
		);
		
	reg acc_replace=0;
	reg acc_cycle=0;
	
	//wire [159:0] acc_ring_in_data;
	wire [159:0] acc_ring_out_data;
	
	switching_ring_buffer #(N, 1, 1) acc_buf (
		.core_clk(core_clk), 
		.cycle({write_enable, acc_cycle}),
		.selector(mode!=1),
		.replace(acc_replace), 
		//.in_data(acc_ring_in_data),
		.in_data({data_in, acc_ring_out_data^data}),
		.out_data(acc_ring_out_data),
		.mid_data(),
		.mid_data2()
		);
		
	(* dont_merge *) reg [159:0] write_data_copy;
	reg[31:0] timer=0;
	reg [15:0] loop_counter=0;
	reg [10:0] inst_counter=0;
	
	reg data_src_switch=0;
	assign data_sha_input=(data_src_switch) ? data : acc_ring_out_data;
	reg [7:0] sms=0;
	reg[31:0] job_count=0;

	assign pad_ring_in_data = acc_ring_out_data;
	assign data_out = (mode==0) ? pad_ring_out_data : acc_ring_out_data;
	//assign acc_ring_in_data=(mode!=1) ? data_in : (acc_ring_out_data^data);
	assign done = (status==4);
	
	SHA1_5x5_bare s55(core_clk, timer[6:0], pad_ring_out_data, data_sha_input, out_ctx);
	
	reg first_iter=0, second_iter=0, last_iter=0, first_pass=0;
	
always @ (posedge core_clk)               
	begin					
		if(timer!=32'hffffffff)
			timer<=timer+1;
		else
			timer<=0;
		if(mode==0)
			begin
			acc_replace<=1;
			pad_replace<=1;
			status<=0;
			end
		else if(mode==1 && status==0)
			begin
				$display("Core %d job %d filled", instance_id, job_count);
				$display("%x %x %x", pad_buf.data[0], pad_buf.data[1], acc_buf.data[0]);
/*				
			if((instance_id==0 || instance_id==1) && job_count<2)
				begin
					if(buffers[159:64]!=buffers_expected[159:64])
							$display("Pad buffer mismatch: observing %x %x %x", 
								pad_buf.data[0][31:0], pad_buf.data[N*2-2][31:0], pad_buf.data[N*2-1][31:0]);
					if(buffers[63:0]!=buffers_expected[63:0])
							$display("Acc buffer mismatch: observing %x %x", acc_buf.data[N-3][31:0], acc_buf.data[N-2][31:0]);
				end
*/				
			counter <= N;
			loop_counter <= 0;
			inst_counter <= N;
			job_count<=(job_count!=32'hffffffff)?job_count+1:0;
			data_cycle<=1;
			data_replace<=1;
			status<=2;
			sms<=2;
			acc_cycle<=0;
			acc_replace<=0;
			data_src_switch<=0;
			last_iter<=0;
			first_iter<=1;
			second_iter<=0;
			end
		else if(status==2)
			begin
				pad_cycle<=1;
				pad_replace<=0;
				if(last_iter)//counter==Niter*N*2+0)
					begin
					acc_cycle<=0;
					status<=4;
					$display("Core %d finished", instance_id);
					end
				else
					acc_cycle<=1;
				if(second_iter && first_pass)
					data_src_switch<=1;

				acc_replace<=((!first_iter) && (inst_counter >= N))?1:0;
				
				counter<=counter+1;
				if(inst_counter == 2*N-1)
					begin
					loop_counter <= loop_counter+1;
					inst_counter <= 0;
					second_iter<=first_iter;
					first_iter<=0;
					first_pass<=1;
					last_iter <= (loop_counter==Niter-1);
					end
				else
					begin
					inst_counter <= inst_counter+1;
					first_pass <= 0;
					end
				
				data[31:0]<=data_bare[31:0]+pad_half_delayed[31:0];
				data[63:32]<=data_bare[63:32]+pad_half_delayed[63:32];
				data[95:64]<=data_bare[95:64]+pad_half_delayed[95:64];
				data[127:96]<=data_bare[127:96]+pad_half_delayed[127:96];
				data[159:128]<=data_bare[159:128]+pad_half_delayed[159:128];
				
				pad_half_delayed <= pad_ring_mid_data;
			end
		else if(mode==1 && status==4)
			begin
			acc_cycle<=0;
			pad_cycle<=0;
			end
		else if(mode==2)
			begin
			acc_replace<=1;
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



typedef reg[159:0] PAD;

typedef struct 
{
	PAD ipad;
	PAD opad;
	PAD data;
	PAD expect_acc_10;
	PAD expect_acc_4096;
} testcase;

testcase testcases[6:0]=
'{
'{
	160'hdd703e0b119e9000de162d2be611b157a562a2e5,
	160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40,
	160'hfe4e9708a46b0012fb850d0c87d0b1216b4a0528,
	160'h96c7329c2a3c45511891af4ac1204c4eb4925e3e,
	160'h90ac65510acd595160d1481235ed6efd8a87a4d2
	//reg[159:0] expect_int1_0=160'h66ed4af39c89a114b097e4feabd8ab01ac44780e;
	//reg[159:0] expect_ctx1_0=160'h8427f3038b329cc9adb58fc8b3527b28aaf7f0ce;
	//reg[159:0] expect_acc1_0=160'h7a69640b2f599cdb563082c43482ca09c1bdf5e6;
},
'{
	160'hdd703e0b119e9000de162d2be611b157a562a2e5,
	160'h8bb0065d70b33d2f6e23e60593ec31d861e87c40,
	160'hbd40b2ce6e1fc59622b4455559265902aa6b088c,
	160'hc9f5a0d851d9aaf405b75f4e3204e0f47b5fe086,
	160'h8c0866ac1688a0fc1e82c064fab26f0fdb121096
//reg[159:0] expect_ctx1_1=160'hbb8130829d637dfaf8127597b21b9c766a494df6;
//reg[159:0] expect_acc1_1=160'h06c1824cf37cb86cdaa630c2eb3dc574c022457a;
},
'{
	160'h51da39b7abb93a9512b3d4483e02457747588185,
	160'h242d564083cf6d7346d2d8a2059405571367cfec,
	160'h6ae229b8aded0e8b9974d9fce62d02375b19c584,
	160'h21aefd2a1419cfcd9a76c615da5f96e253094569,
	160'hc3cd9902b1d20fe443902c0b3404b2b19295aceb
},
'{
	160'h0,
	160'h0,
	{5{32'h1}},
	160'h9e3b2134db31f0398f9c357e583260cf4dad1004,
	160'h0
},
'{
	{5{32'h12345678}},
	{5{32'h87654321}},
	{5{32'h35353535}},
	160'hc10290cc2d015256edfa6053b3cd1728ee0ef34b,
	160'h0
},
'{
160'hec467b050c69ff9b470deadf450d08ddf8b30868,
160'h8e0c7dba8e9f45fe762382d0301f2338e3f2e177,
160'h0abd4464ec70f3d429883e7316ad92561033b215,
160'hee071b53e9b42b5210dacf6f74f0de88c3dd8d31,
160'h934ca6db5abc2e2dc9dc7e91f230524c8654f331
},
'{
160'h41ec5b1406d6d1ed064c538fc687d0ae8b83580d,
160'hb7222da92695d2ec6ae24f22e9532df4d2c70df5,
160'h17f5c555becdec8a0323a4969e9a0d378511ae24,
160'hc47fcb24c48b16c88dddc271d542c6cc8a03b3fe,
160'he73a0b3d096701324c47d2f6f477d9e70d8d6d7f
}
};

//
// Gatherer module: takes in N W-wide sources using standard lookahead FIFO interface, 
// concatenates them front to back and exposes them as through a single W-wide interface.
//
// All sources must report nonempty before the module announces availability by lowering rdempty_1.
// If any source goes empty while being drained, it's marked 'done' and the module moves on to the next one.
// When the module is done with the last source, it raises rdempty_1 and goes dormant. 
// To restart the operation from the first source, it must be reset.
//
`ifdef REGISTERED_GATHER
module data_gather(clk,
	rden_1, rdempty_1, rddata_1,
	rden_N, rdempty_N, rddata_N, reset );
	input clk, rden_1, reset;
	parameter N=4;
	parameter W=160;
	output [W-1:0] rddata_1;
	output rdempty_1;
	
	output[N-1:0] rden_N;
	input [N-1:0] rdempty_N;
	input [N*W-1:0] rddata_N;
	
	reg[3:0] inst=0;
	reg[W-1:0] data, data1, data4[3:0];
	reg[N-1:0] reg_rden_N;
	reg[31:0] I, J;
	
	reg is_empty=1, is_empty_delayed=1, is_empty_delayed2=1;
	
	wire [W*16-1:0] rddata_16;
	assign rddata_16[N*W-1:0]=rddata_N;
	reg[3:0] state=0;
/*
generate
	genvar gi;
	for(gi=0; gi<N; gi=gi+1) begin : a
		assign rden_N[gi]=(rden_1 && !rdempty_N[gi] && gi==inst) || (gi==0 && state[2]);//loading!=0);
	end
endgenerate
	*/
	
	function [31:0] find_pad;
		input[159:0] x;
		reg[31:0] I;
		begin
			find_pad=123456;
			for(I=0; I<7; I=I+1)
				if(x==testcases[I].expect_acc_10)
					find_pad=I;
		end
	endfunction
	assign rden_N=reg_rden_N;
	assign rddata_1=data;
	assign rdempty_1=is_empty_delayed2;
	reg[31:0] clock=0;
	reg[31:0] read_count=0;
	reg[N-1:0] inst_mask=1;
	
	reg[3:0] inst_delay=0;
	
	reg rden_delay=0, rden_delay2=0, rden_delay3=0;
	reg advance=0;
	always @(posedge clk)
		begin
			if(N>=16)
				$display("ERROR: data_gather supports up to 15 instances");
/*
			clock<=clock+1;
			if(rden_1)
				read_count<=read_count+1;
				
			//if((read_count>=120 && read_count<=130) || (rden_1 && rdempty_N[inst]))
			//if((read_count>=1 && read_count<20)||state[2])
		//	if(clock>=11085 && clock<=11110)
			if(read_count>=500 && read_count<=520)		
				begin
				$display("%d: read_count %d, inst %d/%d, rden_1 %d, rden_N[inst] %d, data %d, data1 %d, data4 %d, rddata_N[inst] %d, rdempty_N[inst] %d, state %d",
					clock, read_count, inst, N, rden_1, reg_rden_N[inst], 
						find_pad(data), find_pad(data1), find_pad(data4[inst>>2]), find_pad(rddata_N[inst*W+:160]), rdempty_N[inst], state);
				end
*/
/**
	Using 3 intermediate registers to avoid chaining multiplexers

	done loading: expecting
			data:			v[0]
			data1:		v[1]
			data4:		v[2]
			rden_N[0]:	v[3]

	t=0: 	0 1 2 3   rden_1 signaled: data <= data1; data1 <= data4; request update from downstream
	t=1: 	1 2 2 3   reg_rden_N signaled; data4 <= reg_rddata; downstream entity sees the request
	t=2:	1 2 3 4 			downstream entity replaces rddata_N and signals rdempty_N
	t=5:	1 2 3 4   rden_1 signaled; data <= data1; data1 <= data4; notice signaled rdempty_N; increment inst; don't request an update at this time 
				(next entry is already in rddata_N)
				
	We may assume that rden_1 requests are widely spaced except in the beginning
	(they are sent by unpacker_160_to_32, which outputs 32 bit per clock)
	We may also assume no more than 2 rden_1 requests back to back

	t=0				0 1 2 3
	t=1	rden		0 1 2 3
	t=2	rden		0 1 2 3
**/
			if(rden_delay)
				inst_delay<=inst;
			if(state[2])
				begin
					reg_rden_N[0]<=(state!=7);					
					for(I=1; I<N; I=I+1)
						reg_rden_N[I]<=0;
					advance <= 0;
					rden_delay <= 0;
					rden_delay2 <= 0;
					rden_delay3 <= 0;
					data1<=data4[0];
					data4[0]<=rddata_N[W-1:0];
				end
			else
				begin
					for(I=0; I<N; I=I+1)
						reg_rden_N[I]<=(rden_1 && !rdempty_N[I] && I==inst);
					advance <= rden_1 && ((rdempty_N & inst_mask) != 0);
					rden_delay<=rden_1;
					rden_delay2 <= rden_1 && rden_delay;
					rden_delay3 <= rden_delay;
					
/***					
	handles a special case of 2 rden_1's back to back
					
	if(rden_1||rden_delay2)
	t=0:                  0 1 2 3
	t=1: rden_1 signaled; 0 1 2 3
	t=2: rden_1 signaled: 1 2 2 3
	t=3: 						 2 2 3 4
	t=4:                  2 3 4 5		
	
	if (rden_delay)
	
	t=0:                  0 1 2 3
	t=1: rden_1 signaled; 0 1 2 3
	t=2: rden_1 signaled: 1 1 2 3
	t=3: 						 1 2 3 4
	t=4:                  1 3 4 5		- lost #2
	
	if (rden_1)

	t=0:                  0 1 2 3
	t=1: rden_1 signaled; 0 1 2 3
	t=2: rden_1 signaled: 1 2 2 3
	t=3: 						 2 2 3 4
	t=4:                  2 2 4 5
	t=5: rden_1 signaled: 2 2 4 5
	t=6:                  2 4 4 5 	- lost #3 
	
***/					
					if(rden_1 || rden_delay2)
					//if(rden_1)
							data1<=data4[inst_delay[3:2]];
					if(rden_delay)
					//if(rden_1)
							begin
							for(I=0; I<4; I=I+1)
								data4[I]<=rddata_N[(I*4+(inst&3))*W+:W];
							end//			if(read_delay2)
							
					if(advance)
						begin
						if(inst!=N-1)
							begin
							inst<=inst+1;
							inst_mask<=1<<(inst+1);
							end
						else
							is_empty<=1;
						end				
				end
				/*
			for(I=0; I<N; I=I+1)
				reg_rden_N[I]<=(rden_1 && !rdempty_N[I] && I==inst) || (I==0 && (state==4 || state==5 || state==6));
			advance <= rden_1 && ((rdempty_N & inst_mask) ? 1 : 0);
			rden_delay<=rden_1;
			rden_delay2 <= rden_1 && rden_delay;
			if(rden_1 || rden_delay2 || state[2])			
					begin
					data1<=data4[inst[3:2]];
					end
			if(rden_delay || advance || state[2])
					begin
					for(I=0; I<4; I=I+1)
						data4[I]<=rddata_N[(I*4+(inst&3))*W+:W];
					end//			if(read_delay2)
					
			if(advance)
				begin
				if(inst!=N-1)
					begin
					inst<=inst+1;
					inst_mask<=1<<(I+1);
					end
				else
					is_empty<=1;
				end
				*/	
				
			if(reset)
				begin
					inst<=0;
					inst_delay<=0;
					is_empty<=1;
					is_empty_delayed<=1;
					is_empty_delayed2<=1;
					inst_mask<=1;
					state<=0;
				end
				
			else
				case(state)
				0: if(rdempty_N==0)
						begin
						inst<=0;
						inst_delay<=0;
						is_empty<=1;
						inst_mask<=1;
						is_empty_delayed<=1;
						is_empty_delayed2<=1;
						state<=4;
						end
				4:	state<=5;
				5: state<=6;
				6: state<=7;
				7: begin
					data<=data1;
					is_empty<=0;
					is_empty_delayed<=0;	
					is_empty_delayed2<=0;
					state<=1;
					end
				1: begin
	
					if(rden_1)
						begin
					
						data<=data1;
						is_empty_delayed<=is_empty;
						is_empty_delayed2<=is_empty_delayed;
						end
					end
				endcase
		end
endmodule

`else

module data_gather(clk,
	rden_1, rdempty_1, rddata_1,
	rden_N, rdempty_N, rddata_N, reset );
	input clk, rden_1, reset;
	parameter N=4;
	parameter W=160;
	output [W-1:0] rddata_1;
	output rdempty_1;
	
	output[N-1:0] rden_N;
	input [N-1:0] rdempty_N;
	input [N*W-1:0] rddata_N;
	
	reg[5:0] inst=0;
	reg[W-1:0] data;
	reg[N-1:0] reg_rden_N;
	reg initialized=0;
	reg[31:0] I;
	
generate
	genvar gi;
	for(gi=0; gi<N; gi=gi+1) begin : a
		assign rden_N[gi]=(rden_1 && !rdempty_N[gi] && gi==inst);
	end
endgenerate
	assign rddata_1=rddata_N[inst*W+:W];
	assign rdempty_1=(rdempty_N[inst] && (inst==N-1)) || !initialized;

//	reg[31:0] clock=0;
//	reg[31:0] read_count=0;
	
	always @(posedge clk)
		begin
//			clock<=clock+1;
//			if(rden_1)
//				read_count<=read_count+1;
				
			//if((read_count>=120 && read_count<=130) || (rden_1 && rdempty_N[inst]))
//			if(read_count>=250 && read_count<260 && rden_1)
//				$display("%d: read_count %d, inst %d, rden_1 %d, rddata_N[inst] %x, rdempty_N[inst] %d",
//					clock, read_count, inst, rden_1, rddata_N[inst*W+:W], rdempty_N[inst]);
			if(reset)
				begin
					initialized<=0;
					inst<=0;
				end
			else if(initialized==0 && rdempty_N==0)
				begin
					initialized<=1;
					inst<=0;
				end
			else if(rden_1 && rdempty_N[inst] && inst!=N-1)
				inst<=inst+1;
		end
endmodule
`endif

//
// Scatterer module. Exposes a single W-wide sink interface (wren_1/wrfull_wrdata_1) and feeds the data arriving
// through that interface into N W-wide sinks, in order, switching as they report full status. 
// 
module data_scatter(clk,
	wren_1, wrfull_1, wrdata_1,
	wren_N, wrfull_N, wrdata_N, reset);
	input clk, wren_1, reset;
	parameter N=4;
	parameter W=160;
	input [W-1:0] wrdata_1;
	output wrfull_1;
	
	output[N-1:0] wren_N;
	input [N-1:0] wrfull_N;
	output [N*W-1:0] wrdata_N;
	
	(* maxfan=64 *) reg[5:0] inst=0;
	reg[N*W-1:0] data;
	reg[N-1:0] reg_wren_N;
	reg full=0;
	reg[31:0] I;
	
	assign wrfull_1=full;
	assign wren_N=reg_wren_N;
	assign wrdata_N=data;
	reg[N-1:0] inst_mask=1;
	always @(posedge clk)
	begin
		for(I=0; I<N; I=I+1)
			data[I*W+:W]<=wrdata_1;

		if(reset)
			begin
			inst<=0;
			full<=0;
			reg_wren_N<=0;
			inst_mask<=1;
			end
		else 
			begin
			for(I=0; I<N; I=I+1)
				reg_wren_N[I]<=inst_mask[I] && wren_1 && !(wrfull_N[I] && I+1==N);
				
			if(inst_mask[N-1] && wrfull_N[N-1])
				full<=1;
			
			for(I=0; I<N; I=I+1)
				if(inst_mask[I] && wrfull_N[I] && I+1<N)
					begin
						inst<=inst+1;
						inst_mask<=1<<(I+1);
					end
					
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
	
	
	parameter Njobs=100;
	reg[15:0] lines_written=0;
	
	(* maxfan = 64 *) reg write_160_enable=0;
	wire write_160_full;
	
	
	(* dont_merge *) (* ramstyle="logic" *) reg[159:0] input_line=0;
	reg[3:0] dwords_written=0;
		
	assign write_160_wren = write_160_enable;
	reg is_full=0;
`ifdef PRECALC_WRFULL
	assign write_32_full = is_full;
`else
	assign write_32_full = write_160_full;
`endif
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
			is_full<=1;
			end
		else if(write_32_wren)
			begin
				input_line[159:128]<=write_32_data;
				input_line[127:0]<=input_line[159:32];
				if(dwords_written==4)
					begin
						write_160_enable<=1;
						lines_written<=lines_written+1;
//						$display("%d/%d", lines_written, Njobs*3-1);
						if(lines_written==Njobs*3-1)
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
			if(!write_160_full)
				is_full<=0;
			write_160_enable<=0;
			end
			
	end
endmodule

// Takes in a 160-bit source and exposes it as a 32-bit source
`ifdef REGISTER_OUTPUT
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
	
	parameter N=128;
	
	input reset;
	reg is_empty=1, line_valid=0, next_line_valid=0;
	reg[1:0] loading=0;
	reg[159:0] line, next_line;
	reg[3:0] read_pos=0;
	assign user_r_read_32_empty = is_empty;
	reg reg_rd160en=0;
	assign read_160_rden = reg_rd160en;
	//assign read_160_rden = user_r_read_32_rden && (read_pos==4);
	
	reg[31:0] timer=0;
	reg[31:0] line_count=0;
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
				if(read_pos==4)
					next_line<=read_160_data;
				else
					next_line<={32'b0,next_line[159:32]};
//				next_line<={read_160_data[read_pos*32+:32], next_line[159:32]};
				next_line_valid<=!read_160_empty;
				if(read_pos<4)
					begin
					read_pos<=read_pos+1;
//					if(read_pos==3)
//						is_empty<=!line_valid;
					end
				else// if(read_pos==4)
					begin
					line_count<=line_count+1;
					read_pos<=0;
	//				line<=next_line;				
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

`else

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
	
	input reset;
	reg is_empty=1;
	wire[159:0] line;
	reg[3:0] read_pos=0;
	assign user_r_read_32_empty = is_empty;
	assign read_160_rden = user_r_read_32_rden && (read_pos==4);
  	assign line=read_160_data;
	assign user_r_read_32_data=line[read_pos*32+:32];
   always @(posedge clk)
     begin
	if(reset)
		begin
		read_pos<=0;
		is_empty<=1;
		end
	else if(user_r_read_32_rden && !is_empty)
		begin
		if(read_pos<4)
			read_pos<=read_pos+1;
		else if(read_pos==4 && !read_160_empty)
			read_pos<=0;
		else
			begin
			read_pos<=0;
			is_empty<=1;
			end
		end
	else if(is_empty && !read_160_empty)
		is_empty<=0;
     end
endmodule

`endif
// wrapper for pmk_calc_ring_fifo with an arbitrary number of stamps and automatic 32-bit I/O marshalling
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
	parameter debug=0;
	
	wire wren_1;
	wire wrfull_1;
	wire[159:0] wrdata_1;
	
	wire[N-1:0] wren_N;
	wire[N-1:0] wrfull_N;
	wire[160*N-1:0] wrdata_N;

	reg filler_reset=0;
	reg[7:0] out_status[N-1:0];
	reg drainer_reset=0;
	
	wire rden_1;
	wire rdempty_1;
	wire[159:0] rddata_1;
	
	wire[N-1:0] rden_N;
	wire[N-1:0] rdempty_N;
	wire[160*N-1:0] rddata_N;
	
	reg[7:0] prev_last_status=0, prev_first_status=0;
generate
genvar gi;

	for(gi=0; gi<N; gi=gi+1) begin: workers
		pmk_calc_ring_fifo #(Njobs,Niter, debug ? gi : 32'hFFFFFFFF) 
//		pmk_calc_dummy #(Njobs) 
			worker(clk, 
			rdempty_N[gi],
			rden_N[gi],
			rddata_N[gi*160+:160],
			wrfull_N[gi],
			wren_N[gi],
			wrdata_N[gi*160+:160],
			out_status[gi]
		);
		end
endgenerate	

	packer_32_to_160 #(Njobs) packer(clk, write_32_wren, write_32_full, write_32_data,
		wren_1, wrfull_1, wrdata_1, filler_reset);
	unpacker_160_to_32 unpacker(clk, read_32_rden, read_32_empty, read_32_data, 
		rden_1, rdempty_1, rddata_1, drainer_reset);
	
	data_scatter #(N, 160) filler (clk,
		wren_1, wrfull_1, wrdata_1,
		wren_N, wrfull_N, wrdata_N, filler_reset);
	data_gather #(N, 160) drainer (clk,
		rden_1, rdempty_1, rddata_1,
		rden_N, rdempty_N, rddata_N, drainer_reset);

	always @(posedge clk)
		begin
	//	if(write_32_full)
	//		$display("Packer full");
		filler_reset <= (prev_last_status!=0 && out_status[N-1]==0);
		drainer_reset<= (prev_first_status!=2 && out_status[0]==2);
		if(filler_reset)
			$display("Filler reset signaled");
		if(drainer_reset)
			$display("Drainer reset signaled");
		prev_last_status<=out_status[N-1];
		prev_first_status<=out_status[0];
		end
endmodule


module pmk_dispatcher_daisy(clk, read_32_rden,
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
	parameter debug=0;
	
	wire[159:0] daisy_chain_input;
	wire[159:0] daisy_chain_output;

	reg[N-1:0] worker_status;
	reg[15:0] read_count=0, write_count=0;
	(* maxfan=64 *) reg[2:0] mode=0;
	reg filler_reset=0, drainer_reset=0;
	
	wire[160*N-1:0] temp_wires;
	wire packer_request, unpacker_request;
	wire write_enable = (mode==0) ? packer_request : unpacker_request;
generate
genvar gi;
/*
module pmk_calc_daisy(input core_clk, 
		input [159:0] data_in,
		input write_enable,
		output [159:0] data_out,
		input [2:0] mode,
		output done
	);

*/
	for(gi=0; gi<N-1; gi=gi+1) begin: workers
		pmk_calc_daisy #(Njobs,Niter, debug ? gi : 32'hFFFFFFFF) 
			worker(clk, 
			gi==0 ? daisy_chain_input : temp_wires[(gi-1)*160+:160],
			write_enable,
//			(gi==N-1) ? daisy_chain_output : temp_wires[gi*160+:160],
//daisy_chain_output ,
temp_wires[gi*160+:160],
			mode,
			worker_status[gi]			
		);
		end
endgenerate	
		pmk_calc_daisy #(Njobs,Niter, debug ? N-1 : 32'hFFFFFFFF) 
			worker(clk, 
			temp_wires[(N-2)*160+:160],
			write_enable,
			daisy_chain_output,
			mode,
			worker_status[N-1]);			

//module packer_32_to_160(clk, write_32_wren, write_32_full, write_32_data,
//	write_160_wren, write_160_full, write_160_data, reset);

	reg empty=1;//, full=0;
	//assign write_32_full=full;
	//assign read_32_empty=empty;
	packer_32_to_160 #(N*Njobs) packer(
		.clk(clk), 
		.write_32_wren(write_32_wren), 
		.write_32_full(write_32_full), 
		.write_32_data(write_32_data),
		.write_160_wren(packer_request), 
		.write_160_full(mode!=0), 
		.write_160_data(daisy_chain_input), 
		.reset(filler_reset)
		);
//module unpacker_160_to_32(clk, user_r_read_32_rden, user_r_read_32_empty, user_r_read_32_data,
//	read_160_rden, read_160_empty, read_160_data,	reset);
		
	unpacker_160_to_32 #(N*Njobs) unpacker(
		.clk(clk), 
		.user_r_read_32_rden(read_32_rden),
		.user_r_read_32_empty(read_32_empty),
		.user_r_read_32_data(read_32_data), 
		.read_160_rden(unpacker_request), 
		.read_160_empty(empty),
		.read_160_data(daisy_chain_output),
		.reset(drainer_reset)
		);

		
	always @(posedge clk)
		begin
		if(mode==0)
			begin
			empty<=1;
			if(packer_request)
				begin
				write_count<=write_count+1;
				if(write_count==3*Njobs*N-1)
					begin
					$display("pmk_dispatcher_daisy: transition to state 1");
					mode<=1;
					drainer_reset<=1;
					//full<=1;
					end
				end				
			end
		else if(mode==1)
			begin
			drainer_reset<=0;
			if(worker_status == (1<<N)-1)
				begin
				$display("pmk_dispatcher_daisy: transition to state 2");
				filler_reset<=1;
				read_count<=0;
				mode<=2;
				empty<=0;
				end
			end
		else if(mode==2)
			begin
			filler_reset<=0;
			if(unpacker_request)
				begin
				read_count<=read_count+1;
				if(read_count==Njobs*N-1)
					begin
					$display("pmk_dispatcher_daisy: transition to state 0");
					write_count<=0;
					mode<=0;
					empty<=1;
					//full<=0;
					end
				end
			end
	//	if(write_32_full)
	//		$display("Packer full");
	/*
		filler_reset <= (prev_last_status!=0 && out_status[N-1]==0);
		drainer_reset<= (prev_first_status!=2 && out_status[0]==2);
		if(filler_reset)
			$display("Filler reset signaled");
		if(drainer_reset)
			$display("Drainer reset signaled");
		prev_last_status<=out_status[N-1];
		prev_first_status<=out_status[0];
	*/
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
	wrfull);

	input	[31:0]  data;
	input	  rdclk;
	input	  rdreq;
	input	  wrclk;
	input	  wrreq;
	output	[31:0]  q;
	output	  rdempty;
	output	  wrfull;

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
				.aclr (),
				.eccstatus (),
				.rdfull (),
				.rdusedw (),
				.wrempty (),
				.wrusedw ());
	defparam
		dcfifo_component.intended_device_family = "Cyclone V",
		dcfifo_component.lpm_numwords = 8192,
		dcfifo_component.lpm_showahead = "OFF",
		dcfifo_component.lpm_type = "dcfifo",
		dcfifo_component.lpm_width = 32,
		dcfifo_component.lpm_widthu = 13,
		dcfifo_component.overflow_checking = "ON",
		dcfifo_component.rdsync_delaypipe = 5,
		dcfifo_component.underflow_checking = "ON",
		dcfifo_component.use_eab = "ON",
		dcfifo_component.wrsync_delaypipe = 5;
endmodule


module fifo_to_store(clk, read_empty, read_data, read_enable, write_full, write_data, write_enable);
	input clk;
	input read_empty;
	input [31:0] read_data;
	output read_enable;
	input write_full;
	output [31:0] write_data;
	output write_enable;
	
	reg pull_request=0;
	reg push_request=0;
	reg[31:0] word;
	reg word_valid=0;
	
	reg half_clock=0;
	assign read_enable=pull_request;
	assign write_enable=push_request;
	assign write_data=word;
	always @(posedge clk)
		begin
			word<=read_data;
			half_clock <= ~half_clock;	
			if(half_clock)
				begin
					pull_request<=!read_empty && !write_full;
					word_valid<=!read_empty && !write_full;
					push_request<=word_valid;					
				end
			else
				begin
					pull_request<=0;
					push_request<=0;
				end
		end
endmodule

//`define HALF_RATE

`ifdef HALF_RATE
module lookahead_to_store(clk, read_empty, read_data, read_enable, write_full, write_data, write_enable);
	input clk;
	input read_empty;
	input [31:0] read_data;
	output read_enable;
	input write_full;
	output [31:0] write_data;
	output write_enable;

	reg pull_request=0;
	reg push_request=0;
	reg[31:0] word;
	reg word_valid=0;

	reg half_clock=0;

	reg[31:0] write_count=0;
	assign read_enable=pull_request;
	assign write_enable=push_request;
	assign write_data=word;
	always @(posedge clk)
		begin
			half_clock <= ~half_clock;	
			if(half_clock)
				begin
					pull_request<=!read_empty && !write_full;
					word_valid<=!read_empty && !write_full;
					push_request<=!read_empty && !write_full;					
					word <= read_data;
					if(!read_empty && !write_full)
						begin
							write_count<=write_count+1;
//							if(write_count>=1275 && write_count<=1285)
//								$display("lookahead_to_store write %d %x", write_count, read_data);
						end
				end
			else
				begin
					push_request<=0;
					pull_request<=0;
				end
		end
endmodule

`else


/****
	(Case 1) lookahead empty
	(Case 2) lookahead just opened (read_empty==0 and pull_request==0) 
		2.1. store is full
		2.2. store is not full
	(Case 3) lookahead open and active
		3.1. store is full
		3.2. store is not full
	(Case 4) lookahead paused because store is full
	(Case 5) lookahead just signaled empty for the first time
****/
module lookahead_to_store(clk, read_empty, read_data, read_enable, write_full, write_data, write_enable);
	input clk;
	input read_empty;
	input [31:0] read_data;
	output read_enable;
	input write_full;
	output [31:0] write_data;
	output write_enable;

	reg pull_request=0;
	reg push_request=0;
	reg[31:0] word, word2;
	reg word_valid=0;
	reg[31:0] write_count=0;

	assign read_enable=pull_request;
	assign write_enable=push_request;
	assign write_data=word2;
	reg [3:0] status=0;

	always @(posedge clk)
	begin
//		begin
//			if((write_count>=1 && write_count<=20) || (write_count>=1020 && write_count<=1040 && write_count!=1024) || (write_count>=1275 && status!=0))
//					$display("%d %d empty=%d full=%d valid=%d wire=%x word=%x word2=%x", write_count, status, read_empty, write_full, word_valid, read_data, word, word2);
//		end

		if(status==0)
			if(!read_empty)
				begin
				status<=1;
				pull_request<=0;
				push_request<=0;
				end
			else
				begin
				pull_request<=0;
				push_request<=0;
				end
		else if(status==1)
			begin
			word2<=read_data;
			pull_request<=1;
			push_request<=0;
			//assert(pull_request==1);
			status<=2;
			end
		else if(status==2)
			begin
			if(!write_full && !read_empty)
				begin
				word2<=read_data;
				pull_request<=1;
				push_request<=1;
//				if(write_count<20  || (write_count>=1020 && write_count<=1040) || write_count>=1910)
//					$display("Writing %x", read_data);
				write_count <= write_count+1;
				end
			else if(read_empty)
				begin
				status<=4;
				word2<=read_data;
				pull_request<=1;
				push_request<=0;
				end
			else if(write_full && push_request) // by now the last write request has bounced and needs to be reissued
				begin
				status<=3;
				word<=read_data;
				write_count <= write_count-1;
				
				pull_request<=0;
				push_request<=0;
				end
			else if(write_full && !push_request)
				begin
				$display("Not sure what to do");
				status<=3;
				word<=read_data;
				write_count <= write_count-1;
				pull_request<=0;
				push_request<=0;
				end
			else
				begin
				pull_request<=0;
				push_request<=0;
				status<=0;
				end
			end
		else if(status==3)
			begin
			if(write_full)
				begin
				// word; v[k+1]
				// word2: v[k]
				// wire: v[k+2]
				pull_request<=0;
				push_request<=0;
				end
			else 
				begin
				pull_request<=0;
				push_request<=1;
//				word_valid<=0;
//				if(write_count<20  || (write_count>=1020 && write_count<=1040) || write_count>=1910)
//					$display("Writing %x", word2);
				write_count <= write_count+1;
				status<=5;
				end
			end
		else if(status==4)
			begin
				if(!write_full)
					begin
					push_request<=1;
					pull_request<=0;
//					word2<=read_data;
//					if(write_count<20  || (write_count>=1020 && write_count<=1040) || write_count>=1910)
//						$display("Writing %x", read_data);
					write_count <= write_count+1;
//					if(pull_request==0)
						status<=0;
				end
			end
		else if(status==5)
			begin
			// wire: v[k+1]
			// word: v[k]
				if(!read_empty && !write_full)
					begin
					word2<=word;
					pull_request<=1;
					push_request<=1;
					status<=2;
//					if(write_count<20  || (write_count>=1020 && write_count<=1040) || write_count>=1910)
//						$display("Writing %x", read_data);
					write_count <= write_count+1;
					end
				else if(read_empty && !write_full)
					begin
					word2<=word;
					status<=4;
					end
				else if(read_empty && write_full)
					status<=0;
			end
	end
endmodule

`endif

module pmk_dispatcher_dualclock(core_clk, bus_clk, read_32_rden,
	read_32_empty, read_32_data,
	write_32_wren, write_32_full, write_32_data);
	input core_clk, bus_clk;
	input read_32_rden;
	output read_32_empty;
	output [31:0] read_32_data;
	input write_32_wren;
	output write_32_full;
	input [31:0] write_32_data;	
	parameter N=2;
	parameter Njobs=100;
	parameter Niter=4096;

	wire core_input_empty;
	wire dispatcher_full, dispatcher_empty;
	wire f2c_full, c2f_empty;
/*		
	wire f2c_request;
	assign f2c_request = !f2c_full && !dispatcher_empty;
	
	wire c2f_request;	
	assign c2f_request = !c2f_empty && !dispatcher_full;
	
	reg c2f_pull_request=0;
	reg c2f_push_request=0;
	reg[31:0] c2f_word;
	wire[31:0] c2f_wire;
	reg c2f_word_valid=0;
	
	reg[31:0] timer=0, pull_counter=0;
	reg half_clock=0;
	wire f2c_pull_request, f2c_push_request;
	always @(posedge core_clk)
		begin
			half_clock <= ~half_clock;	
			if(half_clock)
				begin
					c2f_pull_request<=!c2f_empty && !dispatcher_full;
					c2f_word_valid<=!c2f_empty && !dispatcher_full;
					c2f_push_request<=c2f_word_valid;					
				end
			else
				begin
					c2f_push_request<=0;
					c2f_pull_request<=0;
				end
		end
		*/
	always @(posedge bus_clk)
		begin
			if(write_32_wren && write_32_full)
				$display("ERROR: writing into full c2f fifo");
			if(read_32_rden && read_32_empty)
				$display("ERROR: reading from empty f2c fifo");
		end
	wire[31:0] core_input_data;
	wire[31:0] core_return_data, core_return_data2;
	wire[31:0] c2f_data_out, c2f_data_in;
	wire c2f_pull_request, c2f_push_request, f2c_pull_request, f2c_push_request;
	
	fifo_to_store regc2f(core_clk, c2f_empty, c2f_data_out, c2f_pull_request,
		dispatcher_full, c2f_data_in, c2f_push_request);
	
	lookahead_to_store regf2c(core_clk, dispatcher_empty, core_return_data, f2c_pull_request,
		f2c_full, core_return_data2, f2c_push_request);
	
	myfifo cpu_to_fpga_crosser(
		write_32_data,   // pcie data incoming into fifo (bus_clk)
		core_clk,
		//c2f_request, 	// core request to pull one word from fifo into fpga (clkintop_p)
		c2f_pull_request,
		bus_clk,
		write_32_wren,	// pcie request to push one word into fifo (bus_clk)
		//core_input_data,			// data coming out of fifo into core (clkintop_p)
		c2f_data_out,
		c2f_empty,			// fifo signaling the core that it's empty (clkintop_p)
		write_32_full);  // fifo signaling pcie that it's full (bus_clk)
		
/*
	input read_empty;
	input [31:0] read_data;
	output read_enable;
	input write_full;
	output [31:0] write_data;
	output write_enable;
*/

	myfifo fpga_to_cpu_crosser(
		core_return_data2,
		bus_clk,
		read_32_rden,
		core_clk,
		f2c_push_request,
		read_32_data,
		read_32_empty,
		f2c_full);

	pmk_dispatcher_daisy #(N, Njobs, Niter, 1) disp(core_clk, 
		f2c_pull_request,
		dispatcher_empty, 
		core_return_data,
		//c2f_request,
		c2f_push_request,
		dispatcher_full, 
		//core_input_data
		c2f_data_in
		);

endmodule


`timescale 1 ns / 1 ns
module sha1_tb;
	reg clk;
	reg [31:0] counter;
	reg [159:0] ctx, data, out_ctx, expect_ctx_0, expect_ctx_1, expect_ctx_2;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	ctx = 	0;//		160'h3141592689134205834965352a06585346c45230;
	data = 	0;//		160'h9305823cdcdbfac3ed5342790158340985634986;
	expect_ctx_0 = 160'h1b6b263594af1e2cef6d7bb40f46529e885669bf;
	expect_ctx_1 = 160'hee249bc3dfb613cb7384e2c6226b184320f9aca3;
	expect_ctx_2 = 160'h1b7aba12f27e45604d1f89ac7ee643f2bf7bb5ea;
end

SHA1_5x5_bare sha(clk, counter[6:0], ctx, data, out_ctx);

always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
	
	if(clk)
	begin
	
		if((counter&32'h7F)==32'h40)
			begin
				ctx <= 160'h0123456789abcdef0123456789abcdef01234567;
				data <= 160'h23456789abcdef0123456789abcdef0123456789;
				//$display("%x %x", out_ctx[31:0], expect_ctx_0[31:0]);
				//assert(out_ctx==expect_ctx_0);
			end
		else if((counter&32'h7F)==32'h6f)
			begin
				ctx <= 0;
				data <= 0;
				//$display("%x %x", out_ctx[31:0], expect_ctx_0[31:0]);
				//assert(out_ctx==expect_ctx_0);
			end
		else if((counter&32'h7f)==23)
			begin	
				ctx <= 160'h3141592689134205834965352a06585346c45230;
				data <=	160'h9305823cdcdbfac3ed5342790158340985634986;
			end
		//if(counter>250 && counter<400)
/*		
		if(counter==200)
			begin	
				ctx <= 160'h3141592689134205834965352a06585346c45230;
				data <=	160'h9305823cdcdbfac3ed5342790158340985634986;
			end
*/	
		if(counter>=90 && counter<1000)
			begin
				if(!((out_ctx==expect_ctx_0)||(out_ctx==expect_ctx_1)||(out_ctx==expect_ctx_2)))
					$display("corrupted at %d", counter);
				if(counter==100 || counter==200 || counter==300)
					begin
					//$display("%d %x %x", counter, sha.xbuf2[counter[5:0]][31:0], out_ctx[31:0]);
					if(out_ctx==expect_ctx_0)
						$display("ctx_0 at %d: %x", counter, out_ctx);
					else if(out_ctx==expect_ctx_1)
						$display("ctx_1 at %d", counter);
					else if(out_ctx==expect_ctx_2)
						$display("ctx_2 at %d", counter);
					else
						$display("corrupted at %d: %x", counter, out_ctx);						
					end
			end
			/*
		if(counter==400)
			begin
				$display("%x %x", out_ctx[31:0], expect_ctx_1[31:0]);
				assert(out_ctx==expect_ctx_1);
			end
*/
	end
end
endmodule

//`define TEST_BENCHES
`ifdef TEST_BENCHES

reg[159:0] new_test_data[0:255]={
160'h97e0e035c42a685f8b58f2b6b12069080a4a3e14,
160'hd370280a96fb43b346575fc19d82a52d54f50f2c,
160'h317d86643c3aa60174f911f44b2327487af43ae7,
160'h70881790b5125b129ee0d90bfa4a744f193bf0ae,
160'h70c9be1fe1b3853ef6646e9be9a6284854debf75,
160'hb411164d982cade9fcd0c9cac8b1a35b4c10e951,
160'hc860ff6a67f8b2e685bbadd370f7a6f8a31fc5c4,
160'h5f0ca92caa1218447152934bacffc3904b875c2b,
160'hd7cbdf09c829d06fd0de0d908e9f96bfb60c8646,
160'hf89ce19dc2a1f5aa5f2ccf961e2dec29d2640143,
160'hbd59fe61ffb2a5137fa86c75bdf04b6adf176a74,
160'ha3fd167c8f457575da2076385245741a6d4b77fb,
160'h551219396fd411235d582dd9aef7afd82309c658,
160'h50a63a9d1c60d9dc5da228f18096cdc720dfd9e2,
160'h8c8ef0ea7eeecb724c2e6363ca35dee6df48dc2e,
160'h18cd92f7ef731e83e41830e469f8e406637babbd,
160'he5a9598ecc88b688e3f8a24fdcd634ce12f50e0b,
160'hcccd53f53503593d1235f2500bd2a37edd95130f,
160'hc935ec2e0e76991900225bc88b11ce2076f4337c,
160'h8a86eaf49c4ca61745185d8a800d0c069f21a7ad,
160'hb86cc45b9043f42b130b31f5a3c96d6646d23a07,
160'h1c4c92dc652128dc8d731c1cf0691ebb1e3ea267,
160'hbc8917317e6935790dbd9bd65360215804d6028d,
160'h63de2b877cfb69d3d8c770ad18a85e10ebfc699d,
160'h89b15378650927227fd38e45ba5e98385e456776,
160'h21db69710ab8cec1856c9d644f9f38a82d1a05bd,
160'hfbfec327659dd66850483f02ccfb14569dda0c5a,
160'h5680e6770a18a2778407c5dda80c35596bb9a619,
160'h00347657e72ac2596de2ff4be77fd7509941eac0,
160'h237fb0385b7bb8ac19a106bc45808a2839ebe447,
160'h6c51844be1d422b0bffeb20059265c3d1c860484,
160'h9374833d23337f95196f000fa8ba6ff4d04f5b9f,
160'h26fbfe98ffc8c05d2422f4296e46f3b097bfc1e9,
160'h93e69afaceb55f3dce2de2faf7021222d25aff55,
160'hb65d42c4908eb1ea38420fb24ffa1aa91f14f0c1,
160'h32a1cdfc13221241bc6447ee8225638a59e75d92,
160'he6e7fe3bf8574b2768f433d280175d3bec9b69b2,
160'he95076bbc0f946e31bc2fb1564cdc830004bbb2b,
160'h57cf7f505ef2709ac4fcd2393850f0bc2f95b6d9,
160'h9d43a909ad46017c341a6703a5797eb01880e54a,
160'h0189e34e66c5674ea591d2c1ef61c88fcce74493,
160'h4757362eb0aa53a0f5b16815ef2680473d636785,
160'hcc46a189a1eb988003460616d1d15d14de8a9d8a,
160'h47739ca55a38f6e3054687ce1cf223fea7a82ee6,
160'hea69de3fbf04c8355ec9cf6d972dc27c121a3738,
160'h21994182b58202d9f7c59c69c6166f5a617eca15,
160'ha401d6b3543edfb51b37ff68ad61bd99591e6479,
160'h5bdf586324fd89239f8abd41a89afbfdd35e7284,
160'h56ba7e6b592eaff3507bc083d76789e6b269eb9f,
160'h511a88700e6d14960551a8a692241b744773f03c,
160'h8cd1a01098ecdf1307b63dc75caf8e3651cef2cd,
160'h59ab1272fba41bacaccbee83edbf357820ffe8a7,
160'h24c4ffe3ce9918c8229e29c345c77475b91d808f,
160'h5b3bb3cf598acfb7d287630101e25ffccc863919,
160'hbcd7e1fbe6538b4e04dd409c880819ed65bd102e,
160'h3b235cefa37f54fce1dc25b9203e164aa3c518e3,
160'h1f67d52ae258df91fe53f6988cdc0db9d2e9e256,
160'ha884db921644e7d1c85f5868c2ca03adf61ae49f,
160'h02564bf95bafdd82cb7ccc6bdaf0baf231848a2c,
160'he5fd2b633120ede29f20d39e7725c26258fba6f3,
160'h32a1c09726f7adb5694aaf900c8a297652563501,
160'hf4ccbe10c7287dcdae6d6723d16bd103c6689c63,
160'h5d073a75f1a3046a85fc0f595feeffd9923244c6,
160'h83a1a2bce7f0df3e41722e904e7be415b76de09a,
160'h673a3bc955f60af75700f07bc91632145d945d2b,
160'h80f19fb52f316436870d69fe5688ff51e4215162,
160'he58223681c6bfa70db290580dba9fb4937556ee0,
160'he509d3e7d9e5551b6a1814dd3b348ead0d0dc640,
160'h663305527c766c7f3c43a933759ff910eece411c,
160'hfc093d81900840ecc49db8cee3c62137df40e731,
160'hc5a010457d2a593dc3084d040769874ae447b24b,
160'h8bc5825cf236cb3788516da80ae5ad61f69795ff,
160'hb315164d7b55b5a448dcd02e13d3ddd96fc48755,
160'h34acb3b1d99f6f7378b8612548ca307e3c99e34e,
160'hb9f8e05fe25d62f6b34811bd58cdbf6437a202a9,
160'hf1b38e0c0ef4cb0221cee0396279534017ba8589,
160'hea8b5e3c935d9a17074771fcdb673c0bbda2686e,
160'h40301978735cb2663ff2f4e809344be4e0e2f4ae,
160'h954cac96c7532dccaec349cc6a290cb236cf535b,
160'h0f2ee30d1b22b95c76bc911688b5a827d5c73086,
160'h274422ae3ab604d665ecdf62b0bfb820e881ff1c,
160'hc39d02fdc8dca812b5dbf8f3ec39d1c664ead5ad,
160'h46c194730abf74761ba68e1759429dd5a660595c,
160'hb7b322202fdedc822d0debf910e115592b903785,
160'h25dabfb3d29aeca4748df29c7629efa11e561880,
160'hf07ac3ab4680ea65167ea3d551abaa8545d2a026,
160'h300f89b5d13d520e70933a45067fbede8ac7677b,
160'h27f33cee9199b9da0111e2df4262a2e869a34056,
160'h6e804cb79449df7134b80aa378416a504c366656,
160'hf36b4aa2cc3c42c9fbfd96c1bab25bfbc2cbf7c5,
160'h5624b39058db5955aaecec7e418523e803223f73,
160'h93b9d0459070d226e6b653fdee235dd8ac7ca4f3,
160'hd78e735d004d9d1e04732da3d9d5f844196f826f,
160'h1f60a980ae86185ad1627877a7e3c3563c2d48e6,
160'h8824f63b369864089ecb5fb2c2d79dcad9a57956,
160'h133ad40e3ab58d01d2cf557c13a4e695b523819e,
160'hd4942f09f368533d6c954d7fb14e217cd6ac50de,
160'hdf52730f3a2bf4e573c82320a57e7c83ecd161f2,
160'h4afb70b03d1b90c671e51bd9d0f41b0c9df79b4e,
160'heb935cb1a4f2641ac9f80c50a5f7ebeba3a58aa3,
160'hd69942eeefd00835bee43000fc874f5eeb4b1ed0,
160'h83da5eb060a26df5a2a6fd5c6ec07acda66b53e7,
160'h7dcde41c32776b26b4af444aa43dce3f7dca7e02,
160'hc079e525070d38b3003b83986efc36234d056ed3,
160'h15ca8391b05cb879fd570d01cb97a902a7bccd8a,
160'h18fdc34fa3e116f93b7568b7c27d43bafb316e9b,
160'hd04172d7ce6b1a9a3b18af1ebf32666cff1f1968,
160'hb76ec1f96f945100c746f5b6c7ffb75375fe6015,
160'he6ccdfc9724893eb3d80b8e6723a7f489bd37e7d,
160'h2c7ae526c7d0b9c88feb39f3044ad3b2939f93b3,
160'h47a69ec304ab1ae88ca94cc50ebbf2e6741f276d,
160'h523cbac8b422a9ea01cfa21057dfcc35e88c10fc,
160'hd6eb4c328378c0723aaf6933bf8a98262f9756a1,
160'h1a009ce82306ba32592314770fb3d7e7d54cdd53,
160'h77f030292c466200de435ed885e22e7cf13a61cb,
160'heebb73c210a440cebab2f7a805b97fb6653f71ba,
160'h1426386f5caa168ea42c2b8f34f3d818e366eaa6,
160'h1b859197dc0d9cd9c912ed017cc554ac240f5a1e,
160'h9389d48769b3ae6bfdf0d050e3abf3e9e662a2db,
160'h706fb40c91691ad77f69820302515c0b8e3032ca,
160'hf2338fb5155eb1ddb8b1d7c150542d077a4a5df5,
160'h50c84d09d05db24d2dbbc3bc3734b6a740861d3d,
160'hdc0d77aa735deab63c84650bcd9799aa940a13b5,
160'h0042cec00a64cc41891d2c9e56ac7ff281db1edc,
160'hd1a96406ddefc8ee96a79dfbbaaa02e19f89d917,
160'h8da6a0a8873b24067bcb6f59a7104925f962d515,
160'h06bb22418fb38974732c7ef45d214d2bbe8c741a,
160'hb637434e21de558763a3574ee99cc09a90f35c81,
160'h25ad3c943fe48846293837f8e24d52367f262e3b,
160'h0bab6e3a820f9d4273a9859082b373058fe0196d,
160'he4fe1300940f095b91c285966b2e09c567519fb3,
160'h5b87c0af8f91b0d35c09dc1d946b61532d32f1fd,
160'he27c8040e3c3a77c9395494dd65b9646a49a5808,
160'h74de754d6655a3d61940725d797110a466f584dc,
160'hebedfb32a0c2bf101defe84a48315f53f930138f,
160'h4a51e4430176c8f01b257cbb975f44dfbe1ba1ff,
160'h45c0bb8dd5bd2b99cdd6f4d1400ddb2e3f8f6a65,
160'he0b3ea3660da7e6e09413da84089a5d5bed34e2a,
160'h324757728b1ee09f71fccaedb24e7b4966c31dac,
160'h26d5a483ba6e40cf9c62469436bf9df0386dd573,
160'h41c984581cb7425e57a30d77fd6182d5c3a84b2e,
160'h93ec47fe69b33c3df458566f084d649edcd9c576,
160'hd68c5485d30e85b41d166d8aec2f29953d63db14,
160'h7f4e58e76c81c2bb1ba54f61907eb52a90397b92,
160'h891d85d0647338627ebcaab27a4b80269cc1e05c,
160'h0666d7edce16b8b8bc4f1fdf3bc9555bf4dadbbf,
160'h1e1285d0b656b2d9a59ec9f2d50202fb1908b442,
160'h3f207534d6377fe83a8a5d8907de896a41afae9b,
160'h6fb082d1aeba9f4cf8a585af83b18155f15f8c38,
160'h0614b1fa68f19123aa9517af8911bd8d92304f4a,
160'hb81c700f5b055a71294b326c3b7ef9fdd8ebffdc,
160'h2acfc48c5b80fe7bbf2d7fd3d1212d9abae55b5b,
160'hfc952901d0a51177ec29b3687cb1a35e902ab60d,
160'h2224ab86a3069f70657339f4826d2c2438f37bbb,
160'h14398c4e42b11b308bb12780fc0007e095c30488,
160'h6a2538de18e9a6020600f3d25c4482134a62fc68,
160'hdd5a61d3b7a59be54deb343500e5292f84a5e871,
160'ha660bc90ffee277e6138911b2ddb3d7f55d999fd,
160'ha6d85c144cdedb917af3b4e57a441630ccaecdc9,
160'ha13819399416e60a43254acfecbca58a8845acdc,
160'h0730ea690439602c1c57defb65dd321c295fe395,
160'h128fb605ea2f28ed4e57be866081fc39bf3fde02,
160'h7b384539e1b148ff6ff4821eadac96a6725f3950,
160'hab5eb0acdc99985dc5e95a2e3d9e5a2dac8d0c09,
160'h2f00c5f66b9f833b743f5793fa945f2c79fea2b1,
160'h570ea67bf910d449f646b500e8bfd9587cc0fac6,
160'h688de762cacaaeb1d69e725aa9df99fdf5d908dc,
160'h8d0a4d2d07553258fdd6859f5ec99762076aa289,
160'h236c173d4681c709dbe0f9881b1e990f647b65f0,
160'hed8c559eb7bb78f66cf90b397c15aabfd0a5d38e,
160'h0a379a8dfb4da9a7c913f925f917f0edbcb578da,
160'hbd6da178015fdbfbf25d12a1dda0b0c3be443f06,
160'ha255fd9a5930d4a2272bbeca8c63f9ea6b1da7b2,
160'hfb9090caafca8c6d4110cc01842db1a4a1fbfb5b,
160'h91a6fb69c8ae9d39c4ad1e0596eb208b3d4272d4,
160'h0cb349ae5021bc1725a615d737daae8a031fb453,
160'h30bf87cd4701d8b9cb036845a4fc14313500ef5d,
160'h76cb7ef170a8d65826d293ccc0b73acf74907dc5,
160'h0e328364a5310d9c89b034f6456554fc50f37ea1,
160'h46c65b8c7172a4e17ca3a203d4da2bcc9d9a3177,
160'h63601ee855190b39df68db2b34273c1e194ac643,
160'h0a47d738e5e987096245af7b65657398a7465491,
160'h9f48f0e98ff498b59d935ceabc0600c3740d290c,
160'h8f445c05abf369b2271af633a0960d2665a02845,
160'hcf192a2aefed57979975a50e9622bb22c50eda07,
160'h1ecb2b6c3562c375f0e4d598a86fe32fade570a8,
160'h0e6dd5bce3c7d02ce4a4912ba13424974aedf651,
160'h0ae355e3f2aff71715c98db398be0ba03974c0c4,
160'he893695ee9da78728fdc2ee77567738cbd6ddcf1,
160'h96123d597b055ae4f7c935313141297d62ed4312,
160'hfcdfcec374f7b2ac3ddfef1c92431425dff97622,
160'h9b08645a49d2cf3ea2ff1b3d8df7029d4a2e1f03,
160'he17116a84b4d7af96c8a2ae17a1d9aae60135808,
160'he77ef67750b677d364f1d46b0bba294c36f4dc65,
160'h3b8808c9b842f67e87fd6d68e15f44068ea1a7f0,
160'ha8d4d365aee8b4d4dfcdca144547fc1abc1b7d99,
160'hcdd339e321b3149c2da6f5c706c90e6bb5a78e00,
160'hfcb1f981019aa82687d4b8baa48081ea13993928,
160'heaa55f215bc9b8778ac141540af524810d5270f2,
160'hbf8747e8dd1e48fb42d977ef2274cfe3953f0d6e,
160'h5569f0286fcb17de77cecbebda2b75a7bc3a0a23,
160'hba24c799570aa9d417ea34ef8525e4323165f80c,
160'ha5d2cc8cc175d995a59539df11d7237d45b463d1,
160'h30978a2c85e65aa7b37d0250745bc0614fa100f0,
160'h0f91c69dd4705d82b1d8e6c42f4a553ee932170e,
160'hd98730924bce90488a2d73ca0f1ae71df93ea4e2,
160'h168ffd6d1f32281898d638d042e54649ec3b205b,
160'h1b56dfccd933859b0086af38d110aaa2e5d2d6ed,
160'hc0032f82d25b8a115f366ccf6f7884e4922177bb,
160'h7eb4ac6789013067d4b6efb051183b1866fa2872,
160'h6588f55e396ae59c7af587586bde9344cacac5bb,
160'h8fb1dcfb48104e0ef70137db8ba5a127b6f98e24,
160'h1f2f37eefc6406cf278be005c766870d322e1fbc,
160'hffa6303a2ff0c33daf1a5c8aac60296faf230baa,
160'hfaee0f625b2adec1aecf109a98a7e763019b73a9,
160'hb0d9bb6b6e50fae41d20ff6c7ca52baa98d3dce1,
160'hf4b9f5e956763fba62d0cf8f4ec8f28bf7e76143,
160'h18870966c48dbda875d4eb9fb146567f112d85b8,
160'h7da9f2b45be077017b2f4c79e514a1dbc906381a,
160'hfdd489194c9d727b6c8aa781b77d9ea0645e0aac,
160'h946a7be112edf5d022536ac0e833cb837a14cf8a,
160'hb3e559953857533a9fa6f53daa2e709190296288,
160'h965b572f0953d892c94ba5ed7bde8b054da1b558,
160'h82405da1c5589b3ef5f3dcc64f0e7a9178678f22,
160'h30071521d662276331d2b4b8b1f160a738e7c10e,
160'h3f86456dc73bcee1eec2db2ea390a3278cb788b6,
160'hf7a5dbdeab77d907327b6829a1ce6db92a995c72,
160'hde765e8bc11ba276807c1fa6fa6e5ff4148868eb,
160'h8111d9bae0792854a4aa73eaf493be682b57299f,
160'h085b180d91c7d7d6880f3735954fc3f3d8b6c27f,
160'h6fbb7871e1c7741383093cbbb9c3756a6639f293,
160'hfa2fe02e1481c9d0ac68594417726eb39b5d6be8,
160'ha6190374d8fddf04829fda1b26b5ec17dff84f4e,
160'h10451421c811111dfea2c046121253c22f6ed1b4,
160'h19676cdbd8cc075840ba75dd8991ac67cfb4f426,
160'h04fafbc12f65c1d13d4d9cfe1edc3aade07b94c1,
160'h1963a4b037ce27989e15ac9aedfdb4ae9b87d9de,
160'h96cd4cc480235c466b3cb4b89e011e735bdb41ed,
160'hbbf5da2234926be68a1fb9992d56f4423385f6a0,
160'h6c1af28b2c13049bffd3566d5b97307801fb5f2a,
160'h31c7579fea39a0404a4b6008683e6f7bcdf4c75a,
160'hfb41b5187846584b4298b9b79c4f1e8bddb5ec46,
160'h213b2ddd40a786a4f86935cae96a6ca388c5c128,
160'h1137bbed5b573f0a35e1fcf53617a31efc242d60,
160'ha6ffbdc2a99521a38f1f94fffc0629ccbc1545a3,
160'hdc1c0ae6a22528f08d8b3ba7cc54d35a733ddfe2,
160'h8aa82546c31f242e16b5412ee8d0587cbc2c1957,
160'ha3bb58224d5638f56896afd5a9b19d954a784bfa,
160'h845ab18b9bbab42ca6a874cd2ab9550b10141ca3,
160'hfd4450825b57781945d62be26afe11ba0789a374,
160'hcc88a13f3e9718982a16db66abf989f76def7552,
160'h95cd15506a1baa6ce80b815a287b2034531bdd9c,
160'h64f79d4d1a89c8f8983dad3ef6f3f1d50b693ec3,
160'he4e49477de7757c888a89330eb615e7c27f674d1,
160'h06b3025a5b143ba38b1ddf53519009ea710d25b5,
160'h65ca00f436905c89dda6f65e62ebc5c9972323fb
};

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
	//pmk_dispatcher	
	pmk_dispatcher_daisy 
		#(N, Njobs, Niter, 1) disp(clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data);


	reg[31:0] pads[30*Njobs*N-1:0];
	reg[31:0] expect_data[2*5*Njobs*N-1:0];
	reg[31:0] recv_data[5*Njobs*N-1:0];
	reg[31:0] I, J, K, M;
	reg[31:0] recv_count=0;
	testcase src;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	for(M=0; M<2; M=M+1)
	for(J=0; J<N; J=J+1)
		for(K=0; K<Njobs; K=K+1)
			begin
			if(M==0)
				begin
				src.ipad={32'h0,M,J,K,32'h0};
				src.opad={32'h1,M,J,K,32'h1};
				src.data={32'h2,M,J,K,32'h2};
				src.expect_acc_10=new_test_data[J*128+K];
				end
			else
				src=testcases[(K+J*Njobs)%7];
			for(I=0; I<5; I=I+1)
				begin
				pads[(M*N+J)*15*Njobs+K*5+I] <= src.ipad[I*32+:32];
				pads[(M*N+J)*15*Njobs+K*5+I+5*Njobs] <= src.opad[I*32+:32];
				pads[(M*N+J)*15*Njobs+K*5+I+10*Njobs] <= src.data[I*32+:32];
				expect_data[(M*N+J)*5*Njobs+K*5+I] <= src.expect_acc_10[I*32+:32];
				end
			end
end
	
	wire[31:0] first_write, first_read, second_write, second_read, work_time;
	assign first_write=0;
	assign work_time=2*Njobs*Niter+200;
	// assumes 10 iterations only (with 4096, takes something like 30 min for ModelSim to complete the run)
	assign first_read=15*Njobs*N+work_time;
	assign second_write=30*Njobs*N+work_time+200;
	assign second_read=45*Njobs*N+2*work_time+200;
always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
end
reg[31:0] write_count=0;
reg[31:0] first_read_count=0;

reg[31:0] deltas[7:0]={1,2,3,2,1,2,1,3};
reg[31:0] next_read=15*Njobs*N+2*Njobs*Niter+200;
reg[31:0] expect_idx, observe_idx;
reg read_32_rden_prev=0;
always @(posedge clk)
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
			if(counter>=first_read && first_read_count<5*Njobs*N && counter<first_read+15*Njobs*N)
					begin
					read_32_rden<=(counter==next_read);					
					if(counter==next_read)
						begin
				//		$display("%d %d", counter, next_read);
						next_read<=counter+deltas[write_count&7];
						write_count<=write_count+1;
						end
					if(read_32_rden)
						begin						
						recv_data[first_read_count]<=read_32_data;
						first_read_count<=first_read_count+1;
						end
					end			
			else if(counter==first_read+15*Njobs*N+100)
				begin
				$display("First read done");
				if(first_read_count<5*Njobs*N)
					$display("Error: only %d / %d words received", first_read_count, 5*Njobs*N);
				read_32_rden<=0;
				assert(recv_data==expect_data[5*N*Njobs-1:0]);
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif				
						if(recv_data[J*5*Njobs+K*5+:5]!=expect_data[J*5*Njobs+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								for(I=0; I<256; I=I+1)
									if(160'(expect_data[J*5*Njobs+K*5+:5])==new_test_data[I])
										expect_idx=I+1;
								for(I=0; I<256; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==new_test_data[I])
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[J*5*Njobs+K*5+:5]), 160'(recv_data[J*5*Njobs+K*5+:5]));
							end
//						for(I=0; I<5; I=I+1)
//							if(recv_data[J*5*Njobs+K*5+I]!=expect_data[J*5*Njobs+K*5+I])
//								$display("Mismatch at instance %d job %d dword %d (expect %x, observe %x)", J, K, I,
//									expect_data[J*5*Njobs+K*5+I], recv_data[J*5*Njobs+K*5+I]);
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
				assert(recv_data==expect_data[2*5*N*Njobs-1:5*N*Njobs]);
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif								
						if(recv_data[J*5*Njobs+K*5+:5]!=expect_data[(J+N)*5*Njobs+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								
								for(I=0; I<7; I=I+1)
									if(160'(expect_data[(J+N)*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										expect_idx=I+1;
								for(I=0; I<7; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[(J+N)*5*Njobs+K*5+:5]), 160'(recv_data[J*5*Njobs+K*5+:5]));
							
								/*
								for(I=0; I<256; I=I+1)								
									if(160'(expect_data[(J+N)*5*Njobs+K*5+:5])==new_test_data[I])
										expect_idx=I+1;
								for(I=0; I<256; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==new_test_data[I])
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[(J+N)*5*Njobs+K*5+:5]), 160'(recv_data[(J+N)*5*Njobs+K*5+:5]));
								*/
							end
//						for(I=0; I<5; I=I+1)
//							if(recv_data[J*5*Njobs+K*5+I]!=expect_data[J*5*Njobs+K*5+I])
//								$display("Mismatch at instance %d job %d dword %d (expect %x, observe %x)", J, K, I,
//									expect_data[J*5*Njobs+K*5+I], recv_data[J*5*Njobs+K*5+I]);
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
endmodule


// test bench for pmk_dispatcher
`timescale 1 ns / 1 ns
module pmk_calc_32_tb_2;

	reg clk;
	reg [31:0] counter;
	wire [7:0] out;
	wire read_32_empty;
	reg read_32_rden=0;
	wire [31:0] read_32_data;
	wire write_32_full;
	reg write_32_wren=0;
	reg [31:0] write_32_data;
	parameter N=10;
	parameter Njobs=240;
	parameter Niter=10;
	pmk_dispatcher #(N, Njobs, Niter, 1) disp(clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data);


	reg[31:0] pads[30*Njobs*N-1:0];
	reg[31:0] recv_data[15*Njobs*N-1:0];
	reg[31:0] I, J, K, M;
	reg[31:0] recv_count=0;
	testcase src;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	for(M=0; M<2; M=M+1)
	for(J=0; J<N; J=J+1)
		for(K=0; K<Njobs; K=K+1)
			begin
			if(M==0)
				src=testcases[(K+J*Njobs)%7];
			else
				src=testcases[(K+(J+1)*Njobs+1)%7];
			for(I=0; I<5; I=I+1)
				begin
				pads[(M*N+J)*15*Njobs+K*5+I] <= {M[7:0],J[7:0],K[7:0],I[3:0],4'h0};
				pads[(M*N+J)*15*Njobs+K*5+I+5*Njobs] <= {M[7:0],J[7:0],K[7:0],I[3:0],4'h1};
				pads[(M*N+J)*15*Njobs+K*5+I+10*Njobs] <= {M[7:0],J[7:0],K[7:0],I[3:0],4'h2};
				end
			end
end
	
	wire[31:0] first_write, first_read, second_write, second_read, work_time;
	assign first_write=0;
	assign work_time=2*Njobs*Niter+200;
	// assumes 10 iterations only (with 4096, takes something like 30 min for ModelSim to complete the run)
	assign first_read=15*Njobs*N+work_time;
	assign second_write=40*Njobs*N+work_time+200;
	assign second_read=65*Njobs*N+2*work_time+200;
always #1 
begin
	clk<=~clk;
	counter<=counter+clk;
end
reg[31:0] write_count=0;
reg[31:0] first_read_count=0, second_read_count=0;

reg[31:0] deltas[7:0]={1,2,1,2,3,2,1,1};
reg[31:0] next_read=15*Njobs*N+2*Njobs*Niter+200;
reg[31:0] expect_idx, observe_idx;
reg read_32_rden_prev=0;
reg[31:0] error_count=0;
always @(posedge clk)
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
			if(counter>=first_read && first_read_count<15*Njobs*N && counter<first_read+30*Njobs*N)
					begin
					read_32_rden<=(counter==next_read);					
					if(counter==next_read)
						begin
				//		$display("%d %d", counter, next_read);
						next_read<=counter+deltas[write_count&7];
						write_count<=write_count+1;
						end
					if(read_32_rden)
						begin						
						recv_data[first_read_count]<=read_32_data;
						first_read_count<=first_read_count+1;
						end
					end			
			else if(counter==first_read+30*Njobs*N+100)
				begin
				$display("First read done");
				if(first_read_count<15*Njobs*N)
					$display("Error: only %d / %d words received", first_read_count, 15*Njobs*N);
				read_32_rden<=0;
				assert(recv_data==pads[15*N*Njobs-1:0]);
				for(J=0; J<15*N*Njobs; J=J+1)
					if(recv_data[J]!=pads[J])
						begin
						$display("%x %x %x", J, recv_data[J], pads[J]);
						error_count=error_count+1;
						end
				$display("%d errors", error_count);
				next_read<=second_read;
				/*
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif				
						if(recv_data[J*5*Njobs+K*5+:5]!=expect_data[J*5*Njobs+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								for(I=0; I<7; I=I+1)
									if(160'(expect_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										expect_idx=I+1;
								for(I=0; I<7; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect v[%d], observe %x)", J, K, testcases[expect_idx-1].expect_acc_10, 160'(recv_data[J*5*Njobs+K*5+:5]));
							end
//						for(I=0; I<5; I=I+1)
//							if(recv_data[J*5*Njobs+K*5+I]!=expect_data[J*5*Njobs+K*5+I])
//								$display("Mismatch at instance %d job %d dword %d (expect %x, observe %x)", J, K, I,
//									expect_data[J*5*Njobs+K*5+I], recv_data[J*5*Njobs+K*5+I]);
						end
					*/
				end
			else if(counter>=second_read && second_read_count<15*Njobs*N && counter<=second_read+30*Njobs*N)
					begin
					read_32_rden<=(counter==next_read);					
					if(counter==next_read)
						begin
				//		$display("%d %d", counter, next_read);
						next_read<=counter+deltas[write_count&7];
						write_count<=write_count+1;
						end
					if(read_32_rden)
						begin						
						recv_data[second_read_count]<=read_32_data;
						second_read_count<=second_read_count+1;
						end
					end			
			else if(counter==second_read+30*Njobs*N+100)
				begin
				read_32_rden<=0;
				$display("Second read done");
				if(second_read_count<15*Njobs*N)
					$display("Error: only %d / %d words received", second_read_count, 15*Njobs*N);
				read_32_rden<=0;
				error_count=0;
				assert(recv_data==pads[30*N*Njobs-1:15*N*Njobs]);
				for(J=0; J<15*N*Njobs; J=J+1)
					if(recv_data[J]!=pads[J+15*N*Njobs])
						begin
						$display("%x %x %x", J, recv_data[J], pads[J+15*N*Njobs]);
						error_count=error_count+1;
						end
				$display("%d errors", error_count);
				end
			else if(counter==second_read+30*Njobs*N+200)
				begin
				$display("Finished!");
				read_32_rden<=0;
				end
			else
				read_32_rden<=0;
end
endmodule


// test bench for pmk_dispatcher
`timescale 1 ns / 1 ns
module pmk_calc_32_dualclock_tb;

	wire [7:0] out;
	wire read_32_empty;
	reg read_32_rden=0;
	wire [31:0] read_32_data;
	wire write_32_full;
	reg write_32_wren=0;
	reg [31:0] write_32_data;
	
	reg clk;
	reg [31:0] counter;

	reg bus_clk;
	reg [31:0] bus_counter;
	
//	assign bus_clk=counter[0];
//	assign bus_counter=counter[31:1];
	
	parameter N=2;
	parameter Njobs=128;
	parameter Niter=10;
	pmk_dispatcher_dualclock #(N, Njobs, Niter) disp(clk, bus_clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data);
	

	reg[31:0] pads[30*Njobs*N-1:0];
	reg[31:0] expect_data[2*5*Njobs*N-1:0];
	reg[31:0] recv_data[5*Njobs*N-1:0];
	reg[31:0] I, J, K, M;
	reg[31:0] recv_count=0;
	testcase src;
initial
begin
	bus_clk=1'b0;
	bus_counter=32'b0;
	clk=1'b0;
	counter = 32'b0;
	for(M=0; M<2; M=M+1)
	for(J=0; J<N; J=J+1)
		for(K=0; K<Njobs; K=K+1)
			begin
			if(M==0)
				src=testcases[(K+J*Njobs)%7];
			else
				src=testcases[(K+(J+1)*Njobs+1)%7];
			for(I=0; I<5; I=I+1)
				begin
				pads[(M*N+J)*15*Njobs+K*5+I] <= src.ipad[I*32+:32];
				pads[(M*N+J)*15*Njobs+K*5+I+5*Njobs] <= src.opad[I*32+:32];
				pads[(M*N+J)*15*Njobs+K*5+I+10*Njobs] <= src.data[I*32+:32];
				expect_data[(M*N+J)*5*Njobs+K*5+I] <= src.expect_acc_10[I*32+:32];
				end
			end
end

	wire[31:0] first_write, first_read, second_write, second_read, work_time;
	assign first_write=0;
	assign work_time=2*Njobs*Niter+200;
	// assumes 10 iterations only (with 4096, takes something like 30 min for ModelSim to complete the run)
	assign first_read=15*Njobs*N+work_time;
	assign second_write=30*Njobs*N+work_time+200;
	assign second_read=45*Njobs*N+2*work_time+200;
	
reg[31:0] deltas[7:0]={1,2,3,2,1,3,2,2};
reg[31:0] next_read=15*Njobs*N+2*Njobs*Niter+200;
reg[31:0] write_count=0;
reg[31:0] first_read_count=0, second_read_count=0;
reg[31:0] expect_idx, observe_idx;
	
always #2
begin
	clk<=~clk;
	counter<=counter+clk;
end

always #5
begin
	bus_clk<=~bus_clk;
	bus_counter<=bus_counter+bus_clk;
end

reg read_32_delay=0;

always @(posedge bus_clk)
	begin
			if(bus_counter>=first_write && bus_counter<first_write+15*Njobs*N)
					begin
						write_32_wren<=1;
						write_32_data<=pads[bus_counter-first_write];
					end
			else if(bus_counter>=second_write && bus_counter<second_write+15*Njobs*N)
					begin
						write_32_wren<=1;
						write_32_data<=pads[15*Njobs*N+bus_counter-second_write];
					end
			else
					write_32_wren<=0;

			if(bus_counter==first_write+15*Njobs*N+10)
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
			if(bus_counter>=first_read && first_read_count<5*Njobs*N && bus_counter<first_read+15*Njobs*N)
					begin
					read_32_delay<=read_32_rden;
//					if((first_read<20 || first_read>1260) && (bus_counter==next_read || read_32_rden || read_32_delay || bus_counter==first_read+15*Njobs*N-1))
//						$display("%d %d %x %d", bus_counter, first_read_count, read_32_data, read_32_empty);

					if(bus_counter==next_read)
						begin
						read_32_rden<=!read_32_empty;
						if(!read_32_empty)
							begin
				//		$display("%d %d", counter, next_read);
								next_read<=bus_counter+deltas[write_count&7];
								write_count<=write_count+1;
							end
						else
							next_read<=bus_counter+2;
						end
					else
						read_32_rden<=0;
					if(read_32_delay)
						begin						
						recv_data[first_read_count]<=read_32_data;
						first_read_count<=first_read_count+1;
						end
					end
			else if(bus_counter==first_read+15*Njobs*N)
				begin
//				$display("%d %d %x %d", bus_counter, first_read_count, read_32_data, read_32_empty);
//				recv_data[first_read_count]<=read_32_data;
//				first_read_count<=first_read_count+1;
				read_32_delay<=0;
				end
			else if(bus_counter==first_read+15*Njobs*N+100)
				begin
				$display("%d First read done", bus_counter);
				if(first_read_count<5*Njobs*N)
					$display("Error: only %d / %d words received", first_read_count, 5*Njobs*N);
				read_32_rden<=0;
				next_read<=second_read;
				assert(recv_data==expect_data[5*N*Njobs-1:0]);
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif								
						if(recv_data[J*5*Njobs+K*5+:5]!=expect_data[J*5*Njobs+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								for(I=0; I<7; I=I+1)
									if(160'(expect_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										expect_idx=I+1;
								for(I=0; I<7; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[J*5*Njobs+K*5+:5]), 160'(recv_data[J*5*Njobs+K*5+:5]));
							end
						end
				end
			else if(bus_counter>=second_read && bus_counter<second_read+15*Njobs*N && second_read_count<5*Njobs*N) 
					begin
					read_32_delay<=read_32_rden;
//					if(second_read_count<20 && (bus_counter==next_read || read_32_rden || read_32_delay))
//						$display("%d %d %x %d", bus_counter, second_read_count, read_32_data, read_32_empty);
					if(bus_counter==next_read)
						begin
						read_32_rden<=!read_32_empty;
						if(!read_32_empty)
							begin
				//		$display("%d %d", counter, next_read);
								next_read<=bus_counter+deltas[write_count&7];
								write_count<=write_count+1;
							end
						else
							next_read<=bus_counter+2;
						end
					else
						read_32_rden<=0;
					if(read_32_delay)
						begin						
						recv_data[second_read_count]<=read_32_data;
						//$display("%d %d %x", bus_counter, first_read_count, read_32_data);
						second_read_count<=second_read_count+1;
						end
					end
			else if(bus_counter==second_read+15*Njobs*N)
				begin
				read_32_delay<=0;
//				recv_data[second_read_count]<=read_32_data;
//				second_read_count<=second_read_count+1;
				end
			else if(bus_counter==second_read+15*Njobs*N+100)
				begin
				read_32_rden<=0;
				$display("Second read done");
				if(second_read_count<5*Njobs*N)
					$display("Error: only %d / %d words received", second_read_count, 5*Njobs*N);
				
				assert(recv_data==expect_data[2*5*N*Njobs-1:5*N*Njobs]);
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif								
						if(recv_data[J*5*Njobs+K*5+:5]!=expect_data[(J+N)*5*Njobs+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								for(I=0; I<7; I=I+1)
									if(160'(expect_data[(J+N)*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										expect_idx=I+1;
								for(I=0; I<7; I=I+1)
									if(160'(recv_data[J*5*Njobs+K*5+:5])==testcases[I].expect_acc_10)
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[(J+N)*5*Njobs+K*5+:5]), 160'(recv_data[J*5*Njobs+K*5+:5]));
							end
						end
				end
			else if(bus_counter==second_read+5*Njobs*N+200)
				begin
				$display("Finished!");
				read_32_rden<=0;
				end
			else
				read_32_rden<=0;
end


endmodule

`endif