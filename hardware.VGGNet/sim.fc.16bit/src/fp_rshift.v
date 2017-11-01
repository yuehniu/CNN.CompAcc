// ---------------------------------------------------
// File       : fp_rshift.v
//
// Description: right shift
//
// Version    : 1.0
// ---------------------------------------------------

module fp_rshift #(
          parameter SHIFTWIDTH = 8,
          parameter DATAWIDTH  = 24
      )(
        input  wire [DATAWIDTH-1:0]  val,
        input  wire [SHIFTWIDTH-1:0] count,
        // append 2 bit to the end
        output wire [DATAWIDTH+1:0]  val_o
      );

  reg [SHIFTWIDTH*(DATAWIDTH+2)-1:0] _val;
  // initialization
  always@(count or val) begin
    if(count[0] == 1'b1)
      _val[DATAWIDTH+1:0] = {val,2'b0}>>1;
    else
      _val[DATAWIDTH+1:0] = {val,2'b0};
  end

  genvar cnt;
  generate
    for(cnt=1; cnt<SHIFTWIDTH; cnt=cnt+1)
      begin: shift_gen

        always@(count or _val[cnt*(DATAWIDTH+2)-1 : (cnt-1)*(DATAWIDTH+2)]) begin
          if(count[cnt] == 1'b1)
            _val[(cnt+1)*(DATAWIDTH+2)-1 : cnt*(DATAWIDTH+2)] = _val[cnt*(DATAWIDTH+2)-1 : (cnt-1)*(DATAWIDTH+2)] >> (2**cnt);
          else
            _val[(cnt+1)*(DATAWIDTH+2)-1 : cnt*(DATAWIDTH+2)] = _val[cnt*(DATAWIDTH+2)-1 : (cnt-1)*(DATAWIDTH+2)];
        end

      end
  endgenerate

  assign val_o = _val[SHIFTWIDTH*(DATAWIDTH+2)-1 : (SHIFTWIDTH-1)*(DATAWIDTH+2)];

endmodule 
