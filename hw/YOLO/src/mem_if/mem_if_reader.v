
`timescale 1ns / 1ps

module mem_if_reader
    (
        clk,
        reset,

        /* Request must sit inside buffer boundaries */
        rx_axis_tdata,
        rx_axis_tvalid,
        rx_axis_tready,

        m_axi_arid,
        m_axi_araddr,
        m_axi_arlen,
        m_axi_arvalid,
        m_axi_arready,

        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_rvalid,
        m_axi_rready,

        //axi4s-lite ready before valid
        tx_axis_tdata,
        tx_axis_tlast,
        tx_axis_tuser,
        tx_axis_tvalid,
        tx_axis_tready,

        ddr_addr_offset_in,
        fsm_state_vec_out
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
    localparam                      PACKET_COUNT_WIDTH      = 15;
    localparam                      FIFO_COUNT_WIDTH        = 4;

    localparam                      STATE_WAIT              = 0;
    localparam                      STATE_REQUEST           = 1;
    localparam                      STATE_NXT_REQ           = 2;
    localparam                      STATE_WAIT_READY        = 3;
    localparam                      STATE_WAIT_END          = 4;

    localparam                      STATE_RD_FIFO           = 2;
    localparam                      STATE_START             = 3;
    localparam                      STATE_DATA              = 4;

    localparam                      STATE_END               = 6;

    localparam                      FSM_STATE_WIDTH         = 4;

    localparam [MEM_BEAT_ADDR_WIDTH-1:0]    AXI3_MAX_BEAT   = 2**AXI3_BLEN_WIDTH;
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           clk;
    input                                           reset;

    input       [AXI4S_DATA_WIDTH-1:0]              rx_axis_tdata;
    input                                           rx_axis_tvalid;
    output reg                                      rx_axis_tready;

    output      [AXI3_ID_WIDTH-1 : 0]               m_axi_arid;
    output reg  [AXI3_ADDR_WIDTH-1 : 0]             m_axi_araddr;
    output reg  [AXI3_BLEN_WIDTH-1 : 0]             m_axi_arlen;
    output reg                                      m_axi_arvalid;
    input                                           m_axi_arready;

    input       [AXI3_ID_WIDTH-1 : 0]               m_axi_rid;
    input       [AXI3_DATA_WIDTH-1 : 0]             m_axi_rdata;
    input       [AXI3_RESP_WIDTH-1 : 0]             m_axi_rresp;
    input                                           m_axi_rlast;
    input                                           m_axi_rvalid;
    output reg                                      m_axi_rready;

    output reg  [AXI4S_DATA_WIDTH-1 : 0]            tx_axis_tdata;
    output reg                                      tx_axis_tlast;
    output reg                                      tx_axis_tuser;
    output reg                                      tx_axis_tvalid;
    input                                           tx_axis_tready;

    input       [AXI4L_DATA_WIDTH-1 : 0]            ddr_addr_offset_in;
    output reg  [AXI4L_DATA_WIDTH-1 : 0]            fsm_state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    wire        [MEM_BUF_IDX_WIDTH-1:0]             buf_index;
    wire        [MEM_BEAT_ADDR_WIDTH-1:0]           beat_addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1 : 0]         remain_beat_count;
    reg         [PACKET_COUNT_WIDTH-1 : 0]          mem_packet_count;
    wire        [FIFO_COUNT_WIDTH-1 : 0]            fifo_data_count;
    reg         [PACKET_COUNT_WIDTH-1 : 0]          mem_packets_din;
    wire        [PACKET_COUNT_WIDTH-1 : 0]          mem_packets_dout;
    reg                                             fifo_wr_en;
    reg                                             fifo_rd_en;
    wire                                            fifo_full;
    wire                                            fifo_empty;

    integer                                         rx_state, tx_state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------
    assign m_axi_arid                       = {AXI3_ID_WIDTH{1'b0}};
//    assign beat_addr                        = rx_axis_tdata[MEM_ADDR_POS +: MEM_BEAT_ADDR_WIDTH];
//    assign buf_index                        = rx_axis_tdata[MEM_BUF_IDX_POS +: MEM_BUF_IDX_WIDTH];
    assign beat_addr                        = rx_axis_tdata[0 +: MEM_BEAT_ADDR_WIDTH];
    assign buf_index                        = rx_axis_tdata[MEM_BEAT_ADDR_WIDTH +: MEM_BUF_IDX_WIDTH];
//    assign m_axi_araddr                     = {{(AXI3_ADDR_WIDTH-MEM_ADDR_WIDTH){1'b0}}, buf_index, beat_addr, {MEM_BEAT_BYTE_ADDR_WIDTH{1'b0}}} + ddr_addr_offset_in;

    always@(posedge clk) begin
        if (reset) begin
            rx_axis_tready                  <= 1'b0;
//            beat_addr                       <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
//            buf_index                       <= {MEM_BUF_IDX_WIDTH{1'b0}};
            m_axi_araddr                    <= {AXI3_ADDR_WIDTH{1'b0}};
            m_axi_arlen                     <= {AXI3_BLEN_WIDTH{1'b0}};
            m_axi_arvalid                   <= 1'b0;
            remain_beat_count               <= {MEM_BEAT_ADDR_WIDTH{1'b0}};
            mem_packets_din                 <= {PACKET_COUNT_WIDTH{1'b0}};
            fifo_wr_en                      <= 1'b0;
            rx_state                        <= STATE_WAIT;
        end
        else begin
            case (rx_state)
                STATE_WAIT: begin
                    rx_axis_tready          <= 1'b1;
                    mem_packets_din         <= rx_axis_tdata[(MEM_LENGTH_POS+4) +: MEM_ADDR_WIDTH] + (|rx_axis_tdata[MEM_LENGTH_POS +: 4]);
                    m_axi_araddr            <= {{(AXI3_ADDR_WIDTH-MEM_ADDR_WIDTH){1'b0}}, buf_index, beat_addr, {MEM_BEAT_BYTE_ADDR_WIDTH{1'b0}}} + ddr_addr_offset_in;
                    remain_beat_count       <= rx_axis_tdata[MEM_LENGTH_POS +: MEM_ADDR_WIDTH];
                    if (rx_axis_tready & rx_axis_tvalid) begin
                        fifo_wr_en          <= 1'b1;
                        rx_axis_tready      <= 1'b0;
                        rx_state            <= STATE_REQUEST;
                    end
                end
                STATE_REQUEST: begin
                    fifo_wr_en              <= 1'b0;
                    if (remain_beat_count > AXI3_MAX_BEAT) begin
                        m_axi_arlen         <= AXI3_MAX_BEAT - 1'b1;
                        remain_beat_count   <= remain_beat_count - AXI3_MAX_BEAT;
//                        if (m_axi_arready) begin
//                            rx_state        <= STATE_NXT_REQ;
//                        end
//                        else begin
                            rx_state        <= STATE_WAIT_READY;
//                        end
                    end
                    else begin
                        m_axi_arlen         <= remain_beat_count - 1'b1;
//                        if (m_axi_arready) begin
//                            rx_state        <= STATE_END;
//                        end
//                        else begin
                            rx_state        <= STATE_WAIT_END;
//                        end
                    end
//                    mem_packets_din         <= mem_packets_din + 1'b1;
                end
//                STATE_NXT_REQ: begin
//                    m_axi_araddr[MEM_BEAT_BYTE_ADDR_WIDTH +: MEM_ADDR_WIDTH]        <= m_axi_araddr[MEM_BEAT_BYTE_ADDR_WIDTH +: MEM_ADDR_WIDTH] + AXI3_MAX_BEAT;
////                    beat_addr               <= beat_addr + AXI3_MAX_BEAT;
//                    m_axi_arvalid           <= 1'b0;
//                    rx_state                <= STATE_REQUEST;
//                end
                STATE_WAIT_READY: begin
                    m_axi_arvalid           <= 1'b1;
                    if (m_axi_arready & m_axi_arvalid) begin
                        m_axi_araddr[MEM_BEAT_BYTE_ADDR_WIDTH +: MEM_ADDR_WIDTH]    <= m_axi_araddr[MEM_BEAT_BYTE_ADDR_WIDTH +: MEM_ADDR_WIDTH] + AXI3_MAX_BEAT;
//                        beat_addr           <= beat_addr + AXI3_MAX_BEAT;
                        m_axi_arvalid       <= 1'b0;
                        rx_state            <= STATE_REQUEST;
                    end
                end
                STATE_WAIT_END: begin
                    m_axi_arvalid           <= 1'b1;
                    if (m_axi_arready & m_axi_arvalid) begin
                        m_axi_arvalid       <= 1'b0;
                        rx_state            <= STATE_END;
                    end
                end
                STATE_END: begin
                    m_axi_arvalid       <= 1'b0;
                    if (~fifo_full) begin
                        rx_state        <= STATE_WAIT;
                    end
                end
            endcase
        end
    end

    mem_if_req_fifo
    u_mem_if_req_fifo (
        .clk        (clk),                // input wire clk
        .srst       (reset),              // input wire srst
        .din        (mem_packets_din),    // input wire [14 : 0] din
        .wr_en      (fifo_wr_en),         // input wire wr_en
        .rd_en      (fifo_rd_en),         // input wire rd_en
        .dout       (mem_packets_dout),   // output wire [14 : 0] dout
        .full       (fifo_full),          // output wire full
        .empty      (fifo_empty),         // output wire empty
        .data_count (fifo_data_count)     // output wire [3 : 0] data_count
    );

    always@(posedge clk) begin
        if (reset) begin
            tx_axis_tdata                   <= {AXI4S_DATA_WIDTH{1'b0}};
            tx_axis_tlast                   <= 1'b0;
            tx_axis_tuser                   <= 1'b0;
            tx_axis_tvalid                  <= 1'b0;
            fifo_rd_en                      <= 1'b0;
            m_axi_rready                    <= 1'b0;
            mem_packet_count                <= {PACKET_COUNT_WIDTH{1'b0}};
            tx_state                        <= STATE_WAIT;
        end
        else begin
            case (tx_state)
                STATE_WAIT: begin
                    tx_axis_tvalid          <= 1'b0;
                    tx_axis_tuser           <= 1'b1;
                    if (~fifo_empty) begin
                        fifo_rd_en          <= 1'b1;
                        tx_state            <= STATE_RD_FIFO;
                    end
                end
                STATE_RD_FIFO: begin
                    fifo_rd_en              <= 1'b0;
                    tx_state                <= STATE_START;
                end
                STATE_START: begin
                    mem_packet_count        <= mem_packets_dout;
                    if (tx_axis_tready) begin
                        tx_state            <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    m_axi_rready            <= 1'b1;
                    tx_axis_tdata           <= m_axi_rdata;
                    tx_axis_tlast           <= 1'b0;
                    tx_axis_tvalid          <= m_axi_rvalid & m_axi_rready;

                    if (m_axi_rvalid && (m_axi_rresp != AXI3_RESP_OKAY)) begin
                        tx_axis_tuser       <= 1'b0;
                    end

                    if (m_axi_rready && m_axi_rvalid && m_axi_rlast) begin
                        if (mem_packet_count == 1'b1) begin
                            tx_axis_tlast   <= 1'b1;
                            m_axi_rready    <= 1'b0;
                            tx_state        <= STATE_WAIT;
                        end
                        else begin
                            mem_packet_count <= mem_packet_count - 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (tx_state)
            STATE_WAIT:     fsm_state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_WAIT;
            STATE_RD_FIFO:  fsm_state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_RD_FIFO;
            STATE_START:    fsm_state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_START;
            STATE_DATA:     fsm_state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_DATA;
            default:        fsm_state_vec_out[0 +: FSM_STATE_WIDTH]     <= {FSM_STATE_WIDTH{1'b1}};
        endcase

        case (rx_state)
            STATE_WAIT:     fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_WAIT;
            STATE_REQUEST:  fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_REQUEST;
            STATE_NXT_REQ:  fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_NXT_REQ;
            STATE_WAIT_READY:  fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_WAIT_READY;
            STATE_WAIT_END: fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_WAIT_END;
            STATE_END:      fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_END;
            default:        fsm_state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= {FSM_STATE_WIDTH{1'b1}};
        endcase

        fsm_state_vec_out[2*FSM_STATE_WIDTH +: FSM_STATE_WIDTH]         <= fifo_data_count;
        fsm_state_vec_out[3*FSM_STATE_WIDTH +: FSM_STATE_WIDTH]         <= {m_axi_rvalid, m_axi_rready, m_axi_arvalid, m_axi_arready};
    end
endmodule
