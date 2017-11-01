`timescale 1 ns/1 ns
module fpadd_2path (nA,nB,nR);   

	parameter wE = 4;         
	parameter wF = 5;          
       
 	parameter a_width = wF+2;
        parameter addr_width = log(a_width);
	localparam wNZeros = addr_width;
        `include "misc.v"
        `include "DW_lzd_function.inc"

	input[wE+wF : 0]  nA;// The whole length is wE + wF + signbit = wE + wF + 1
	input[wE+wF : 0]  nB;
	output[wE+wF : 0] nR;

	wire sAB;// valid operation(0:add, 1:sub)

	wire[wE+wF : 0] nA0;// the absolute bigger one
	wire[wE+wF : 0] nB0;

	wire[wF+2 : 0] fAc1;  
	wire[wF+2 : 0] fBc1;  
	wire[wF+2 : 0] fRc0;  

	wire[wF+1 : 0] fRc1;
	wire[wE+1 : 0]   eRc1;
	wire[wF : 0]   fRc2;
	wire[wF : 0]   fRc; 
	wire[wE+1 : 0]   eRc2;
	wire[wE : 0]   eRc;
	wire eZero;

	wire[wF+1 : 0] fBf1;
	wire[wF+3 : 0] fBf2;
	wire[wF+3 : 0] fAf3;

	wire[wE : 0] eRf0;
        wire[wF+3 : 0] fRf0;

	reg[wE : 0] eRf1;
	reg[wF : 0] fRf1; 


	wire sRn;
	wire[wE : 0] eRn;
	wire[wF : 0] fRn;

	wire[wE-1 : 0] expDiff;

	wire[wNZeros : 0] nZeros;

	wire close;

	assign sAB = nA[wE+wF] ^ nB[wE+wF];//signbit xor
	//get the bigger one and smaller one, compute the exponent difference 
	fpadd_swap # (wE, wF) swap( 
		.nA(nA),                 // input one [wE+wF:0] 
		.nB(nB),
		.nR(nA0),               // the absolute bigger one  [wE+wF:0]
		.nS(nB0),              
		.eD(expDiff));          //exponent difference  [wE-1:0] 

	assign close = (expDiff[wE-1 : 1] == {(wE-1){1'b0}})? sAB : 1'b0;//

	//close path d<=1                                                                              
	assign fAc1 = {2'b01, nA0[wF-1 : 0], 1'b0};  
	assign fBc1 = expDiff[0] ? {3'b001, nB0[wF-1 : 0]} : {2'b01, nB0[wF-1 : 0], 1'b0};
	assign fRc0 = fAc1 - fBc1; 		
	assign fRc1 = fRc0[wF+2] ? {{(wF+1){1'b0}},1'b1} - fRc0[wF+1 : 0] : fRc0[wF+1 : 0] + 1'b1;//???
	// count leading zeros
	assign nZeros = DWF_lzd_enc(fRc1);
	assign eRc1 = {2'b00, nA0[wE+wF-1 : wF]};        

	//close path shift
	
	fpadd_shift_l # (wE, wF,wNZeros) shiftc( 
		.fA(fRc1[wF+1:0]), 
		.n(nZeros),         
		.fR(fRc2));            

	//close path exp
        assign eRc2 = eRc1 - nZeros;

        assign eZero = eRc2[wE];    
	assign eRc = (eZero | fRc0=={(wF+2){1'b0}}) ? {(wE+1){1'b0}} : eRc2[wE:0];
	assign fRc = (eZero | fRc0=={(wF+2){1'b0}}) ? {(wF+1){1'b0}} : fRc2;

	//far path shift
	assign fBf1 = {2'b01, nB0[wF-1 : 0]};//1'b1->2'b01 
	fpadd_shift # (wE, wF) shiftf(          
		.fA(fBf1),      
		.n(expDiff),    
		.fR({fBf2}));  
 
	assign fAf3 = {2'b01, nA0[wF-1 : 0], 2'b00};
        assign fRf0 = (sAB)? (fAf3 - fBf2 + 2'b10) : (fAf3 + fBf2 + 2'b10);
	assign eRf0 = {1'b0, nA0[wE+wF-1 : wF]};
	always @ (fRf0 or eRf0)
	begin
		case (fRf0[wF+3 : wF+2])    
			2'b01 : begin
				eRf1 = eRf0; 
				fRf1 = {1'b0,fRf0[wF+1 :2]};				
				end
			2'b00 : begin
				eRf1 = eRf0 - 1'b1;
				fRf1 = {1'b0,fRf0[wF :1]};
				end
			default:begin
				eRf1 = eRf0 + 1'b1; 
			 	fRf1 = {1'b0,fRf0[wF+2 :3]};
				end
		endcase
	end

	assign sRn = (close==1'b1 && fRc1 == {(wF+2){1'b0}}) ? 1'b0 : nA0[wE+wF] ^ (close & fRc0[wF+2]);        
	assign eRn = close ? eRc : eRf1; 
	assign fRn = close ? fRc : fRf1; 
	assign nR[wE+wF] = sRn;
	assign nR[wE+wF-1 : 0] = {eRn[wE-1 : 0], fRn[wF-1 : 0]};

endmodule



