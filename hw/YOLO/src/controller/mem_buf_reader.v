`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/06/2018 01:03:20 PM
// Design Name:
// Module Name: mem_buf_reader
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


module mem_buf_reader
    (
        clk,
        reset,

        ctrl_buf_idx_in,
        ctrl_addr_in,
        ctrl_width_in,      //if ctrl_rd_from_buf_in==1  ctrl_width_in is discarded & length is taken as ctrl_count_in
        ctrl_offset_in,
        ctrl_count_in,
//        ctrl_rd_from_buf_in,
//        ctrl_wr_to_buf_in,
        ctrl_header_in,
        ctrl_header_valid_in,
        ctrl_header_only_in,
        ctrl_valid_in,
        ctrl_ack_out,

        ctrl_tx_axis_tdata,
        ctrl_tx_axis_tlast,
        ctrl_tx_axis_tvalid,
        ctrl_tx_axis_tready,

        mem_tx_axis_tdata,
        mem_tx_axis_tvalid,
        mem_tx_axis_tready,

        mem_rx_axis_tdata,
        mem_rx_axis_tlast,
        mem_rx_axis_tvalid,
        mem_rx_axis_tready,

        tx_count_out,
        tx_count_reg_out,
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
    localparam                      MEM_REQ_RSVD0_WIDTH         = MEM_LENGTH_POS - MEM_BEAT_ADDR_WIDTH - MEM_BUF_IDX_WIDTH;
    localparam                      MEM_REQ_RSVD1_WIDTH         = AXI4S_DATA_WIDTH - MEM_LENGTH_POS - MEM_BEAT_ADDR_WIDTH;

    localparam                      STATE_WAIT              = 0;
    localparam                      STATE_REQ               = 1;
    localparam                      STATE_REQ_END           = 2;
    localparam                      STATE_WAIT_LOCK         = 3;

    localparam                      STATE_DATA              = 1;
    localparam                      STATE_HEADER            = 2;

    localparam                      STATE_END               = 4;

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
    input       [AXI4S_DATA_WIDTH-1:0]              ctrl_header_in;
    input                                           ctrl_header_valid_in;
    input                                           ctrl_header_only_in;
    input                                           ctrl_valid_in;
    output reg                                      ctrl_ack_out;

    output reg  [AXI4S_DATA_WIDTH-1 : 0]            ctrl_tx_axis_tdata;
    output reg                                      ctrl_tx_axis_tlast;
    output reg                                      ctrl_tx_axis_tvalid;
    input                                           ctrl_tx_axis_tready;

    output      [AXI4S_DATA_WIDTH-1:0]              mem_tx_axis_tdata;
    output reg                                      mem_tx_axis_tvalid;
    input                                           mem_tx_axis_tready;

    input       [AXI4S_DATA_WIDTH-1 : 0]            mem_rx_axis_tdata;
    input                                           mem_rx_axis_tlast;
    input                                           mem_rx_axis_tvalid;
    output reg                                      mem_rx_axis_tready;

    output reg  [15:0]                              tx_count_out;
    output reg  [15:0]                              tx_count_reg_out;
    output reg  [2*FSM_STATE_WIDTH-1 : 0]           state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           count;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           data_count;
    reg         [AXI4S_DATA_WIDTH-1:0]              header;
    reg                                             header_valid;
    reg                                             header_only;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           data_count_reg;
//    reg         [AXI4S_DATA_WIDTH-1:0]              header_reg;
//    reg                                             header_valid_reg;
//    reg                                             header_only_reg;
//    reg         [RAM_ADDR_WIDTH-1:0]                addra;
//    reg         [RAM_ADDR_WIDTH-1:0]                addrb;
//    reg                                             wea;
//    reg                                             enb;
//    wire        [AXI4S_DATA_WIDTH-1:0]              doutb;
    reg                                             rx_lock;
    reg                                             tx_lock;
    wire                                            lock;
    integer                                         rx_state, tx_state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------

    assign mem_tx_axis_tdata = {{MEM_REQ_RSVD1_WIDTH{1'b0}}, ctrl_width_in, {MEM_REQ_RSVD0_WIDTH{1'b0}}, ctrl_buf_idx_in, addr};
    assign lock = rx_lock ^ tx_lock;

    always@(posedge clk) begin
        if (reset) begin
            addr                            <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            count                           <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            ctrl_ack_out                    <= 1'b0;
            mem_tx_axis_tvalid              <= 1'b0;
            rx_lock                         <= 1'b0;
            header                          <= {AXI4S_DATA_WIDTH{1'b0}};
            header_valid                    <= 1'b0;
            header_only                     <= 1'b0;
            rx_state                        <= STATE_WAIT;
        end
        else begin
            case (rx_state)
                STATE_WAIT: begin
                    addr                        <= ctrl_addr_in;
                    count                       <= ctrl_count_in;

                    if (ctrl_valid_in) begin
                        if (ctrl_header_only_in) begin
                            count               <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
                            rx_state            <= STATE_WAIT_LOCK;
                        end
                        else begin
                            mem_tx_axis_tvalid  <= 1'b1;
                            rx_state            <= STATE_REQ_END;
                        end
                    end
                end
                STATE_REQ: begin
                    count                       <= count - 1'b1;
                    addr                        <= addr + ctrl_offset_in;
                    mem_tx_axis_tvalid          <= 1'b1;
                    rx_state                    <= STATE_REQ_END;
                end
                STATE_REQ_END: begin
                    if (mem_tx_axis_tready) begin
                        mem_tx_axis_tvalid      <= 1'b0;
                        rx_state                <= STATE_WAIT_LOCK;
                    end
                end
                STATE_WAIT_LOCK: begin
                    if (~lock) begin
                        rx_lock                 <= ~rx_lock;

                        header                  <= ctrl_header_in;
                        header_valid            <= ctrl_header_valid_in;
                        header_only             <= ctrl_header_only_in;

                        data_count              <= ctrl_count_in;

                        if (count > 1'b1) begin
                            rx_state            <= STATE_REQ;
                        end
                        else begin
                            ctrl_ack_out        <= 1'b1;
                            rx_state            <= STATE_END;
                        end
                    end
                end
                STATE_END: begin
                    ctrl_ack_out                <= 1'b0;
                    rx_state                    <= STATE_WAIT;
                end
            endcase
        end
    end

    always@(posedge clk) begin
        if (reset) begin
            tx_lock                             <= 1'b0;
            mem_rx_axis_tready                  <= 1'b0;
            ctrl_tx_axis_tdata                  <= {AXI4S_DATA_WIDTH{1'b0}};
            ctrl_tx_axis_tlast                  <= 1'b0;
            ctrl_tx_axis_tvalid                 <= 1'b0;
//            header_reg                          <= {AXI4S_DATA_WIDTH{1'b0}};
//            header_valid_reg                    <= 1'b0;
//            header_only_reg                     <= 1'b0;
            tx_count_out                        <= 16'h0;
            tx_count_reg_out                    <= 16'h0;
            data_count_reg                      <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            tx_state                            <= STATE_WAIT;
        end
        else begin
            case (tx_state)
                STATE_WAIT: begin
                    data_count_reg              <= data_count;
//                    header_reg                  <= header;
//                    header_only_reg             <= header_only;
//                    header_valid_reg            <= header_valid;

                    if (lock & ctrl_tx_axis_tready) begin
                        tx_count_out            <= 16'h0;
                        if (header_valid) begin
                            tx_state            <= STATE_HEADER;
                        end
                        else begin
                            tx_lock             <= ~tx_lock;
                            mem_rx_axis_tready  <= 1'b1;
                            tx_state            <= STATE_DATA;
                        end
                    end
                end
                STATE_HEADER: begin
                    tx_lock                     <= ~tx_lock;
                    ctrl_tx_axis_tdata          <= header;
                    ctrl_tx_axis_tlast          <= header_only;
                    ctrl_tx_axis_tvalid         <= 1'b1;
                    if (header_only) begin
                        tx_state                <= STATE_END;
                    end
                    else begin
                        mem_rx_axis_tready      <= 1'b1;
                        tx_state                <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    ctrl_tx_axis_tdata          <= mem_rx_axis_tdata;
                    ctrl_tx_axis_tlast          <= 1'b0;
                    ctrl_tx_axis_tvalid         <= mem_rx_axis_tvalid;

                    if (mem_rx_axis_tvalid) begin
                        tx_count_out            <= tx_count_out + 16'h1;
                    end

                    if (mem_rx_axis_tvalid & mem_rx_axis_tlast) begin
                        data_count_reg          <= data_count_reg - 1'b1;
                        if (data_count_reg == 1'b1) begin
                            ctrl_tx_axis_tlast  <= 1'b1;
                            mem_rx_axis_tready  <= 1'b0;
//                            tx_lock             <= ~tx_lock;
                            tx_state            <= STATE_END;
                        end
                        else begin
                            tx_lock             <= ~tx_lock;
                        end
                    end
                end
                STATE_END: begin
                    tx_count_reg_out            <= tx_count_out;
                    ctrl_tx_axis_tlast          <= 1'b0;
                    ctrl_tx_axis_tvalid         <= 1'b0;
                    tx_state                    <= STATE_WAIT;
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (rx_state)
            STATE_WAIT:         state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_WAIT;
            STATE_REQ:          state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_REQ;
            STATE_REQ_END:      state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_REQ_END;
            STATE_WAIT_LOCK:    state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_WAIT_LOCK;
            STATE_END:          state_vec_out[0 +: FSM_STATE_WIDTH] <= STATE_END;
        endcase

        case (tx_state)
            STATE_WAIT:         state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_WAIT;
            STATE_HEADER:       state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_HEADER;
            STATE_DATA:         state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_DATA;
            STATE_END:          state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH] <= STATE_END;
        endcase
    end
endmodule
