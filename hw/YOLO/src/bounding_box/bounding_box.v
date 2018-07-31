`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/04/2018 05:18:18 PM
// Design Name:
// Module Name: bounding_box
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


module bounding_box(
   clk,
   reset,
   axi_data,
   axi_valid,
   axi_last,
   axi_ready,
   read_done,

   xywh_out,
   xywh_addr,
   set_num_out,
   xywh_valid
);


    input               clk;
    input               reset;
    input   [63:0]      axi_data;
    input   [0:0]       axi_valid;
    input   [0:0]       axi_last;
    input               read_done;
    output reg          axi_ready;


    output reg [63:0]       xywh_out;
    output reg [15:0]       xywh_addr;
    output reg [2:0]        set_num_out;
    output reg              xywh_valid;

    //////////////////////////////////////////////////////////

    localparam      SCALE_PROB_1        = 0;
    localparam      PROB_1              = 1;
    localparam      WAIT_PROCESS        = 2;
    localparam      READ_XYWH           = 3;
    localparam      INIT_STATE          = 4;
    localparam      WAIT_XYWH_READ      = 5;
    localparam      SCALE_PROB_WAIT     = 6;
    localparam      LAST_PROB_WAIT      = 7;

    localparam      CONSUME_INIT        = 0;
    localparam      CONSUME_BRAM1       = 1;
    localparam      CONSUME_BRAM2       = 2;
    localparam      CONSUME_BRAM3       = 3;
    localparam      CONSUME_BRAM4       = 4;
    localparam      CONSUME_BRAM5       = 5;



    localparam      PROB_ITERATION_COUNT = 5'd22;
    localparam      SET_ITERATION_COUNT  = 3'd4;
    localparam      PIXEL_COUNT          = 169;

    ///////////////////////////////////////////////////////////
    integer state;
    integer consumer_state;

    reg     [15 :0]         scale_data;
    wire     [15 :0]         scale_data_sig;
    reg                     scale_dvalid;
    reg     [7:0]           scale_addr;
    reg     [7:0]           scale_addr_r;
    wire     [7:0]           scale_addr_r26;

    reg     [63 :0]         prob_data;
    reg                     prob_dvalid;
    reg     [7:0]           prob_addr;

    reg     [7:0]           xywh_addr_int;

    wire    [7:0]           prob_addr_r13;
    wire    [7:0]           prob_addr_r18;
    wire    [7:0]           prob_addr_r22;

    reg     [15:0]          current_sum_prob;

    wire    [15:0]          current_sum_prob_s1;
//    wire    [15:0]          current_sum_prob_s2;
//    wire    [15:0]          current_sum_prob_s3;
//    wire    [15:0]          current_sum_prob_s4;
//    wire    [15:0]          current_sum_prob_s5;


    wire    [15:0]          new_sum_prob;
    wire                    new_sum_dvalid;

    reg     [15:0]          current_max_prob;
    reg     [15:0]          current_max_prob_r;
    reg     [15:0]          current_max_prob_r2;

    reg     [15:0]          current_min_prob;
    reg     [15:0]          current_min_prob_r;
    reg     [15:0]          current_min_prob_r2;

    wire    [15:0]          current_max_prob_s1;
    wire    [15:0]          current_min_prob_s1;
//    wire    [15:0]          current_max_prob_s2;
//    wire    [15:0]          current_max_prob_s3;
//    wire    [15:0]          current_max_prob_s4;
//    wire    [15:0]          current_max_prob_s5;




    reg     [15:0]          new_max_prob;
    wire                    new_max_dvalid;
    reg                     new_max_dvalid_r;
    reg     [15:0]          new_min_prob;
    wire                    new_min_dvalid;
    reg                     new_min_dvalid_r;

    wire    [ 7:0]          max_comp_reslt;
    wire    [ 7:0]          min_comp_reslt;

    wire    [15:0]          temp_max_prob;
    reg     [15:0]          temp_max_prob_r;
    reg     [15:0]          temp_max_prob_r2;
    wire    [15:0]          temp_min_prob;
    reg     [15:0]          temp_min_prob_r;
    reg     [15:0]          temp_min_prob_r2;


    wire    [15:0]          temp_sum_prob;
    wire                    temp_dvalid;

    reg     [5:0]           prob_count;


    reg     [4:0]           bram_en;
    reg     [4:0]           bram_en_i;
    wire     [4:0]          bram_chip_av_sum;
    wire     [4:0]          bram_chip_av_max;
    wire     [4:0]          bram_chip_av_min;

    reg     [4:0]           bram_chip_select;
    reg     [2:0]           set_count;
    wire                    scale_dvalid_sig;

    wire    [15:0]          calc_dprob_max;
    wire    [15:0]          calc_dprob_min;
    wire    [15:0]          calc_dprob_sum;
    wire    [15:0]          calc_dprob_scale;
    reg     [7:0]           calc_prob_addr;
    reg                     calc_valid;
    reg                     calc_last;
    reg     [2:0]           calc_set_count;

    wire                    calc_done;
    wire    [7:0]           calc_prob_addr_out;
    wire    [2:0]           calc_set_count_out;
    wire                    calc_valid_out;

    wire    [16*5 - 1:0]    calc_dprob_scale_init;

    reg    [7:0]            max_prob_addr;
    reg    [2:0]            max_prob_set;
    reg    [2:0]            max_prob_set_cnt;
    reg    [2:0]            xywh_last_cnt;

    reg    [63:0]           xywh_out_r;
    reg    [15:0]           xywh_addr_r;
    reg    [2:0]            set_num_out_r;
    reg                     xywh_valid_r;

    reg                     first_set;
    wire first_set_i;

    reg                     calc_valid_r    ;
    reg                     calc_last_r     ;
    reg   [7:0]             calc_prob_addr_r;
    reg   [2:0]             calc_set_count_r;

    always @(posedge clk) begin
        if(reset) begin
            scale_addr   <= 0;
            scale_data   <= 0;
            scale_dvalid <= 0;

            prob_addr    <= 0;
            prob_count   <= 0;
            bram_en      <= 5'b00001;
            set_count    <= 0;
            xywh_addr    <= 0;
            xywh_addr_int <= 0;
            xywh_out     <= 0;
            set_num_out  <= 0;
            xywh_valid      <= 1'b0;

            axi_ready    <= 1'b0;
            first_set    <= 1'b0;
            state        <= INIT_STATE;

        end
        else begin
            case(state)
                INIT_STATE : begin
                    scale_addr   <= 0;
                    scale_data   <= 0;
                    scale_dvalid <= 0;

                    prob_addr    <= 0;
                    prob_count   <= 0;
                    bram_en      <= 5'b00001;
                    set_count    <= 0;
                    xywh_addr    <= 0;
                    xywh_out     <= 0;
                    xywh_addr_int   <= 0;
                    set_num_out     <= 0;
                    xywh_last_cnt   <= 0;
                    xywh_valid      <= 1'b0;
                    first_set    <= 1'b1;
                    axi_ready    <= 1'b0;
                    state        <= SCALE_PROB_1;
                end
                SCALE_PROB_1 : begin
                    if(axi_valid)begin
                       scale_addr   <= scale_addr + 1'b1;
                       scale_addr_r <= scale_addr;
                       scale_data   <= axi_data[15:0];
                       scale_dvalid <= 1'b1;

                       prob_data    <= {16'd0,axi_data[63:16]};
                       prob_dvalid  <= 1'b1;
                       prob_addr    <= prob_addr + 1;
                       first_set    <= 1'b1;

                       if(axi_last) begin
                            state <= PROB_1;
                            prob_addr <=  0;
                            scale_addr   <= 0;
                       end
                    end
                    else begin
                        scale_dvalid <= 1'b0;
                        prob_dvalid  <= 1'b0;
                    end
                    axi_ready <= 1'b1;
                end
                PROB_1 : begin
                    axi_ready <= 1'b1;
                    first_set <= 1'b0;
                    scale_dvalid <= 1'b0;
                    if(axi_valid)begin
                        prob_data   <= axi_data;
                        prob_dvalid <= 1'b1;
                        prob_addr <= prob_addr + 1;
                        if(axi_last) begin
                            prob_count <= prob_count + 1'b1;
                            if(prob_count == PROB_ITERATION_COUNT ) begin
                                state <= SCALE_PROB_WAIT;
                                prob_count <= 0;
                                axi_ready <= 1'b0;
                                set_count <= set_count + 1'b1;
                                if(set_count == SET_ITERATION_COUNT) begin
                                    state <= LAST_PROB_WAIT;
                                end
                            end
                            prob_addr <=  0;
                        end
                    end
                    else begin
                        prob_dvalid <= 1'b0;
                    end
                end
                SCALE_PROB_WAIT : begin
                    prob_dvalid <= 1'b0;
                    if(prob_addr_r22 == 168 && new_sum_dvalid) begin
                        bram_en <= bram_en << 1;
                        state <= SCALE_PROB_1;
                    end
                end
                LAST_PROB_WAIT : begin
                    prob_dvalid <= 1'b0;
                    if(prob_addr_r22 == 168 && new_sum_dvalid) begin
                        bram_en <= 5'd0;
                        state <= WAIT_PROCESS;
                    end
                end
                WAIT_PROCESS : begin
                    axi_ready <= 1'b0;
                    xywh_valid      <= 1'b0;
                    if(calc_done & calc_valid_out) begin
                        max_prob_addr   <= calc_prob_addr_out;
                        max_prob_set    <= calc_set_count_out;
                        max_prob_set_cnt<= calc_set_count_out;
                        axi_ready       <= 1'b1;
                        state           <= READ_XYWH;
                    end
                end
                READ_XYWH : begin
                    if(axi_valid)begin
                        xywh_addr_int <= xywh_addr_int + 1'b1;

                        if((xywh_addr_int == max_prob_addr) && max_prob_set_cnt == 0) begin
                            xywh_out_r        <= axi_data;
                            xywh_addr_r       <= max_prob_addr;
                            set_num_out_r     <= max_prob_set;
                        end
                        if(axi_last) begin
                            max_prob_set_cnt <= max_prob_set_cnt - 1'b1;
                            xywh_last_cnt <= xywh_last_cnt + 1'b1;
                            xywh_addr_int <= 1'b0;
                       end
                       if(xywh_last_cnt == SET_ITERATION_COUNT) begin
                            if(axi_last) begin
                                axi_ready     <= 1'b0;
                                state <= WAIT_XYWH_READ;
                            end
                        end
                    end
                end
                WAIT_XYWH_READ :begin
                    xywh_out     <= xywh_out_r;
                    xywh_addr    <= xywh_addr_r;
                    set_num_out  <= set_num_out_r;
                    xywh_valid   <= 1'b1;

                    if(read_done) begin
                        state <= INIT_STATE;
                        xywh_valid   <= 1'b0;
                    end
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if(first_set_i) begin
            current_max_prob <= 16'hFC00;//current_max_prob_s1;
            current_min_prob <= 16'h7C00;
            current_sum_prob <= 0;//current_sum_prob_s1;
        end
        else begin
            current_max_prob <= current_max_prob_s1;
            current_min_prob <= current_min_prob_s1;
            current_sum_prob <= current_sum_prob_s1;
        end
    end

    dprob_process data_process_module (
        .clk                         (clk),
        .axi_data                    (prob_data),
        .axi_valid                   (prob_dvalid),
        .first_set                   (first_set),

        .max_prob                    (temp_max_prob),
        .min_prob                    (temp_min_prob),
        .sum_prob                    (temp_sum_prob),
        .valid_out                   (temp_dvalid)
    );

    shift_reg #(
        .CLOCK_CYCLES   (13),
        .DATA_WIDTH     (9)
    )
    addr_shift_reg_13 (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({first_set,prob_addr}),
        .data_out       ({first_set_i,prob_addr_r13})
    );

    shift_reg #(
        .CLOCK_CYCLES   (5),
        .DATA_WIDTH     (8)
    )
    addr_shift_reg_3 (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        (prob_addr_r13),
        .data_out       (prob_addr_r18)
    );

    shift_reg #(
        .CLOCK_CYCLES   (9),
        .DATA_WIDTH     (8)
    )
    addr_shift_reg_5 (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        (prob_addr_r13),
        .data_out       (prob_addr_r22)
    );

/*
    bmem_16_10_dp sum_prob_ram_s1 (
        .clka   (clk),                      // input wire clka
        .ena    (bram_en[0]),               // input wire ena
        .wea    (new_sum_dvalid),           // input wire [0 : 0] wea
        .addra  (prob_addr_r22),            // input wire [7 : 0] addra
        .dina   (new_sum_prob),             // input wire [15 : 0] dina
        .clkb   (clk),                      // input wire clkb
        .enb    (1'b1),                     // input wire enb
        .addrb  (prob_addr_r13),            // input wire [9 : 0] addrb
        .doutb  (current_sum_prob_s1)       // output wire [15 : 0] doutb
    );
*/
    bb_cache_block bb_cache_sum(
        .clk                (clk),
        .reset              (reset),

        //port a
        .port_a_wrt_data_in (new_sum_prob),
        .port_a_wrt_addr_in (prob_addr_r22),
        .port_a_wrt_en_in   (new_sum_dvalid),
        .port_a_rd_addr_in  (prob_addr_r13),
        .port_a_rd_data_out (current_sum_prob_s1),
        .port_a_chip_sel_in (bram_en),

        //port b
        .port_b_av_out      (bram_chip_av_sum),
        .port_b_rd_addr_in  (calc_prob_addr),
        .port_b_rd_data_out (calc_dprob_sum),
        .port_b_chip_sel_in (bram_chip_select)
    );


    floating_point_adder prob_adder (
        .aclk                           (clk),                  // input wire aclk
        .s_axis_a_tvalid                (temp_dvalid),          // input wire s_axis_a_tvalid
        .s_axis_a_tdata                 (current_sum_prob),     // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid                (temp_dvalid),          // input wire s_axis_b_tvalid
        .s_axis_b_tdata                 (temp_sum_prob),        // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid           (new_sum_dvalid),       // output wire m_axis_result_tvalid
        .m_axis_result_tdata            (new_sum_prob)          // output wire [15 : 0] m_axis_result_tdata
    );

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    floating_point_comp u_max_prob_comp (
        .aclk                          (clk),
        .s_axis_a_tvalid               (temp_dvalid),
        .s_axis_a_tdata                (current_max_prob),
        .s_axis_b_tvalid               (temp_dvalid),
        .s_axis_b_tdata                (temp_max_prob),
        .m_axis_result_tvalid          (new_max_dvalid),
        .m_axis_result_tdata           (max_comp_reslt)

        );

    floating_point_comp u_min_prob_comp (
        .aclk                          (clk),
        .s_axis_a_tvalid               (temp_dvalid),
        .s_axis_a_tdata                (current_min_prob),
        .s_axis_b_tvalid               (temp_dvalid),
        .s_axis_b_tdata                (temp_min_prob),
        .m_axis_result_tvalid          (new_min_dvalid),
        .m_axis_result_tdata           (min_comp_reslt)

    );

    always @(posedge clk) begin
        current_max_prob_r  <= current_max_prob;
        current_max_prob_r2 <= current_max_prob_r;

        current_min_prob_r  <= current_min_prob;
        current_min_prob_r2 <= current_min_prob_r;

        temp_max_prob_r     <= temp_max_prob;
        temp_max_prob_r2    <= temp_max_prob_r;

        temp_min_prob_r     <= temp_min_prob;
        temp_min_prob_r2    <= temp_min_prob_r;

        new_max_dvalid_r    <= new_max_dvalid;
        new_min_dvalid_r    <= new_min_dvalid;
    end

    always @(posedge clk) begin
        if(new_max_dvalid) begin
            if(max_comp_reslt[0]) begin
                new_max_prob  <= current_max_prob_r2;
            end
            else begin
                new_max_prob  <= temp_max_prob_r2;
            end
        end

        if(new_min_dvalid) begin
            if(min_comp_reslt[0] == 0) begin
                new_min_prob  <= current_min_prob_r2;
            end
            else begin
                new_min_prob  <= temp_min_prob_r2;
            end
        end
    end

/*    bmem_16_10_dp max_prob_ram_s1 (
        .clka   (clk),
        .ena    (bram_en[0]),
        .wea    (new_max_dvalid_r),
        .addra  (prob_addr_r18),
        .dina   (new_max_prob),
        .clkb   (clk),
        .enb    (1'b1),
        .addrb  (prob_addr_r13),
        .doutb  (current_max_prob_s1)
    );*/

    bb_cache_block bb_cache_max_prob(
        .clk                (clk),
        .reset              (reset),

        //port a
        .port_a_wrt_data_in (new_max_prob),
        .port_a_wrt_addr_in (prob_addr_r18),
        .port_a_wrt_en_in   (new_max_dvalid_r),
        .port_a_rd_addr_in  (prob_addr_r13),
        .port_a_rd_data_out (current_max_prob_s1),
        .port_a_chip_sel_in (bram_en),

        //port b
        .port_b_av_out      (bram_chip_av_max),
        .port_b_rd_addr_in  (calc_prob_addr),
        .port_b_rd_data_out (calc_dprob_max),
        .port_b_chip_sel_in (bram_chip_select)
    );


    bb_cache_block bb_cache_min_prob(
        .clk                (clk),
        .reset              (reset),

        //port a
        .port_a_wrt_data_in (new_min_prob),
        .port_a_wrt_addr_in (prob_addr_r18),
        .port_a_wrt_en_in   (new_min_dvalid_r),
        .port_a_rd_addr_in  (prob_addr_r13),
        .port_a_rd_data_out (current_min_prob_s1),
        .port_a_chip_sel_in (bram_en),

        //port b
        .port_b_av_out      (bram_chip_av_min),
        .port_b_rd_addr_in  (calc_prob_addr),
        .port_b_rd_data_out (calc_dprob_min),
        .port_b_chip_sel_in (bram_chip_select)
    );

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    bmem_16_10_dp scale_ram_s1 (
        .clka(clk),
        .ena(scale_dvalid_sig),
        .wea(bram_en[0]),
        .addra(scale_addr_r26),
        .dina(scale_data_sig),
        .clkb(clk),
        .enb(bram_chip_select[0]),
        .addrb(calc_prob_addr),
        .doutb(calc_dprob_scale_init[0 +: 16])
    );

    bmem_16_10_dp scale_ram_s2 (
        .clka(clk),
        .ena(scale_dvalid_sig),
        .wea(bram_en[1]),
        .addra(scale_addr_r26),
        .dina(scale_data_sig),
        .clkb(clk),
        .enb(bram_chip_select[1]),
        .addrb(calc_prob_addr),
        .doutb(calc_dprob_scale_init[16 +: 16])
    );

    bmem_16_10_dp scale_ram_s3 (
        .clka(clk),
        .ena(scale_dvalid_sig),
        .wea(bram_en[2]),
        .addra(scale_addr_r26),
        .dina(scale_data_sig),
        .clkb(clk),
        .enb(bram_chip_select[2]),
        .addrb(calc_prob_addr),
        .doutb(calc_dprob_scale_init[32 +: 16])
    );

    bmem_16_10_dp scale_ram_s4 (
        .clka(clk),
        .ena(scale_dvalid_sig),
        .wea(bram_en[3]),
        .addra(scale_addr_r26),
        .dina(scale_data_sig),
        .clkb(clk),
        .enb(bram_chip_select[3]),
        .addrb(calc_prob_addr),
        .doutb(calc_dprob_scale_init[48 +: 16])
    );

    bmem_16_10_dp scale_ram_s5 (
        .clka(clk),
        .ena(scale_dvalid_sig),
        .wea(bram_en[4]),
        .addra(scale_addr_r26),
        .dina(scale_data_sig),
        .clkb(clk),
        .enb(bram_chip_select[4]),
        .addrb(calc_prob_addr),
        .doutb(calc_dprob_scale_init[64 +: 16])
    );

    assign calc_dprob_scale = calc_dprob_scale_init[calc_set_count*16 +: 16];
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    sigmoid_ram_wrapper sigmoid_cal
        (
            .clk                    (clk),
            .reset_n                (~reset),
            .x_axis_data_in         (scale_data),
            .read_value_in          (scale_dvalid),
            .y_axis_data_out        (scale_data_sig),
            .y_axis_valid_out       (scale_dvalid_sig)
        );

        shift_reg #(
                .CLOCK_CYCLES   (26),
                .DATA_WIDTH     (8)
            )
            scl_addr_shift_reg_26 (
                .clk            (clk),
                .enable         (1'b1),
                .data_in        (scale_addr_r),
                .data_out       (scale_addr_r26)
            );

    always @(posedge clk) begin
        if(reset) begin
            calc_prob_addr <= 0;
            bram_chip_select <= 5'b00000;
            consumer_state <= CONSUME_INIT;
            calc_set_count  <= 0;
            calc_last       <= 1'b0;
            calc_valid      <= 1'b0;
        end
        else begin
            case(consumer_state)
                CONSUME_INIT : begin
                    if(bram_chip_av_sum[0] && bram_chip_av_max[0] && bram_chip_av_min[0]) begin
                        bram_chip_select <= 5'b00001;
                        calc_prob_addr   <= 0;
                        calc_set_count   <= 0;
                        consumer_state   <= CONSUME_BRAM1;
                        calc_valid       <= 1'b1;
                    end
                end
                CONSUME_BRAM1 : begin
                    if(calc_prob_addr < (PIXEL_COUNT - 1)) begin
                        calc_prob_addr   <= calc_prob_addr + 1'b1;
                    end
                    else begin
                        calc_valid       <= 1'b0;
                        if(bram_chip_av_sum[1] && bram_chip_av_max[1] && bram_chip_av_min[1]) begin
                            bram_chip_select <= 5'b00010;
                            calc_prob_addr   <= 0;
                            calc_set_count   <= 1;
                            consumer_state   <= CONSUME_BRAM2;
                            calc_valid       <= 1'b1;
                        end
                    end
                end
                CONSUME_BRAM2 : begin
                    if(calc_prob_addr < (PIXEL_COUNT - 1)) begin
                        calc_prob_addr   <= calc_prob_addr + 1'b1;
                    end
                    else begin
                        calc_valid       <= 1'b0;
                        if(bram_chip_av_sum[2] && bram_chip_av_max[2] && bram_chip_av_min[2]) begin
                            bram_chip_select <= 5'b00100;
                            calc_prob_addr   <= 0;
                            calc_set_count   <= 2;
                            consumer_state   <= CONSUME_BRAM3;
                            calc_valid       <= 1'b1;
                        end
                    end
                end
                CONSUME_BRAM3 : begin
                    if(calc_prob_addr < (PIXEL_COUNT - 1)) begin
                        calc_prob_addr   <= calc_prob_addr + 1'b1;
                    end
                    else begin
                        calc_valid       <= 1'b0;
                        if(bram_chip_av_sum[3] && bram_chip_av_max[3] && bram_chip_av_min[3]) begin
                            bram_chip_select <= 5'b01000;
                            calc_prob_addr   <= 0;
                            calc_set_count   <= 3;
                            consumer_state   <= CONSUME_BRAM4;
                            calc_valid       <= 1'b1;
                        end
                    end
                end
                CONSUME_BRAM4 : begin
                    if(calc_prob_addr < (PIXEL_COUNT - 1)) begin
                        calc_prob_addr   <= calc_prob_addr + 1'b1;
                    end
                    else begin
                        calc_valid       <= 1'b0;
                        if(bram_chip_av_sum[4] && bram_chip_av_max[4] && bram_chip_av_min[4]) begin
                            bram_chip_select <= 5'b10000;
                            calc_prob_addr   <= 0;
                            calc_set_count   <= 4;
                            consumer_state   <= CONSUME_BRAM5;
                            calc_valid       <= 1'b1;
                        end
                    end
                end
                CONSUME_BRAM5 : begin
                    if(calc_prob_addr < (PIXEL_COUNT - 1)) begin
                        calc_prob_addr   <= calc_prob_addr + 1'b1;
                    end
                    else begin
                        calc_valid       <= 1'b0;
                        calc_last        <= 1'b0;
                        if(calc_done) begin
                            bram_chip_select <= 5'b00000;
                            calc_prob_addr   <= 0;
                            calc_set_count   <= 0;
                            consumer_state   <= CONSUME_INIT;
                        end
                    end
                    if(calc_prob_addr == (PIXEL_COUNT - 2)) begin
                        calc_last    <= 1'b1;
                    end
                end
            endcase
        end
    end

    always@(posedge clk) begin
        calc_valid_r       <= calc_valid;
        calc_last_r        <= calc_last;
        calc_prob_addr_r   <= calc_prob_addr;
        calc_set_count_r   <= calc_set_count;
    end


    calc_dprob prob_max_finder(
        .clk                    (clk),
        .reset                  (reset),

        .prob_max_in            (calc_dprob_max     ),
        .prob_min_in            (calc_dprob_min),
        .prob_sum_in            (calc_dprob_sum     ),
        .scale_in               (calc_dprob_scale   ),
        .valid_in               (calc_valid_r         ),
        .last_in                (calc_last_r          ),
        .addr_in                (calc_prob_addr_r     ),
        .set_in                 (calc_set_count_r     ),

        .valid_out              (calc_valid_out),
        .addr_out               (calc_prob_addr_out ),
        .set_out                (calc_set_count_out  ),
        .last_out               (calc_done )
    );

endmodule
