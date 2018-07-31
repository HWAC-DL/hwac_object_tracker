`timescale 1ns / 1ps

module conv_pool_layer
    (
        clk,
        reset,

        r_id_in,
        r_data_in,
        r_valid_in,
        r_ready_out,
        r_last_in,

        t_data_out,
        t_valid_out,
        t_ready_in,
        t_last_out,

        stat_line_buff_row_count_out,
        stat_line_buff_col_count_out,
        stat_cache_writer_row_count_out,
        stat_cache_writer_col_count_out,
        conv_stream_state_out,
        rx_pix_count_out
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
    localparam                                                  IM_CACHE_ADDR_BUS_WIDTH     = IM_CACHE_ADDR_WIDTH * IM_CACHE_COUNT;

    localparam                                                  FSM_STATE_VECTOR_WIDTH      = 32;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [IN_STREAM_ID_WIDTH-1 : 0]                      r_id_in;
    input       [INPUT_DIM       * DATA_WIDTH-1 : 0]            r_data_in;
    input                                                       r_valid_in;
    output                                                      r_ready_out;
    input                                                       r_last_in;

    output       [OUTPUT_DIM*DATA_WIDTH-1 : 0]                  t_data_out;
    output                                                      t_valid_out;
    input                                                       t_ready_in;
    output                                                      t_last_out;

    output      [INPUT_DIM * DIM_WIDTH -1 : 0]                  stat_line_buff_row_count_out;
    output      [INPUT_DIM * DIM_WIDTH -1 : 0]                  stat_line_buff_col_count_out;
    output      [OUTPUT_DIM * DIM_WIDTH -1 : 0]                 stat_cache_writer_row_count_out;
    output      [OUTPUT_DIM * DIM_WIDTH -1 : 0]                 stat_cache_writer_col_count_out;
    output      [FSM_STATE_VECTOR_WIDTH-1 : 0]                  conv_stream_state_out;
    output      [TOTAL_PXL_WIDTH-1 : 0]                         rx_pix_count_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    wire        [INPUT_DIM* DATA_WIDTH-1:0]                     weights_bus;
    wire        [OUTPUT_DIM-1 : 0]                              out_dim_channel_sel;

    wire        [INPUT_DIM* DATA_WIDTH-1:0]                     pixel_bus;
    wire                                                        pixel_valid;
    wire                                                        pixel_last;

    wire        [DIM_WIDTH-1 : 0]                               im_cols;
    wire        [DIM_WIDTH-1 : 0]                               im_rows;
    wire        [DIM_WIDTH-1 : 0]                               conv_result_cols;
    wire        [DIM_WIDTH-1 : 0]                               conv_result_rows;
    wire        [DIM_WIDTH-1 : 0]                               im_cols_reg;
    wire        [DIM_WIDTH-1 : 0]                               im_rows_reg;
    wire        [TOTAL_PXL_WIDTH-1 : 0]                         im_tot_pix;
    wire        [CONV_SIZE_WIDTH-1 : 0]                         conv_size;
    wire        [DIM_WIDTH-1 : 0]                               conv_dim;
    wire        [STRIDE_WIDTH-1 : 0]                            pool_stride;
    wire        [STRIDE_WIDTH-1 : 0]                            pool_stride_reg;
    wire        [PADDING_WIDTH-1 : 0]                           padding_mask;
    wire        [DATA_WIDTH-1 : 0]                              padding_val;

    wire                                                        cache_blk_sel;
    wire                                                        accum_result_valid;
    wire                                                        save_result_valid;
    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_a;
    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_b;
    wire                                                        activation_en;
    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_a_reg;
    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_b_reg;
    wire                                                        activation_en_reg;
    wire                                                        save_result_ack;

    wire        [CONV_KERNEL_DIM*CONV_KERNEL_DIM*INPUT_DIM*DATA_WIDTH-1:0]window_bus;
    wire        [INPUT_DIM-1 : 0]                               window_bus_valid;

    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 conv_result_bus;
    wire        [OUTPUT_DIM-1 : 0]                              conv_result_valid_bus;

    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 cache_wrt_data_bus;
    wire        [OUTPUT_DIM * IM_CACHE_ADDR_WIDTH-1 : 0]        cache_wrt_addr_bus;
    wire        [OUTPUT_DIM * IM_CACHE_COUNT-1 : 0]             cache_wr_sel_bus;
    wire        [OUTPUT_DIM-1 : 0]                              cache_wr_en_bus;
    wire        [OUTPUT_DIM-1 : 0]                              cache_wr_last_bus;

    wire        [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 cache_rd_data_bus_a;
    wire        [OUTPUT_DIM * IM_CACHE_ADDR_WIDTH-1 : 0]        cache_rd_addr_bus_a;
    wire        [OUTPUT_DIM * IM_CACHE_COUNT-1 : 0]             cache_rd_sel_bus_a;

    wire        [OUTPUT_DIM * IM_CACHE_DATA_BUS_WIDTH-1 : 0]    cache_rd_data_bus_b;
    wire        [IM_CACHE_ADDR_BUS_WIDTH-1 : 0]                 cache_rd_addr_bus_b;


    wire                                                        bram_read_data_valid;
    wire                                                        bram_read_data_last;

    wire        [OUTPUT_DIM*DATA_WIDTH-1 : 0]                   pool_data;
    wire        [OUTPUT_DIM-1 : 0]                              pool_data_valid;
    wire        [OUTPUT_DIM-1 : 0]                              pool_data_last;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

    conv_stream
    u_conv_stream
    (
        .clk                        (clk),
        .reset                      (reset),

        .r_id_in                    (r_id_in),
        .r_data_in                  (r_data_in),
        .r_valid_in                 (r_valid_in),
        .r_ready_out                (r_ready_out),
        .r_last_in                  (r_last_in),

        .weights_out                (weights_bus),
        .out_dim_channel_sel_out    (out_dim_channel_sel),

        .im_cols_out                (im_cols),
        .im_rows_out                (im_rows),
        .conv_result_cols_out       (conv_result_cols),
        .conv_result_rows_out       (conv_result_rows),
        .im_tot_pix_out             (im_tot_pix),
        .conv_size_out              (conv_size),
        .conv_dim_out               (conv_dim),
        .pool_stride_out            (pool_stride),
        .padding_mask_out           (padding_mask),
        .padding_val_out            (padding_val),

        .cache_blk_sel_out          (cache_blk_sel),
        .accum_valid_out            (accum_result_valid),
        .save_result_valid_out      (save_result_valid),
        .norm_param_a_out           (norm_param_a),
        .norm_param_b_out           (norm_param_b),
        .activation_en_out          (activation_en),
        .save_result_ack_in         (save_result_ack),
//        .save_result_ack_in         (1'b1),

        .pixels_out                 (pixel_bus),
        .pixels_valid_out           (pixel_valid),
        .pixels_last_out            (pixel_last),
        .cache_wrt_done_in          ((|cache_wr_last_bus)),

        .state_vector_out           (conv_stream_state_out),
        .rx_pix_count_out           (rx_pix_count_out)
    );


    genvar j;
    generate
        for(j=0;j<INPUT_DIM;j=j+1) begin : line_buff_blk
            line_buffer
            u_line_buffer
            (
                .clk                (clk),
                .reset              (reset),
                .im_cols_in         (im_cols),
                .im_rows_in         (im_rows),
                .padding_mask_in    (padding_mask),
                .padding_val_in     (padding_val),
                .conv_size_in       (conv_size),
                .pixel_in           (pixel_bus       [j*DATA_WIDTH +: DATA_WIDTH]),
                .pixel_valid_in     (pixel_valid),
                .pixel_last_in      (pixel_last),
                .window_out         (window_bus      [j*(CONV_KERNEL_DIM*CONV_KERNEL_DIM*DATA_WIDTH) +: (CONV_KERNEL_DIM*CONV_KERNEL_DIM*DATA_WIDTH)]),
                .window_valid_out   (window_bus_valid[j]),

                .stat_row_addr_out  (stat_line_buff_row_count_out   [j*DIM_WIDTH +: DIM_WIDTH]),
                .stat_col_addr_out  (stat_line_buff_col_count_out   [j*DIM_WIDTH +: DIM_WIDTH])
            );
        end
    endgenerate

    genvar i;
    genvar k;
    generate
        for(i=0;i<OUTPUT_DIM;i=i+1) begin : out_channel_blk
            conv_out_channel
            u_conv_out_channel
            (
                .clk                    (clk),
                .reset                  (reset),

                .max_cols_in            (im_cols),
                .max_rows_in            (im_rows),
                .conv_size_in           (conv_dim),

                .weights_in             (weights_bus),
                .weights_valid_in       (out_dim_channel_sel[i]),

                .window_bus_in          (window_bus),
                .window_bus_valid_in    (window_bus_valid),

                .conv_result_out        (conv_result_bus        [i*DATA_WIDTH +: DATA_WIDTH]),
                .conv_result_valid_out  (conv_result_valid_bus  [i])
                );

            im_cache_writer
            u_im_cache_writer (
                .clk                    (clk),
                .reset                  (reset),

                .conv_size_in           (conv_size),
                .max_row_in             (conv_result_rows),
                .max_col_in             (conv_result_cols),
                .accum_result_in        (accum_result_valid),
                .params_valid_in        (1'b1), //todo:chng
                .pixel_in               (conv_result_bus        [i*DATA_WIDTH +: DATA_WIDTH]),
                .pixel_valid_in         (conv_result_valid_bus  [i]),

                .cache_rd_addr_out      (cache_rd_addr_bus_a    [i*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
                .cache_rd_sel_out       (cache_rd_sel_bus_a     [i*IM_CACHE_COUNT +: IM_CACHE_COUNT]),
                .cache_data_in          (cache_rd_data_bus_a    [i*DATA_WIDTH +: DATA_WIDTH]),

                .cache_data_out         (cache_wrt_data_bus     [i*DATA_WIDTH +: DATA_WIDTH]),
                .cache_wrt_addr_out     (cache_wrt_addr_bus     [i*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
                .cache_wrt_sel_out      (cache_wr_sel_bus       [i*IM_CACHE_COUNT +: IM_CACHE_COUNT]),
                .cache_wr_en_out        (cache_wr_en_bus        [i]),
                .cache_wr_last_out      (cache_wr_last_bus      [i]),

                .stat_row_addr_out      (stat_cache_writer_row_count_out    [i*DIM_WIDTH +: DIM_WIDTH]),
                .stat_col_addr_out      (stat_cache_writer_col_count_out    [i*DIM_WIDTH +: DIM_WIDTH])
                );

            /*
            for(k=0;k<IM_CACHE_COUNT;k=k+1) begin : cache_split_blk
                conv_cache_bram
                u_conv_cache
                (
                    .clka               (clk),
                    .wea                (cache_wr_en_bus[i] & cache_sel_bus[i*IM_CACHE_COUNT + k]),
                    .addra              (cache_wrt_addr_bus         [i*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
                    .dina               (cache_wrt_data_bus         [i*DATA_WIDTH +: DATA_WIDTH]),
                    .clkb               (clk),
                    .addrb              (),
                    .doutb              ()
                );
            end
            */
            conv_cache_blk
            u_conv_cache_blk
            (
                .clk                     (clk),
                .reset                   (reset),
                .cache_blk_sel_in        (cache_blk_sel),

                .cache_port_a_wrt_data_in(cache_wrt_data_bus    [i*DATA_WIDTH +: DATA_WIDTH]),
                .cache_port_a_wrt_addr_in(cache_wrt_addr_bus    [i*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
                .cache_port_a_wrt_sel_in (cache_wr_sel_bus      [i*IM_CACHE_COUNT +: IM_CACHE_COUNT]),
                .cache_port_a_wrt_en_in  (cache_wr_en_bus       [i]),

                .cache_port_a_rd_addr_in (cache_rd_addr_bus_a   [i*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
                .cache_port_a_rd_sel_in  (cache_rd_sel_bus_a    [i*IM_CACHE_COUNT +: IM_CACHE_COUNT]),
                .cache_port_a_rd_data_out(cache_rd_data_bus_a   [i*DATA_WIDTH +: DATA_WIDTH]),

                .cache_port_b_rd_addr_in (cache_rd_addr_bus_b),
                //.cache_port_b_rd_addr_in ({IM_CACHE_ADDR_WIDTH{1'b0}}),
                .cache_port_b_rd_data_out(cache_rd_data_bus_b   [i*IM_CACHE_DATA_BUS_WIDTH +: IM_CACHE_DATA_BUS_WIDTH])
            );
        end
    endgenerate

    //todo : insert normalize/activation/pooling logic here
    bram_controller
    u_bram_controller
    (
        .clk                      (clk),
        .reset                    (reset),

        .bram_enable              (),
        .bram_addr_1              (cache_rd_addr_bus_b [0 +: IM_CACHE_ADDR_WIDTH]),
        .bram_addr_2              (cache_rd_addr_bus_b [1 * IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
        .bram_addr_3              (cache_rd_addr_bus_b [2 * IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
        .bram_addr_4              (cache_rd_addr_bus_b [3 * IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH]),
        .bram_start_reading       (save_result_valid),
        .bram_start_ack           (save_result_ack),

        .pixel_data_valid_out     (bram_read_data_valid),
        .pixel_data_last_out      (bram_read_data_last),
        //.pooling_data_out_ready   (1'b1),
        .pooling_data_out_ready   (t_ready_in),

        .image_width              (conv_result_cols),
        .image_hight              (conv_result_rows),
        .pooling_stride           (pool_stride),
        .noramlization_const_1    (norm_param_a),
        .noramlization_const_2    (norm_param_b),
        .activation_const         (1),
        .activation_en            (activation_en),
        .noramlization_const_1_out(norm_param_a_reg),
        .noramlization_const_2_out(norm_param_b_reg),
        .activation_const_out     (),
        .activation_en_out        (activation_en_reg),
        .pooling_stride_r         (pool_stride_reg),
        .image_width_r            (im_cols_reg),
        .image_hight_r            (im_rows_reg)
    );

    generate
        for(i=0;i<OUTPUT_DIM;i=i+1) begin : normalization_bloak
            normalization_top
            norm_top_inst
            (
                .clk                    (clk),
                .reset                  (reset),

                .noramlization_const_1  (norm_param_a_reg [i * DATA_WIDTH +:DATA_WIDTH]),
                .noramlization_const_2  (norm_param_b_reg [i * DATA_WIDTH +:DATA_WIDTH]),
                .activation_en          (activation_en_reg),

                .bram_data_1            (cache_rd_data_bus_b [ i*IM_CACHE_DATA_BUS_WIDTH +: DATA_WIDTH]),
                .bram_data_2            (cache_rd_data_bus_b [ i*IM_CACHE_DATA_BUS_WIDTH + DATA_WIDTH +: DATA_WIDTH]),
                .bram_data_3            (cache_rd_data_bus_b [ i*IM_CACHE_DATA_BUS_WIDTH + 2*DATA_WIDTH  +: DATA_WIDTH]),
                .bram_data_4            (cache_rd_data_bus_b [ i*IM_CACHE_DATA_BUS_WIDTH + 3*DATA_WIDTH +: DATA_WIDTH]),

                .data_valid             (bram_read_data_valid),
                .data_last              (bram_read_data_last),

                .pool_data_out          (t_data_out[i * DATA_WIDTH +: DATA_WIDTH]),
                .pool_data_valid_out    (pool_data_valid[i]),
                .pool_data_last_out     (pool_data_last[i]),

                .image_width            (im_cols_reg),
                .image_hight            (im_rows_reg),
                .pooling_stride         (pool_stride_reg)
            );

        end
    endgenerate

    assign  t_valid_out = |pool_data_valid;
    assign  t_last_out  = |pool_data_last;

endmodule