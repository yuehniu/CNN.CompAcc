`timescale 1 ns/1 ns
module fpadd_shift_l (fA, n, fR);
    `include "misc.v"
    parameter wE = 4;
    parameter wF = 5;
    parameter wNZeros=4;

    localparam maxShift = min(log(wF+2), wE);//3

    input[wF+1 : 0] fA;
    input[wNZeros : 0] n;
    output[wF : 0] fR;

    reg[(maxShift+1)*(wF+2)-1 : 0] shift;//[27:0]

    genvar i;//[20:14]=[6:0]
    assign  shift[(maxShift+1)*(wF+2)-1 : maxShift*(wF+2)] = fA; //[27:21]
    generate
        for(i = 0; i < maxShift; i = i + 1)//i<3
            begin : shift_loop				//i=0,[27:21];i=1,[20:14],i=2,[13:7]
                always @(n[i] or shift[(maxShift-i+1)*(wF+2)-1 : (maxShift-i)*(wF+2)])
		begin
                    if (n[i] == 1'b1 ) //i=0,[20:14]=[26:21]0;i=1,[13:7]=[18:14]00;i=2,[6:0]=[9:7]0000
                        shift[(maxShift-i)*(wF+2)-1 : (maxShift-1-i)*(wF+2)] = {shift[(maxShift-i+1)*(wF+2)-1-2**i : (maxShift-i)*(wF+2)], {(2**i){1'b0}}}; 
                    else//         //i=0,[20:14]=[27:21];i=1,[13:7]=[20:14];i=2,[6:0]=[13:7]
                        shift[(maxShift-i)*(wF+2)-1 : (maxShift-1-i)*(wF+2)] = shift[(maxShift-i+1)*(wF+2)-1 : (maxShift-i)*(wF+2)];
		end 
	    end
    endgenerate
    
    assign fR = shift[wF+1 : 1];
endmodule
