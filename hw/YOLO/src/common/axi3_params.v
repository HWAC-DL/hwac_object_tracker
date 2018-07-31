localparam                          AXI3_ID_WIDTH           = 6;
localparam                          AXI3_ADDR_WIDTH         = 32;
localparam                          AXI3_BLEN_WIDTH         = 4;
localparam                          AXI3_BTYPE_WIDTH        = 2;
localparam                          AXI3_BSIZE_WIDTH        = 3;
localparam                          AXI3_LOCK_WIDTH         = 2;
localparam                          AXI3_CACHE_WIDTH        = 4;
localparam                          AXI3_PROT_WIDTH         = 3;
localparam                          AXI3_QOS_WIDTH          = 4;
localparam                          AXI3_DATA_WIDTH         = 64;
localparam                          AXI3_STRB_WIDTH         = 8;
localparam                          AXI3_RESP_WIDTH         = 2;

localparam [AXI3_BTYPE_WIDTH-1:0]   AXI3_BTYPE_FIXED        = 2'b00;
localparam [AXI3_BTYPE_WIDTH-1:0]   AXI3_BTYPE_INCR         = 2'b01;
localparam [AXI3_BTYPE_WIDTH-1:0]   AXI3_BTYPE_WRAP         = 2'b10;

localparam [AXI3_BSIZE_WIDTH-1:0]   AXI3_SIZE_8             = 3'b011;   // 8 byte burst

localparam [AXI3_LOCK_WIDTH-1:0]    AXI3_LOCK_NORMAL        = 2'b0;
localparam [AXI3_LOCK_WIDTH-1:0]    AXI3_LOCK_EXCLUSIVE     = 2'b1;

localparam [AXI3_CACHE_WIDTH-1:0]   AXI3_CACHE_DEV_NON_BUF  = 4'b0000;  // Device Non-bufferable
localparam [AXI3_CACHE_WIDTH-1:0]   AXI3_CACHEABLE_BUFFERABLE  = 4'b0011;

localparam [AXI3_PROT_WIDTH-1:0]    AXI3_PROT               = 3'b000;   // Unprivileged secure data access
localparam [AXI3_QOS_WIDTH-1:0]     AXI3_QOS                = 4'b0000;  // No QOS

localparam [AXI3_RESP_WIDTH-1:0]    AXI3_RESP_OKAY          = 2'b00;
localparam [AXI3_RESP_WIDTH-1:0]    AXI3_RESP_EXOKAY        = 2'b01;
localparam [AXI3_RESP_WIDTH-1:0]    AXI3_RESP_SLVERR        = 2'b10;
localparam [AXI3_RESP_WIDTH-1:0]    AXI3_RESP_DECERR        = 2'b11;