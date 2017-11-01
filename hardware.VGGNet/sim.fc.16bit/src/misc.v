function automatic integer log (input integer length);
  begin
    integer i;
    integer o;
    i = length;
    for (o = 0; i>0; o = o + 1) // length > 1 ?
      i = i >> 1;
    log = o;
  end
endfunction

function automatic integer ttlog (input integer length);
  begin
    integer i;
    integer o;
    i = length;
    for (o = 0; i >0; o = o + 1)
      i = i >> 1;
    ttlog = o;
  end
endfunction

function automatic integer min(input integer a, input integer b);
    begin
        if (a > b)
            min = b;
        else
            min = a;
    end
endfunction
