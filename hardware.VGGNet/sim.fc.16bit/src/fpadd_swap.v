`timescale 1 ns/1 ns
module fpadd_swap (nA, nB, nR, nS, eD);
	parameter wE = 4;               
	parameter wF = 5;                   

	input[wE+wF : 0]  nA;            
	input[wE+wF : 0]  nB;
	output[wE+wF : 0] nR;           
	output[wE+wF : 0] nS;
	output[wE-1 : 0] eD;            
  
	wire[wE : 0] eD0;         
	wire[wE-1 : 0] eD1;    		 
	wire swap;                      

	assign eD0 = {1'b0, nA[wE+wF-1 : wF]} - {1'b0, nB[wE+wF-1 : wF]};   
    	assign swap = eD0[wE];              
    
    	assign nR = (swap) ? nB : nA;        
   	assign nS = (swap) ? nA : nB;        

    genvar i;                                 
    generate
        for (i = wE-1; i >= 0; i = i-1)
        begin:absolute
            assign eD1[i] = eD0[i] ^ swap;   
        end
    endgenerate

    assign eD = eD1 + {{(wE-1){1'b0}}, swap};  

endmodule
