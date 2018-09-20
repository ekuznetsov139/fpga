

module xor4(x0, x1, x2, x3, q);
parameter N=32;
input [N-1:0] x0, x1, x2, x3;
output [N-1:0] q;
wire[N-1:0] y0, y1, y2, y3, p;
generate
genvar gi;
for(gi=0; gi<N; gi=gi+1) begin : lc1
	assign q[gi]=x0[gi]^x1[gi]^x2[gi]^x3[gi];
/*
	lut_input input1(.in(x0[gi]), .out(y0[gi]));
	lut_input input2(.in(x1[gi]), .out(y1[gi]));
	lut_input input3(.in(x2[gi]), .out(y2[gi]));
	lut_input input4(.in(x3[gi]), .out(y3[gi]));
	assign p[gi] = y0[gi] ^ y1[gi] ^ y2[gi] ^ y3[gi];
	lut_output output1(.in(p[gi]), .out(q[gi])); 
*/	
	end
endgenerate
endmodule

module permuter_6b(input clk, input [517:0] x, output reg [517:0] x_);
parameter N=0;

function automatic [31:0] rot1;
	input [31:0] y;
	begin
	rot1 = {y[30:0], y[31:31]};
//	rot1 = y;
	end
endfunction

function automatic [511:0] rotn;
	input [511:0] y;
	input [3:0] n;
	begin
	rotn = (y>>(n*32)) | (y<<(512-n*32));
	end
endfunction

	wire [31:0] x0, x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15;

		
	wire[511:0] xrot;

	assign {x15,x14,x13,x12,x11,x10,x9,x8,x7,x6,x5,x4,x3,x2,x1,x0} = rotn(x[511:0],N&15);
		
	wire[5:0] c;
	assign c=x[517:512];
	
	wire[31:0] x10_, x11_, x12_, x13_, x14_, x15_;
	
	assign x10_ = {x10[31:1],c[0] };
	assign x11_ = {x11[31:1],c[1] };
	assign x12_ = {x12[31:1],c[2] };
	assign x13_ = {x13[31:1],c[3] };
	assign x14_ = {x14[31:1],c[4] };
	assign x15_ = {x15[31:1],c[5] };
	
	
	wire[31:0] y0, y1, y2, y3, y4, y5, y6, y7, y8,  y9, y10, y11, y12, y13, y14, y15;
	// y0[0] = fun(x0[31])
	// y0[1] = fun(x0[0])
	// y0[2] = fun(x0[1]) ...
	xor4 do0(rot1(x0), rot1(x2), rot1(x13_),rot1(x8),   y0);
	xor4 do1(rot1(x1), rot1(x3), rot1(x14_), rot1(x9),  y1);
	xor4 do2(rot1(x2), rot1(x4), rot1(x15_),rot1(x10_),  y2);

	xor4 do3(rot1(x3), rot1(x5), rot1(y0), rot1(x11_),  y3);
	xor4 do4(rot1(x4), rot1(x6), rot1(y1), rot1(x12_),  y4);
	xor4 do5(rot1(x5), rot1(x7), rot1(y2), rot1(x13_),  y5);
		
always @(posedge clk)
	begin
	x_[517:512] <= {y5[0], y4[0], y3[0], y2[0], y1[0], y0[0]};
	x_[511:0] <= rotn({x15_,x14_,x13_,x12_,x11_,x10_,x9,x8,x7,x6,y5[31:1],1'b0,y4[31:1],1'b0,y3[31:1],1'b0,y2[31:1],1'b0,y1[31:1],1'b0,y0[31:1],1'b0}, (N&15)==0 ? 0 : 16-(N&15));
	//x_[511:0] <= rotn({x15_,x14_,x13_,x12_,x11_,x10_,x9,x8,x7,x6,y5,y4,y3,y2,y1,y0}, (N&15)==0 ? 0 : 16-(N&15));
	end
endmodule

/*
y = [x15..x7, rot1(x5 x7 x13 y2), rot1 (x4 x6 x12 y1), rot1(x3 x5 x11 y0), 
	rot1(x2 x4 x10 x15), rot1(x1 x3 x9 x14), rot1(x0 x2 x8 x13)] 
	
	
	---
z6 = rot1(y6 y8 y14 y3)
z = [x15, x14, x13, x12, rot1(y11 y13 y3 z8), rot1(y10 y12 y2 z7), rot1(y9 y11 y1 z6), z8, z7, z6, y5, y4, ... y0]

redefining & dropping one rotation:

y0 = x0 x2 x8 x13
y1 = x1 x3 x9 x14
..
y = [x15..x7, x5 x7 x13 rot1(y2), x4 x6 x12 rot1(y1), x3 x5 x11 rot1(y0), y2, y1, y0] 
	- 3 boundary crossings
	
z8 = y8 y10 rot1(y0 y5)
z7 = y7 y9 y15 rot1(y4)
z6 = y6 y8 y14 rot1(y3)

z = [x15, x14, x13, x12, y11 y13 rot1(y3 z8), y10 y12 rot1(y2 z7), y9 y11 rot1 (y1 z6), 
	y8 y10 rot1(y0 y5),
	y7 y9 y15 rot1(y4),
	y6 y8 y14 rot1(y3),	y5, y4, ... y0]
	- 7 boundary crossings

t = [z15 rot1(z1 z7 t12), z14 rot1(z0 z6 z11), z13 z15 rot1(z5 z10), z12 z14 rot1(z4 z9), ..., rot1(z1 z3 z9 t14), rot1(z0 z2 z8 t13)]
	- 14 boundary crossings 

**/


module permuter_6b_series(input clk, input [511:0] x, output [2047:0] to_mem);

	wire[517:0] stages[10:0];
	
genvar g,h;
	permuter_6b #(0) stage1(clk, {x[480],x[448],x[416],x[384],x[352], x[320], x}, stages[0]);

//	assign to_mem[191:0] = stages[0][191:0];
generate
	for(g=0; g<6; g=g+1) begin: aa
		assign to_mem[g*32+:32] = {stages[0][g*32+1+:31], stages[0][512+g]};
	end
for(g=0; g<10; g=g+1) begin : aaa
	permuter_6b #((g+1)*6) stage(clk, stages[g], stages[g+1]);
	for(h=0; h<6; h=h+1) begin: bbb
		if((g+1)*192+h*32<2048)
			assign to_mem[(g+1)*192+h*32+:32]={stages[g+1][((h+(g+1)*6)&15)*32+1+:31], stages[g+1][512+h]};
	end
end
endgenerate

endmodule