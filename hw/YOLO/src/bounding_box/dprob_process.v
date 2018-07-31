`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/23/2018 06:28:12 PM
// Design Name:
// Module Name: dprob_process
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


module dprob_process(
    input               clk,
    input   [63:0]      axi_data,
    input               axi_valid,
    input               first_set,

    output      [15:0]      max_prob,
    output      [15:0]      min_prob,
    output      [15:0]      sum_prob,
    output                  valid_out

    );

    wire    [15:0]          mid_sum_prob1;
    wire                    mid_valid1;

    wire    [15:0]          mid_sum_prob2;
    wire                    mid_valid2;

    wire                    sum_valid;

    wire                    comp_valid_lvl_00;
    wire    [ 7:0]          comp_reslt_lvl_00;

    wire                    comp_valid_lvl_01;
    wire    [ 7:0]          comp_reslt_lvl_01;

    wire                    max_comp_valid_lvl_10;
    wire    [ 7:0]          max_comp_reslt_lvl_10;

    wire                    min_comp_valid_lvl_10;
    wire    [ 7:0]          min_comp_reslt_lvl_10;

    reg     [15:0]          mid_comp_max_prob1;
    reg     [15:0]          mid_comp_max_prob2;

    reg     [15:0]          mid_comp_min_prob1;
    reg     [15:0]          mid_comp_min_prob2;

    reg     [15:0]          mid_comp_max_prob1_r1;
    reg     [15:0]          mid_comp_max_prob2_r1;

    reg     [15:0]          mid_comp_min_prob1_r1;
    reg     [15:0]          mid_comp_min_prob2_r1;

    reg     [15:0]          mid_comp_max_prob1_r2;
    reg     [15:0]          mid_comp_max_prob2_r2;

    reg     [15:0]          mid_comp_min_prob1_r2;
    reg     [15:0]          mid_comp_min_prob2_r2;

    reg     [63:0]          axi_data_r;
    reg     [63:0]          axi_data_r2;

    reg                     axi_valid_r;
    reg                     axi_valid_r2;
    reg                     axi_valid_r3;

    reg     [15:0]          max_prob_r;
    reg     [15:0]          min_prob_r;
    wire                    first_set_i;

    //------------------------- ADDER ----------------------------------------------------------------

    floating_point_adder adder_lvl_00 (
        .aclk                           (clk),                // input wire aclk
        .s_axis_a_tvalid                (axi_valid),          // input wire s_axis_a_tvalid
        .s_axis_a_tdata                 (axi_data[15:0]),     // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid                (axi_valid),          // input wire s_axis_b_tvalid
        .s_axis_b_tdata                 (axi_data[31:16]),    // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid           (mid_valid1),         // output wire m_axis_result_tvalid
        .m_axis_result_tdata            (mid_sum_prob1)       // output wire [15 : 0] m_axis_result_tdata
    );


    floating_point_adder adder_lvl_01 (
        .aclk                           (clk),
        .s_axis_a_tvalid                (axi_valid),
        .s_axis_a_tdata                 (axi_data[47:32]),
        .s_axis_b_tvalid                (axi_valid),
        .s_axis_b_tdata                 (axi_data[63:48]),
        .m_axis_result_tvalid           (mid_valid2),
        .m_axis_result_tdata            (mid_sum_prob2)
    );

    floating_point_adder adder_lvl_10 (
        .aclk                           (clk),
        .s_axis_a_tvalid                (mid_valid1),
        .s_axis_a_tdata                 (mid_sum_prob1),
        .s_axis_b_tvalid                (mid_valid2),
        .s_axis_b_tdata                 (mid_sum_prob2),
        .m_axis_result_tvalid           (sum_valid),
        .m_axis_result_tdata            (sum_prob)
    );

    assign valid_out = sum_valid;

    //-------------------------  COMPARE  -------------------------------------------------------------

    floating_point_comp comp_lvl_00 (
        .aclk                           (clk),                          // input wire aclk
        .s_axis_a_tvalid                (axi_valid),                    // input wire s_axis_a_tvalid
        .s_axis_a_tdata                 (axi_data[15:0]),               // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid                (axi_valid),                    // input wire s_axis_b_tvalid
        .s_axis_b_tdata                 (axi_data[31:16]),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid           (comp_valid_lvl_00),            // output wire m_axis_result_tvalid
        .m_axis_result_tdata            (comp_reslt_lvl_00)             // output wire [7 : 0] m_axis_result_tdata
    );

    floating_point_comp comp_lvl_01 (
        .aclk                          (clk),
        .s_axis_a_tvalid               (axi_valid),
        .s_axis_a_tdata                (axi_data[47:32]),
        .s_axis_b_tvalid               (axi_valid),
        .s_axis_b_tdata                (axi_data[63:48]),
        .m_axis_result_tvalid          (comp_valid_lvl_01),
        .m_axis_result_tdata           (comp_reslt_lvl_01)
    );



    always @(posedge clk) begin
        axi_valid_r     <= axi_valid;
        axi_valid_r2    <= axi_valid_r;
        axi_valid_r3    <= axi_valid_r2;

        axi_data_r      <= axi_data;
        axi_data_r2     <= axi_data_r;

        mid_comp_max_prob1_r1 <= mid_comp_max_prob1;
        mid_comp_max_prob2_r1 <= mid_comp_max_prob2;

        mid_comp_min_prob1_r1 <= mid_comp_min_prob1;
        mid_comp_min_prob2_r1 <= mid_comp_min_prob2;

        mid_comp_max_prob1_r2 <= mid_comp_max_prob1_r1;
        mid_comp_max_prob2_r2 <= mid_comp_max_prob2_r1;

        mid_comp_min_prob1_r2 <= mid_comp_min_prob1_r1;
        mid_comp_min_prob2_r2 <= mid_comp_min_prob2_r1;
    end

    always @(posedge clk) begin
        if(comp_valid_lvl_00) begin
            if(comp_reslt_lvl_00[0]) begin
                mid_comp_max_prob1  <= axi_data_r2[15:0];
                mid_comp_min_prob1  <= axi_data_r2[31:16];
                // nmin <= axi_data_r2[31:16];
            end
            else begin
                mid_comp_max_prob1  <= axi_data_r2[31:16];
                mid_comp_min_prob1  <= axi_data_r2[15:0];
                //min    <= axi_data_r2[15:0];
            end
        end

        if(comp_valid_lvl_01) begin
            if(comp_reslt_lvl_01[0] | first_set_i) begin
                mid_comp_max_prob2  <= axi_data_r2[47:32];
            end
            else begin
                mid_comp_max_prob2  <= axi_data_r2[63:48];
            end
            
            if(!comp_reslt_lvl_01[0] | first_set_i) begin
                mid_comp_min_prob2  <= axi_data_r2[47:32];
            end
            else begin
                mid_comp_min_prob2  <= axi_data_r2[63:48];
            end

        end
    end

    floating_point_comp max_comp_lvl_10 (
        .aclk                          (clk),
        .s_axis_a_tvalid               (axi_valid_r3),
        .s_axis_a_tdata                (mid_comp_max_prob1),
        .s_axis_b_tvalid               (axi_valid_r3),
        .s_axis_b_tdata                (mid_comp_max_prob2),
        .m_axis_result_tvalid          (max_comp_valid_lvl_10),
        .m_axis_result_tdata           (max_comp_reslt_lvl_10)
        );

    floating_point_comp min_comp_lvl_10 (
        .aclk                          (clk),
        .s_axis_a_tvalid               (axi_valid_r3),
        .s_axis_a_tdata                (mid_comp_min_prob1),
        .s_axis_b_tvalid               (axi_valid_r3),
        .s_axis_b_tdata                (mid_comp_min_prob2),
        .m_axis_result_tvalid          (min_comp_valid_lvl_10),
        .m_axis_result_tdata           (min_comp_reslt_lvl_10)
    );

     always @(posedge clk) begin
        if(max_comp_valid_lvl_10) begin
            if(max_comp_reslt_lvl_10[0] ) begin
                max_prob_r      <= mid_comp_max_prob1_r2;
            end
            else begin
                max_prob_r      <= mid_comp_max_prob2_r2;
            end
        end

        if(min_comp_valid_lvl_10) begin
            if(min_comp_reslt_lvl_10[0] ) begin
                min_prob_r      <= mid_comp_min_prob2_r2;
            end
            else begin
                min_prob_r      <= mid_comp_min_prob1_r2;
            end
        end
    end

    shift_reg #(
        .CLOCK_CYCLES   (8),
        .DATA_WIDTH     (32)
    )
    max_data_shift_reg_b (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({max_prob_r, min_prob_r}),
        .data_out       ({max_prob, min_prob})
        );

    shift_reg #(
        .CLOCK_CYCLES   (5),
        .DATA_WIDTH     (1)
    )
    first_set_shift_reg_b (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        (first_set),
        .data_out       (first_set_i)
        );


endmodule
