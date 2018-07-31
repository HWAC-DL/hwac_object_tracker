function integer clog2;
    input integer value;
    begin
        value = value - 1;
        for (clog2 = 0; value > 0; clog2 = clog2 + 1) begin
            value = value >> 1;
        end
    end
endfunction

function integer count2width(input integer value);
    if (value <= 1) begin
	   	count2width = 1;
    end
    else begin
        value = value - 1;
        for (count2width = 0; value > 0; count2width = count2width + 1) begin
            value = value >> 1;
        end
    end
endfunction

`define keepcode2keep(i, KEEP_LENGTH, keepcode, keep)\
    always@(*) begin\
        keep   = {KEEP_LENGTH{1'b1}};\
        for (i=1; i<KEEP_LENGTH; i=i+1) begin\
            if (i == keepcode) begin\
                keep = ({KEEP_LENGTH{1'b1}}) >> (KEEP_LENGTH - i);\
            end\
        end\
    end