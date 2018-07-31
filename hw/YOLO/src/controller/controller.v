
`timescale 1ns / 1ps

module controller
    (
        clk,
        reset,

        rd_tx_axis_tdata,
        rd_tx_axis_tvalid,
        rd_tx_axis_tready,

        rd_rx_axis_tdata,
        rd_rx_axis_tlast,
        rd_rx_axis_tvalid,
        rd_rx_axis_tready,

        cp_tx_axis_tdata,
        cp_tx_axis_tlast,
        cp_tx_axis_tvalid,
        cp_tx_axis_tready,

        cp_rx_axis_tdata,
        cp_rx_axis_tlast,
        cp_rx_axis_tvalid,
        cp_rx_axis_tready,

        wr_tx_axis_tdata,
        wr_tx_axis_tlast,
        wr_tx_axis_tvalid,
        wr_tx_axis_tready,

        bb_tx_axis_tdata,
        bb_tx_axis_tlast,
        bb_tx_axis_tvalid,
        bb_tx_axis_tready,

        inst_in,
        inst_addr_in,
        inst_wr_en_in,

        start_in,
        sw_bb_in,
        mem_wr_done_in,
        layer_end_out,
        done_out,

        data_counts_out,
        wr_state_out,
        rd_state_out,
        cp_header_out,
        loop_state_out,
        state_vec_out
    );

//-------------------------------------------------------------------------------------------------
// Global constant headers
//-------------------------------------------------------------------------------------------------
    `include "../src/common/axi4_params.v"
    `include "../src/common/axi3_params.v"
    `include "../src/mem_if/mem_params.v"
    `include "../src/tiny_yolo_params.v"
//-------------------------------------------------------------------------------------------------
// Parameter definitions
//-------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------
// Localparam definitions
//-------------------------------------------------------------------------------------------------

    localparam                      STATE_WAIT_START        = 0;
    localparam                      STATE_WAIT              = 1;
    localparam                      STATE_INIT_FULL         = 2;
    localparam                      STATE_RD_WEIGHTS        = 3;
    localparam                      STATE_RD_DATA           = 4;
    localparam                      STATE_RD_CHECK          = 5;
    localparam                      STATE_WR_DATA           = 6;
    localparam                      STATE_WR_CHECK          = 7;
    localparam                      STATE_LAYER_END         = 8;
    localparam                      STATE_END               = 9;
    localparam                      STATE_DONE              = 10;

    localparam                      FSM_STATE_WIDTH         = 4;
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           clk;
    input                                           reset;

    output      [AXI4S_DATA_WIDTH-1:0]              rd_tx_axis_tdata;
    output                                          rd_tx_axis_tvalid;
    input                                           rd_tx_axis_tready;

    input       [AXI4S_DATA_WIDTH-1 : 0]            rd_rx_axis_tdata;
    input                                           rd_rx_axis_tlast;
    input                                           rd_rx_axis_tvalid;
    output                                          rd_rx_axis_tready;

    output      [AXI4S_DATA_WIDTH-1 : 0]            cp_tx_axis_tdata;
    output                                          cp_tx_axis_tlast;
    output                                          cp_tx_axis_tvalid;
    input                                           cp_tx_axis_tready;

    input       [AXI4S_DATA_WIDTH-1 : 0]            cp_rx_axis_tdata;
    input                                           cp_rx_axis_tlast;
    input                                           cp_rx_axis_tvalid;
    output                                          cp_rx_axis_tready;

    output      [AXI4S_DATA_WIDTH-1 : 0]            wr_tx_axis_tdata;
    output                                          wr_tx_axis_tlast;
    output                                          wr_tx_axis_tvalid;
    input                                           wr_tx_axis_tready;

    output      [AXI4S_DATA_WIDTH-1:0]              bb_tx_axis_tdata;
    output                                          bb_tx_axis_tlast;
    output                                          bb_tx_axis_tvalid;
    input                                           bb_tx_axis_tready;

    input       [AXI4L_DATA_WIDTH*3 - 1:0]          inst_in;
    input       [AXI4L_DATA_WIDTH-1 :0]             inst_addr_in;
    input                                           inst_wr_en_in;

    input                                           start_in;
    input                                           sw_bb_in;
    input                                           mem_wr_done_in;
    output reg                                      layer_end_out;
    output reg                                      done_out;

    output      [2*AXI4L_DATA_WIDTH-1 : 0]          data_counts_out;
    output      [AXI4L_DATA_WIDTH-1 : 0]            loop_state_out;
    output      [3*AXI4L_DATA_WIDTH-1 : 0]          wr_state_out;
    output      [3*AXI4L_DATA_WIDTH-1 : 0]          rd_state_out;
    output      [2*AXI4L_DATA_WIDTH-1 : 0]          cp_header_out;
    output      [AXI4L_DATA_WIDTH-1 : 0]            state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    wire        [CMD_WIDTH-1:0]                     inst_cmd;
    wire        [MEM_BUF_IDX_WIDTH-1:0]             inst_buf_idx;
    wire        [CH_COUNT_WIDTH-1:0]                inst_ch4_cnt;
    wire        [FLT_COUNT_WIDTH-1:0]               inst_flt4_cnt;
    wire        [MEM_FULL_BEAT_ADDR_WIDTH-1:0]      inst_addr;
    wire        [DIM_WIDTH-1:0]                     inst_width;
    wire        [DIM_WIDTH-1:0]                     inst_height;
    wire        [CONV_SIZE_WIDTH-1:0]               inst_conv_size;
    wire        [STRIDE_WIDTH-1:0]                  inst_pool_stride;
    wire        [PADDING_WIDTH-1:0]                 inst_padding;
    wire        [MEM_BEAT_ADDR_WIDTH-1:0]           inst_offset;
    wire        [TOTAL_PXL_WIDTH-1:0]               inst_total_pxl;
    wire                                            inst_save_results;
    wire        [TOTAL_PXL_WIDTH-1:0]               inst_wr_offset;
    wire                                            inst_prev_weights;
    wire                                            inst_feed_bb;
    wire                                            inst_tb_pad_val;
    wire                                            inst_valid;
    reg                                             inst_next;

    reg         [MEM_BUF_IDX_WIDTH-1:0]             rd_buf_idx;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           rd_addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           rd_width;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           rd_offset;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           rd_count;
    reg         [AXI4S_DATA_WIDTH-1:0]              rd_header;
    reg                                             rd_header_valid;
    reg                                             rd_header_only;
    reg                                             rd_valid;
    wire                                            rd_ack;

    reg         [MEM_BUF_IDX_WIDTH-1:0]             wr_buf_idx;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           wr_addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           wr_width;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           wr_offset;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           wr_count;
    reg                                             wr_bb;
    reg                                             wr_valid;
    wire                                            wr_ack;

    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           d_rd_addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           d_rd_len;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           d_rd_cnt;
    reg         [MEM_BUF_IDX_WIDTH-1:0]             d_rd_buf_idx;
    reg         [MEM_FULL_BEAT_ADDR_WIDTH-1:0]      w_addr;
    reg         [DIM_WIDTH-1:0]                     width;
    reg         [DIM_WIDTH-1:0]                     height;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           offset;
    reg         [TOTAL_PXL_WIDTH-1:0]               total_pxls;
    reg         [TOTAL_PXL_WIDTH-1:0]               wr_total_pxls;
    reg         [PADDING_WIDTH-1:0]                 padding;
    reg         [CONV_SIZE_WIDTH-1:0]               conv_size;
    reg         [STRIDE_WIDTH-1:0]                  pool_stride;
    reg         [CH_COUNT_WIDTH-1:0]                ch4_cnt;
    reg         [CH_COUNT_WIDTH-1:0]                ch4_cnt_reg;
    reg         [FLT_COUNT_WIDTH-1:0]               flt4_cnt;
    reg                                             save_result;
    reg                                             prev_weights;
    reg                                             tb_pad_val;
    reg                                             full_loop;
    wire                                            activation;
    reg                                             layer_end;
    wire                                            wr_bb_cond;

    reg         [2*FSM_STATE_WIDTH-1:0]             state_reg;
    integer                                         state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------

    mem_buf_reader
    u_mem_buf_reader (
        .clk                (clk),
        .reset              (reset),

        .ctrl_buf_idx_in     (rd_buf_idx),
        .ctrl_addr_in        (rd_addr),
        .ctrl_width_in       (rd_width),
        .ctrl_count_in       (rd_count),
        .ctrl_offset_in      (rd_offset),
        .ctrl_header_in      (rd_header),
        .ctrl_header_valid_in(rd_header_valid),
        .ctrl_header_only_in (rd_header_only),
        .ctrl_valid_in       (rd_valid),
        .ctrl_ack_out        (rd_ack),

        .mem_tx_axis_tdata  (rd_tx_axis_tdata),
        .mem_tx_axis_tready (rd_tx_axis_tready),
        .mem_tx_axis_tvalid (rd_tx_axis_tvalid),

        .mem_rx_axis_tdata  (rd_rx_axis_tdata),
        .mem_rx_axis_tlast  (rd_rx_axis_tlast),
        .mem_rx_axis_tready (rd_rx_axis_tready),
        .mem_rx_axis_tvalid (rd_rx_axis_tvalid),

        .ctrl_tx_axis_tdata (cp_tx_axis_tdata),
        .ctrl_tx_axis_tlast (cp_tx_axis_tlast),
        .ctrl_tx_axis_tready(cp_tx_axis_tready),
        .ctrl_tx_axis_tvalid(cp_tx_axis_tvalid),

        .tx_count_out       (data_counts_out[15:0]),
        .tx_count_reg_out   (data_counts_out[31:16]),
        .state_vec_out      (state_vec_out[0 +: 2*FSM_STATE_WIDTH])
    );

    assign wr_bb_cond = sw_bb_in ? 1'b0 : wr_bb;

    mem_buf_writer
    u_mem_buf_writer (
        .clk                (clk),
        .reset              (reset),

        .ctrl_addr_in       (wr_addr),
        .ctrl_buf_idx_in    (wr_buf_idx),
        .ctrl_width_in      (wr_width),
        .ctrl_count_in      (wr_count),
        .ctrl_offset_in     (wr_offset),
//        .ctrl_feed_bb_in    (wr_bb),
        .ctrl_feed_bb_in    (wr_bb_cond),
        .ctrl_valid_in      (wr_valid),
        .ctrl_ack_out       (wr_ack),

        .ctrl_rx_axis_tdata (cp_rx_axis_tdata),
        .ctrl_rx_axis_tlast (cp_rx_axis_tlast),
        .ctrl_rx_axis_tready(cp_rx_axis_tready),
        .ctrl_rx_axis_tvalid(cp_rx_axis_tvalid),

        .mem_tx_axis_tdata  (wr_tx_axis_tdata),
        .mem_tx_axis_tlast  (wr_tx_axis_tlast),
        .mem_tx_axis_tready (wr_tx_axis_tready),
        .mem_tx_axis_tvalid (wr_tx_axis_tvalid),

        .bb_tx_axis_tdata   (bb_tx_axis_tdata),
        .bb_tx_axis_tlast   (bb_tx_axis_tlast),
        .bb_tx_axis_tvalid  (bb_tx_axis_tvalid),
        .bb_tx_axis_tready  (bb_tx_axis_tready),

        .rx_count_out       (data_counts_out[47:32]),
        .rx_count_reg_out   (data_counts_out[63:48]),
        .state_vec_out      (state_vec_out[2*FSM_STATE_WIDTH +: 2*FSM_STATE_WIDTH])
    );


    instructions
    u_instructions (
        .clk             (clk),
        .reset           (reset),

        .inst_in         (inst_in),
        .inst_addr_in    (inst_addr_in),
        .inst_wr_en_in   (inst_wr_en_in),

        .cmd_out         (inst_cmd),
        .buf_idx_out     (inst_buf_idx),
        .width_out       (inst_width),
        .height_out      (inst_height),
        .addr_out        (inst_addr),
        .offset_out      (inst_offset),
        .ch4_cnt_out     (inst_ch4_cnt),
        .flt4_cnt_out    (inst_flt4_cnt),
        .conv_size_out   (inst_conv_size),
        .pool_stride_out (inst_pool_stride),
        .padding_out     (inst_padding),
        .save_results_out(inst_save_results),
        .wr_offset_out   (inst_wr_offset),
        .total_out       (inst_total_pxl),
        .prev_weights_out(inst_prev_weights),
        .feed_bb_out     (inst_feed_bb),
        .tb_pad_val_out  (inst_tb_pad_val),

        .valid_out       (inst_valid),
        .next_in         (inst_next),

        .state_vec_out   (state_vec_out[4*FSM_STATE_WIDTH +: FSM_STATE_WIDTH])
    );

    assign activation = ~wr_bb;

    always@(posedge clk) begin
        if (reset) begin
            width                           <= 0;
            height                          <= 0;
            offset                          <= 0;  //sub_w * sub_w_count
            d_rd_addr                       <= 0;
            d_rd_buf_idx                    <= 0;
            d_rd_len                        <= 'h0;
            d_rd_cnt                        <= 'h0;
            conv_size                       <= 0;
            pool_stride                     <= 0;
            ch4_cnt                         <= 0;
            ch4_cnt_reg                     <= 0;
            flt4_cnt                        <= 1;
            save_result                     <= 1'b0;
            w_addr                          <= 0;
            wr_total_pxls                   <= 0;
            total_pxls                      <= {TOTAL_PXL_WIDTH{1'b0}};
            padding                         <= {PADDING_WIDTH{1'b0}};
            prev_weights                    <= 1'b0;
            tb_pad_val                      <= 1'b0;
            layer_end                       <= 1'b0;
            layer_end_out                   <= 1'b0;

            rd_buf_idx                      <= 0;
            rd_addr                         <= 0;
            rd_width                        <= 0;
            rd_offset                       <= 0;
            rd_count                        <= 0;
            rd_header                       <= {AXI4S_DATA_WIDTH{1'b0}};
            rd_header_valid                 <= 0;
            rd_header_only                  <= 0;
            rd_valid                        <= 1'b0;

            wr_buf_idx                      <= 0;
            wr_addr                         <= 0;
            wr_width                        <= 0;
            wr_offset                       <= 0;
            wr_count                        <= 0;
            wr_bb                           <= 1'b0;
            wr_valid                        <= 1'b0;

            full_loop                       <= 1'b0;
            inst_next                       <= 1'b0;
            done_out                        <= 1'b0;
            state                           <= STATE_WAIT_START;
        end
        else begin
            case (state)
                STATE_WAIT_START: begin
                    layer_end               <= 1'b0;
                    if (start_in) begin
                        done_out            <= 1'b0;
                        layer_end_out       <= 1'b0;
                        state               <= STATE_WAIT;
                    end
                end
                STATE_WAIT: begin
                    full_loop               <= 1'b0;
                    d_rd_buf_idx            <= inst_buf_idx;
                    w_addr                  <= inst_addr;
                    d_rd_addr               <= inst_addr[MEM_BEAT_ADDR_WIDTH-1:0];
                    d_rd_len                <= inst_width;
                    d_rd_cnt                <= inst_height;

                    width                   <= inst_width;
                    height                  <= inst_height;
                    offset                  <= inst_offset;
                    total_pxls              <= inst_total_pxl;
                    padding                 <= inst_padding;
                    conv_size               <= inst_conv_size;
                    pool_stride             <= inst_pool_stride;
                    save_result             <= inst_save_results;
                    prev_weights            <= inst_prev_weights;
                    tb_pad_val              <= inst_tb_pad_val;

                    wr_buf_idx              <= inst_buf_idx;
                    wr_addr                 <= inst_addr[MEM_BEAT_ADDR_WIDTH-1:0];
                    wr_width                <= inst_width;
                    wr_count                <= inst_height;
                    wr_offset               <= inst_offset;
                    wr_bb                   <= 1'b0;

                    if (inst_valid) begin
                        inst_next           <= 1'b1;
                        case (inst_cmd)
                            CMD_LD_W: begin
                                state       <= STATE_RD_WEIGHTS;
                            end
                            CMD_LD_D: begin
                                state       <= STATE_RD_DATA;
                            end
                            CMD_SV_D: begin
                                state       <= STATE_WR_DATA;
                            end
                            CMD_FULL: begin
                                state       <= STATE_INIT_FULL;
                            end
                            CMD_WAIT_END: begin
                                state       <= STATE_LAYER_END;
                            end
                            CMD_END: begin
                                state       <= STATE_DONE;
                            end
                        endcase
                    end
                end
                STATE_INIT_FULL: begin
                    inst_next               <= 1'b0;
                    d_rd_addr               <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
                    d_rd_len                <= total_pxls;
                    d_rd_cnt                <= 'h1;
                    wr_addr                 <= inst_wr_offset;
                    wr_total_pxls           <= (inst_wr_offset << 1) + inst_total_pxl;
                    wr_buf_idx              <= inst_buf_idx;
                    wr_width                <= inst_total_pxl;
                    wr_count                <= 'h1;
                    wr_offset               <= 'h0;
                    wr_bb                   <= inst_feed_bb;
                    ch4_cnt                 <= inst_ch4_cnt;
                    flt4_cnt                <= inst_flt4_cnt;
                    ch4_cnt_reg             <= inst_ch4_cnt;
                    save_result             <= 1'b0;
                    prev_weights            <= 1'b0;

//                    width                   <= total_pxls;
//                    height                  <= 'h1;

                    full_loop               <= 1'b1;
                    if (inst_valid & ~inst_next) begin
                        inst_next           <= 1'b1;
                        state               <= STATE_RD_WEIGHTS;
                    end
                end
                STATE_RD_WEIGHTS: begin
                    inst_next               <= 1'b0;
                    rd_buf_idx              <= w_addr[MEM_FULL_BEAT_ADDR_WIDTH-1:MEM_BEAT_ADDR_WIDTH];
                    rd_addr                 <= w_addr[MEM_BEAT_ADDR_WIDTH-1:0];
                    rd_width                <= wr_bb ? (save_result ? FC_WEIGHTS_PARAM_LEN :FC_WEIGHTS_LEN) : (save_result ? WEIGHTS_PARAM_LEN : WEIGHTS_LEN);
                    rd_count                <= 20'h1;
                    rd_offset               <= 20'h0;
                    rd_header               <= {23'b0, activation, tb_pad_val, save_result, padding, pool_stride, conv_size, total_pxls, height, width};
                    rd_header_valid         <= 1'b1;
                    rd_header_only          <= prev_weights;
                    rd_valid                <= 1'b1;
                    if (rd_ack) begin
                        rd_valid            <= 1'b0;
                        state               <= full_loop ? STATE_RD_DATA : STATE_WAIT;
                    end
                end
                STATE_RD_DATA: begin
                    inst_next               <= 1'b0;
                    rd_buf_idx              <= d_rd_buf_idx;
                    rd_addr                 <= d_rd_addr;
                    rd_width                <= d_rd_len;
                    rd_count                <= d_rd_cnt;
                    rd_offset               <= offset;
                    rd_header_valid         <= 1'b0;
                    rd_header_only          <= 1'b0;
                    rd_valid                <= 1'b1;
                    if (rd_ack) begin
                        rd_valid            <= 1'b0;
                        state               <= full_loop ? STATE_RD_CHECK : STATE_WAIT;
                    end
                end
                STATE_RD_CHECK: begin
                    ch4_cnt                 <= ch4_cnt - 1'b1;
                    w_addr                  <= w_addr + (wr_bb ? (save_result ? FC_WEIGHTS_PARAM_LEN :FC_WEIGHTS_LEN) : (save_result ? WEIGHTS_PARAM_LEN : WEIGHTS_LEN));
                    d_rd_addr               <= d_rd_addr + total_pxls;
                    if (ch4_cnt == 10'h2) begin
                        save_result         <= 1'b1;
                    end
                    else begin
                        save_result         <= 1'b0;
                    end

                    if (ch4_cnt == 10'h1) begin
                        state               <= STATE_WR_DATA;
                    end
                    else begin
                        state               <= STATE_RD_WEIGHTS;
                    end
                    $display("CTRL c4: %d n4: %d", ch4_cnt, flt4_cnt);
                end
                STATE_WR_DATA: begin
                    inst_next               <= 1'b0;
                    wr_valid                <= 1'b1;
                    if (wr_ack) begin
                        wr_valid            <= 1'b0;
                        state               <= full_loop ? STATE_WR_CHECK : STATE_WAIT;
                    end
                end
                STATE_WR_CHECK: begin
                    flt4_cnt                <= flt4_cnt - 1'b1;
                    wr_addr                 <= wr_addr + wr_total_pxls;
                    d_rd_addr               <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
                    ch4_cnt                 <= ch4_cnt_reg;
                    if (flt4_cnt == 1'b1) begin
                        state               <= STATE_END;
                    end
                    else begin
                        state               <= STATE_RD_WEIGHTS;
                    end
                end
                STATE_LAYER_END: begin
                    inst_next               <= 1'b0;
                    if (cp_rx_axis_tvalid & cp_rx_axis_tlast) begin
                        layer_end           <= 1'b1;
                        state               <= STATE_END;
                    end
                end
                STATE_END: begin
                    inst_next               <= 1'b0;
                    if (mem_wr_done_in) begin
                        layer_end_out       <= layer_end;
                        state               <= STATE_WAIT;
                    end
                end
                STATE_DONE: begin
                    inst_next               <= 1'b0;
                    done_out                <= 1'b1;
                    state                   <= STATE_WAIT_START;
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (state)
            STATE_WAIT_START       : state_reg <= STATE_WAIT_START;
            STATE_WAIT             : state_reg <= STATE_WAIT      ;
            STATE_INIT_FULL        : state_reg <= STATE_INIT_FULL ;
            STATE_RD_WEIGHTS       : state_reg <= STATE_RD_WEIGHTS;
            STATE_RD_DATA          : state_reg <= STATE_RD_DATA   ;
            STATE_RD_CHECK         : state_reg <= STATE_RD_CHECK  ;
            STATE_WR_DATA          : state_reg <= STATE_WR_DATA   ;
            STATE_WR_CHECK         : state_reg <= STATE_WR_CHECK  ;
            STATE_END              : state_reg <= STATE_END       ;
            STATE_DONE             : state_reg <= STATE_DONE      ;
            default                : state_reg <= 8'hff;
        endcase
    end

    assign state_vec_out[5*FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   = 4'b0;
    assign state_vec_out[6*FSM_STATE_WIDTH +: 2*FSM_STATE_WIDTH] = state_reg;

    assign loop_state_out = {8'b0, rd_ack, rd_valid, wr_ack, wr_valid, flt4_cnt, ch4_cnt};
    assign wr_state_out = {wr_ack, wr_valid, wr_bb, wr_offset, wr_count, wr_width, wr_addr, wr_buf_idx};
    assign rd_state_out = {rd_ack, rd_valid, rd_header_only, rd_offset, rd_count, rd_width, rd_addr, rd_buf_idx};
    assign cp_header_out = rd_header;

endmodule

