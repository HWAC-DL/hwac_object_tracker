`timescale 1ns / 1ps

module conv_stream
    (
        clk,
        reset,

        r_id_in,
        r_data_in,
        r_valid_in,
        r_ready_out,
        r_last_in,

        im_cols_out,
        im_rows_out,
        conv_result_cols_out,
        conv_result_rows_out,
        im_tot_pix_out,
        conv_dim_out,
        conv_size_out,
        pool_stride_out,
        padding_mask_out,
        padding_val_out,

        cache_blk_sel_out,
        accum_valid_out,
        save_result_valid_out,
        norm_param_a_out,
        norm_param_b_out,
        activation_en_out,
        save_result_ack_in,

        weights_out,
        out_dim_channel_sel_out,

        pixels_out,
        pixels_valid_out,
        pixels_last_out,
        cache_wrt_done_in,

        state_vector_out,
        rx_pix_count_out
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
   `include "../src/tiny_yolo_params.v"
   `include   "common/common_defs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam                                                 STATE_HEADER_0           = 0;
    localparam                                                 STATE_HEADER_1           = 1;
    localparam                                                 STATE_HEADER_2           = 2;
    localparam                                                 STATE_HEADER_3           = 3;
    localparam                                                 STATE_WEIGHTS            = 4;
    localparam                                                 STATE_PIXELS             = 5;
    localparam                                                 STATE_WAIT_DONE          = 6;
    localparam                                                 STATE_WAIT_SAVE_RESULT_ACK = 7;
    localparam                                                 STATE_BOTTOM_PAD_PIX     = 8;
    localparam                                                 STATE_RIGHT_PAD_PIX      = 9;

    parameter                                                  OUTPUT_DIM_WIDTH     	= $clog2(OUTPUT_DIM);
    parameter                                                  WIEGHT_COUNT_WIDTH  		= $clog2(CONV_KERNEL_DIM * CONV_KERNEL_DIM);

    localparam                                                  FSM_STATE_WIDTH          = 4;
    localparam                                                  FSM_STATE_VECTOR_WIDTH   = 4 * FSM_STATE_WIDTH;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [IN_STREAM_ID_WIDTH-1 : 0]                      r_id_in;
    input       [INPUT_DIM * DATA_WIDTH-1 : 0]                  r_data_in;
    input                                                       r_valid_in;
    output reg                                                  r_ready_out;
    input                                                       r_last_in;

    //parameters
    output reg  [DIM_WIDTH-1 : 0]                               im_cols_out;
    output reg  [DIM_WIDTH-1 : 0]                               im_rows_out;
    output reg  [DIM_WIDTH-1 : 0]                               conv_result_cols_out;
    output reg  [DIM_WIDTH-1 : 0]                               conv_result_rows_out;
    output reg  [TOTAL_PXL_WIDTH-1 : 0]                         im_tot_pix_out;
    output reg  [DIM_WIDTH-1 : 0]                               conv_dim_out;
    output reg  [CONV_SIZE_WIDTH-1 : 0]                         conv_size_out;
    output reg  [STRIDE_WIDTH-1 : 0]                            pool_stride_out;
    output reg  [PADDING_WIDTH-1 : 0]                           padding_mask_out;
    output reg  [DATA_WIDTH-1 : 0]                              padding_val_out;

    output reg                                                  cache_blk_sel_out;
    output reg                                                  save_result_valid_out;
    output reg                                                  accum_valid_out;
    output reg  [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_a_out;
    output reg  [OUTPUT_DIM * DATA_WIDTH-1 : 0]                 norm_param_b_out;
    output reg                                                  activation_en_out;
    input                                                       save_result_ack_in;

    output reg  [INPUT_DIM * DATA_WIDTH-1:0]                    weights_out;
    output reg  [OUTPUT_DIM-1 : 0]                              out_dim_channel_sel_out;

    output reg  [INPUT_DIM * DATA_WIDTH-1 : 0]                  pixels_out;
    output reg                                                  pixels_valid_out;
    output reg                                                  pixels_last_out;
    input                                                       cache_wrt_done_in;

    output      [FSM_STATE_VECTOR_WIDTH-1 : 0]                  state_vector_out;
    output reg  [TOTAL_PXL_WIDTH-1 : 0]                         rx_pix_count_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    //reg                                                         r_valid_reg;
    reg                                                         weights_valid_reg;
    reg         [WIEGHT_COUNT_WIDTH-1 : 0]                      weight_counter;
    reg         [OUTPUT_DIM_WIDTH-1 : 0]                        out_dim_channel_counter;
    //reg         [OUTPUT_DIM-1 : 0]                              out_dim_channel_sel;
    reg                                                         save_result_flag;
    wire                                                        top_pad;
    wire                                                        left_pad;
    wire                                                        right_pad;
    wire                                                        bottom_pad;
    reg         [DIM_WIDTH-1 : 0]                               im_cols_tmp_a;
    reg         [DIM_WIDTH-1 : 0]                               im_rows_tmp_a;

    reg         [DIM_WIDTH-1 : 0]                               pad_pix_count;


    integer                                                     state;
    reg         [FSM_STATE_WIDTH-1 : 0]                         state_int;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

    //assign out_dim_channel_sel_out = (r_valid_reg) ? out_dim_channel_sel : {OUTPUT_DIM{1'b0}};
    assign {right_pad, left_pad, bottom_pad, top_pad} = padding_mask_out;

    always @(posedge clk) begin
        if(reset) begin
            //r_valid_reg                                 <= 1'b0;
            weights_valid_reg                           <= 1'b0;
            r_ready_out                                 <= 1'b0;

            im_cols_out                                 <= {DIM_WIDTH{1'b0}};
            im_rows_out                                 <= {DIM_WIDTH{1'b0}};
            conv_result_cols_out                        <= {DIM_WIDTH{1'b0}};
            conv_result_rows_out                        <= {DIM_WIDTH{1'b0}};
            im_tot_pix_out                              <= {TOTAL_PXL_WIDTH{1'b0}};
            conv_dim_out                                <= {DIM_WIDTH{1'b0}};
            conv_size_out                               <= {CONV_SIZE_WIDTH{1'b0}};
            pool_stride_out                             <= {STRIDE_WIDTH{1'b0}};
            padding_mask_out                            <= {PADDING_WIDTH{1'b0}};
            padding_val_out                             <= {DATA_WIDTH{1'b0}};

            cache_blk_sel_out                           <= 1'b0;
            save_result_flag                            <= 1'b0;
            save_result_valid_out                       <= 1'b0;
            accum_valid_out                             <= 1'b0;
            norm_param_a_out                            <= {(OUTPUT_DIM * DATA_WIDTH){1'b0}};
            norm_param_b_out                            <= {(OUTPUT_DIM * DATA_WIDTH){1'b0}};
            activation_en_out                           <= 1'b0;

            weight_counter                              <= {WIEGHT_COUNT_WIDTH{1'b0}};
            out_dim_channel_counter                     <= {OUTPUT_DIM_WIDTH{1'b0}};
            weights_out                                 <= {(INPUT_DIM * DATA_WIDTH){1'b0}};
            //out_dim_channel_sel                         <= {OUTPUT_DIM{1'b0}};

            pixels_out                                  <= {(INPUT_DIM * DATA_WIDTH){1'b0}};
            pixels_valid_out                            <= 1'b0;
            pixels_last_out                             <= 1'b0;

            pad_pix_count                               <= {(DIM_WIDTH){1'b0}};
            rx_pix_count_out                            <= {TOTAL_PXL_WIDTH{1'b0}};
            state                                       <= STATE_HEADER_1;
        end
        else begin
            im_cols_tmp_a                               <= im_cols_out + left_pad + right_pad;
            im_rows_tmp_a                               <= im_rows_out + top_pad + bottom_pad;
            if(conv_size_out == CONV_SIZE_3_3) begin
                conv_result_cols_out                    <= im_cols_tmp_a - 2;
                conv_result_rows_out                    <= im_rows_tmp_a - 2;
            end
            else if(conv_size_out == CONV_SIZE_1_1) begin
                conv_result_cols_out                    <= im_cols_tmp_a;
                conv_result_rows_out                    <= im_rows_tmp_a;
            end
            case(state)
                STATE_HEADER_1 : begin
                    rx_pix_count_out                    <= {TOTAL_PXL_WIDTH{1'b0}};
                    r_ready_out                         <= 1'b1;
                    if(r_valid_in) begin
                        if(r_last_in) begin
                           state                        <=  STATE_PIXELS;
                        end
                        else if(r_data_in[SAVE_RESULT_FLAG_POS]) begin
                            state                       <= STATE_HEADER_2;
                        end
                        else begin
                            state                       <= STATE_WEIGHTS;
                        end
                    end
                    {activation_en_out, padding_val_out[0],save_result_flag, padding_mask_out, pool_stride_out, conv_size_out, im_tot_pix_out, im_rows_out, im_cols_out}
                                                        <= r_data_in[0 +: (INPUT_DIM * DATA_WIDTH - 23)];
                    if(r_data_in[CONV_SIZE_START +: CONV_SIZE_WIDTH] == CONV_SIZE_1_1) begin //todo : could this be done in the controller?
                        conv_dim_out                    <= CONV_DIM_1_1;
                    end
                    else if(r_data_in[CONV_SIZE_START +: CONV_SIZE_WIDTH] == CONV_SIZE_3_3) begin
                        conv_dim_out                    <= CONV_DIM_3_3;
                    end
                    else begin
                        conv_dim_out                    <= CONV_DIM_3_3;
                    end
                end
                STATE_HEADER_2 : begin
                    norm_param_a_out                    <= r_data_in;
                    if(r_valid_in) begin
                        state                           <= STATE_HEADER_3;
                    end
                end
                STATE_HEADER_3 : begin
                    norm_param_b_out                    <= r_data_in;
                    if(r_valid_in) begin
//                        if(r_last_in) begin
//                           state                        <=  STATE_PIXELS;
//                        end
//                        else begin
                            state                       <= STATE_WEIGHTS;
                        //end
                    end
                end
                STATE_WEIGHTS : begin
                    weights_out                         <= r_data_in;
                    if(r_valid_in) begin
                        if(r_last_in) begin
                            r_ready_out                 <= 1'b0;
                        end
                        weights_valid_reg               <= 1'b1;
                    end
                    else begin
                        weights_valid_reg               <= 1'b0;
                    end
                    if(weights_valid_reg) begin
                        if(weight_counter == conv_dim_out-1) begin
                            weight_counter              <= {WIEGHT_COUNT_WIDTH{1'b0}};
                            if(out_dim_channel_counter == OUTPUT_DIM-1) begin
                                r_ready_out             <= 1'b1;
                                out_dim_channel_counter <= {OUTPUT_DIM_WIDTH{1'b0}};
                                state                   <= STATE_PIXELS;
                            end
                            else begin
                                out_dim_channel_counter <= out_dim_channel_counter + 1'b1;
                            end
                        end
                        else begin
                            weight_counter              <= weight_counter + 1'b1;
                        end
                    end
                end
                STATE_PIXELS : begin
                    weights_valid_reg                   <= 1'b0;
                    //out_dim_channel_sel                 <= {OUTPUT_DIM{1'b0}};
                    pixels_out                          <= r_data_in;

                    if(r_valid_in) begin
                        rx_pix_count_out                <= rx_pix_count_out + 1'b1;
                        pixels_valid_out                <= 1'b1;
                    end
                    else begin
                        pixels_valid_out                <= 1'b0;
                    end

                    if(r_valid_in && r_last_in) begin
                        r_ready_out                     <= 1'b0;

                        if(bottom_pad) begin
                            state                       <= STATE_BOTTOM_PAD_PIX;
                        end
                        else if(right_pad) begin
                            state                       <= STATE_RIGHT_PAD_PIX;
                        end
                        else begin
                            pixels_last_out             <= 1'b1;
                            state                       <= STATE_WAIT_DONE;
                        end
                    end
                end
                STATE_BOTTOM_PAD_PIX : begin
                    pixels_last_out                     <= 1'b0;
                    pixels_out                          <= {(INPUT_DIM * DATA_WIDTH){1'b0}};
                    if(pad_pix_count == im_cols_out) begin  //first pix : pad_pix_count == 1
                        if(!right_pad) begin    //todo:last
                            pixels_valid_out            <= 1'b0;
                        end
                        else begin
                            pixels_last_out             <= 1'b1;
                        end
                        pad_pix_count                   <= {(DIM_WIDTH){1'b0}};
                        state                           <= STATE_WAIT_DONE;
                    end
                    else if(pad_pix_count == im_cols_out - 1) begin
                        pad_pix_count                   <= pad_pix_count + 1'b1;
                        if(!right_pad) begin
                            pixels_last_out             <= 1'b1;
                        end
                    end
                    else begin
                        pad_pix_count                   <= pad_pix_count + 1'b1;
                    end
                end
                STATE_RIGHT_PAD_PIX : begin
                    pixels_out                          <= {(INPUT_DIM * DATA_WIDTH){1'b0}};
                    pixels_valid_out                    <= 1'b1;
                    pixels_last_out                     <= 1'b1;
                    state                               <= STATE_WAIT_DONE;
                end
                STATE_WAIT_DONE : begin
                    pixels_last_out                     <= 1'b0;
                    pixels_valid_out                    <= 1'b0;
                    if(cache_wrt_done_in) begin
                        state                           <= STATE_WAIT_SAVE_RESULT_ACK;
                        if(save_result_flag) begin
                            cache_blk_sel_out           <= ~cache_blk_sel_out;
                            save_result_valid_out           <= 1'b1;
                        end
                    end
                end
                STATE_WAIT_SAVE_RESULT_ACK : begin
                    if(save_result_valid_out)begin
                        accum_valid_out                 <= 1'b0;
                        if(save_result_ack_in) begin
                            save_result_flag            <= 1'b0;
                            save_result_valid_out       <= 1'b0;

                            r_ready_out                 <= 1'b1;
                            state                       <= STATE_HEADER_1;
                        end
                    end
                    else begin
                        accum_valid_out                 <= 1'b1;
                        r_ready_out                     <= 1'b1;
                        state                           <= STATE_HEADER_1;
                    end
                end
            endcase
        end
    end

    integer i;
    always @(*) begin
        case(state)
            STATE_HEADER_1 : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_HEADER_2 : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_HEADER_3 : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_WEIGHTS : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
                for(i=0;i<OUTPUT_DIM;i=i+1) begin
                    if(i == out_dim_channel_counter && weights_valid_reg) begin
                        out_dim_channel_sel_out[i]  = 1'b1;
                    end
                end
            end
            STATE_PIXELS : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_BOTTOM_PAD_PIX : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_RIGHT_PAD_PIX : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_WAIT_DONE : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            STATE_WAIT_SAVE_RESULT_ACK : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
            default : begin
                out_dim_channel_sel_out = {OUTPUT_DIM{1'b0}};
            end
        endcase
    end

    always@(posedge clk) begin
        if(reset) begin
            state_int  <= {FSM_STATE_WIDTH{1'b0}};
        end
        else begin
            case(state)
                STATE_HEADER_1              : state_int <= STATE_HEADER_1;
                STATE_HEADER_2              : state_int <= STATE_HEADER_2;
                STATE_HEADER_3              : state_int <= STATE_HEADER_3;
                STATE_WEIGHTS               : state_int <= STATE_WEIGHTS;
                STATE_PIXELS                : state_int <= STATE_PIXELS;
                STATE_BOTTOM_PAD_PIX        : state_int <= STATE_BOTTOM_PAD_PIX;
                STATE_RIGHT_PAD_PIX         : state_int <= STATE_RIGHT_PAD_PIX;
                STATE_WAIT_DONE             : state_int <= STATE_WAIT_DONE;
                STATE_WAIT_SAVE_RESULT_ACK  : state_int <= STATE_WAIT_SAVE_RESULT_ACK;
        endcase
    end
    end

    fsm_monitor #(
        .INTSTATE_WIDTH       (FSM_STATE_WIDTH),
        .INTSTATE_VECTOR_WIDTH(FSM_STATE_VECTOR_WIDTH)
    )
    u_fsm_monitor (
        .clk                  (clk),
        .reset                (reset),
        .state_in             (state_int),
        .state_vector_out     (state_vector_out)
        );

endmodule
