
`timescale 1ns / 1ps

module tiny_yolo
    (
        aclk,
        areset,

        //axi3 write address
        m_axi_awid,
        m_axi_awaddr,
        m_axi_awlen,
        m_axi_awsize,
        m_axi_awburst,
        m_axi_awlock,
        m_axi_awprot,
        m_axi_awcache,
        m_axi_awqos,
        m_axi_awvalid,
        m_axi_awready,

        //axi3 write data
        m_axi_wid,
        m_axi_wdata,
        m_axi_wstrb,
        m_axi_wlast,
        m_axi_wvalid,
        m_axi_wready,

        //axi3 write response
        m_axi_bid,
        m_axi_bresp,
        m_axi_bvalid,
        m_axi_bready,

        //axi3 read address
        m_axi_arid,
        m_axi_araddr,
        m_axi_arlen,
        m_axi_arsize,
        m_axi_arburst,
        m_axi_arlock,
        m_axi_arprot,
        m_axi_arcache,
        m_axi_arqos,
        m_axi_arvalid,
        m_axi_arready,

        //axi3 read data
        m_axi_rid,
        m_axi_rdata,
        m_axi_rresp,
        m_axi_rlast,
        m_axi_rvalid,
        m_axi_rready,

        //axi4-lite write addr
        s_axi_awaddr,
        s_axi_awvalid,
        s_axi_awready,

        //axi4-lite write data
        s_axi_wdata,
        s_axi_wstrb,
        s_axi_wvalid,
        s_axi_wready,

        //axi4-lite write resp
        s_axi_bresp,
        s_axi_bvalid,
        s_axi_bready,

        //axi4-lite read addr
        s_axi_araddr,
        s_axi_arvalid,
        s_axi_arready,

        //axi4-lite read data
        s_axi_rdata,
        s_axi_rresp,
        s_axi_rvalid,
        s_axi_rready
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//--------------------------------]-------------------------------------------------------------------------------------
    `include "../src/common/axi4_params.v"
    `include "../src/common/axi3_params.v"
    `include "../src/mem_if/mem_params.v"
    `include "../src/tiny_yolo_params.v"
    `include   "common/common_defs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                           aclk;
    input                                           areset;

    input       [AXI4L_ADDR_WIDTH-1:0]              s_axi_awaddr;
    input                                           s_axi_awvalid;
    output                                          s_axi_awready;

    input       [AXI4L_DATA_WIDTH-1:0]              s_axi_wdata;
    input       [AXI4L_STRB_WIDTH-1:0]              s_axi_wstrb;
    input                                           s_axi_wvalid;
    output                                          s_axi_wready;

    output      [AXI4L_RESP_WIDTH-1:0]              s_axi_bresp;
    output                                          s_axi_bvalid;
    input                                           s_axi_bready;

    input       [AXI4L_ADDR_WIDTH-1:0]              s_axi_araddr;
    input                                           s_axi_arvalid;
    output                                          s_axi_arready;

    output      [AXI4L_DATA_WIDTH-1:0]              s_axi_rdata;
    output      [AXI4L_RESP_WIDTH-1:0]              s_axi_rresp;
    output                                          s_axi_rvalid;
    input                                           s_axi_rready;


    output      [AXI3_ID_WIDTH-1:0]                 m_axi_awid;
    output      [AXI3_ADDR_WIDTH-1:0]               m_axi_awaddr;
    output      [AXI3_BLEN_WIDTH-1:0]               m_axi_awlen;
    output      [AXI3_BSIZE_WIDTH-1:0]              m_axi_awsize;
    output      [AXI3_BTYPE_WIDTH-1:0]              m_axi_awburst;
    output      [AXI3_LOCK_WIDTH-1:0]               m_axi_awlock;
    output      [AXI3_PROT_WIDTH-1:0]               m_axi_awprot;
    output      [AXI3_CACHE_WIDTH-1:0]              m_axi_awcache;
    output      [AXI3_QOS_WIDTH-1:0]                m_axi_awqos;
    output                                          m_axi_awvalid;
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

    output      [AXI3_ID_WIDTH-1:0]                 m_axi_arid;
    output      [AXI3_ADDR_WIDTH-1:0]               m_axi_araddr;
    output      [AXI3_BLEN_WIDTH-1:0]               m_axi_arlen;
    output      [AXI3_BSIZE_WIDTH-1:0]              m_axi_arsize;
    output      [AXI3_BTYPE_WIDTH-1:0]              m_axi_arburst;
    output      [AXI3_LOCK_WIDTH-1:0]               m_axi_arlock;
    output      [AXI3_PROT_WIDTH-1:0]               m_axi_arprot;
    output      [AXI3_CACHE_WIDTH-1:0]              m_axi_arcache;
    output      [AXI3_QOS_WIDTH-1:0]                m_axi_arqos;
    output                                          m_axi_arvalid;
    input                                           m_axi_arready;

    input       [AXI3_ID_WIDTH-1:0]                 m_axi_rid;
    input       [AXI3_DATA_WIDTH-1:0]               m_axi_rdata;
    input       [AXI3_RESP_WIDTH-1:0]               m_axi_rresp;
    input                                           m_axi_rlast;
    input                                           m_axi_rvalid;
    output                                          m_axi_rready;


