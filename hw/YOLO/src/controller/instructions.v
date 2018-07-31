`timescale 1ns / 1ps

module instructions(
        clk,
        reset,

        inst_in,
        inst_addr_in,
        inst_wr_en_in,

        cmd_out,
        buf_idx_out,

        ch4_cnt_out,
        flt4_cnt_out,
        addr_out,

        width_out,
        height_out,
        conv_size_out,
        pool_stride_out,
        padding_out,
        offset_out,
        wr_offset_out,

        total_out,
        save_results_out,
//        save_buf_idx_out,
        prev_weights_out,
        feed_bb_out,
        tb_pad_val_out,

        valid_out,
        next_in,

        state_vec_out
    );

//-------------------------------------------------------------------------------------------------
// Global constant headers
//-------------------------------------------------------------------------------------------------
    `include "../src/common/axi4_params.v"
    `include "../src/mem_if/mem_params.v"
    `include "../src/tiny_yolo_params.v"
//-------------------------------------------------------------------------------------------------
// Parameter definitions
//-------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------
// Localparam definitions
//-------------------------------------------------------------------------------------------------
    localparam  ROM_ADDR_WIDTH  = 11;
    localparam  ROM_DATA_WIDTH  = 72;

    localparam  STATE_WAIT_READY      = 0;
    localparam  STATE_ADDR0           = 1;
    localparam  STATE_ADDR1           = 2;
    localparam  STATE_DATA            = 3;
    localparam  STATE_WAIT_NXT        = 4;
    localparam  STATE_END             = 5;

    localparam  FSM_STATE_WIDTH       = 4;
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           clk;
    input                                           reset;

    input       [AXI4L_DATA_WIDTH*3 - 1:0]          inst_in;
    input       [AXI4L_DATA_WIDTH-1 :0]             inst_addr_in;
    input                                           inst_wr_en_in;

    output reg  [CMD_WIDTH-1:0]                     cmd_out;
    output reg  [MEM_BUF_IDX_WIDTH-1:0]             buf_idx_out;

    output reg  [CH_COUNT_WIDTH-1:0]                ch4_cnt_out;
    output reg  [FLT_COUNT_WIDTH-1:0]               flt4_cnt_out;
    output reg  [MEM_FULL_BEAT_ADDR_WIDTH-1:0]      addr_out;

    output reg  [DIM_WIDTH-1:0]                     width_out;
    output reg  [DIM_WIDTH-1:0]                     height_out;
    output reg  [CONV_SIZE_WIDTH-1:0]               conv_size_out;
    output reg  [STRIDE_WIDTH-1:0]                  pool_stride_out;
    output reg  [PADDING_WIDTH-1:0]                 padding_out;
    output reg  [MEM_BEAT_ADDR_WIDTH-1:0]           offset_out;
    output reg  [TOTAL_PXL_WIDTH-1:0]               wr_offset_out;

    output reg  [TOTAL_PXL_WIDTH-1:0]               total_out;
    output reg                                      save_results_out;
