localparam                          HALF_WIDTH  = 16;

localparam                          CMD_WIDTH       = 3;
//localparam                          OFFSET_WIDTH    = 16;
localparam                          DIM_WIDTH       = 8;
localparam                          CH_COUNT_WIDTH  = 10;
localparam                          FLT_COUNT_WIDTH = 10;
localparam                          CONV_SIZE_WIDTH = 2;
localparam                          STRIDE_WIDTH    = 2;
localparam                          TOTAL_PXL_WIDTH = 14;
localparam                          PADDING_WIDTH   = 4;

localparam [CMD_WIDTH-1:0]          CMD_END         = 3'h0;
localparam [CMD_WIDTH-1:0]          CMD_LD_W        = 3'h1;
localparam [CMD_WIDTH-1:0]          CMD_LD_D        = 3'h2;
localparam [CMD_WIDTH-1:0]          CMD_SV_D        = 3'h3;
localparam [CMD_WIDTH-1:0]          CMD_FULL        = 3'h4;
localparam [CMD_WIDTH-1:0]          CMD_WAIT_END    = 3'h5;

//localparam                          WEIGHTS_LEN     = 9;

//localparam [MEM_BUF_IDX_WIDTH-1:0]      WEIGHTS_BUF_IDX     = 0;
//localparam [MEM_BEAT_ADDR_WIDTH-1:0]    WEIGHTS_LD_COUNT   = (9 * 4) + 2;

localparam [3-1:0]      WEIGHTS_BUF_IDX     = 0;
localparam [20-1:0]     WEIGHTS_LEN         = (9 * 4);
localparam [20-1:0]     WEIGHTS_PARAM_LEN   = (9 * 4) + 2;
localparam [20-1:0]     FC_WEIGHTS_LEN      = 4;
localparam [20-1:0]     FC_WEIGHTS_PARAM_LEN = 4 + 2;