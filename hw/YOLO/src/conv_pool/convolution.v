`timescale 1ns / 1ps

//`define BYPASS_ARITHMETIC
module convolution
    (
        clk,
        reset,

        max_cols_in,
        max_rows_in,
        conv_size_in,

        weights_in,
        weights_valid_in,

        window_in,
        window_valid_in,

        out_pix_out,
        valid_out
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
    parameter                                                             WIEGHT_COUNT_WIDTH = $clog2(CONV_KERNEL_DIM * CONV_KERNEL_DIM);
    localparam                                                            HALF_ADD_DELAY     = 4;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                                 clk;
    input                                                                 reset;

    input       [DIM_WIDTH-1 : 0]                                         max_cols_in;
    input       [DIM_WIDTH-1 : 0]                                         max_rows_in;
    input       [DIM_WIDTH-1 : 0]                                         conv_size_in;

    input       [DATA_WIDTH-1 : 0]                                        weights_in;
    input                                                                 weights_valid_in;

    input       [CONV_KERNEL_DIM*CONV_KERNEL_DIM*DATA_WIDTH -1 : 0]       window_in;
    input                                                                 window_valid_in;

    output reg  [DATA_WIDTH-1 : 0]                                        out_pix_out;
    output reg                                                            valid_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg         [WIEGHT_COUNT_WIDTH-1 : 0]                                weight_reg_addr;
    reg         [DATA_WIDTH * CONV_KERNEL_DIM * CONV_KERNEL_DIM -1 : 0]   weight_reg;

    wire        [CONV_KERNEL_DIM * CONV_KERNEL_DIM * DATA_WIDTH -1 : 0]   conv_mult_pix;
    wire        [CONV_KERNEL_DIM * CONV_KERNEL_DIM - 1: 0]                conv_mult_ovalid;

    wire                                                                  is_adders_used;
    //wire        [DATA_WIDTH -1 : 0]                                       conv_mult_pix_delayed_reg;
    //wire                                                                  conv_mult_pix_delayed_valid;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------------------------------------
// Instantiation of rldram3_axi4_slave
//---------------------------------------------------------------------------------------------------------------------

    always @(posedge clk) begin
        if(reset) begin
            weight_reg_addr                                                 <= {WIEGHT_COUNT_WIDTH{1'b0}};
            weight_reg                                                      <= {(DATA_WIDTH * CONV_KERNEL_DIM * CONV_KERNEL_DIM){1'b0}};
        end
        else begin
            if(weights_valid_in) begin
                if(weight_reg_addr == conv_size_in-1) begin
                    weight_reg_addr                                         <= {WIEGHT_COUNT_WIDTH{1'b0}};
                end
                else begin
                    weight_reg_addr                                         <= weight_reg_addr + 1'b1;
                end
                weight_reg[weight_reg_addr * DATA_WIDTH +: DATA_WIDTH]      <= weights_in;
            end
        end
    end

    `ifdef BYPASS_ARITHMETIC
        always @(*) begin
            out_pix_out = window_in [0 +: DATA_WIDTH];
            valid_out   = window_valid_in;
        end
    `else
    genvar i;
    generate
        for(i=0; i<CONV_KERNEL_DIM * CONV_KERNEL_DIM;i=i+1) begin : conv_mult
            half_mult
            u_conv_mult
            (
              .aclk                 (clk),
              .s_axis_a_tvalid      (window_valid_in),
              .s_axis_a_tdata       (window_in          [i *  DATA_WIDTH +: DATA_WIDTH]),
              .s_axis_b_tvalid      (window_valid_in),
              .s_axis_b_tdata       (weight_reg         [i *  DATA_WIDTH +: DATA_WIDTH]),
              .m_axis_result_tvalid (conv_mult_ovalid   [i]),
              .m_axis_result_tdata  (conv_mult_pix      [i *  DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    //replace with adder tree
    wire                                conv_mult_ovalid_int;
    //temporary
    wire  [4 * DATA_WIDTH-1 : 0]        conv_add_temp_a;
    wire  [4-1 : 0]                     conv_add_temp_a_valid;
    wire  [2 * DATA_WIDTH-1 : 0]        conv_add_temp_b;
    wire  [2-1 : 0]                     conv_add_temp_b_valid;
    wire  [2*DATA_WIDTH - 1   : 0]      conv_add_temp_c;
    wire  [2-1 : 0]                     conv_add_temp_c_valid;
    wire  [DATA_WIDTH - 1   : 0]        conv_add_result;
    wire                                conv_add_result_valid;

    assign conv_mult_ovalid_int = |conv_mult_ovalid;
    assign is_adders_used   = (conv_size_in == CONV_DIM_3_3) ? conv_mult_ovalid_int : 1'b0 ;    //pipeline branching

    genvar j;
    generate
        for(j=0;j<4;j=j+1) begin : conv_add_a
            half_add
            u_half_add
            (
                .aclk                   (clk),
                .s_axis_a_tvalid        ((is_adders_used & conv_mult_ovalid_int)),
                .s_axis_a_tdata         (conv_mult_pix          [2*j * DATA_WIDTH +: DATA_WIDTH]),
                .s_axis_b_tvalid        ((is_adders_used & conv_mult_ovalid_int)),
                .s_axis_b_tdata         (conv_mult_pix          [(2*j+1) * DATA_WIDTH +: DATA_WIDTH]),
                .m_axis_result_tvalid   (conv_add_temp_a_valid  [j]),
                .m_axis_result_tdata    (conv_add_temp_a        [j * DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    genvar k;
    generate
        for(k=0;k<2;k=k+1) begin : conv_add_b
            half_add
            u_half_add_b
            (
                .aclk                   (clk),
                .s_axis_a_tvalid        ((|conv_add_temp_a_valid)),
                .s_axis_a_tdata         (conv_add_temp_a        [2 * k * DATA_WIDTH +: DATA_WIDTH]),
                .s_axis_b_tvalid        ((|conv_add_temp_a_valid)),
                .s_axis_b_tdata         (conv_add_temp_a        [(2 * k + 1) * DATA_WIDTH +: DATA_WIDTH]),
                .m_axis_result_tvalid   (conv_add_temp_b_valid  [k]),
                .m_axis_result_tdata    (conv_add_temp_b        [k * DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    half_add
    u_half_add_final_a
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        ((|conv_add_temp_b_valid)),
        .s_axis_a_tdata         (conv_add_temp_b        [0 +: DATA_WIDTH]),
        .s_axis_b_tvalid        ((|conv_add_temp_b_valid)),
        .s_axis_b_tdata         (conv_add_temp_b        [DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_result_tvalid   (conv_add_temp_c_valid  [0]),
        .m_axis_result_tdata    (conv_add_temp_c        [0 +: DATA_WIDTH])
        );

    shift_reg #(
            .CLOCK_CYCLES           (HALF_ADD_DELAY * 3),
        .DATA_WIDTH             (DATA_WIDTH + 1)
    )
    u_shift_reg (
        .clk                    (clk),
        .enable                 (1'b1),
        .data_in                ({(conv_mult_ovalid[CONV_KERNEL_DIM * CONV_KERNEL_DIM - 1] & is_adders_used), conv_mult_pix[(CONV_KERNEL_DIM * CONV_KERNEL_DIM -1) * DATA_WIDTH +: DATA_WIDTH]}),
        .data_out               ({conv_add_temp_c_valid[1], conv_add_temp_c[DATA_WIDTH +: DATA_WIDTH]})
    );


    half_add
    u_half_add_final_b
    (
        .aclk                   (clk),
        .s_axis_a_tvalid        (|conv_add_temp_c_valid),
        .s_axis_a_tdata         (conv_add_temp_c        [0 +: DATA_WIDTH]),
        .s_axis_b_tvalid        (|conv_add_temp_c_valid),
        .s_axis_b_tdata         (conv_add_temp_c        [DATA_WIDTH +: DATA_WIDTH]),
        .m_axis_result_tvalid   (conv_add_result_valid),
        .m_axis_result_tdata    (conv_add_result)
    );

/*
 *
    //todo : adder tree
    always @(posedge clk) begin : test_blk
        if(reset) begin
            out_pix_out <= {DATA_WIDTH{1'b0}};
            valid_out   <= 1'b0;
        end
        else begin

            out_pix_out <= conv_mult_pix[0 * DATA_WIDTH +: DATA_WIDTH] + conv_mult_pix[1` * DATA_WIDTH +: DATA_WIDTH];
            valid_out   <= |conv_mult_ovalid;
        end
    end
*/


    always @(*) begin
        if(conv_size_in == CONV_DIM_3_3) begin
            out_pix_out = conv_add_result;
            valid_out   = conv_add_result_valid;
        end
        else if(conv_size_in == CONV_DIM_1_1) begin
            out_pix_out = conv_mult_pix [0 +: DATA_WIDTH];
            valid_out   = conv_mult_ovalid_int;
        end
        else begin
            out_pix_out = {DATA_WIDTH{1'b0}};
            valid_out   = 1'b0;
        end
    end
    `endif


endmodule