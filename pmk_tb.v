`define FULL_TB_CHECKS

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

wire [31:0] a0_precompute;
wire[63:0] pad_pp;

pad_preprocess64 pp(ctx, pad_pp);
assign a0_precompute = pad_pp[63:32] + pad_pp[31:0];

SHA1_5x5_bare sha(clk, counter[6:0], a0_precompute, ctx, data, out_ctx);

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

reg[159:0] new_test_data[0:383]={
160'h97e0e035c42a685f8b58f2b6b12069080a4a3e14,160'hd370280a96fb43b346575fc19d82a52d54f50f2c,160'h317d86643c3aa60174f911f44b2327487af43ae7,160'h70881790b5125b129ee0d90bfa4a744f193bf0ae,
160'h70c9be1fe1b3853ef6646e9be9a6284854debf75,160'hb411164d982cade9fcd0c9cac8b1a35b4c10e951,160'hc860ff6a67f8b2e685bbadd370f7a6f8a31fc5c4,160'h5f0ca92caa1218447152934bacffc3904b875c2b,
160'hd7cbdf09c829d06fd0de0d908e9f96bfb60c8646,160'hf89ce19dc2a1f5aa5f2ccf961e2dec29d2640143,160'hbd59fe61ffb2a5137fa86c75bdf04b6adf176a74,160'ha3fd167c8f457575da2076385245741a6d4b77fb,
160'h551219396fd411235d582dd9aef7afd82309c658,160'h50a63a9d1c60d9dc5da228f18096cdc720dfd9e2,160'h8c8ef0ea7eeecb724c2e6363ca35dee6df48dc2e,160'h18cd92f7ef731e83e41830e469f8e406637babbd,
160'he5a9598ecc88b688e3f8a24fdcd634ce12f50e0b,160'hcccd53f53503593d1235f2500bd2a37edd95130f,160'hc935ec2e0e76991900225bc88b11ce2076f4337c,160'h8a86eaf49c4ca61745185d8a800d0c069f21a7ad,
160'hb86cc45b9043f42b130b31f5a3c96d6646d23a07,160'h1c4c92dc652128dc8d731c1cf0691ebb1e3ea267,160'hbc8917317e6935790dbd9bd65360215804d6028d,160'h63de2b877cfb69d3d8c770ad18a85e10ebfc699d,
160'h89b15378650927227fd38e45ba5e98385e456776,160'h21db69710ab8cec1856c9d644f9f38a82d1a05bd,160'hfbfec327659dd66850483f02ccfb14569dda0c5a,160'h5680e6770a18a2778407c5dda80c35596bb9a619,
160'h00347657e72ac2596de2ff4be77fd7509941eac0,160'h237fb0385b7bb8ac19a106bc45808a2839ebe447,160'h6c51844be1d422b0bffeb20059265c3d1c860484,160'h9374833d23337f95196f000fa8ba6ff4d04f5b9f,
160'h26fbfe98ffc8c05d2422f4296e46f3b097bfc1e9,160'h93e69afaceb55f3dce2de2faf7021222d25aff55,160'hb65d42c4908eb1ea38420fb24ffa1aa91f14f0c1,160'h32a1cdfc13221241bc6447ee8225638a59e75d92,
160'he6e7fe3bf8574b2768f433d280175d3bec9b69b2,160'he95076bbc0f946e31bc2fb1564cdc830004bbb2b,160'h57cf7f505ef2709ac4fcd2393850f0bc2f95b6d9,160'h9d43a909ad46017c341a6703a5797eb01880e54a,
160'h0189e34e66c5674ea591d2c1ef61c88fcce74493,160'h4757362eb0aa53a0f5b16815ef2680473d636785,160'hcc46a189a1eb988003460616d1d15d14de8a9d8a,160'h47739ca55a38f6e3054687ce1cf223fea7a82ee6,
160'hea69de3fbf04c8355ec9cf6d972dc27c121a3738,160'h21994182b58202d9f7c59c69c6166f5a617eca15,160'ha401d6b3543edfb51b37ff68ad61bd99591e6479,160'h5bdf586324fd89239f8abd41a89afbfdd35e7284,
160'h56ba7e6b592eaff3507bc083d76789e6b269eb9f,160'h511a88700e6d14960551a8a692241b744773f03c,160'h8cd1a01098ecdf1307b63dc75caf8e3651cef2cd,160'h59ab1272fba41bacaccbee83edbf357820ffe8a7,
160'h24c4ffe3ce9918c8229e29c345c77475b91d808f,160'h5b3bb3cf598acfb7d287630101e25ffccc863919,160'hbcd7e1fbe6538b4e04dd409c880819ed65bd102e,160'h3b235cefa37f54fce1dc25b9203e164aa3c518e3,
160'h1f67d52ae258df91fe53f6988cdc0db9d2e9e256,160'ha884db921644e7d1c85f5868c2ca03adf61ae49f,160'h02564bf95bafdd82cb7ccc6bdaf0baf231848a2c,160'he5fd2b633120ede29f20d39e7725c26258fba6f3,
160'h32a1c09726f7adb5694aaf900c8a297652563501,160'hf4ccbe10c7287dcdae6d6723d16bd103c6689c63,160'h5d073a75f1a3046a85fc0f595feeffd9923244c6,160'h83a1a2bce7f0df3e41722e904e7be415b76de09a,
160'h673a3bc955f60af75700f07bc91632145d945d2b,160'h80f19fb52f316436870d69fe5688ff51e4215162,160'he58223681c6bfa70db290580dba9fb4937556ee0,160'he509d3e7d9e5551b6a1814dd3b348ead0d0dc640,
160'h663305527c766c7f3c43a933759ff910eece411c,160'hfc093d81900840ecc49db8cee3c62137df40e731,160'hc5a010457d2a593dc3084d040769874ae447b24b,160'h8bc5825cf236cb3788516da80ae5ad61f69795ff,
160'hb315164d7b55b5a448dcd02e13d3ddd96fc48755,160'h34acb3b1d99f6f7378b8612548ca307e3c99e34e,160'hb9f8e05fe25d62f6b34811bd58cdbf6437a202a9,160'hf1b38e0c0ef4cb0221cee0396279534017ba8589,
160'hea8b5e3c935d9a17074771fcdb673c0bbda2686e,160'h40301978735cb2663ff2f4e809344be4e0e2f4ae,160'h954cac96c7532dccaec349cc6a290cb236cf535b,160'h0f2ee30d1b22b95c76bc911688b5a827d5c73086,
160'h274422ae3ab604d665ecdf62b0bfb820e881ff1c,160'hc39d02fdc8dca812b5dbf8f3ec39d1c664ead5ad,160'h46c194730abf74761ba68e1759429dd5a660595c,160'hb7b322202fdedc822d0debf910e115592b903785,
160'h25dabfb3d29aeca4748df29c7629efa11e561880,160'hf07ac3ab4680ea65167ea3d551abaa8545d2a026,160'h300f89b5d13d520e70933a45067fbede8ac7677b,160'h27f33cee9199b9da0111e2df4262a2e869a34056,
160'h6e804cb79449df7134b80aa378416a504c366656,160'hf36b4aa2cc3c42c9fbfd96c1bab25bfbc2cbf7c5,160'h5624b39058db5955aaecec7e418523e803223f73,160'h93b9d0459070d226e6b653fdee235dd8ac7ca4f3,
160'hd78e735d004d9d1e04732da3d9d5f844196f826f,160'h1f60a980ae86185ad1627877a7e3c3563c2d48e6,160'h8824f63b369864089ecb5fb2c2d79dcad9a57956,160'h133ad40e3ab58d01d2cf557c13a4e695b523819e,
160'hd4942f09f368533d6c954d7fb14e217cd6ac50de,160'hdf52730f3a2bf4e573c82320a57e7c83ecd161f2,160'h4afb70b03d1b90c671e51bd9d0f41b0c9df79b4e,160'heb935cb1a4f2641ac9f80c50a5f7ebeba3a58aa3,
160'hd69942eeefd00835bee43000fc874f5eeb4b1ed0,160'h83da5eb060a26df5a2a6fd5c6ec07acda66b53e7,160'h7dcde41c32776b26b4af444aa43dce3f7dca7e02,160'hc079e525070d38b3003b83986efc36234d056ed3,
160'h15ca8391b05cb879fd570d01cb97a902a7bccd8a,160'h18fdc34fa3e116f93b7568b7c27d43bafb316e9b,160'hd04172d7ce6b1a9a3b18af1ebf32666cff1f1968,160'hb76ec1f96f945100c746f5b6c7ffb75375fe6015,
160'he6ccdfc9724893eb3d80b8e6723a7f489bd37e7d,160'h2c7ae526c7d0b9c88feb39f3044ad3b2939f93b3,160'h47a69ec304ab1ae88ca94cc50ebbf2e6741f276d,160'h523cbac8b422a9ea01cfa21057dfcc35e88c10fc,
160'hd6eb4c328378c0723aaf6933bf8a98262f9756a1,160'h1a009ce82306ba32592314770fb3d7e7d54cdd53,160'h77f030292c466200de435ed885e22e7cf13a61cb,160'heebb73c210a440cebab2f7a805b97fb6653f71ba,
160'h1426386f5caa168ea42c2b8f34f3d818e366eaa6,160'h1b859197dc0d9cd9c912ed017cc554ac240f5a1e,160'h9389d48769b3ae6bfdf0d050e3abf3e9e662a2db,160'h706fb40c91691ad77f69820302515c0b8e3032ca,
160'hf2338fb5155eb1ddb8b1d7c150542d077a4a5df5,160'h50c84d09d05db24d2dbbc3bc3734b6a740861d3d,160'hdc0d77aa735deab63c84650bcd9799aa940a13b5,160'h0042cec00a64cc41891d2c9e56ac7ff281db1edc,
160'hd1a96406ddefc8ee96a79dfbbaaa02e19f89d917,160'h8da6a0a8873b24067bcb6f59a7104925f962d515,160'h06bb22418fb38974732c7ef45d214d2bbe8c741a,160'hb637434e21de558763a3574ee99cc09a90f35c81,
160'h25ad3c943fe48846293837f8e24d52367f262e3b,160'h0bab6e3a820f9d4273a9859082b373058fe0196d,160'he4fe1300940f095b91c285966b2e09c567519fb3,160'h5b87c0af8f91b0d35c09dc1d946b61532d32f1fd,
160'he27c8040e3c3a77c9395494dd65b9646a49a5808,160'h74de754d6655a3d61940725d797110a466f584dc,160'hebedfb32a0c2bf101defe84a48315f53f930138f,160'h4a51e4430176c8f01b257cbb975f44dfbe1ba1ff,
160'h45c0bb8dd5bd2b99cdd6f4d1400ddb2e3f8f6a65,160'he0b3ea3660da7e6e09413da84089a5d5bed34e2a,160'h324757728b1ee09f71fccaedb24e7b4966c31dac,160'h26d5a483ba6e40cf9c62469436bf9df0386dd573,
160'h41c984581cb7425e57a30d77fd6182d5c3a84b2e,160'h93ec47fe69b33c3df458566f084d649edcd9c576,160'hd68c5485d30e85b41d166d8aec2f29953d63db14,160'h7f4e58e76c81c2bb1ba54f61907eb52a90397b92,
160'h891d85d0647338627ebcaab27a4b80269cc1e05c,160'h0666d7edce16b8b8bc4f1fdf3bc9555bf4dadbbf,160'h1e1285d0b656b2d9a59ec9f2d50202fb1908b442,160'h3f207534d6377fe83a8a5d8907de896a41afae9b,
160'h6fb082d1aeba9f4cf8a585af83b18155f15f8c38,160'h0614b1fa68f19123aa9517af8911bd8d92304f4a,160'hb81c700f5b055a71294b326c3b7ef9fdd8ebffdc,160'h2acfc48c5b80fe7bbf2d7fd3d1212d9abae55b5b,
160'hfc952901d0a51177ec29b3687cb1a35e902ab60d,160'h2224ab86a3069f70657339f4826d2c2438f37bbb,160'h14398c4e42b11b308bb12780fc0007e095c30488,160'h6a2538de18e9a6020600f3d25c4482134a62fc68,
160'hdd5a61d3b7a59be54deb343500e5292f84a5e871,160'ha660bc90ffee277e6138911b2ddb3d7f55d999fd,160'ha6d85c144cdedb917af3b4e57a441630ccaecdc9,160'ha13819399416e60a43254acfecbca58a8845acdc,
160'h0730ea690439602c1c57defb65dd321c295fe395,160'h128fb605ea2f28ed4e57be866081fc39bf3fde02,160'h7b384539e1b148ff6ff4821eadac96a6725f3950,160'hab5eb0acdc99985dc5e95a2e3d9e5a2dac8d0c09,
160'h2f00c5f66b9f833b743f5793fa945f2c79fea2b1,160'h570ea67bf910d449f646b500e8bfd9587cc0fac6,160'h688de762cacaaeb1d69e725aa9df99fdf5d908dc,160'h8d0a4d2d07553258fdd6859f5ec99762076aa289,
160'h236c173d4681c709dbe0f9881b1e990f647b65f0,160'hed8c559eb7bb78f66cf90b397c15aabfd0a5d38e,160'h0a379a8dfb4da9a7c913f925f917f0edbcb578da,160'hbd6da178015fdbfbf25d12a1dda0b0c3be443f06,
160'ha255fd9a5930d4a2272bbeca8c63f9ea6b1da7b2,160'hfb9090caafca8c6d4110cc01842db1a4a1fbfb5b,160'h91a6fb69c8ae9d39c4ad1e0596eb208b3d4272d4,160'h0cb349ae5021bc1725a615d737daae8a031fb453,
160'h30bf87cd4701d8b9cb036845a4fc14313500ef5d,160'h76cb7ef170a8d65826d293ccc0b73acf74907dc5,160'h0e328364a5310d9c89b034f6456554fc50f37ea1,160'h46c65b8c7172a4e17ca3a203d4da2bcc9d9a3177,
160'h63601ee855190b39df68db2b34273c1e194ac643,160'h0a47d738e5e987096245af7b65657398a7465491,160'h9f48f0e98ff498b59d935ceabc0600c3740d290c,160'h8f445c05abf369b2271af633a0960d2665a02845,
160'hcf192a2aefed57979975a50e9622bb22c50eda07,160'h1ecb2b6c3562c375f0e4d598a86fe32fade570a8,160'h0e6dd5bce3c7d02ce4a4912ba13424974aedf651,160'h0ae355e3f2aff71715c98db398be0ba03974c0c4,
160'he893695ee9da78728fdc2ee77567738cbd6ddcf1,160'h96123d597b055ae4f7c935313141297d62ed4312,160'hfcdfcec374f7b2ac3ddfef1c92431425dff97622,160'h9b08645a49d2cf3ea2ff1b3d8df7029d4a2e1f03,
160'he17116a84b4d7af96c8a2ae17a1d9aae60135808,160'he77ef67750b677d364f1d46b0bba294c36f4dc65,160'h3b8808c9b842f67e87fd6d68e15f44068ea1a7f0,160'ha8d4d365aee8b4d4dfcdca144547fc1abc1b7d99,
160'hcdd339e321b3149c2da6f5c706c90e6bb5a78e00,160'hfcb1f981019aa82687d4b8baa48081ea13993928,160'heaa55f215bc9b8778ac141540af524810d5270f2,160'hbf8747e8dd1e48fb42d977ef2274cfe3953f0d6e,
160'h5569f0286fcb17de77cecbebda2b75a7bc3a0a23,160'hba24c799570aa9d417ea34ef8525e4323165f80c,160'ha5d2cc8cc175d995a59539df11d7237d45b463d1,160'h30978a2c85e65aa7b37d0250745bc0614fa100f0,
160'h0f91c69dd4705d82b1d8e6c42f4a553ee932170e,160'hd98730924bce90488a2d73ca0f1ae71df93ea4e2,160'h168ffd6d1f32281898d638d042e54649ec3b205b,160'h1b56dfccd933859b0086af38d110aaa2e5d2d6ed,
160'hc0032f82d25b8a115f366ccf6f7884e4922177bb,160'h7eb4ac6789013067d4b6efb051183b1866fa2872,160'h6588f55e396ae59c7af587586bde9344cacac5bb,160'h8fb1dcfb48104e0ef70137db8ba5a127b6f98e24,
160'h1f2f37eefc6406cf278be005c766870d322e1fbc,160'hffa6303a2ff0c33daf1a5c8aac60296faf230baa,160'hfaee0f625b2adec1aecf109a98a7e763019b73a9,160'hb0d9bb6b6e50fae41d20ff6c7ca52baa98d3dce1,
160'hf4b9f5e956763fba62d0cf8f4ec8f28bf7e76143,160'h18870966c48dbda875d4eb9fb146567f112d85b8,160'h7da9f2b45be077017b2f4c79e514a1dbc906381a,160'hfdd489194c9d727b6c8aa781b77d9ea0645e0aac,
160'h946a7be112edf5d022536ac0e833cb837a14cf8a,160'hb3e559953857533a9fa6f53daa2e709190296288,160'h965b572f0953d892c94ba5ed7bde8b054da1b558,160'h82405da1c5589b3ef5f3dcc64f0e7a9178678f22,
160'h30071521d662276331d2b4b8b1f160a738e7c10e,160'h3f86456dc73bcee1eec2db2ea390a3278cb788b6,160'hf7a5dbdeab77d907327b6829a1ce6db92a995c72,160'hde765e8bc11ba276807c1fa6fa6e5ff4148868eb,
160'h8111d9bae0792854a4aa73eaf493be682b57299f,160'h085b180d91c7d7d6880f3735954fc3f3d8b6c27f,160'h6fbb7871e1c7741383093cbbb9c3756a6639f293,160'hfa2fe02e1481c9d0ac68594417726eb39b5d6be8,
160'ha6190374d8fddf04829fda1b26b5ec17dff84f4e,160'h10451421c811111dfea2c046121253c22f6ed1b4,160'h19676cdbd8cc075840ba75dd8991ac67cfb4f426,160'h04fafbc12f65c1d13d4d9cfe1edc3aade07b94c1,
160'h1963a4b037ce27989e15ac9aedfdb4ae9b87d9de,160'h96cd4cc480235c466b3cb4b89e011e735bdb41ed,160'hbbf5da2234926be68a1fb9992d56f4423385f6a0,160'h6c1af28b2c13049bffd3566d5b97307801fb5f2a,
160'h31c7579fea39a0404a4b6008683e6f7bcdf4c75a,160'hfb41b5187846584b4298b9b79c4f1e8bddb5ec46,160'h213b2ddd40a786a4f86935cae96a6ca388c5c128,160'h1137bbed5b573f0a35e1fcf53617a31efc242d60,
160'ha6ffbdc2a99521a38f1f94fffc0629ccbc1545a3,160'hdc1c0ae6a22528f08d8b3ba7cc54d35a733ddfe2,160'h8aa82546c31f242e16b5412ee8d0587cbc2c1957,160'ha3bb58224d5638f56896afd5a9b19d954a784bfa,
160'h845ab18b9bbab42ca6a874cd2ab9550b10141ca3,160'hfd4450825b57781945d62be26afe11ba0789a374,160'hcc88a13f3e9718982a16db66abf989f76def7552,160'h95cd15506a1baa6ce80b815a287b2034531bdd9c,
160'h64f79d4d1a89c8f8983dad3ef6f3f1d50b693ec3,160'he4e49477de7757c888a89330eb615e7c27f674d1,160'h06b3025a5b143ba38b1ddf53519009ea710d25b5,160'h65ca00f436905c89dda6f65e62ebc5c9972323fb,
160'ha28ae0d7c3ae35e7ffa5f47993a1fc77dc3cfe22,160'h6650a17882f76159aa12b75a8b212dd45ab7774a,160'h04135682474bd6a3082456e7072f7392f1e8b43a,160'h8247c26c1d6650f614ad530528a130767b3ed8f2,
160'h37e7524a16c1c3a0515bd9f6635444d223803e88,160'hb16659de0db8ed493200c2b6705b04eb3fbf2fc7,160'h7cd272c2b7feb8bb0b87e4bd2377f0ef7acb27c1,160'hdff696bb72582f92b811f8603a8ea8ce65492efd,
160'hb6a55903ba57ff1e21e31ba0d65175dbc521b94a,160'hcda79a2f21100df80bb0d6c2e9851d3c204bbb48,160'ha0f61a965133aca8680b71273490c3501e3696d6,160'h31c8c5d2f981a3995bf5125cdf65947fd05468eb,
160'h2afcae255d91a2d5e6005d649e1a65a6e609d89b,160'h1c83f501a18ccf0fe0732211a541f544fe4cfa00,160'hefd18fa5f03acca94b7bf4c50ea17a001cf8528a,160'hb1633e20dc7c6c60067936daf6c97fabb8244a16,
160'hd4b21cb4ead62091d784e7804e614e532f8c9b9c,160'h7d76c6ad90ad262d46a1cec518b100e3581eb8b6,160'h5381d14432959578f44ef061fc72a7b1d5290a25,160'ha7cccc82d0ad3e62a1a32aa45dc979a02453a671,
160'h92134321cd83dbea4b6c79be984c8bc47573f151,160'h2fb71766ff8121339adc74b5d8f166e2b86a8e24,160'hac2eeff031441120217b44b26802afb48bd867b1,160'h785ff894752779b55af6985cd25b0d30a660b302,
160'h4e18a1b212a5b9ab97fd456d3b7aaa3818c07f09,160'h58edab949b580e5b0c605b4440fd23574aac1d24,160'hc1c0447311472b437b7f992cafdadde144bcea17,160'h7114bfcd4f12a96ab6183c8ddb9a8d6f84e0e29e,
160'he9c1866424e9ccebd296aff836fcde957b08ea96,160'h93424b3c77d7434d3678fed1bfb1c8e8e0d55997,160'h98c99dcd5cd2a1e5ed6c3adf912d294b0f6b91fc,160'hbf12b4efd0b14a564c6ac60f8322dffd6ddf329b,
160'he5e9e389a33d85adef3766a609f6a029d0eebf81,160'h83ef98aac8febfbac6e5b74771c58310ee1df53f,160'hfc8638715ce565b7f6a99d53aa093fbfdd1e04a1,160'hdffdf6d93df95025a87be11ea3813b12d48c777c,
160'h0456c947ad56edc47b5efd07ca1de32f36f1c9ca,160'h6ed21b2e83bffe2323e44274010632524350d3ca,160'hc60be83ff806008779817bab1593cc0513cdf8f3,160'hf91a90196639c23c922167a7b020df11502dccfe,
160'h7bb3450261cce9fd0546b71d0e2802ffea0a217a,160'h665df7c82c7fb4c4b36e12fe2f2c0fd26e9e8edd,160'hd312cca76f292349a7e6d8ad4bda56df4a518216,160'hdfcefc4a6fca57ab524ebdcee468ffa4418057cd,
160'hba156290e7af11ab764e9073145e4133acd3805f,160'h4ea8aa5bf4b01f43595c98c3683acf34f5a0f034,160'h981fd9388e4a2905058bf5fe6e230bc88cd4895e,160'h820520255ea59cef58f3074e4cefdd36394f332d,
160'hbd34c8ade1cb085ca3763b9e95d583b461c28b35,160'he8cdce6249810bde3be4059858ebfbb1200ce5cd,160'h82ebb63ba34067d098958e0b4667c76c184f9efd,160'h99ff502e44439c5aa7c013069d234ac2f0af9ad5,
160'h39946612c3273e13dcb340973d0863eed03c3677,160'hbb3698b0b13e2c13e313070a478ca00f4452b007,160'h4793996fd28c5a1ca784783642643c5303595af4,160'h17195b2ab452521920734f6dfcdf82b075a59143,
160'h7072a9219c4ae1538e8a0a1ca321a340cb62faac,160'h3c4363b2b9817d428f0b1e98a062e257e956fe3a,160'h9b509f1d22aa7b92131ab35eddbf8f127d62b950,160'haf9b4fcb3ff1ddfe9d76fcd5efb34c6fcafad06d,
160'h0eb7b986bd9f2c313ce453a35f5a82ecc23b244f,160'he4f3fb2abc9c27302038176eef401677227f4a96,160'hf33b3d0cf3d81bdfc01babcb40539f4a210da9de,160'h23205648a6819c50d4e811f017c520c621cd4a83,
160'h230719b427efc60f4a59c189bac4b65e25416662,160'h25ad16a9d479189d37653bade0e831751aa2d389,160'h74c1723b7e71a5b63a3529ee2a541c4f59d700e5,160'h0c5c6a51cd1b4c3508a9a4403ba514aa3d6b45eb,
160'h7f453e1242ade40f13765677d41e2d5158ff6ec3,160'h63c938153244cfd052c2d0b356c58b86c32aa46b,160'h8773cd4ccba62b09eee7e3989ea43c94abf9691a,160'h733bd2e31ed66882851808c363bcba2934f8bb5c,
160'h081039f1aec59a629edf7ce0d0685df3d3db7142,160'h2303bf5a9fd3d79d0e0556ed62fa0104f5e582dc,160'h0d139736c8d55034435d1971552c541159945303,160'h5390cc51e03c8c556af2eacb7a41982243fac226,
160'h18f4ec5923c646305a57533f0b11693544e9c19c,160'h011c0001b9bdf4eba211dc303d3d2bbbbff6235a,160'hd396c15433c7aff67ec99c6c24208a1f8876a371,160'h25b56d82517c57d70b684749a38a10d5c32a1ebe,
160'h1fb5444c1b5e01fd7f6023abdb86587ed6b2b18a,160'h950cbd0226f604d1bd5f16a8251c6349e5cf9be3,160'hff8156319b15741c263c718796a3b49bac540913,160'hc52de172149fe0e6956ed98fd28dbca996108893,
160'h8078c51542e968ac61d30384077c2c4632a14525,160'h7faa61e7d581d1eae8308d5d0654b735a4aa9eee,160'hb0bc0281a4fe844aceb6b4002d41d3016046bd87,160'hfbe4a86b2deeb3943aa41da92bb411a2453a3194,
160'h659855ebf58be213f86ac0056b76c50978b549fd,160'h2370634dea2e465b963cdfd8aa8960bcb94e9bb2,160'h45e79ec7fe28f26b73af06ee2ed3f40043c8e42f,160'h3424f1b6e89ae2c9ae7e7f81461bdc2bfcf2bb81,
160'h417106885efbd5c1a2f561989bd9eaa645ca04fe,160'hf8e2578ff1d4eb29526320327df71b256bf728ef,160'hc67b04f8638749f510221c2561b82db0d59a9b4f,160'h926dda95420c406ad60c776aceddbef67b915e95,
160'h6424ea292e709cd4bcfb16e0dec65f3cbdada434,160'h675db7c13b3a1c6712306cb12c29cbc4c4af552e,160'h9fd4a60ca0b2285e61dbd3ae1ec4b3ab59f43ca1,160'h9855a3313649099d4ab1db88ee374a184c632a39,
160'hda27e6a25ad89b851de5b50a71b0f23aeed8f7f8,160'he7eca508a9ef100e058916738c24e33f7aaaa8f2,160'hf8aaa8df5de321c6c5f9e2389a88bf7fcc584367,160'h1b737402923c81595ad976a6de0f4cbcf49f8d9f,
160'h133d8c4bf398933a3c5348abf7ffc319d7d1a674,160'hecc20c09dd62512d04f1bb126f7b9e029dd12d6a,160'h2c997e118d36b66183e9d1905452330d696c337a,160'ha79c954d823e4afeec17469d6da70e008a2c3853,
160'hbbb9ca8329c982166f313cbd963dba9a27663938,160'hd4ae917983faa89427e6daf408cebd0d282c1b4b,160'hf410f71c83e1e6e98e2a6403a89fcf915b0a0eb7,160'h6bd6aa1e35889ce08cc7630b5d1d93b1a69ab22d,
160'he27c5d346fda3131e4cba86b181b41165afb3f8f,160'h11fa4a0601e2f1f3de4c0fa495dc0d44e5adca7a,160'hc0260a82a8405a837bba0c79573a3d25831ac2be,160'he2bb57e20d5456452db098e52aab0cf3a7b632f2,
160'h42864ecc768b70467fb63f075db489100520e040,160'hdc87a56ed1d9484dc2dcd7faea50082ec88b3bce,160'hc94fa971256355b8c2e35dd8f97605a94e1b26e3,160'h6f799b33306838d3cbd9dcd1deefe1502853c4aa,
160'haee41576735dabbff4df3968de34c9fc75a1fc49,160'h91e5845c4d063a338aed73bf75e042d6985ad0c3,160'hdc52b5ba84b1eb74718613a404624c58bd03ad07,160'h39896d60a37e0b37c3b6ed12492857399b2385d3,
160'h2f483f9d05c90d25a91fc596927f364f70c0529d,160'h1bebabc0c63c04b02ff9442e67ca43ab72b49f8b,160'h8e50c479a12b85c3caa9605b86c33eb65ac374f9,160'h81071af40f6503af528ca676dfd98eac9139f198
};



module counter_4(clk, reset, enable, r1, r2, r3, r4);
	parameter N1=5;
	parameter N2=5;
	parameter N3=5;
	parameter N4=5;
	parameter LN1=$clog2(N1);
	parameter LN2=$clog2(N2);
	parameter LN3=$clog2(N3);
	parameter LN4=$clog2(N4);
	input clk, enable, reset;
	output reg[LN1-1:0] r1;
	output reg[LN2-1:0] r2;
	output reg[LN3-1:0] r3;
	output reg[LN4-1:0] r4;
	reg stop2;
	always @(posedge clk)
	begin
	if(reset)
		begin
		r1<=0;
		r2<=0;
		r3<=0;
		r4<=0;
		stop2<=0;		
		end
	else if(enable)
		begin
		stop2<=(r1==N1-2 && r2==N2-1);
		
		if(r1!=N1-1)
			r1<=r1+1;
		else
			begin
			r1<=0;
			if(r2!=N2-1)
				r2<=r2+1;
			else
				r2<=0;
			end
		if(stop2)
			begin
			if(r3!=N3-1)
				r3<=r3+1;
			else
				begin
				r3<=0;
				r4<=r4+1;
				end
			end
		end
	end	
endmodule
		


`timescale 1 ns / 1 ns
module pmk_calc_direct_tb;

	reg clk=0;
	reg [31:0] counter=0;

	parameter N=3;
	parameter Njobs=120;
	parameter Niter=10;

	reg[31:0] core_addr=0;
	reg[31:0] core_data_in;
	reg rden=0, wren=0;
	reg[1:0] ext_mode=0;
	wire[31:0] core_data_out;
	wire readdatavalid;
	wire done;
	pmk_calc_direct_feed_multicore #(N,Njobs,Niter) core(
		.core_clk(clk), 
		.addr(core_addr[16:0]),
		.rden(rden),
		.wren(wren),
		.data_in(core_data_in),
		.data_out(core_data_out),
		.readdatavalid(readdatavalid),
		.ext_mode(ext_mode),
		.done(done),
		.disp_status()
		);

