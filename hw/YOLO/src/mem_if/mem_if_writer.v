
`timescale 1ns / 1ps

module mem_if_writer
    (
        clk,
        reset,

        rx_axis_tdata,
        rx_axis_tlast,
        rx_axis_tvalid,
        rx_axis_tready,

        m_axi_awid,
        m_axi_awaddr,
        m_axi_awlen,
        m_axi_awvalid,
        m_axi_awready,

        m_axi_wid,
        m_axi_wdata,
        m_axi_wstrb,
        m_axi_wlast,
        m_axi_wvalid,
        m_axi_wready,

        m_axi_bid,
        m_axi_bresp,
        m_axi_bvalid,
        m_axi_bready,

        idle_out,
        ddr_addr_offset_in,
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

    localparam                      STATE_READY             = 0;
    localparam                      STATE_FULL              = 1;

    localparam                      STATE_WAIT              = 0;
    localparam                      STATE_REQ               = 1;
    localparam                      STATE_REQ_WAIT          = 2;
    localparam                      STATE_DATA              = 3;
    localparam                      STATE_END               = 4;

    localparam                      FSM_STATE_WIDTH         = 8;
    localparam [MEM_BEAT_ADDR_WIDTH-1:0]    AXI3_MAX_BEAT   = 2**AXI3_BLEN_WIDTH;
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           clk;
    input                                           reset;

    input       [AXI4S_DATA_WIDTH-1 : 0]            rx_axis_tdata;
    input                                           rx_axis_tlast;
    input                                           rx_axis_tvalid;
    output reg                                      rx_axis_tready;

    output      [AXI3_ID_WIDTH-1:0]                 m_axi_awid;
    output reg  [AXI3_ADDR_WIDTH-1:0]               m_axi_awaddr;
    output reg  [AXI3_BLEN_WIDTH-1:0]               m_axi_awlen;
    output reg                                      m_axi_awvalid;
    input                                           m_axi_awready;

    output      [AXI3_ID_WIDTH-1:0]                 m_axi_wid;
    output      [AXI3_DATA_WIDTH-1:0]               m_axi_wdata;
    output      [AXI3_STRB_WIDTH-1:0]               m_axi_wstrb;
    output                                          m_axi_wlast;
    output                                          m_axi_wvalid;
    input                                           m_axi_wready;

    input       [AXI3_ID_WIDTH-1:0]                 m_axi_bid;
    input       [AXI3_RESP_WIDTH-1:0]               m_axi_bresp;
    input                                           m_axi_bvalid;
    output                                          m_axi_bready;

    output reg                                      idle_out;
    input       [AXI4L_DATA_WIDTH-1 : 0]            ddr_addr_offset_in;
    output reg  [AXI4L_DATA_WIDTH-1 : 0]            state_vec_out;
//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    wire        [FIFO_WIDTH-1:0]                    fifo_din;
    wire                                            fifo_wr_en;
    reg                                             fifo_rd_en;
    wire                                            fifo_full;
    wire                                            fifo_empty;
    wire                                            prog_full_1665;
    reg                                             multiple_request;
    wire        [AXI4S_DATA_WIDTH-1:0]              rx_data;
    wire                                            rx_last;
    reg         [MEM_BUF_IDX_WIDTH-1:0]             buf_index;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           beat_addr;
    reg         [MEM_BEAT_ADDR_WIDTH-1:0]           beat_length;
    reg                                             tx_valid;
    reg                                             idle;
    reg                                             idle_reg;

    integer                                         rx_state, tx_state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------
    assign  m_axi_awid      = {AXI3_ID_WIDTH{1'b0}};
    assign  m_axi_wid       = {AXI3_ID_WIDTH{1'b0}};
    assign  m_axi_wstrb     = {AXI3_STRB_WIDTH{1'b1}};
    assign  m_axi_bready    = 1'b1;

    assign fifo_din         = {rx_axis_tlast, rx_axis_tdata};
    assign fifo_wr_en       = rx_axis_tvalid & rx_axis_tready;

    always@(posedge clk) begin
        if (reset) begin
            rx_axis_tready              <= 1'b0;
            rx_state                    <= STATE_READY;
        end
        else begin
            case (rx_state)
                STATE_READY: begin
                    if (rx_axis_tready & rx_axis_tvalid & rx_axis_tlast & prog_full_1665) begin
                        rx_axis_tready  <= 1'b0;
                        rx_state        <= STATE_FULL;
                    end
                    else begin
                        rx_axis_tready  <= 1'b1;
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

    mem_if_data_fifo
    u_mem_if_data_fifo (
        .clk        (clk),
        .srst       (reset),
        .din        (fifo_din),
        .wr_en      (fifo_wr_en),
        .rd_en      (fifo_rd_en | (tx_valid & m_axi_wready)),
        .dout       ({rx_last, rx_data}),
        .full       (fifo_full),
        .empty      (fifo_empty),
        .data_count (),
        .prog_full  (prog_full_1665)
    );

    assign m_axi_wvalid = tx_valid & ~fifo_empty;
    assign m_axi_wdata = rx_data;
    assign m_axi_wlast = (m_axi_awlen == 4'b0) ? 1'b1 : 1'b0;

    always@(posedge clk) begin
        if (reset) begin
            beat_addr                       <= {MEM_ADDR_WIDTH{1'b0}};
            buf_index                       <= {MEM_BUF_IDX_WIDTH{1'b0}};
            beat_length                     <= {MEM_ADDR_WIDTH{1'b0}};
            fifo_rd_en                      <= 1'b0;
            m_axi_awaddr                    <= {AXI3_ADDR_WIDTH{1'b0}};
            m_axi_awlen                     <= {AXI3_BLEN_WIDTH{1'b0}};
            m_axi_awvalid                   <= 1'b0;
            multiple_request                <= 1'b0;
            tx_valid                        <= 1'b0;
            idle                            <= 1'b1;
            idle_reg                        <= 1'b1;
            tx_state                        <= STATE_WAIT;
        end
        else begin
            idle_reg                        <= idle;
            idle_out                        <= idle & idle_reg;
            case (tx_state)
                STATE_WAIT: begin
                    beat_addr               <= rx_data[MEM_ADDR_POS +: MEM_ADDR_WIDTH];
                    buf_index               <= rx_data[MEM_BUF_IDX_POS +: MEM_BUF_IDX_WIDTH];
                    beat_length             <= rx_data[MEM_LENGTH_POS +: MEM_ADDR_WIDTH];
                    if (~fifo_empty) begin
                    idle                    <= 1'b0;
                        fifo_rd_en          <= 1'b1;
                        tx_state            <= STATE_REQ;
                    end
                end
                STATE_REQ: begin
                    fifo_rd_en              <= 1'b0;
                    m_axi_awaddr            <= {buf_index, beat_addr, {MEM_BEAT_BYTE_ADDR_WIDTH{1'b0}}} + ddr_addr_offset_in;
                    beat_addr               <= beat_addr + AXI3_MAX_BEAT;
                    if (beat_length > AXI3_MAX_BEAT) begin
                        beat_length         <= beat_length - AXI3_MAX_BEAT;
                        m_axi_awlen         <= AXI3_MAX_BEAT - 1'b1;
                        multiple_request    <= 1'b1;
                    end
                    else begin
                        m_axi_awlen         <= beat_length - 1'b1;
                        multiple_request    <= 1'b0;
                    end
                    m_axi_awvalid           <= 1'b1;
                    if (m_axi_awready & m_axi_awvalid) begin
                        tx_valid            <= 1'b1;
                        tx_state            <= STATE_DATA;
                    end
                    else begin
                        tx_state            <= STATE_REQ_WAIT;
                    end
                end
                STATE_REQ_WAIT: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid       <= 1'b0;
                        tx_valid            <= 1'b1;
                        tx_state            <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    m_axi_awvalid           <= 1'b0;
                    if (m_axi_wready & ~fifo_empty) begin
                        m_axi_awlen         <= m_axi_awlen - 1'b1;
                        if (m_axi_wlast) begin
                            tx_valid        <= 1'b0;
                            tx_state        <= STATE_END;
                        end
                    end
                end
                STATE_END: begin
                    if (multiple_request) begin
                        tx_state            <= STATE_REQ;
                    end
                    else begin
                        idle                <= 1'b1;
                        tx_state            <= STATE_WAIT;
                    end
                end
            endcase
        end
    end

    always@(posedge clk) begin
        case (tx_state)
            STATE_WAIT:     state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_WAIT;
            STATE_REQ:      state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_REQ;
            STATE_REQ_WAIT: state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_REQ_WAIT;
            STATE_DATA:     state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_DATA;
            STATE_END:      state_vec_out[0 +: FSM_STATE_WIDTH]     <= STATE_END;
            default:        state_vec_out[0 +: FSM_STATE_WIDTH]     <= {FSM_STATE_WIDTH{1'b1}};
        endcase

        case (rx_state)
            STATE_READY:    state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_READY;
            STATE_FULL:     state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= STATE_FULL;
            default:        state_vec_out[FSM_STATE_WIDTH +: FSM_STATE_WIDTH]   <= {FSM_STATE_WIDTH{1'b1}};
        endcase

        state_vec_out[2*FSM_STATE_WIDTH +: FSM_STATE_WIDTH]         <= {2'b0, m_axi_bvalid, m_axi_bready, m_axi_wvalid, m_axi_wready, m_axi_awvalid, m_axi_awready};
        state_vec_out[3*FSM_STATE_WIDTH +: FSM_STATE_WIDTH]         <= {idle_out, 2'b0, rx_axis_tvalid, rx_axis_tready, prog_full_1665, fifo_empty, fifo_full};
    end
endmodule
