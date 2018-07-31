localparam                          MEM_ADDR_WIDTH              = 26;
localparam                          MEM_BUF_IDX_WIDTH           = 3;
localparam                          MEM_BEAT_BYTE_ADDR_WIDTH    = 3;
localparam                          MEM_BEAT_ADDR_WIDTH         = (MEM_ADDR_WIDTH - MEM_BUF_IDX_WIDTH - MEM_BEAT_BYTE_ADDR_WIDTH);
localparam                          MEM_FULL_BEAT_ADDR_WIDTH    = (MEM_ADDR_WIDTH - MEM_BEAT_BYTE_ADDR_WIDTH);

localparam                          MEM_ADDR_POS                = 0;
localparam                          MEM_BUF_IDX_POS             = MEM_ADDR_WIDTH;
localparam                          MEM_LENGTH_POS              = 32;