//    output reg  [MEM_BUF_IDX_WIDTH-1:0]             save_buf_idx_out;
    output reg                                      prev_weights_out;
    output reg                                      feed_bb_out;
    output reg                                      tb_pad_val_out;

    output reg                                      valid_out;
    input                                           next_in;

    output reg  [FSM_STATE_WIDTH-1:0]               state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    reg                                             mem_ready;
    reg                                             enb;
    reg         [ROM_ADDR_WIDTH-1:0]                addrb;
    wire        [ROM_DATA_WIDTH-1:0]                doutb;
    integer                                         state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------


    mem_instruction
    u_mem_instruction (
      .clka (clk),    // input wire clka
      .ena  (inst_wr_en_in),      // input wire ena
      .wea  (inst_wr_en_in),      // input wire [0 : 0] wea
      .addra(inst_addr_in[ROM_ADDR_WIDTH-1:0]),  // input wire [10 : 0] addra
      .dina (inst_in[ROM_DATA_WIDTH-1:0]),    // input wire [71 : 0] dina

      .clkb (clk),    // input wire clkb
      .enb  (enb),      // input wire enb
      .addrb(addrb),  // input wire [10 : 0] addrb
      .doutb(doutb)  // output wire [71 : 0] doutb
    );


    always@(posedge clk) begin
        if (reset) begin
            mem_ready       <= 1'b0;
        end
        else begin
            if (inst_in[0 +: CMD_WIDTH] == CMD_END && inst_wr_en_in) begin
                mem_ready   <= 1'b1;
            end
        end
    end

    always@(posedge clk) begin
        if (reset) begin
            cmd_out             <= {CMD_WIDTH{1'b0}};
            buf_idx_out         <= {MEM_BUF_IDX_WIDTH{1'b0}};
            width_out           <= {DIM_WIDTH{1'b0}};
            height_out          <= {DIM_WIDTH{1'b0}};
            conv_size_out       <= {CONV_SIZE_WIDTH{1'b0}};
            pool_stride_out     <= {STRIDE_WIDTH{1'b0}};
            padding_out         <= {PADDING_WIDTH{1'b0}};
            offset_out          <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            ch4_cnt_out         <= {CH_COUNT_WIDTH{1'b0}};
            flt4_cnt_out        <= {FLT_COUNT_WIDTH{1'b0}};
            addr_out            <= {MEM_FULL_BEAT_ADDR_WIDTH{1'b0}};
            total_out           <= {TOTAL_PXL_WIDTH{1'b0}};
            save_results_out    <= 1'b0;
            wr_offset_out       <= {TOTAL_PXL_WIDTH{1'b0}};
            prev_weights_out    <= 1'b0;
            feed_bb_out         <= 1'b0;
            tb_pad_val_out      <= 1'b0;

            valid_out           <= 1'b0;
            enb                 <= 1'b0;
            addrb               <= {ROM_ADDR_WIDTH{1'b0}};
            state               <= STATE_WAIT_READY;
        end
        else begin
            case (state)
                STATE_WAIT_READY: begin
                    if (mem_ready) begin
                        state   <= STATE_ADDR0;
                        enb     <= 1'b1;
                    end
                end
                STATE_ADDR0: begin
                    state       <= STATE_ADDR1;
                end
                STATE_ADDR1: begin
                    state       <= STATE_DATA;
                end
                STATE_DATA: begin
                    cmd_out     <= doutb[0 +: CMD_WIDTH];
                    buf_idx_out <= doutb[CMD_WIDTH +: MEM_BUF_IDX_WIDTH];

                    width_out       <= doutb[(6) +: DIM_WIDTH];
                    height_out      <= doutb[(6 + DIM_WIDTH) +: DIM_WIDTH];
                    conv_size_out   <= doutb[(6 + 2*DIM_WIDTH) +: CONV_SIZE_WIDTH];
                    pool_stride_out <= doutb[(6 + 2*DIM_WIDTH + CONV_SIZE_WIDTH) +: STRIDE_WIDTH];
                    padding_out     <= doutb[(6 + 2*DIM_WIDTH + CONV_SIZE_WIDTH + STRIDE_WIDTH) +: PADDING_WIDTH];
                    wr_offset_out   <= doutb[(6 + DIM_WIDTH) +: TOTAL_PXL_WIDTH];

                    addr_out        <= doutb[30 +: MEM_FULL_BEAT_ADDR_WIDTH];
                    ch4_cnt_out     <= doutb[33 +: CH_COUNT_WIDTH];
                    flt4_cnt_out    <= doutb[(33 + CH_COUNT_WIDTH) +: FLT_COUNT_WIDTH];

                    offset_out      <= {1'b0, {doutb[ROM_DATA_WIDTH-1: (30 + MEM_FULL_BEAT_ADDR_WIDTH)]}};
                    total_out       <= doutb[(30 + MEM_FULL_BEAT_ADDR_WIDTH) +: TOTAL_PXL_WIDTH];
                    save_results_out<= doutb[(30 + MEM_FULL_BEAT_ADDR_WIDTH + TOTAL_PXL_WIDTH)];
                    prev_weights_out<= doutb[(30 + MEM_FULL_BEAT_ADDR_WIDTH + TOTAL_PXL_WIDTH + 1)];
                    feed_bb_out     <= doutb[(30 + MEM_FULL_BEAT_ADDR_WIDTH + TOTAL_PXL_WIDTH + 2)];
                    tb_pad_val_out  <= doutb[(30 + MEM_FULL_BEAT_ADDR_WIDTH + TOTAL_PXL_WIDTH + 3)];

                    valid_out       <= 1'b1;
                    state           <= STATE_WAIT_NXT;
                end
                STATE_WAIT_NXT: begin
                    if (next_in) begin
                        valid_out   <= 1'b0;
                        addrb       <= addrb + 1'b1;
                        if (cmd_out == CMD_END) begin
                            state       <= STATE_END;
                        end
                        else begin
                            state       <= STATE_ADDR0;
                        end
                    end
                end
                STATE_END: begin
                    addrb               <= {ROM_ADDR_WIDTH{1'b0}};
                    state               <= STATE_ADDR0;
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (state)
            STATE_WAIT_READY:   state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_WAIT_READY;
            STATE_ADDR0:        state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_ADDR0;
            STATE_ADDR1:        state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_ADDR1;
            STATE_DATA:         state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_DATA;
            STATE_WAIT_NXT:     state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_WAIT_NXT;
            STATE_END:          state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_END;
        endcase
    end
endmodule