//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    wire                                reset;
    wire                                start;
    wire                                sw_bb;
    wire                                done;
    wire                                layer_end;
    wire                                mem_wr_idle;
    wire [AXI4S_DATA_WIDTH-1:0]         mem_rd_addr_tdata;
    wire                                mem_rd_addr_tvalid;
    wire                                mem_rd_addr_tready;
    wire [AXI4S_DATA_WIDTH-1 : 0]       mem_rd_axis_tdata;
    wire                                mem_rd_axis_tlast;
    wire                                mem_rd_axis_tuser;
    wire                                mem_rd_axis_tvalid;
    wire                                mem_rd_axis_tready;
    wire [AXI4S_DATA_WIDTH-1 : 0]       mem_wr_axis_tdata;
    wire                                mem_wr_axis_tlast;
    wire                                mem_wr_axis_tvalid;
    wire                                mem_wr_axis_tready;
    wire [AXI4L_DATA_WIDTH-1 : 0]       mem_wr_state_vec;
    wire [AXI4L_DATA_WIDTH-1 : 0]       mem_rd_state_vec;
    wire [AXI4L_DATA_WIDTH-1 : 0]       ddr_addr_offset;
    wire [AXI4L_DATA_WIDTH-1 : 0]       ctrl_loop_state;
    wire [3*AXI4L_DATA_WIDTH-1 : 0]     ctrl_wr_state;
    wire [3*AXI4L_DATA_WIDTH-1 : 0]     ctrl_rd_state;
    wire [2*AXI4L_DATA_WIDTH-1 : 0]     ctrl_cp_header;
    wire [AXI4L_DATA_WIDTH-1 : 0]       ctrl_state_vec;
    wire [2*AXI4L_DATA_WIDTH-1 : 0]     ctrl_data_counts;

    wire        [AXI4L_DATA_WIDTH*3 - 1:0]          inst_data;
    wire        [AXI4L_DATA_WIDTH-1 :0]             inst_addr;
    wire                                            inst_wr_en;

    //conv pool layer stat
    wire    [INPUT_DIM * DIM_WIDTH -1 : 0]          stat_line_buff_row_count;
    wire    [INPUT_DIM * DIM_WIDTH -1 : 0]          stat_line_buff_col_count;
    wire    [OUTPUT_DIM * DIM_WIDTH -1 : 0]         stat_cache_writer_row_count;
    wire    [OUTPUT_DIM * DIM_WIDTH -1 : 0]         stat_cache_writer_col_count;
    wire    [AXI4L_DATA_WIDTH-1 : 0]                conv_stream_state_vec;
    wire    [TOTAL_PXL_WIDTH-1 : 0]                 conv_layer_rx_pix_count;

    wire [63:0] data;
    wire last;
    wire valid;
    wire ready;
    wire [63:0] tdata;
    wire tlast;
    wire tvalid;
    wire tready;

    wire [63:0] bb_data;
    wire bb_valid;
    wire bb_last;
    wire bb_ready;
    wire [63:0] bb_xywh;
    wire [7:0] bb_addr;
    wire [2:0] bb_set;
    wire bb_rslt_valid;

