`timescale 1ns / 1ps

/*
 Single cache for output filter is broken into 4 to create the neighbourhood for pooling layer. This module creates the addressing for writing the cache
 */

module im_cache_writer
    (
        clk,
        reset,

        //params
        conv_size_in,
        max_row_in,
        max_col_in,
        //padding_mask_in,
        accum_result_in,
        params_valid_in,

        pixel_in,
        pixel_valid_in,

        cache_rd_addr_out,
        cache_rd_sel_out,
        cache_data_in,

        cache_data_out,
        cache_wrt_addr_out,
        cache_wrt_sel_out,
        cache_wr_en_out,
        cache_wr_last_out,

        stat_row_addr_out,
        stat_col_addr_out
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
   `include "../src/tiny_yolo_params.v"
   `include   "common/common_defs.v"
   `include   "common/util_funcs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam                                                  IM_CACHE_ADDR_WIDTH         = clog2(IM_CACHE_DEPTH);
    localparam                                                  IM_CACHE_SEL_WIDTH          = clog2(IM_CACHE_COUNT);
    localparam                                                  HALF_ADD_DELAY              = 4;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [CONV_SIZE_WIDTH-1 : 0]                         conv_size_in;
    input       [DIM_WIDTH-1 : 0]                               max_row_in;
    input       [DIM_WIDTH-1 : 0]                               max_col_in;
    //input       [PADDING_WIDTH-1 : 0]                           padding_mask_in;
    input                                                       accum_result_in;
    input                                                       params_valid_in;

    input       [DATA_WIDTH-1 : 0]                              pixel_in;
    input                                                       pixel_valid_in;

    output reg  [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_rd_addr_out;
    output reg  [IM_CACHE_COUNT-1 : 0]                          cache_rd_sel_out;
    input       [DATA_WIDTH-1 : 0]                              cache_data_in;

    output reg  [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_wrt_addr_out;
    output reg  [IM_CACHE_COUNT-1 : 0]                          cache_wrt_sel_out;
    output reg  [DATA_WIDTH-1 : 0]                              cache_data_out;
    output reg                                                  cache_wr_en_out;
    output reg                                                  cache_wr_last_out;

    output      [DIM_WIDTH-1 : 0]                               stat_row_addr_out;
    output      [DIM_WIDTH-1 : 0]                               stat_col_addr_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    //reg                                                         top_pad, right_pad, left_pad, bottom_pad;
    reg         [DIM_WIDTH-1 : 0]                               max_row_count;
    reg         [DIM_WIDTH-1 : 0]                               max_col_count;
    reg         [DIM_WIDTH-1 : 0]                               max_row_offset;
    reg         [DIM_WIDTH-1 : 0]                               max_col_offset;
    reg                                                         accum_result;

    reg                                                         is_last_addr_reached;
    reg                                                         is_last_addr_reached_reg;

    reg         [DIM_WIDTH-1 : 0]                               col_div2_ceil;
    reg         [DIM_WIDTH-1 : 0]                               col_count;
    reg         [DIM_WIDTH-1 : 0]                               row_count;
    wire                                                        is_row_odd;
    wire                                                        is_col_odd;

    reg         [DATA_WIDTH-1 : 0]                              pixel_in_reg;
    reg                                                         pixel_valid_in_reg;


    wire        [DATA_WIDTH-1 : 0]                              pixel_in_delayed;
    wire                                                        pixel_valid_in_delayed;
    wire                                                        is_last_addr_reached_delayed;

    wire        [DATA_WIDTH-1 : 0]                              accumulated_pixel;
    wire                                                        accumulated_pixel_valid;

    wire        [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_rd_addr_delayed;
    wire        [IM_CACHE_COUNT-1 : 0]                          cache_rd_sel_delayed;

    //reg         [IM_CACHE_SIZE_WIDTH-1 : 0]                     pix_count;
    //integer                                                     i;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------


    always @(posedge clk) begin : init_blk
        if(reset) begin
//            top_pad                 <= 1'b0;
//            right_pad               <= 1'b0;
//            bottom_pad              <= 1'b0;
//            left_pad                <= 1'b0;
            max_row_count           <= {DIM_WIDTH{1'b0}};
            max_col_count           <= {DIM_WIDTH{1'b0}};
            max_row_offset          <= {DIM_WIDTH{1'b0}};
            max_col_offset          <= {DIM_WIDTH{1'b0}};
            col_div2_ceil           <= {DIM_WIDTH{1'b0}};
            accum_result            <= 1'b0;
        end
        else begin
            if(params_valid_in) begin
//                {top_pad, left_pad, bottom_pad, right_pad}
//                                    <= padding_mask_in;
//                {right_pad, left_pad, bottom_pad, top_pad}
//                                    <= padding_mask_in;
                accum_result        <= accum_result_in;
                //if(conv_size_in == CONV_SIZE_1_1) begin
                    max_row_count   <= max_row_in ;
                    max_col_count   <= max_col_in;
//                end
//                else if(conv_size_in == CONV_SIZE_3_3)begin
//                    max_row_count   <= max_row_in - 2;
//                    max_col_count   <= max_col_in - 2;
//                end
            end
//            max_row_offset          <= max_row_count - 1 + top_pad + bottom_pad;
//            max_col_offset          <= max_col_count - 1 + left_pad + right_pad;
            max_row_offset          <= max_row_count - 1;
            max_col_offset          <= max_col_count - 1;
            //col_div2_ceil       <= max_col_in[POOL_KERNEL_DIM_COUNT_WIDTH +: (DIM_WIDTH-POOL_KERNEL_DIM_COUNT_WIDTH)] + max_col_in[0 +: POOL_KERNEL_DIM_COUNT_WIDTH];
            col_div2_ceil           <= max_col_count/POOL_KERNEL_DIM + max_col_count%POOL_KERNEL_DIM;
        end
    end

    //***********************************************************************************
    //pipeline stage 1 start(addr computation)
    //***********************************************************************************
    assign is_row_odd = (row_count % 2 == 1) ? 1'b1 : 1'b0;
    assign is_col_odd = (col_count % 2 == 1) ? 1'b1 : 1'b0;
    always @(posedge clk) begin : addr_gen_blk
        if(reset) begin
            pixel_in_reg            <= {DATA_WIDTH{1'b0}};
            pixel_valid_in_reg      <= 1'b0;

            col_count               <= {DIM_WIDTH{1'b0}};
            row_count               <= {DIM_WIDTH{1'b0}};
            is_last_addr_reached    <= 1'b0;
        end
        else begin
            pixel_in_reg            <= pixel_in;
            pixel_valid_in_reg      <= pixel_valid_in;

            is_last_addr_reached
                                    <= 1'b0;
            if(pixel_valid_in) begin
                if(col_count == max_col_offset) begin
                    col_count       <= {DIM_WIDTH{1'b0}};
                    if(row_count == max_row_offset) begin
                        is_last_addr_reached
                                    <= 1'b1;
                        row_count   <= {DIM_WIDTH{1'b0}};
                    end
                    else begin
                        row_count   <= row_count + 1'b1;
                    end
                end
                else begin
                    col_count       <= col_count + 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            is_last_addr_reached_reg       <= 1'b0;
            cache_rd_addr_out              <= {(IM_CACHE_ADDR_WIDTH){1'b0}};
            cache_rd_sel_out               <= {(IM_CACHE_COUNT){1'b0}};
        end
        else begin
            is_last_addr_reached_reg       <= is_last_addr_reached;
            cache_rd_addr_out              <= (row_count/POOL_KERNEL_DIM) * col_div2_ceil + (col_count/2);
            cache_rd_sel_out               <= 4'b0;
            if(is_row_odd) begin
                if(is_col_odd) begin
                    cache_rd_sel_out[3]    <= 1'b1;
                end
                else begin
                    cache_rd_sel_out[2]    <= 1'b1;
                end
            end
            else begin
                if(is_col_odd) begin
                    cache_rd_sel_out[1]    <= 1'b1;
                end
                else begin
                    cache_rd_sel_out[0]    <= 1'b1;
                end
            end
        end
    end
//    //pixel is delayed by 2 cycles to sync with addr computation
//    shift_reg #(
//        .CLOCK_CYCLES   (2),
//        .DATA_WIDTH     (DATA_WIDTH + 1)    //data+valid
//    )
//    u_pixel_shift_reg_a (
//        .clk            (clk),
//        .enable         (1'b1),
//        .data_in        ({pixel_valid_in, pixel_in}),
//        .data_out       ({pixel_valid_in_reg, pixel_in_reg})
//    );
    //***********************************************************************************
    //pipeline stage 1 end (addr computation)
    //***********************************************************************************


    //***********************************************************************************
    //pipeline stage 2 start (block ram rd delay)
    //***********************************************************************************
    //delay data by IM_CACHE_DELAY cycles to sync with cache rd data
    shift_reg #(
        .CLOCK_CYCLES   (IM_CACHE_DELAY),
        .DATA_WIDTH     (DATA_WIDTH + 1)    //data+wr_en
    )
    u_pixel_shift_reg_b (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({(accum_result & pixel_valid_in_reg), pixel_in_reg}),  //pipeline branching done
        .data_out       ({pixel_valid_in_delayed, pixel_in_delayed})
        );

    //***********************************************************************************
    //pipeline stage 2 end (block ram rd delay)
    //***********************************************************************************

    //***********************************************************************************
    //pipeline stage 3 start (half add delay)
    //***********************************************************************************
    //delay wrt addr by IM_CACHE_DELAY + HALF_ADD_DELAY to sync with write data result
    shift_reg #(
        .CLOCK_CYCLES   (IM_CACHE_DELAY + HALF_ADD_DELAY),
        .DATA_WIDTH     (IM_CACHE_ADDR_WIDTH + IM_CACHE_COUNT + 1)    //last + addr + sel
    )
    u_addr_shift_reg (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({(accum_result & is_last_addr_reached), cache_rd_addr_out, cache_rd_sel_out}),
        .data_out       ({is_last_addr_reached_delayed, cache_rd_addr_delayed, cache_rd_sel_delayed})
    );

    //synchronized pixel in and cache pixel

    half_add
    u_half_add_final_b
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        (pixel_valid_in_delayed),
        .s_axis_a_tdata         (pixel_in_delayed),
        .s_axis_b_tvalid        (pixel_valid_in_delayed),
        .s_axis_b_tdata         (cache_data_in),
        .m_axis_result_tvalid   (accumulated_pixel_valid),
        .m_axis_result_tdata    (accumulated_pixel)
        );

    //***********************************************************************************
    //pipeline stage 3 end (half add delay)
    //***********************************************************************************

    always@(*) begin
        if(accum_result) begin
            cache_wrt_addr_out  = cache_rd_addr_delayed;
            cache_wrt_sel_out   = cache_rd_sel_delayed;
            cache_data_out      = accumulated_pixel;
            cache_wr_en_out     = accumulated_pixel_valid;
            cache_wr_last_out   = is_last_addr_reached_delayed;
        end
        else begin
            cache_wrt_addr_out  = cache_rd_addr_out;
            cache_wrt_sel_out   = cache_rd_sel_out;
            cache_data_out      = pixel_in_reg;
            cache_wr_en_out     = pixel_valid_in_reg;
            cache_wr_last_out   = is_last_addr_reached;
        end
    end

    //stat
    assign stat_row_addr_out    = row_count;
    assign stat_col_addr_out    = col_count;

endmodule
