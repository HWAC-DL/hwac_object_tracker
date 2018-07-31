`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/11/2018 11:26:39 PM
// Design Name:
// Module Name: bram_controller
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
/////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module bram_controller(

    clk,
    reset,

    bram_enable,
    bram_addr_1,
    bram_addr_2,
    bram_addr_3,
    bram_addr_4,

    bram_start_reading,
    bram_start_ack,

    pixel_data_valid_out,
    pixel_data_last_out,

    pooling_data_out_ready,

    image_width,
    image_hight,
    pooling_stride,

    noramlization_const_1,
    noramlization_const_2,
    activation_const,
    activation_en,

    noramlization_const_1_out,
    noramlization_const_2_out,
    activation_en_out,

    activation_const_out,

    pooling_stride_r,
    image_width_r,
    image_hight_r
    );

    `include "common/common_defs.v"
    `include "conv_pool/normalization/normalization_defs.v"

    //I/O
    input                                                        clk;
    input                                                        reset;
    output                                                       bram_enable;
    output      [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_1;
    output      [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_2;
    output      [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_3;
    output      [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_4;

    input                                                        bram_start_reading;
    output                                                       bram_start_ack;

    output                                                       pixel_data_valid_out;
    output reg                                                   pixel_data_last_out;

    input       [0:0]                                            pooling_data_out_ready;

    input       [IMAGE_SIZE_WIDTH-1 : 0]                         image_width;
    input       [IMAGE_SIZE_WIDTH-1 : 0]                         image_hight;
    input       [1:0]                                            pooling_stride;

    input       [OUTPUT_DIM * NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_1;
    input       [OUTPUT_DIM * NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_2;
    input       [ NORMALIZATION_CONST_WIDTH-1:0]                 activation_const;
    input                                                        activation_en;

    output reg  [OUTPUT_DIM * NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_1_out;
    output reg  [OUTPUT_DIM * NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_2_out;
    output reg  [NORMALIZATION_CONST_WIDTH-1:0]                  activation_const_out;
    output reg                                                   activation_en_out;

    output reg  [1:0]                                            pooling_stride_r;
    output reg  [IMAGE_SIZE_WIDTH-1 :0 ]                         image_width_r;
    output reg  [IMAGE_SIZE_WIDTH-1 :0 ]                         image_hight_r;

    //internal reg/wire
    reg         [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_1_r;
    reg         [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_2_r;
    reg         [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_3_r;
    reg         [BRAM_ADDR_WIDTH-1 : 0]                          bram_addr_4_r;

    reg                                                          pixel_data_valid_r;

    reg                                                          bram_enable_r;
    reg                                                          bram_start_ack_r;

    reg         [IMAGE_SIZE_WIDTH-1 :0 ]                         column_shift_cnt;
    reg         [IMAGE_SIZE_WIDTH-1 :0 ]                         row_shift_cnt;

    integer                                                      state;
    
    reg                                                          bram_start_reading_p;
    reg         [IMAGE_SIZE_WIDTH-1 : 0]                         image_width_p;
    reg         [IMAGE_SIZE_WIDTH-1 : 0]                         image_hight_p;
    reg         [1:0]                                            pooling_stride_p;
    //---------------------------------------------------------------------------------------------------------------------
    // localparam definitions
    //---------------------------------------------------------------------------------------------------------------------
        localparam                                                      STATE_WAIT                              = 0;
        localparam                                                      STATE_WAIT_READY                        = 1;
        localparam                                                      STATE_STRIDE0_FIRST                     = 2;
        localparam                                                      STATE_STRIDE0_SECOND                    = 3;

        localparam                                                      STATE_STRIDE1_SAME_LVL_SAME_ADDR        = 5;
        localparam                                                      STATE_STRIDE1_SAME_LVL_DIFF_ADDR        = 6;
        localparam                                                      STATE_LAYER_FLUSH_1                     = 7;
        localparam                                                      STATE_LAYER_FLUSH_2                     = 8;
        localparam                                                      STATE_STRIDE2_SAME_ADDR                 = 11;
        localparam                                                      STATE_FINISH                            = 12;


    /* always @(posedge clk or posedge reset) begin
        if (reset) begin
            pooling_stride_r <= 0;
            image_width_r    <= 0;
            image_hight_r    <= 0;
        end
        else begin


            noramlization_const_1_out <= (bram_start_reading) ? noramlization_const_1 : 0;
            noramlization_const_2_out <= (bram_start_reading) ? noramlization_const_2 : 0;
            activation_const_out      <= (bram_start_reading) ? activation_const      : 0;
        end
    end */

    assign  bram_addr_1 = bram_addr_1_r;
    assign  bram_addr_2 = bram_addr_2_r;
    assign  bram_addr_3 = bram_addr_3_r;
    assign  bram_addr_4 = bram_addr_4_r;

    assign bram_enable = bram_enable_r;

    assign bram_start_ack = bram_start_ack_r;

    assign pixel_data_valid_out = pixel_data_valid_r;
    
    always @ (posedge clk) begin 
        bram_start_reading_p <= bram_start_reading;
        image_width_p        <= image_width;
        image_hight_p        <= image_hight;
        pooling_stride_p     <= pooling_stride;
    end 

    always @(posedge clk or posedge reset) begin

        if (reset)begin
            state                     <= STATE_WAIT;
            bram_addr_1_r             <= 0;
            bram_addr_2_r             <= 0;
            bram_addr_3_r             <= 0;
            bram_addr_4_r             <= 0;

            bram_start_ack_r          <= 0;
            bram_enable_r             <= 0;

            column_shift_cnt          <= 0;
            row_shift_cnt             <= 0;

            pooling_stride_r          <= 0;
            image_width_r             <= 0;
            image_hight_r             <= 0;

            noramlization_const_1_out <= 0;
            noramlization_const_2_out <= 0;
            activation_const_out      <= 0;
            activation_en_out         <= 1'b0;

            pixel_data_valid_r        <= 1'b0;
            pixel_data_last_out       <= 1'b0;
        end

        else begin
            case (state)
                STATE_WAIT : begin
                    bram_addr_1_r       <= 0;
                    bram_addr_2_r       <= 0;
                    bram_addr_3_r       <= 0;
                    bram_addr_4_r       <= 0;

                    bram_start_ack_r    <= 0;
                    bram_enable_r       <= 0;

                    column_shift_cnt    <= 0;
                    row_shift_cnt       <= 0;
                    pixel_data_valid_r  <= 1'b0;
                    pixel_data_last_out <= 1'b0;

                    if (bram_start_reading_p && pooling_data_out_ready) begin
                        if (pooling_stride_p == 0) begin
                            state <= STATE_STRIDE1_SAME_LVL_SAME_ADDR;
                        end
                        if (pooling_stride_p == 1) begin
                            state <= STATE_STRIDE1_SAME_LVL_SAME_ADDR;
                        end
                        if (pooling_stride_p == 2) begin
                            state <= STATE_STRIDE2_SAME_ADDR;
                        end

                        bram_start_ack_r <= 1'b1;
                        bram_enable_r      <= 1'b1;
                        pooling_stride_r <= pooling_stride_p;
                        image_width_r    <= image_width_p;
                        image_hight_r    <= image_hight_p;

                        noramlization_const_1_out <= noramlization_const_1;
                        noramlization_const_2_out <= noramlization_const_2;
                        activation_const_out      <= activation_const;
                        activation_en_out         <= activation_en;
                    end

                end

                STATE_STRIDE1_SAME_LVL_SAME_ADDR : begin
                    bram_start_ack_r <= 0;
                    bram_enable_r    <= 1'b1;

                    if (bram_addr_2_r >= 1)
                        pixel_data_valid_r <= 1'b1;  // to compensate the lag of initial block ram read


                    if (column_shift_cnt == image_width_r-1) begin
                        if (row_shift_cnt == image_hight_r-1) begin
                            state            <= STATE_LAYER_FLUSH_1;
                            bram_enable_r    <= 1'b0;

                        end
                        else if (row_shift_cnt[0] ==1) begin
                            state            <= STATE_STRIDE1_SAME_LVL_SAME_ADDR;
                            bram_addr_1_r    <= bram_addr_1_r - STRIDE_1_STATE_CHNGE_SIZE;
                            bram_addr_2_r    <= bram_addr_2_r - STRIDE_1_STATE_CHNGE_SIZE;
                            bram_addr_3_r    <= bram_addr_3_r + 1;
                            bram_addr_4_r    <= bram_addr_4_r + 1;
                        end
                        else begin
                            state            <= STATE_STRIDE1_SAME_LVL_SAME_ADDR;
                            bram_addr_1_r    <= bram_addr_1_r + 1;
                            bram_addr_2_r    <= bram_addr_2_r + 1;
                            bram_addr_3_r    <= bram_addr_3_r - STRIDE_1_STATE_CHNGE_SIZE;
                            bram_addr_4_r    <= bram_addr_4_r - STRIDE_1_STATE_CHNGE_SIZE;
                        end

                        column_shift_cnt <= 0;
                        row_shift_cnt    <= row_shift_cnt+1;
                    end
                    else begin
                        state <= STATE_STRIDE1_SAME_LVL_DIFF_ADDR;
                        bram_addr_1_r    <= bram_addr_1_r + 1;
                        bram_addr_3_r    <= bram_addr_3_r + 1;

                        column_shift_cnt <= column_shift_cnt + 1;
                    end
                end
                STATE_STRIDE1_SAME_LVL_DIFF_ADDR : begin
                    bram_enable_r    <= 1'b1;

                    if (bram_addr_1_r >= 1)
                        pixel_data_valid_r <= 1'b1;  // to compensate the lag of initial block ram read


                    bram_addr_2_r    <= bram_addr_2_r + 1;
                    bram_addr_4_r    <= bram_addr_4_r + 1;

                    column_shift_cnt <= column_shift_cnt + 1;

                    state <= STATE_STRIDE1_SAME_LVL_SAME_ADDR;

                end

                STATE_STRIDE2_SAME_ADDR :  begin
                    bram_enable_r    <= 1'b1;

                    bram_addr_1_r    <= bram_addr_1_r + 1;
                    bram_addr_2_r    <= bram_addr_2_r + 1;
                    bram_addr_3_r    <= bram_addr_3_r + 1;
                    bram_addr_4_r    <= bram_addr_4_r + 1;
                    column_shift_cnt <= column_shift_cnt + 1;

                    if (bram_addr_1_r >= 1)
                        pixel_data_valid_r <= 1'b1;


                    if (column_shift_cnt == ((image_width_r>>1)-1)) begin
                         column_shift_cnt <= 0;
                         row_shift_cnt <= row_shift_cnt + 1;
                         if (row_shift_cnt == ((image_hight_r>>1)-1)) begin
                            state <= STATE_LAYER_FLUSH_1;
                         end
                         else
                            state <= STATE_STRIDE2_SAME_ADDR;
                    end
                    else
                        state <= STATE_STRIDE2_SAME_ADDR;
                end

                STATE_LAYER_FLUSH_1 : begin
                    bram_enable_r       <= 1'b0;
                    pixel_data_last_out <= 1'b1;
                    pixel_data_valid_r  <= 1'b1;
                    state               <= STATE_FINISH;
                end
//                STATE_LAYER_FLUSH_2 : begin
//                    bram_enable_r <= 1'b0;
//                    state <= STATE_FINISH;
//                    pixel_data_valid_r <= 1'b1;
//                end

                STATE_FINISH             : begin
                    bram_enable_r       <= 1'b0;
                    pixel_data_valid_r  <= 1'b0;
                    pixel_data_last_out <= 1'b0;
                    state               <= STATE_WAIT;
                end
            endcase
        end

      end
endmodule
