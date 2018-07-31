`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/22/2018 11:13:01 PM
// Design Name:
// Module Name: normalization
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


module normalization(
        clk,


        noramlization_const_1,
        noramlization_const_2,
        activation_const,
        activation_en,

        pixel_data_in,
        pixel_data_valid_in,

        norm_data_out,
        norm_data_valid_out

    );

    `include "conv_pool/normalization/normalization_defs.v"

    input                                           clk;

    input       [0:0]                               pixel_data_valid_in;
    input       [BRAM_DATA_WIDTH-1:0]               pixel_data_in;

    input       [NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_1;
    input       [NORMALIZATION_CONST_WIDTH-1:0]     noramlization_const_2;
    input       [NORMALIZATION_CONST_WIDTH-1:0]     activation_const;
    input                                           activation_en;
    output      [0:0]                               norm_data_valid_out;
    output      [BRAM_DATA_WIDTH-1:0]               norm_data_out;

    reg         [0:0]                               norm_data_valid_r;
    reg         [BRAM_DATA_WIDTH-1:0]               norm_data_r;
    wire        [NORMALIZATION_CONST_WIDTH-1:0]     activ_const;

    wire        [0:0]                               norm_data_valid;
    wire        [BRAM_DATA_WIDTH-1:0]               norm_data;


    assign activ_const = ((norm_data[BRAM_DATA_WIDTH-1] == 0) || (activation_en == 1'b0)) ? 'h3c00 : 'h2E66; //sign bit check

    floating_point_0
    normalization (
      .aclk                     (clk),
      .s_axis_a_tvalid          (pixel_data_valid_in),
      .s_axis_a_tdata           (noramlization_const_1),
      .s_axis_b_tvalid          (pixel_data_valid_in),
      .s_axis_b_tdata           (pixel_data_in),
      .s_axis_c_tvalid          (pixel_data_valid_in),
      .s_axis_c_tdata           (noramlization_const_2),
      .m_axis_result_tvalid     (norm_data_valid),
      .m_axis_result_tdata      (norm_data)
    );

    floating_point_1
    activation (
      .aclk                     (clk),
      .s_axis_a_tvalid          (norm_data_valid),
      .s_axis_a_tdata           (norm_data),
      .s_axis_b_tvalid          (norm_data_valid),
      .s_axis_b_tdata           (activ_const),
      .m_axis_result_tvalid     (norm_data_valid_out),
      .m_axis_result_tdata      (norm_data_out)
        );

endmodule
