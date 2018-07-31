localparam                          AXI4_TID_WIDTH          = 16;
localparam                          AXI4_ID_WIDTH           = 8;
localparam                          AXI4S_DATA_WIDTH        = 64;
localparam                          AXI4S_KEEP_WIDTH        = 8;

localparam                          AXI4L_ADDR_WIDTH        = 32;
localparam                          AXI4L_DATA_WIDTH        = 32;
localparam                          AXI4L_STRB_WIDTH        = 4;
localparam                          AXI4L_RESP_WIDTH        = 2;

localparam [AXI4L_RESP_WIDTH-1:0]   AXI4L_RESP_OKAY         = 2'b00;
localparam [AXI4L_RESP_WIDTH-1:0]   AXI4L_RESP_EXOKAY       = 2'b01;
localparam [AXI4L_RESP_WIDTH-1:0]   AXI4L_RESP_SLVERR       = 2'b10;
localparam [AXI4L_RESP_WIDTH-1:0]   AXI4L_RESP_DECERR       = 2'b11;



