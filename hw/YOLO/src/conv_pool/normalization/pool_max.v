`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/22/2018 08:22:14 PM
// Design Name:
// Module Name: pool_max
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


module pool_max(
        clk,
        reset,
        bram_data_1,
        bram_data_2,
        bram_data_3,
        bram_data_4,

        data_valid_1,
        data_valid_2,
        data_valid_3,
        data_valid_4,

        pool_data_out,
        pool_data_valid

    );

        `include "conv_pool/normalization/normalization_defs.v"

        localparam    DATA_12_P1_VALID_BIT = 0;
        localparam    DATA_34_P1_VALID_BIT = 1;
        localparam    HALF_COMP_CYCLES     = 2;

        //I/O
        input                                         clk;
        input                                         reset;

        input     [0:0]                               data_valid_1;
        input     [0:0]                               data_valid_2;
        input     [0:0]                               data_valid_3;
        input     [0:0]                               data_valid_4;

        input     [0:BRAM_DATA_WIDTH-1]               bram_data_1;
        input     [0:BRAM_DATA_WIDTH-1]               bram_data_2;
        input     [0:BRAM_DATA_WIDTH-1]               bram_data_3;
        input     [0:BRAM_DATA_WIDTH-1]               bram_data_4;

        output reg[0:BRAM_DATA_WIDTH-1]               pool_data_out;
        output                                        pool_data_valid;

        //internal wires and reg
        wire      [3*8-1:0]                           is_a_greater_b;
        //1 st stage delayed wires
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_1_reg;
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_2_reg;
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_3_reg;
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_4_reg;

        wire                                          data_valid_1_reg;
        wire                                          data_valid_2_reg;
        wire                                          data_valid_3_reg;
        wire                                          data_valid_4_reg;

        reg       [0:BRAM_DATA_WIDTH-1]               bram_data_max_34_p1;
        reg       [0:BRAM_DATA_WIDTH-1]               bram_data_max_12_p1;
        wire      [1:0]                               bram_data_p1_valid;
        //2nd stage
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_max_34_p1_reg;
        wire      [0:BRAM_DATA_WIDTH-1]               bram_data_max_12_p1_reg;
        wire      [1:0]                               bram_data_p1_valid_reg;
        //--------------------------------------------------------------------
        //1st pipeline stage
        //--------------------------------------------------------------------

        //shift register to synchronize data with 1st comparator stage
        shift_reg #(
            .CLOCK_CYCLES(HALF_COMP_CYCLES),
            .DATA_WIDTH  (4*(BRAM_DATA_WIDTH + 1))  //data+valid * 4
        )
        u_shift_reg_a (
            .clk         (clk),
            .enable      (1'b1),
            .data_in     ({data_valid_4, data_valid_3, data_valid_2, data_valid_1, bram_data_4, bram_data_3, bram_data_2, bram_data_1}),
            .data_out    ({data_valid_4_reg, data_valid_3_reg, data_valid_2_reg, data_valid_1_reg, bram_data_4_reg, bram_data_3_reg, bram_data_2_reg, bram_data_1_reg})
        );

        max_pool_comparator
        u_comp_a_b
        (
            .aclk                   (clk),
            .s_axis_a_tvalid        (data_valid_1),
            .s_axis_a_tdata         (bram_data_1),
            .s_axis_b_tvalid        (data_valid_2),
            .s_axis_b_tdata         (bram_data_2),
            .m_axis_result_tvalid   (),
            .m_axis_result_tdata    (is_a_greater_b[0 +: 8])
            );

        always @(*)begin
            if (data_valid_1_reg && data_valid_2_reg) begin
                bram_data_max_12_p1     = (is_a_greater_b[0] == 1'b1) ? bram_data_1_reg : bram_data_2_reg;
            end
            else begin
                if(data_valid_1_reg) begin
                    bram_data_max_12_p1 = bram_data_1_reg;
                end
                else if(data_valid_2_reg) begin
                    bram_data_max_12_p1 = bram_data_2_reg;
                end
                else begin
                    bram_data_max_12_p1 = {BRAM_DATA_WIDTH{1'b0}};
                end
            end
        end

        max_pool_comparator
        u_comp_c_d
        (
            .aclk                   (clk),
            .s_axis_a_tvalid        (data_valid_3),
            .s_axis_a_tdata         (bram_data_3),
            .s_axis_b_tvalid        (data_valid_4),
            .s_axis_b_tdata         (bram_data_4),
            .m_axis_result_tvalid   (),
            .m_axis_result_tdata    (is_a_greater_b[8 +: 8])
            );

        always @(*)begin
            if (data_valid_3_reg && data_valid_4_reg) begin
                bram_data_max_34_p1     = (is_a_greater_b[8] == 1'b1) ? bram_data_3_reg : bram_data_4_reg;
            end
            else begin
                if(data_valid_3_reg) begin
                    bram_data_max_34_p1 = bram_data_3_reg;
                end
                else if(data_valid_4_reg) begin
                    bram_data_max_34_p1 = bram_data_4_reg;
                end
                else begin
                    bram_data_max_34_p1 = {BRAM_DATA_WIDTH{1'b0}};
                end
            end
        end
        assign bram_data_p1_valid[0] = data_valid_1_reg | data_valid_2_reg;
        assign bram_data_p1_valid[1] = data_valid_3_reg | data_valid_4_reg;
        //--------------------------------------------------------------------
        //2nd pipeline stage
        //--------------------------------------------------------------------
        shift_reg #(
            .CLOCK_CYCLES(HALF_COMP_CYCLES),
            .DATA_WIDTH  (2*(BRAM_DATA_WIDTH+1))    //data +valid *2
        )
        u_shift_reg_b (
            .clk         (clk),
            .enable      (1'b1),
            .data_in     ({bram_data_p1_valid, bram_data_max_34_p1, bram_data_max_12_p1}),
            .data_out    ({bram_data_p1_valid_reg, bram_data_max_34_p1_reg, bram_data_max_12_p1_reg})
            );

        max_pool_comparator
        u_comp_e_f
        (
            .aclk                   (clk),
            .s_axis_a_tvalid        (bram_data_p1_valid[0]),
            .s_axis_a_tdata         (bram_data_max_12_p1),
            .s_axis_b_tvalid        (bram_data_p1_valid[1]),
            .s_axis_b_tdata         (bram_data_max_34_p1),
            .m_axis_result_tvalid   (),
            .m_axis_result_tdata    (is_a_greater_b[16 +: 8])
            );
        //assign pool_data_out = (is_a_greater_b[16]) ? bram_data_max_12_p1_reg : bram_data_max_34_p1_reg;
        assign pool_data_valid = bram_data_p1_valid_reg[0] | bram_data_p1_valid_reg[1];
        always@(*) begin
            if (bram_data_p1_valid_reg[0] && bram_data_p1_valid_reg[1]) begin
                pool_data_out     = (is_a_greater_b[16] == 1'b1) ? bram_data_max_12_p1_reg : bram_data_max_34_p1_reg;
            end
            else begin
                if(bram_data_p1_valid_reg[0]) begin
                    pool_data_out = bram_data_max_12_p1_reg;
                end
                else if(bram_data_p1_valid_reg[1]) begin
                    pool_data_out = bram_data_max_34_p1_reg;
                end
                else begin
                    pool_data_out = {BRAM_DATA_WIDTH{1'b0}};
                end
            end
        end

endmodule
