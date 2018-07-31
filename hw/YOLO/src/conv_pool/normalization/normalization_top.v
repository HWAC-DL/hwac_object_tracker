`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/13/2018 02:51:57 PM
// Design Name:
// Module Name: normalization_top
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
//////////////////////////////////////////////////////////////////////////////////


module normalization_top(
    clk,
    reset,

    noramlization_const_1,
    noramlization_const_2,
    activation_en,

    bram_data_1,
    bram_data_2,
    bram_data_3,
    bram_data_4,

    data_valid,
    data_last,

    pool_data_out,
    pool_data_valid_out,
    pool_data_last_out,

    image_width,
    image_hight,
    pooling_stride
    );

        `include "conv_pool/normalization/normalization_defs.v"

    localparam             activation_const = 16'h2e66;
    localparam                                      NORMALIZATION_CLK_CYCLES = 15;

    input                                           clk;
    input                                           reset;

    input       [NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_1;
    input       [NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_2;
    input                                           activation_en;

    input       [0:0]                               data_valid;
    input                                           data_last;

    input       [BRAM_DATA_WIDTH-1:0]               bram_data_1;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_2;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_3;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_4;

    output      [BRAM_DATA_WIDTH-1:0]               pool_data_out;
    output      [0:0]                               pool_data_valid_out;
    output                                          pool_data_last_out;

    input       [IMAGE_SIZE_WIDTH-1 : 0]            image_width;
    input       [IMAGE_SIZE_WIDTH-1 : 0]            image_hight;
    input       [1:0]                               pooling_stride;

    wire        [BRAM_DATA_WIDTH-1:0]               bram_data_int_1;
    wire        [BRAM_DATA_WIDTH-1:0]               bram_data_int_2;
    wire        [BRAM_DATA_WIDTH-1:0]               bram_data_int_3;
    wire        [BRAM_DATA_WIDTH-1:0]               bram_data_int_4;

    wire       [0:0]                               data_valid_int_1;
    wire       [0:0]                               data_valid_int_2;
    wire       [0:0]                               data_valid_int_3;
    wire       [0:0]                               data_valid_int_4;


   shift_reg #(
        .CLOCK_CYCLES(NORMALIZATION_CLK_CYCLES),
        .DATA_WIDTH  (1'b1)
    )
    u_shift_reg (
        .clk     (clk),
        .enable  (1'b1),
        .data_in (data_last),
        .data_out(pool_data_last_out)
    );

    normalization
    normalization_1
    (
            .clk(clk),

            .noramlization_const_1(noramlization_const_1),
            .noramlization_const_2(noramlization_const_2),
            .activation_const(activation_const),
        .activation_en        (activation_en),

            .pixel_data_in(bram_data_1),
            .pixel_data_valid_in(data_valid),

            .norm_data_out(bram_data_int_1),
            .norm_data_valid_out(data_valid_int_1)
    );

        normalization
        normalization_2
        (
                .clk(clk),

                .noramlization_const_1(noramlization_const_1),
                .noramlization_const_2(noramlization_const_2),
                .activation_const(activation_const),
            .activation_en        (activation_en),

                .pixel_data_in(bram_data_2),
                .pixel_data_valid_in(data_valid),

                .norm_data_out(bram_data_int_2),
                .norm_data_valid_out(data_valid_int_2)
        );
        normalization
        normalization_3
        (
                .clk(clk),

                .noramlization_const_1(noramlization_const_1),
                .noramlization_const_2(noramlization_const_2),
                .activation_const(activation_const),
            .activation_en        (activation_en),

                .pixel_data_in(bram_data_3),
                .pixel_data_valid_in(data_valid),

                .norm_data_out(bram_data_int_3),
                .norm_data_valid_out(data_valid_int_3)
         );

         normalization
         normalization_4
         (
                .clk(clk),

                .noramlization_const_1(noramlization_const_1),
                .noramlization_const_2(noramlization_const_2),
                .activation_const(activation_const),
            .activation_en        (activation_en),

                .pixel_data_in(bram_data_4),
                .pixel_data_valid_in(data_valid),

                .norm_data_out(bram_data_int_4),
                .norm_data_valid_out(data_valid_int_4)
          );

            pooling_mux_controller
            pool_max_inst
            (
                .clk(clk),
                .reset(reset),
                .bram_data_1(bram_data_int_1),
                .bram_data_2(bram_data_int_2),
                .bram_data_3(bram_data_int_3),
                .bram_data_4(bram_data_int_4),

                .pixel_data_valid(data_valid_int_1),

                .pool_data_out(pool_data_out),
                .pool_data_valid(pool_data_valid_out),

                .image_width(image_width),
                .image_hight(image_hight),
                .pooling_stride(pooling_stride)
            );
endmodule
