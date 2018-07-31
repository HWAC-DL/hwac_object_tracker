`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05/16/2018 08:04:38 PM
// Design Name:
// Module Name: calc_dprob
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


module calc_dprob(
    input                      clk,
    input                      reset,

    input    [ 15:0]           prob_max_in,
    input    [ 15:0]           prob_min_in,
    input    [ 15:0]           prob_sum_in,
    input    [ 15:0]           scale_in,
    input                      valid_in,
    input                      last_in,
    input    [ 7: 0]           addr_in,
    input    [ 2: 0]           set_in,

    output  reg                valid_out,
    output  reg [ 7: 0]        addr_out,
    output  reg [ 2: 0]        set_out,
    output  reg                last_out

    );

    wire     [15:0]         mult_in_prob;
    wire                    mul_result_tvalid;
    wire     [ 15:0]        mul_result_tdata;

    wire     [ 15:0]        prob_sum_r6;

    wire                    div_result_tvalid;
    wire     [ 15:0]        div_result_tdata;


    reg      [ 15:0]        current_max;

    wire                    comp_valid;
    wire     [ 7:0]         comp_reslt;
    wire     [12:0]         set_adr_r22;


    assign mult_in_prob = (prob_sum_in[15] == 1) ? prob_min_in : prob_max_in;  //sign bit check
    floating_16_AxB scl_mul_max(
        .aclk                       (clk),                         // input wire aclk
        .s_axis_a_tvalid            (valid_in),                     // input wire s_axis_a_tvalid
        .s_axis_a_tdata             (mult_in_prob),                  // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid            (valid_in),                     // input wire s_axis_b_tvalid
        .s_axis_b_tdata             (scale_in),                     // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid       (mul_result_tvalid),            // output wire m_axis_result_tvalid
        .m_axis_result_tdata        (mul_result_tdata)              // output wire [15 : 0] m_axis_result_tdata
    );

    floating_A_div_B div_by_max (
        .aclk                       (clk),                          // input wire aclk
        .s_axis_a_tvalid            (mul_result_tvalid),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata             (mul_result_tdata),             // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid            (mul_result_tvalid),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata             (prob_sum_r6),                  // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid       (div_result_tvalid),            // output wire m_axis_result_tvalid
        .m_axis_result_tdata        (div_result_tdata)              // output wire [15 : 0] m_axis_result_tdata
    );

    shift_reg #(
        .CLOCK_CYCLES   (6),
        .DATA_WIDTH     (16)
    )
    prob_shift_reg_7 (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        (prob_sum_in),
        .data_out       (prob_sum_r6)
    );

    shift_reg #(
        .CLOCK_CYCLES   (21),
        .DATA_WIDTH     (13)
    )
    address_shift_reg_22 (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({last_in,valid_in,set_in,addr_in}),
        .data_out       (set_adr_r22)
    );


    float_comp_0_delay comp_max (
        .s_axis_a_tvalid                (div_result_tvalid),                    // input wire s_axis_a_tvalid
        .s_axis_a_tdata                 (div_result_tdata),               // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid                (div_result_tvalid),                    // input wire s_axis_b_tvalid
        .s_axis_b_tdata                 (current_max),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid           (comp_valid),            // output wire m_axis_result_tvalid
        .m_axis_result_tdata            (comp_reslt)             // output wire [7 : 0] m_axis_result_tdata
    );

    always @(posedge clk) begin
        if(reset) begin
            current_max     <= 16'hFC00;
            valid_out       <= 0;
            addr_out        <= 0;
            set_out         <= 0;
        end
        else begin
            if(comp_valid) begin
                if(comp_reslt[0]) begin
                    current_max     <= div_result_tdata;
                    addr_out        <= set_adr_r22[7:0];
                    set_out         <= set_adr_r22[10:8];
                end
            end
            valid_out       <= set_adr_r22[11];
            last_out        <= set_adr_r22[12];

            if(last_out & valid_out) begin
                current_max     <= 16'hFC00;
            end
        end
    end

endmodule