//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
    assign      m_axi_awsize        = AXI3_SIZE_8;
    assign      m_axi_awburst       = AXI3_BTYPE_INCR;
    assign      m_axi_awlock        = AXI3_LOCK_NORMAL;
    assign      m_axi_awprot        = AXI3_PROT;
    assign      m_axi_awcache       = AXI3_CACHE_DEV_NON_BUF;
    assign      m_axi_awqos         = AXI3_QOS;

    assign      m_axi_arsize        = AXI3_SIZE_8;
    assign      m_axi_arburst       = AXI3_BTYPE_INCR;
    assign      m_axi_arlock        = AXI3_LOCK_NORMAL;
    assign      m_axi_arprot        = AXI3_PROT;
    assign      m_axi_arcache       = AXI3_CACHE_DEV_NON_BUF;
    assign      m_axi_arqos         = AXI3_QOS;

    tiny_yolo_config
    u_tiny_yolo_config (
        .aclk         (aclk),
        .areset       (areset),

        .s_axi_araddr (s_axi_araddr),
        .s_axi_arready(s_axi_arready),
        .s_axi_arvalid(s_axi_arvalid),

        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rready (s_axi_rready),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),

        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awready(s_axi_awready),
        .s_axi_awvalid(s_axi_awvalid),

        .s_axi_bready (s_axi_bready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),

        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wready (s_axi_wready),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),

        .sreset_out   (reset),
        .ddr_addr_offset_out(ddr_addr_offset),
        .start_out    (start),
        .sw_bb_out    (sw_bb),
        .layer_end_in (layer_end),
        .done_in      (done & mem_wr_idle),

        .inst_data_out (inst_data),
        .inst_addr_out (inst_addr),
        .inst_wr_en_out(inst_wr_en),

        .ctrl_cp_if_stats_in({'h0, tlast, tvalid, tready, 5'b0, last, valid, ready}),
        .ctrl_data_counts_in(ctrl_data_counts),
        .ctrl_state_vec_in(ctrl_state_vec),
        .mem_rd_state_vec_in(mem_rd_state_vec),
        .mem_wr_state_vec_in(mem_wr_state_vec),
        .loop_state_in      (ctrl_loop_state),
        .cp_header_in       (ctrl_cp_header),
        .wr_state_in        (ctrl_wr_state),
        .rd_state_in        (ctrl_rd_state),

        .line_buff_row_count_in     (stat_line_buff_row_count),
        .line_buff_col_count_in     (stat_line_buff_col_count),
        .cache_writer_row_count_in  (stat_cache_writer_row_count),
        .cache_writer_col_count_in  (stat_cache_writer_col_count),
        .conv_stream_state_vec_in   (conv_stream_state_vec),
        .conv_layer_rx_pix_count_in (conv_layer_rx_pix_count),

        .bb_xywh_in         (bb_xywh),
        .bb_rslt_data_in    ({bb_rslt_valid, bb_set, bb_addr})
    );

    mem_if_reader
    u_mem_if_reader (
        .clk              (aclk),
        .reset            (reset),

        .rx_axis_tdata    (mem_rd_addr_tdata),
        .rx_axis_tvalid   (mem_rd_addr_tvalid),
        .rx_axis_tready   (mem_rd_addr_tready),

        .m_axi_araddr     (m_axi_araddr),
        .m_axi_arid       (m_axi_arid),
        .m_axi_arlen      (m_axi_arlen),
        .m_axi_arvalid    (m_axi_arvalid),
        .m_axi_arready    (m_axi_arready),

        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rid        (m_axi_rid),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_rready     (m_axi_rready),

        .tx_axis_tdata    (mem_rd_axis_tdata),
        .tx_axis_tlast    (mem_rd_axis_tlast),
        .tx_axis_tuser    (mem_rd_axis_tuser),
        .tx_axis_tvalid   (mem_rd_axis_tvalid),
        .tx_axis_tready   (mem_rd_axis_tready),

        .ddr_addr_offset_in(ddr_addr_offset),
        .fsm_state_vec_out (mem_rd_state_vec)
    );

    mem_if_writer
    u_mem_if_writer (
        .clk              (aclk),
        .reset            (reset),

        .rx_axis_tdata    (mem_wr_axis_tdata),
        .rx_axis_tlast    (mem_wr_axis_tlast),
        .rx_axis_tvalid   (mem_wr_axis_tvalid),
        .rx_axis_tready   (mem_wr_axis_tready),

        .m_axi_awid       (m_axi_awid),
        .m_axi_awaddr     (m_axi_awaddr),
        .m_axi_awlen      (m_axi_awlen),
        .m_axi_awvalid    (m_axi_awvalid),
        .m_axi_awready    (m_axi_awready),

        .m_axi_wid        (m_axi_wid),
        .m_axi_wdata      (m_axi_wdata),
        .m_axi_wstrb      (m_axi_wstrb),
        .m_axi_wlast      (m_axi_wlast),
        .m_axi_wvalid     (m_axi_wvalid),
        .m_axi_wready     (m_axi_wready),

        .m_axi_bid        (m_axi_bid),
        .m_axi_bresp      (m_axi_bresp),
        .m_axi_bvalid     (m_axi_bvalid),
        .m_axi_bready     (m_axi_bready),

        .idle_out         (mem_wr_idle),
        .ddr_addr_offset_in(ddr_addr_offset),
        .state_vec_out    (mem_wr_state_vec)
    );


    controller
    u_controller (
        .clk              (aclk),
        .reset            (reset),

        .rd_tx_axis_tdata (mem_rd_addr_tdata),
        .rd_tx_axis_tready(mem_rd_addr_tready),
        .rd_tx_axis_tvalid(mem_rd_addr_tvalid),

        .rd_rx_axis_tdata (mem_rd_axis_tdata),
        .rd_rx_axis_tlast (mem_rd_axis_tlast),
        .rd_rx_axis_tready(mem_rd_axis_tready),
        .rd_rx_axis_tvalid(mem_rd_axis_tvalid),

        .cp_tx_axis_tdata (data),
        .cp_tx_axis_tlast (last),
        .cp_tx_axis_tvalid(valid),
        .cp_tx_axis_tready(ready),

        .cp_rx_axis_tdata (tdata),
        .cp_rx_axis_tlast (tlast),
        .cp_rx_axis_tvalid(tvalid),
        .cp_rx_axis_tready(tready),

        .wr_tx_axis_tdata (mem_wr_axis_tdata),
        .wr_tx_axis_tlast (mem_wr_axis_tlast),
        .wr_tx_axis_tready(mem_wr_axis_tready),
        .wr_tx_axis_tvalid(mem_wr_axis_tvalid),

        .bb_tx_axis_tdata (bb_data),
        .bb_tx_axis_tlast (bb_last),
        .bb_tx_axis_tvalid(bb_valid),
        .bb_tx_axis_tready(bb_ready),

        .inst_in          (inst_data),
        .inst_addr_in     (inst_addr),
        .inst_wr_en_in    (inst_wr_en),

        .start_in         (start),
        .sw_bb_in         (sw_bb),
        .mem_wr_done_in   (mem_wr_idle),
        .layer_end_out    (layer_end),
        .done_out         (done),

        .data_counts_out  (ctrl_data_counts),
        .wr_state_out     (ctrl_wr_state),
        .rd_state_out     (ctrl_rd_state),
        .cp_header_out    (ctrl_cp_header),
        .loop_state_out   (ctrl_loop_state),
        .state_vec_out    (ctrl_state_vec)
    );

    conv_pool_layer u_conv_pool (
        .clk           (aclk),
        .reset         (reset),

        .r_data_in     (data),
        .r_last_in     (last),
        .r_ready_out   (ready),
        .r_valid_in    (valid),

        .t_data_out    (tdata),
        .t_last_out    (tlast),
        .t_ready_in    (tready),
        .t_valid_out                        (tvalid),

        .stat_line_buff_row_count_out       (stat_line_buff_row_count),
        .stat_line_buff_col_count_out       (stat_line_buff_col_count),
        .stat_cache_writer_row_count_out    (stat_cache_writer_row_count),
        .stat_cache_writer_col_count_out    (stat_cache_writer_col_count),

        .conv_stream_state_out              (conv_stream_state_vec),
        .rx_pix_count_out                   (conv_layer_rx_pix_count)

    );

    bounding_box u_bounding_box(
       .clk          (aclk),
       .reset        (reset),

       .axi_data     (bb_data),
       .axi_valid    (bb_valid),
       .axi_last     (bb_last),
       .axi_ready    (bb_ready),

       .read_done    (start),
       .xywh_out     (bb_xywh),
       .xywh_addr    (bb_addr),
       .set_num_out  (bb_set),
       .xywh_valid   (bb_rslt_valid)
    );



//    assign tvalid = 1'b0;
//    assign tlast  = 1'b0;
endmodule