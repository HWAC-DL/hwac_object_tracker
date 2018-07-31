`timescale 1ns / 1ps

module mem_buf_writer
    (
        clk,
        reset,

        ctrl_buf_idx_in,
        ctrl_addr_in,
        ctrl_width_in,
        ctrl_offset_in,
        ctrl_count_in,
        ctrl_feed_bb_in,
        ctrl_valid_in,
        ctrl_ack_out,

        ctrl_rx_axis_tdata,
        ctrl_rx_axis_tlast,
        ctrl_rx_axis_tvalid,
        ctrl_rx_axis_tready,

        mem_tx_axis_tdata,
        mem_tx_axis_tlast,
        mem_tx_axis_tvalid,
        mem_tx_axis_tready,

        bb_tx_axis_tdata,
        bb_tx_axis_tlast,
        bb_tx_axis_tvalid,
        bb_tx_axis_tready,

        rx_count_out,
        rx_count_reg_out,
        state_vec_out
    );

//-------------------------------------------------------------------------------------------------
// Global constant headers
//-------------------------------------------------------------------------------------------------
    `include "../src/common/axi4_params.v"
    `include "../src/common/axi3_params.v"
    `include "../src/mem_if/mem_params.v"
//-------------------------------------------------------------------------------------------------
// Parameter definitions
//-------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------
// Localparam definitions
//-------------------------------------------------------------------------------------------------
    localparam                      FIFO_WIDTH              = AXI4S_DATA_WIDTH + 1;

    localparam                      STATE_WAIT              = 0;
    localparam                      STATE_HEADER            = 1;
    localparam                      STATE_DATA              = 2;
    localparam                      STATE_LAST              = 3;
    localparam                      STATE_FEED_BB           = 4;
    localparam                      STATE_LSAT_BB           = 5;

    localparam                      STATE_READY             = 0;
    localparam                      STATE_FULL              = 1;

    localparam                      FSM_STATE_WIDTH         = 4;
    localparam                      RAM_ADDR_WIDTH          = 13;
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           clk;
    input                                           reset;

    input       [MEM_BUF_IDX_WIDTH-1:0]             ctrl_buf_idx_in;
    input       [MEM_BEAT_ADDR_WIDTH-1:0]           ctrl_addr_in;
    input       [MEM_BEAT_ADDR_WIDTH-1:0]           ctrl_width_in;
    input       [MEM_BEAT_ADDR_WIDTH-1:0]           ctrl_offset_in;
    input       [MEM_BEAT_ADDR_WIDTH-1:0]           ctrl_count_in;
    input                                           ctrl_feed_bb_in;
    input                                           ctrl_valid_in;
    output reg                                      ctrl_ack_out;

    input       [AXI4S_DATA_WIDTH-1 : 0]            ctrl_rx_axis_tdata;
    input                                           ctrl_rx_axis_tlast;
    input                                           ctrl_rx_axis_tvalid;
    output reg                                      ctrl_rx_axis_tready;

    output reg  [AXI4S_DATA_WIDTH-1:0]              mem_tx_axis_tdata;
    output reg                                      mem_tx_axis_tlast;
    output reg                                      mem_tx_axis_tvalid;
    input                                           mem_tx_axis_tready;

    output reg  [AXI4S_DATA_WIDTH-1:0]              bb_tx_axis_tdata;
    output reg                                      bb_tx_axis_tlast;
    output reg                                      bb_tx_axis_tvalid;
    input                                           bb_tx_axis_tready;

    output reg  [15:0]                              rx_count_out;
    output reg  [15:0]                              rx_count_reg_out;
    output reg  [2*FSM_STATE_WIDTH-1 : 0]           state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    wire        [FIFO_WIDTH-1:0]                    fifo_din;
    wire                                            fifo_wr_en;
    reg                                             fifo_rd_en;
    wire                                            fifo_full;
    wire                                            fifo_empty;
    wire                                            prog_full_1665;
    wire        [AXI4S_DATA_WIDTH-1:0]              rx_tdata;
    wire                                            rx_tlast;
    reg                                             ack;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           count;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           width;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           width_reg;
    reg         [MEM_BUF_IDX_WIDTH-1:0]             buf_idx;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           offset;
    integer                                         rx_state, tx_state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------
    assign fifo_din         = {ctrl_rx_axis_tlast, ctrl_rx_axis_tdata};
    assign fifo_wr_en       = ctrl_rx_axis_tvalid & ctrl_rx_axis_tready;

    always@(posedge clk) begin
        if (reset) begin
            rx_count_out                <= 16'b0;
            rx_count_reg_out            <= 16'b0;

            ctrl_rx_axis_tready         <= 1'b0;
            rx_state                    <= STATE_READY;
        end
        else begin
            if (ctrl_rx_axis_tvalid & ctrl_rx_axis_tready) begin
                if (ctrl_rx_axis_tlast) begin
                    rx_count_reg_out        <= rx_count_out + 1'b1;
                    rx_count_out            <= 16'b0;
                end
                else begin
                    rx_count_out            <= rx_count_out + 1'b1;
                end
            end

            case (rx_state)
                STATE_READY: begin
                    if (ctrl_rx_axis_tready & ctrl_rx_axis_tvalid & ctrl_rx_axis_tlast & prog_full_1665) begin
                        ctrl_rx_axis_tready  <= 1'b0;
                        rx_state        <= STATE_FULL;
                    end
                    else begin
                        ctrl_rx_axis_tready  <= 1'b1;
                    end
                end
                STATE_FULL: begin
                    if (~prog_full_1665) begin
                        rx_state        <= STATE_READY;
                    end
                end
            endcase
        end
    end

    ctrl_wr_data_buf
    U_ctrl_wr_data_buf (
        .clk        (clk),              // input wire clk
        .srst       (reset),            // input wire srst
        .din        (fifo_din),              // input wire [64 : 0] din
        .wr_en      (fifo_wr_en),          // input wire wr_en
        .rd_en      (fifo_rd_en),          // input wire rd_en
        .dout       ({rx_tlast, rx_tdata}),            // output wire [64 : 0] dout
        .full       (fifo_full),            // output wire full
        .empty      (fifo_empty),          // output wire empty
        .prog_full  (prog_full_1665)        // output wire prog_full
    );

    always@(posedge clk) begin
        if (reset) begin
            addr                            <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            count                           <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            buf_idx                         <= {MEM_BUF_IDX_WIDTH{1'b0}};
            width                           <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            width_reg                       <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            offset                          <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            ctrl_ack_out                    <= 1'b0;
            mem_tx_axis_tdata               <= {AXI4S_DATA_WIDTH{1'b0}};
            mem_tx_axis_tlast               <= 1'b0;
            mem_tx_axis_tvalid              <= 1'b0;
            bb_tx_axis_tdata                <= {AXI4S_DATA_WIDTH{1'b0}};
            bb_tx_axis_tlast                <= 1'b0;
            bb_tx_axis_tvalid               <= 1'b0;
            fifo_rd_en                      <= 1'b0;
            ack                             <= 1'b1;
            tx_state                        <= STATE_WAIT;
        end
        else begin
            case (tx_state)
                STATE_WAIT: begin
                    addr                        <= ctrl_addr_in;
                    count                       <= ctrl_count_in;
                    buf_idx                     <= ctrl_buf_idx_in;
                    width                       <= ctrl_width_in;
                    offset                      <= ctrl_offset_in;
                    ack                         <= 1'b1;
                    if (ctrl_valid_in) begin
                        if (ctrl_feed_bb_in) begin
                            if (bb_tx_axis_tready & ~fifo_empty) begin
                                fifo_rd_en      <= 1'b1;
                                ctrl_ack_out    <= 1'b1;
                                tx_state        <= STATE_FEED_BB;
                            end
                        end
                        else if (mem_tx_axis_tready) begin
                            tx_state            <= STATE_HEADER;
                        end
                    end
                end
                STATE_HEADER: begin
                    width_reg                   <= width;
                    mem_tx_axis_tdata           <= {AXI4S_DATA_WIDTH{1'b0}};
                    mem_tx_axis_tdata[MEM_ADDR_POS +: MEM_BEAT_ADDR_WIDTH]   <=  addr;
                    mem_tx_axis_tdata[MEM_BUF_IDX_POS +: MEM_BUF_IDX_WIDTH]  <=  buf_idx;
                    mem_tx_axis_tdata[MEM_LENGTH_POS +: MEM_BEAT_ADDR_WIDTH] <=  width;
                    if (~fifo_empty & mem_tx_axis_tready) begin
                        ctrl_ack_out            <= ack;
                        fifo_rd_en              <= 1'b1;
                        mem_tx_axis_tvalid      <= 1'b1;
                        tx_state                <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    ctrl_ack_out                <= 1'b0;

                    mem_tx_axis_tdata           <= rx_tdata;
                    mem_tx_axis_tvalid          <= ~fifo_empty;

                    if (~fifo_empty) begin
                        width_reg               <= width_reg - 1'b1;

                        if (width_reg == 1'b1) begin
                            fifo_rd_en              <= 1'b0;
                            mem_tx_axis_tlast       <= 1'b1;
                            tx_state                <= STATE_LAST;
                        end
                    end
                end
                STATE_LAST: begin
                    ack                         <= 1'b0;
                    mem_tx_axis_tlast           <= 1'b0;
                    mem_tx_axis_tvalid          <= 1'b0;
                    if (count == 1'b1) begin
                        tx_state                <= STATE_WAIT;
                    end
                    else begin
                        addr                    <= addr + offset;
                        count                   <= count - 1'b1;
                        tx_state                <= STATE_HEADER;
                    end
                end
                STATE_FEED_BB: begin
                    bb_tx_axis_tdata            <= rx_tdata;
                    bb_tx_axis_tlast            <= rx_tlast;
                    bb_tx_axis_tvalid           <= ~fifo_empty;
                    ctrl_ack_out                <= 1'b0;
                    if (~fifo_empty & rx_tlast) begin
                        fifo_rd_en              <= 1'b0;
                        tx_state                <= STATE_LSAT_BB;
                    end
                end
                STATE_LSAT_BB: begin
                    ack                         <= 1'b0;
                    bb_tx_axis_tlast            <= 1'b0;
                    bb_tx_axis_tvalid           <= 1'b0;
                    tx_state                    <= STATE_WAIT;
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (rx_state)
            STATE_READY:        state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_READY;
            STATE_FULL:         state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_FULL;
        endcase

        case (tx_state)
            STATE_WAIT:         state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_WAIT;
            STATE_HEADER:       state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_HEADER;
            STATE_DATA:         state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_DATA;
            STATE_LAST:         state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_LAST;
            STATE_FEED_BB:      state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_FEED_BB;
            STATE_LSAT_BB:      state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_LSAT_BB;
        endcase
    end
endmodule
