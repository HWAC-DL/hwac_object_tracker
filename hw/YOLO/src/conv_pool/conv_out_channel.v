`timescale 1ns / 1ps

module conv_out_channel
    (
        clk,
        reset,

        max_cols_in,
        max_rows_in,
        conv_size_in,

        weights_in,
        weights_valid_in,

        window_bus_in,
        window_bus_valid_in,

        conv_result_out,
        conv_result_valid_out
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

//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [DIM_WIDTH-1 : 0]                               max_cols_in;
    input       [DIM_WIDTH-1 : 0]                               max_rows_in;
    input       [DIM_WIDTH-1 : 0]                               conv_size_in;

    input       [INPUT_DIM * DATA_WIDTH-1 : 0]                  weights_in;
    input                                                       weights_valid_in;

    input       [CONV_KERNEL_DIM*CONV_KERNEL_DIM*INPUT_DIM*DATA_WIDTH-1:0]window_bus_in;
    input       [INPUT_DIM-1 : 0]                               window_bus_valid_in;

    output      [DATA_WIDTH - 1 : 0]                            conv_result_out;
    output                                                      conv_result_valid_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    wire        [INPUT_DIM * DATA_WIDTH-1 : 0]                  conv_result_bus;
    wire        [INPUT_DIM-1 : 0]                               conv_result_valid_bus;

    wire        [2 * DATA_WIDTH-1 : 0]                          conv_result_partial_add;
    wire        [1:0]                                           conv_result_partial_add_valid;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

    genvar i;
    generate
        for(i=0;i<INPUT_DIM;i=i+1) begin : input_channel_split
            convolution
            u_conv
            (
                .clk                (clk),
                .reset              (reset),

                .max_cols_in        (max_cols_in),
                .max_rows_in        (max_rows_in),
                .conv_size_in       (conv_size_in),

                .weights_in         (weights_in             [i*DATA_WIDTH+:DATA_WIDTH]),
                .weights_valid_in   (weights_valid_in),

                .window_in          (window_bus_in          [(i * CONV_KERNEL_DIM * CONV_KERNEL_DIM * DATA_WIDTH) +: (CONV_KERNEL_DIM * CONV_KERNEL_DIM * DATA_WIDTH)]),
                .window_valid_in    (window_bus_valid_in    [i]),

                .out_pix_out        (conv_result_bus        [i*DATA_WIDTH +: DATA_WIDTH]),
                .valid_out          (conv_result_valid_bus  [i])
            );
        end
    endgenerate

    half_add_dsp
    u_half_add_a
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        ((|conv_result_valid_bus)),
        .s_axis_a_tdata         (conv_result_bus                [0 * DATA_WIDTH +: DATA_WIDTH]),
        .s_axis_b_tvalid        ((|conv_result_valid_bus)),
        .s_axis_b_tdata         (conv_result_bus                [1 * DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_result_tvalid   (conv_result_partial_add_valid  [0]),
        .m_axis_result_tdata    (conv_result_partial_add        [0 * DATA_WIDTH +: DATA_WIDTH])
    );

    half_add_dsp
    u_half_add_b
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        ((|conv_result_valid_bus)),
        .s_axis_a_tdata         (conv_result_bus                [2 * DATA_WIDTH +: DATA_WIDTH]),
        .s_axis_b_tvalid        ((|conv_result_valid_bus)),
        .s_axis_b_tdata         (conv_result_bus                [3 * DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_result_tvalid   (conv_result_partial_add_valid  [1]),
        .m_axis_result_tdata    (conv_result_partial_add        [1 * DATA_WIDTH +: DATA_WIDTH])
        );

    half_add_dsp
    u_half_add_c
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        ((|conv_result_partial_add_valid)),
        .s_axis_a_tdata         (conv_result_partial_add        [0 * DATA_WIDTH +: DATA_WIDTH]),
        .s_axis_b_tvalid        ((|conv_result_partial_add_valid)),
        .s_axis_b_tdata         (conv_result_partial_add        [1 * DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_result_tvalid   (conv_result_valid_out),
        .m_axis_result_tdata    (conv_result_out)
    );


    //assign conv_result_out        = conv_result_bus[0 * DATA_WIDTH +: DATA_WIDTH];
    //assign conv_result_valid_out  = conv_result_valid_bus[0];

endmodule