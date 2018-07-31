localparam          HALF_DATA_WIDTH             = 16;
localparam          DATA_WIDTH                  = HALF_DATA_WIDTH;

localparam          INPUT_DIM                   = 4;
localparam          OUTPUT_DIM                  = 4;
localparam          CONV_KERNEL_DIM             = 3;
localparam          POOL_KERNEL_DIM             = 2;

//IM_CACHE
localparam          IM_CACHE_DELAY              = 2;
localparam          IM_CACHE_SIZE               = 52 * 128;
localparam          IM_CACHE_COUNT              = 4;
localparam          IM_CACHE_DATA_BUS_WIDTH         = DATA_WIDTH*IM_CACHE_COUNT;
localparam          IM_CACHE_DEPTH              = IM_CACHE_SIZE/4;  // /4 since the a single output cache is broken to 4 block ram to create the neighbourhood for pooling


localparam          MAX_COL                     = 13;
localparam          MAX_ROW                     = 13; //IM_CACHE_SIZE/MAX_COL;

localparam			DATA_BUS_WIDTH	            = DATA_WIDTH * INPUT_DIM;
localparam			CONV_WEIGHT_COUNT_PER_LAYER = CONV_KERNEL_DIM * CONV_KERNEL_DIM * INPUT_DIM * OUTPUT_DIM;
//localparam                  CONV_WEIGHT_COUNT_PER_LAYER = 1 * INPUT_DIM * OUTPUT_DIM;

//input stream params
localparam          IN_STREAM_ID_WIDTH          = 1;
//localparam          DIM_WIDTH                   = 8;   //WIDTH, HEIGHT
//localparam          CONV_SIZE_WIDTH             = 2;
//localparam          STRIDE_WIDTH                = 2;
//localparam          TOTAL_PXL_WIDTH             = 14;
//localparam          PADDING_WIDTH               = 4;

//head params
localparam          IM_COLS_START               = 0;
//localparam          IM_ROWS_START               = IM_COLS_START + DIM_WIDTH;
//localparam          IM_TOT_PIX_START            = IM_ROWS_START + DIM_WIDTH;
//localparam          CONV_SIZE_START             = IM_TOT_PIX_START + TOTAL_PXL_WIDTH;
//localparam          POOL_STRIDE_START           = CONV_SIZE_START + CONV_SIZE_WIDTH;
//localparam          PADDING_MASK_START          = POOL_STRIDE_START + STRIDE_WIDTH;
//localparam          SAVE_RESULT_FLAG_POS        = PADDING_MASK_START + PADDING_WIDTH;
localparam          IM_ROWS_START               = IM_COLS_START + 8;
localparam          IM_TOT_PIX_START            = IM_ROWS_START + 8;
localparam          CONV_SIZE_START             = IM_TOT_PIX_START + 14;
localparam          POOL_STRIDE_START           = CONV_SIZE_START + 2;
localparam          PADDING_MASK_START          = POOL_STRIDE_START + 2;
localparam          SAVE_RESULT_FLAG_POS        = PADDING_MASK_START + 4;


localparam          CONV_SIZE_1_1               = 1;
localparam          CONV_SIZE_3_3               = 3;

localparam          CONV_DIM_3_3                = 9;
localparam          CONV_DIM_1_1                = 1;
