`timescale 1 ns/1 ns
module fpadd_shift (fA, n, fR);
   `include "misc.v"
    
    parameter wE = 4;
    parameter wF = 5;
    localparam maxShift = min(log(wF+2), wE);//maxshift=4;

    input[wF+1 : 0] fA;
    input[wE-1 : 0] n;
    output[wF+3 : 0] fR;
    
    reg[maxShift*(wF+4)-2 : 0] shift;
    reg kill;
    wire sign;
     
     
    genvar i;

    assign  sign = fA[wF+1]; 
    always @ (n[0]  or  sign  or fA)//(n[0] )
    begin   
        if (n[0] == 1'b1)
            shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)] = {sign, fA}; 
        else    
            shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)] = {fA, 1'b0};
    end   
 
    always @ (n[1] or shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)]  or sign ) //(n[1] or shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)])
    begin
        if (n[1] == 1'b1)
            shift[(maxShift-1)*(wF+4)-1 : (maxShift-2)*(wF+4)] = {sign,sign, shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)+1]}; //the same to right shift 2 bit, the last bit is abandoned
        else
            shift[(maxShift-1)*(wF+4)-1 : (maxShift-2)*(wF+4)] = {shift[maxShift*(wF+4)-2 : (maxShift-1)*(wF+4)], 1'b0}; //the length is wF + 3

    end

    generate
        for(i = 2; i < maxShift; i = i + 1)
            begin : shift_loop
                always @(n[i] or shift[(maxShift+1-i)*(wF+4)-1 : (maxShift-i)*(wF+4)] or sign)
		begin
                    if (n[i] == 1'b1 )
                        shift[(maxShift-i)*(wF+4)-1 : (maxShift-1-i)*(wF+4)] = {{(2**i){sign}}, shift[(maxShift+1-i)*(wF+4)-1 : (maxShift-i)*(wF+4)+2**i]}; 
                    else
                        shift[(maxShift-i)*(wF+4)-1 : (maxShift-1-i)*(wF+4)] = shift[(maxShift+1-i)*(wF+4)-1 : (maxShift-i)*(wF+4)];
		end 
	    end
    endgenerate
    
    generate
        if (maxShift < wE)
            begin
	        always @ (n[wE-1 : maxShift] )
                begin
                    if (n[wE-1 : maxShift] == {(wE-maxShift){1'b0}})
                        kill = 1'b0;
                    else
                        kill = 1'b1; //kill = 1 means too long right shift(shift to zero)
                end

		assign fR = (kill == 1'b1) ? {(wF+4){1'b0}} : shift[wF+3 : 0];

            end
        else //maxShift = wE 
            assign fR = {shift[wF+3 : 0]};
     endgenerate 
endmodule