always #1 
begin
	clk<=~clk;
end


wire[31:0] read_start;
assign read_start = 100+N*Njobs*16+Njobs*Niter*2;

wire[31:0] write_counter;
assign write_counter = (counter-100);
wire[15:0] write_job;
wire[1:0] write_column;
wire[2:0] write_word;
assign write_job = {8'b0, write_counter[11:5]};
assign write_column = write_counter[4:3];
assign write_word = write_counter[2:0];

testcase src;
reg[31:0] M, J, K;


wire[7:0] temp;
reg[31:0] expect_data;
reg[31:0] req_read_row=0, req_read_col=0, req_read_inst=0;

/*
reg[31:0] write_inst=0;
reg[1:0] write_comp=0;
reg[6:0] write_row=0;
reg[2:0] write_col=0;
*/
reg[31:0] write_count=0;

wire[1:0] write_inst;
wire[1:0] write_comp;
wire[6:0] write_row;
wire[2:0] write_col;

wire c4_enable, c4_reset;

counter_4 #(5, Njobs, 3, N) c4(clk, c4_reset, c4_enable, write_col, write_row, write_comp, write_inst);

assign c4_enable = (counter >= 100 && write_count<N*Njobs*15);
assign c4_reset = (counter==0 || counter==read_start+N*Njobs*5+100);

reg[31:0] read_inst=0;
reg[31:0] read_row=0;
reg[31:0] read_col=0;
reg[31:0] read_count=0;
reg[31:0] mismatch_count=0;

reg[1:0] loop_pass=0;

wire[7:0] dual_row;
assign dual_row = write_row + Njobs;

always @(posedge clk)
begin
	if(counter >= 100 && write_count<N*Njobs*15)
		begin
		M=0;
		J=write_inst;
		K=(write_row+loop_pass)&127;
		
		src.ipad={32'h0,M,J,K,32'h0};
		src.opad={32'h1,M,J,K,32'h1};
		src.data={32'h2,M,J,K,32'h2};
		/*
		if(write_row!=write_row2 || write_col!=write_col2 || write_comp!=write_comp2 || write_inst!=write_inst2)
			$display("%d  %d %d %d %d  %d %d %d %d", 
				counter,
				write_col, write_row, write_comp, write_inst,
				write_col2, write_row2, write_comp2, write_inst2);
			*/	
		//src=testcases[4];
		wren<=1;
		case(write_comp)
		0: begin
			core_addr<={write_inst, 3'b0, write_row [6:0], write_col[2:0]};
			core_data_in <= src.data[write_col*32+:32];
			end
		1: begin				
			core_addr<={write_inst, 3'b100, write_row [6:0], write_col[2:0]};
			core_data_in <= src.opad[write_col*32+:32];
			end
		2:	begin
			core_addr<={write_inst, 2'b10, dual_row [7:0], write_col[2:0]};
			core_data_in <= src.ipad[write_col*32+:32];
			end
		endcase
		write_count<=write_count+1;
		/*
		if(write_col<4)
			write_col<=write_col+1;
		else if(write_col==4 && write_row<Njobs-1)
			begin
			write_col<=0;
			write_row<=write_row+1;
			end
		else if(write_comp<2)
			begin
			write_col<=0;
			write_row<=0;
			write_comp<=write_comp+1;
			end
		else
			begin
			write_col<=0;
			write_row<=0;
			write_comp<=0;
			write_inst<=write_inst+1;
			end
		*/
		end
	else
		wren<=0;
		
	if(counter == 100+N*Njobs*16)
		ext_mode<=1;
		
	if(counter == read_start)
		begin
		assert(done);
		end
		
	if(counter>=100)
		assert(!$isunknown(readdatavalid));
	
	rden <= (counter >= read_start && counter < read_start+2*N*Njobs*5 && !counter[0]);
	if(counter >= read_start && counter < read_start+2*N*Njobs*5 && !counter[0])
		begin
		core_addr <= req_read_inst*8192 + req_read_row*8 + req_read_col;
		if(req_read_col==4)
			begin
			req_read_col<=0;
			if(req_read_row==Njobs-1)
				begin
				req_read_row<=0;
				req_read_inst<=req_read_inst+1;
				end
			else
				req_read_row<=req_read_row+1;				
			end		
		else
			req_read_col<=req_read_col+1;
		end
		
	if(readdatavalid)
		begin
		expect_data=new_test_data[read_inst*128+((read_row+loop_pass)&127)][read_col*32+:32];
		//expect_data=testcases[4].expect_acc_10[read_col*32+:32];
		if(read_inst==0 && read_row==0 && read_col==0)
			$display("First word: %x", core_data_out);
		if(read_inst==N-1 && read_row==Njobs-1 && read_col==4)
			$display("Last word: %x", core_data_out);
		if(core_data_out != expect_data || $isunknown(core_data_out[0]))
			begin
			if(mismatch_count<10)
				$display("Mismatch at %d %d %d: %x vs %x", read_inst, read_row, read_col, core_data_out, expect_data);
			mismatch_count<=mismatch_count+1;
			end
		if(read_col==4)
			begin
			if(read_row==Njobs-1)
				begin
				read_row<=0;
				read_inst<=read_inst+1;
				end
			else
				read_row<=read_row+1;
			
			read_col<=0;
			end
		else
			begin
			read_col<=read_col+1;
			end
		end	
	if(counter==read_start+2*N*Njobs*5+100)
		begin
		$display("Final state %d %d %d", read_inst, read_row, read_col);
		$display("%d mismatches", mismatch_count);
		req_read_row<=0;
		req_read_col<=0;
		req_read_inst<=0;
		write_count<=0;
		read_inst<=0;
		read_row<=0;
		read_col<=0;
		read_count<=0;
		mismatch_count<=0;
		counter<=0;
		ext_mode<=0;
		if(loop_pass==2)
			loop_pass<=0;
		else
			loop_pass<=loop_pass+1;
		end
	else
		counter<=counter+1;
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
	parameter N=3;
	parameter Njobs=120;
	parameter Niter=10;
	parameter inCnt=N*(3*Njobs+1);
	parameter outCnt=N*(Njobs+1);
	wire[31:0] disp_status;
	pmk_dispatcher_daisy #(N, Njobs, Niter, 1) disp(clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data, 1'b0, disp_status);


	reg[31:0] pads[10*inCnt-1:0];
	reg[31:0] expect_data[2*5*outCnt-1:0];
	reg[31:0] recv_data[5*outCnt+4:0];
	reg[31:0] I, J, K, M;
	reg[31:0] recv_count=0;
	testcase src;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	for(M=0; M<2; M=M+1)
	for(J=0; J<N; J=J+1)
		begin
		for(I=0; I<5; I=I+1)
			pads[(M*N+J)*5*(3*Njobs+1)+I] <= 32'hbaadf00d;
		for(I=0; I<5; I=I+1)
			expect_data[(M*N+J)*5*(Njobs+1)+I] <= 32'hbaadf00d;

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
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+5] <= src.ipad[I*32+:32];
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+5*Njobs+5] <= src.opad[I*32+:32];
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+10*Njobs+5] <= src.data[I*32+:32];
				expect_data[(M*N+J)*5*(Njobs+1)+K*5+I+5] <= src.expect_acc_10[I*32+:32];
				end
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
reg[31:0] next_read=5*inCnt+2*Njobs*Niter+200;
reg[31:0] expect_idx, observe_idx;
reg read_32_rden_prev=0;

always @(posedge clk)
	begin
			if(counter>=first_write && counter<first_write+5*inCnt)
					begin
						write_32_wren<=1;
						write_32_data<=pads[counter-first_write];
					end
			else if(counter>=second_write && counter<second_write+5*inCnt)
					begin
						write_32_wren<=1;
						write_32_data<=pads[5*inCnt+counter-second_write];
					end
			else
					write_32_wren<=0;

			if(counter==first_write+5*inCnt+10)
				begin
				$display("All %d modules loaded", N);
				end
			if(counter>=first_read && first_read_count<5*outCnt+5 && counter<first_read+3*5*outCnt)
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
			else if(counter==first_read+3*5*outCnt+100)
				begin
				$display("First read done");
				if(first_read_count<outCnt*5+5)
					$display("Error: only %d / %d words received", first_read_count, outCnt*5);
				read_32_rden<=0;
				$display("Status line: %x %x %x %x %x", 
					recv_data[5*outCnt], recv_data[5*outCnt+1], 
					recv_data[5*outCnt+2], recv_data[5*outCnt+3], recv_data[5*outCnt+4] );
				assert(recv_data[5*outCnt-1:0]==expect_data[5*outCnt-1:0]);
//				for(K=0; K<Njobs; K=K+1)
//					$display("160'h%x,", 160'(recv_data[2*5*Njobs+K*5+:5]));
					
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs+1; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif				
						if(recv_data[J*5*(Njobs+1)+K*5+:5]!=expect_data[J*5*(Njobs+1)+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								for(I=0; I<384; I=I+1)
									if(160'(expect_data[J*5*(Njobs+1)+K*5+:5])==new_test_data[I])
										expect_idx=I+1;
								for(I=0; I<384; I=I+1)
									if(160'(recv_data[J*5*(Njobs+1)+K*5+:5])==new_test_data[I])
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[J*5*(Njobs+1)+K*5+:5]), 160'(recv_data[J*5*(Njobs+1)+K*5+:5]));
							end
						end
				end
			else if(counter>=second_read && counter<=second_read+5*outCnt)
					begin
					read_32_rden<=(counter<second_read+5*outCnt ? 1 : 0);
					if(counter>second_read)
						recv_data[counter-second_read-1]<=read_32_data;
					end			
			else if(counter==second_read+5*outCnt+100)
				begin
				read_32_rden<=0;
				$display("Second read done");
				assert(recv_data[5*outCnt-1:0]==expect_data[2*5*outCnt-1:5*outCnt]);
				for(J=0; J<N; J=J+1)
					for(K=0; K<Njobs+1; K=K+1)
						begin
`ifndef FULL_TB_CHECKS
							if(K>=2 && K<Njobs-1)
								continue;
`endif								
						if(recv_data[J*5*(Njobs+1)+K*5+:5]!=expect_data[(J+N)*5*(Njobs+1)+K*5+:5])	
							begin
								expect_idx=0;
								observe_idx=0;
								
								for(I=0; I<7; I=I+1)
									if(160'(expect_data[(J+N)*5*(Njobs+1)+5*inCnt+K*5+:5])==testcases[I].expect_acc_10)
										expect_idx=I+1;
								for(I=0; I<7; I=I+1)
									if(160'(recv_data[(J+N)*5*(Njobs+1)+K*5+:5])==testcases[I].expect_acc_10)
										observe_idx=I+1;
								if(observe_idx>0)
									$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
								else
									$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, 160'(expect_data[J*5*(Njobs+1)+5*outCnt+K*5+:5]), 160'(recv_data[J*5*(Njobs+1)+K*5+:5]));
							end
						end
				end
			else if(counter==second_read+5*outCnt+200)
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
	
	parameter N=3;
	parameter Njobs=128;
	parameter Niter=10;
	parameter inCnt=N*(3*Njobs+1);
	parameter outCnt=N*(Njobs+1);
	pmk_dispatcher_dualclock #(N, Njobs, Niter) disp(clk, bus_clk, read_32_rden,
		read_32_empty, read_32_data,
		write_32_wren, write_32_full, write_32_data, 1'b0);
	reg[31:0] pads[10*inCnt-1:0];
	reg[31:0] expect_data[2*5*outCnt-1:0];
	reg[31:0] recv_data[100+5*outCnt+4:0];
	reg[31:0] I, J, K, M;
	reg[31:0] recv_count=0;
	testcase src;
initial
begin
	clk=1'b0;
	counter = 32'b0;
	bus_clk=1'b0;
	bus_counter = 32'b0;
	for(M=0; M<2; M=M+1)
	for(J=0; J<N; J=J+1)
		begin
		for(I=0; I<5; I=I+1)
			pads[(M*N+J)*5*(3*Njobs+1)+I] <= 32'hbaadf00d;
		for(I=0; I<5; I=I+1)
			expect_data[(M*N+J)*5*(Njobs+1)+I] <= 32'hbaadf00d;

		for(K=0; K<Njobs; K=K+1)
			begin
			if(M==0)
				begin
				src.ipad={32'h0,M,J%3,K,32'h0};
				src.opad={32'h1,M,J%3,K,32'h1};
				src.data={32'h2,M,J%3,K,32'h2};
				src.expect_acc_10=new_test_data[(J%3)*128+K];
				end
			else
				src=testcases[(K+J*Njobs)%7];
			for(I=0; I<5; I=I+1)
				begin
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+5] <= src.ipad[I*32+:32];
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+5*Njobs+5] <= src.opad[I*32+:32];
				pads[(M*N+J)*5*(3*Njobs+1)+K*5+I+10*Njobs+5] <= src.data[I*32+:32];
				expect_data[(M*N+J)*5*(Njobs+1)+K*5+I+5] <= src.expect_acc_10[I*32+:32];
				end
			end
		end
end

wire[31:0] work_time;
assign work_time=2*Njobs*Niter+200;
// assumes 10 iterations only (with 4096, takes something like 30 min for ModelSim to complete the run)
//assign first_read=15*Njobs*N+work_time;
//assign second_write=30*Njobs*N+work_time+200;
//assign second_read=45*Njobs*N+2*work_time+200;
	
reg[31:0] deltas[7:0]={1,2,3,2,1,3,2,2};
reg[31:0] next_read=0;
reg[31:0] write_count=0;
reg[31:0] read_count=0;
reg[31:0] expect_idx, observe_idx;

reg[159:0] received, expected;	
always #2
begin
	clk<=~clk;
	counter<=counter+clk;
end

always #3
begin
	bus_clk<=~bus_clk;
	bus_counter<=bus_counter+bus_clk;
end

reg read_32_delay=0;
reg[31:0] write_stop_time=0;
reg[31:0] pass_no=0;

always @(posedge bus_clk)
	begin
		if(write_count<5*inCnt && !write_32_full)
			begin
			write_32_wren<=1;
			write_32_data<=pads[pass_no*5*inCnt+write_count];
			write_count<=write_count+1;
			if(write_count == 5*inCnt-1)
				begin
				write_stop_time<=bus_counter;
				$display("%d All modules loaded", bus_counter);
				end
			end
		else
			write_32_wren<=0;

		if(read_32_delay)
			begin						
			recv_data[read_count]<=read_32_data;
			read_count<=read_count+1;
			end
		read_32_delay<=read_32_rden;
		if(/*read_count<5*outCnt+5 && */bus_counter>=next_read && !read_32_empty)
			begin
			if(!(read_count % 1000))
				$display("%d Issuing read request %d", bus_counter, read_count);
			read_32_rden<=!read_32_empty;
			next_read<=bus_counter+deltas[read_count&7];
			end
		else if(write_count==5*inCnt && (read_count>=5*outCnt+100 || bus_counter>=write_stop_time+work_time+15*outCnt))
			begin
			pass_no <= 1-pass_no;
			read_count<=0;
			write_count<=0;
			$display("%d First read done", bus_counter);
			if(read_count<5*outCnt+5)
				$display("Error: only %d / %d words received", read_count, 5*outCnt+5);
			else if(read_count>5*outCnt+5)
				begin
				$display("Error: %d / %d words received", read_count, 5*outCnt+5);
				for(I=5*outCnt; I<read_count; I=I+1)
					$display("%d %x", I, recv_data[I]);
				end
			read_32_rden<=0;
			assert(recv_data[5*outCnt-1:0]==expect_data[5*outCnt*pass_no+:5*outCnt]);
			for(J=0; J<N; J=J+1)
				for(K=0; K<Njobs+1; K=K+1)
					begin
					received=160'(recv_data[J*5*(Njobs+1)+K*5+:5]);
					expected=160'(expect_data[(J+pass_no*N)*5*(Njobs+1)+K*5+:5]);
					if(received!=expected)	
						begin
						expect_idx=0;
						observe_idx=0;
						if(pass_no==0)
							begin
							for(I=0; I<384; I=I+1)
								if(expected==new_test_data[I])
									expect_idx=I+1;
							for(I=0; I<384; I=I+1)
								if(received==new_test_data[I])
									observe_idx=I+1;
							end
						else
							begin
							for(I=0; I<7; I=I+1)
								if(expected==testcases[I].expect_acc_10)
									expect_idx=I+1;
							for(I=0; I<7; I=I+1)
								if(received==testcases[I].expect_acc_10)
									observe_idx=I+1;
								end
						if(observe_idx>0)
							$display("Mismatch at instance %d job %d (expect v[%d], observe v[%d])", J, K, expect_idx-1, observe_idx-1);
						else
							$display("Mismatch at instance %d job %d (expect %x, observe %x)", J, K, expected, received);
						end
					end
			end
		else
			read_32_rden<=0;
end


endmodule

