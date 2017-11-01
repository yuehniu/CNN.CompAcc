// ---------------------------------------------------
// File       : fp_lshift.v
//
// Description: left shift
//
// Version    : 1.0
// ---------------------------------------------------

module fp_lshift #(
          parameter SHIFTWIDTH = 8,
          parameter DATAWIDTH  = 23
      )(
        input  wire [DATAWIDTH-1 :0] val,
        input  wire [SHIFTWIDTH-1:0] count,
        // append 2 bit to the end
        output wire [DATAWIDTH-1 :0] val_o
      );

  reg [SHIFTWIDTH*DATAWIDTH-1:0] _val;
  // initialization
  always@(count or val) begin
    if(count[0] == 1'b1)
      _val[DATAWIDTH-1:0] = val << 1;
    else
      _val[DATAWIDTH-1:0] = val;
  end

  genvar _cnt;
  generate
    for(_cnt=1; _cnt<SHIFTWIDTH; _cnt=_cnt+1)
      begin: shift_gen

        always@(count or _val[_cnt*DATAWIDTH-1 : (_cnt-1)*DATAWIDTH]) begin
          if(count[_cnt] == 1'b1)
            _val[(_cnt+1)*DATAWIDTH-1 : _cnt*DATAWIDTH] = _val[_cnt*DATAWIDTH-1 : (_cnt-1)*DATAWIDTH] << (2**_cnt);
          else
            _val[(_cnt+1)*DATAWIDTH-1 : _cnt*DATAWIDTH] = _val[_cnt*DATAWIDTH-1 : (_cnt-1)*DATAWIDTH];
        end

      end
  endgenerate

  assign val_o = _val[SHIFTWIDTH*DATAWIDTH-1 : (SHIFTWIDTH-1)*DATAWIDTH];

endmodule 
