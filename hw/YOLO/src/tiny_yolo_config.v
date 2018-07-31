`timescale 1ns / 1ps

module tiny_yolo_config
    (
        aclk,
        areset,

        s_axi_awaddr,
        s_axi_awvalid,
        s_axi_awready,

        s_axi_wdata,
        s_axi_wstrb,
        s_axi_wvalid,
        s_axi_wready,

        s_axi_bresp,
        s_axi_bvalid,
        s_axi_bready,

        s_axi_araddr,
        s_axi_arvalid,
        s_axi_arready,

        s_axi_rdata,
        s_axi_rresp,
        s_axi_rvalid,
        s_axi_rready,

        sreset_out,
        ddr_addr_offset_out,
        start_out,
        sw_bb_out,
        layer_end_in,
        done_in,

        inst_data_out,
        inst_addr_out,
        inst_wr_en_out,

        ctrl_cp_if_stats_in,
        ctrl_data_counts_in,
        ctrl_state_vec_in,
        mem_rd_state_vec_in,
        mem_wr_state_vec_in,
        wr_state_in,
        rd_state_in,
        cp_header_in,
        loop_state_in,

        line_buff_row_count_in,
        line_buff_col_count_in,
        cache_writer_row_count_in,
        cache_writer_col_count_in,
        conv_stream_state_vec_in,
        conv_layer_rx_pix_count_in,

        bb_xywh_in,
        bb_rslt_data_in
    );

//-------------------------------------------------------------------------------------------------
// Global constant headers
//-------------------------------------------------------------------------------------------------
    `include "../src/common/axi4_params.v"
    `include "../src/common/axi3_params.v"
    `include "../src/mem_if/mem_params.v"
    `include "../src/tiny_yolo_params.v"
    `include   "common/common_defs.v"
//-------------------------------------------------------------------------------------------------
// Parameter definitions
//-------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------
// Localparam definitions
//-------------------------------------------------------------------------------------------------
    localparam      STATE_REQ               = 0;
    localparam      STATE_WDATA             = 1;
    localparam      STATE_WRSP              = 2;
    localparam      STATE_RWAIT             = 3;
    localparam      STATE_RDATA             = 4;

    localparam      DEFAULT_BUS_VALUE       = {AXI4L_DATA_WIDTH{1'b0}};
//-------------------------------------------------------------------------------------------------
// I/O signals
//-------------------------------------------------------------------------------------------------
    input                                           aclk;
    input                                           areset;

    input       [AXI4L_ADDR_WIDTH-1:0]              s_axi_awaddr;
    input                                           s_axi_awvalid;
    output reg                                      s_axi_awready;

    input       [AXI4L_DATA_WIDTH-1:0]              s_axi_wdata;
    input       [AXI4L_STRB_WIDTH-1:0]              s_axi_wstrb;
    input                                           s_axi_wvalid;
    output reg                                      s_axi_wready;

    output reg  [1:0]                               s_axi_bresp;
    output reg                                      s_axi_bvalid;
    input                                           s_axi_bready;

    input       [AXI4L_ADDR_WIDTH-1:0]              s_axi_araddr;
    input                                           s_axi_arvalid;
    output reg                                      s_axi_arready;

    output reg  [AXI4L_DATA_WIDTH-1:0]              s_axi_rdata;
    output reg  [AXI4L_RESP_WIDTH-1:0]              s_axi_rresp;
    output reg                                      s_axi_rvalid;
    input                                           s_axi_rready;

    output reg                                      sreset_out;
    output reg  [AXI4L_DATA_WIDTH-1:0]              ddr_addr_offset_out;
    output reg                                      start_out;
    output reg                                      sw_bb_out;
    input                                           layer_end_in;
    input                                           done_in;

    output reg  [AXI4L_DATA_WIDTH*3 - 1:0]          inst_data_out;
    output reg  [AXI4L_DATA_WIDTH-1 :0]             inst_addr_out;
    output reg                                      inst_wr_en_out;

    input       [2*AXI4L_DATA_WIDTH-1 :0]           ctrl_data_counts_in;
    input       [AXI4L_DATA_WIDTH-1 :0]             ctrl_state_vec_in;
    input       [AXI4L_DATA_WIDTH-1 :0]             mem_rd_state_vec_in;
    input       [AXI4L_DATA_WIDTH-1 :0]             mem_wr_state_vec_in;
    input       [AXI4L_DATA_WIDTH-1 : 0]            ctrl_cp_if_stats_in;
    input       [AXI4L_DATA_WIDTH-1 : 0]            loop_state_in;
    input       [2*AXI4L_DATA_WIDTH-1 : 0]          cp_header_in;
    input       [3*AXI4L_DATA_WIDTH-1 : 0]          wr_state_in;
    input       [3*AXI4L_DATA_WIDTH-1 : 0]          rd_state_in;

    input       [INPUT_DIM * DIM_WIDTH -1 : 0]      line_buff_row_count_in;
    input       [INPUT_DIM * DIM_WIDTH -1 : 0]      line_buff_col_count_in;
    input       [OUTPUT_DIM * DIM_WIDTH -1 : 0]     cache_writer_row_count_in;
    input       [OUTPUT_DIM * DIM_WIDTH -1 : 0]     cache_writer_col_count_in;
    input       [AXI4L_DATA_WIDTH-1 : 0]            conv_stream_state_vec_in;
    input       [TOTAL_PXL_WIDTH-1 : 0]             conv_layer_rx_pix_count_in;

    input       [63:0] bb_xywh_in;
    input       [11:0] bb_rslt_data_in;

//-------------------------------------------------------------------------------------------------
// Internal wires and registers
//-------------------------------------------------------------------------------------------------
    reg         [AXI4L_DATA_WIDTH-1:0]              read_data_reg;

    reg         [AXI4L_DATA_WIDTH-1:0]              mem_data_reg;
    reg                                             mem_wr_en_reg;
    reg                                             mem_r_en_reg;
    reg         [15:0]                              mem_addr_reg;

    integer                                         state;
//-------------------------------------------------------------------------------------------------
// Implementation
//-------------------------------------------------------------------------------------------------

    always @ (posedge aclk) begin
        if (areset) begin
            s_axi_awready               <= 1'b0;
            s_axi_wready                <= 1'b0;
            s_axi_bresp                 <= 2'b0;
            s_axi_bvalid                <= 1'b0;
            s_axi_arready               <= 1'b0;
            s_axi_rdata                 <= DEFAULT_BUS_VALUE;
            s_axi_rresp                 <= 2'b0;
            s_axi_rvalid                <= 1'b0;
            mem_wr_en_reg               <= 1'b0;
            mem_r_en_reg                <= 1'b0;
            mem_addr_reg                <= 16'b0;
            mem_data_reg                <= 32'b0;
            state                       <= STATE_REQ;
        end
        else begin
            case (state)
                STATE_REQ: begin
                    s_axi_rvalid        <= 1'b0;
                    if (s_axi_arvalid) begin
                        mem_addr_reg    <= s_axi_araddr[15:0];
                        s_axi_arready   <= 1'b1;
                        state           <= STATE_RWAIT;
                    end
                    if (s_axi_awvalid) begin
                        mem_addr_reg    <= s_axi_awaddr[15:0];
                        mem_r_en_reg    <= 1'b1;
                        s_axi_awready   <= 1'b1;
                        state           <= STATE_WDATA;
                    end
                end
                STATE_WDATA: begin
                    s_axi_awready       <= 1'b0;
                    s_axi_wready        <= 1'b1;
                    if (s_axi_wready & s_axi_wvalid) begin
                        mem_data_reg    <= s_axi_wdata;
                        mem_wr_en_reg   <= 1'b1;
                        s_axi_wready    <= 1'b0;
                        state           <= STATE_WRSP;
                    end
                end
                STATE_WRSP: begin
                    mem_wr_en_reg       <= 1'b0;
                    s_axi_bresp         <= 2'b0;
                    s_axi_bvalid        <= 1'b1;
                    if (s_axi_bvalid & s_axi_bready) begin
                        s_axi_bvalid    <= 1'b0;
                        state           <= STATE_REQ;
                    end
                end
                STATE_RWAIT: begin
                    s_axi_arready       <= 1'b0;
                    mem_r_en_reg        <= 1'b0;
                    if (s_axi_rready) begin
                        state           <= STATE_RDATA;
                    end
                end
                STATE_RDATA: begin
                    s_axi_rdata         <= read_data_reg;
                    s_axi_rresp         <= 2'b0;
                    s_axi_rvalid        <= 1'b1;
                    state               <= STATE_REQ;
                end
            endcase
        end
    end

    always@(posedge aclk) begin
        if (areset) begin
            inst_wr_en_out                          <= 1'b0;
            sreset_out                              <= 1'b1;
            start_out                               <= 1'b0;
            sw_bb_out                               <= 1'b0;
            ddr_addr_offset_out                     <= {AXI4L_DATA_WIDTH{1'b0}};
            inst_addr_out                           <= {AXI4L_DATA_WIDTH{1'b0}};
            inst_data_out                           <= {(3*AXI4L_DATA_WIDTH){1'b0}};
            read_data_reg                           <= DEFAULT_BUS_VALUE;
        end
        else begin
            inst_wr_en_out                          <= 1'b0;
            start_out                               <= 1'b0;
            case (mem_addr_reg)
                0: begin
                    if(mem_wr_en_reg) begin
                        sreset_out                  <= mem_data_reg[0];
                    end
                    read_data_reg                   <= DEFAULT_BUS_VALUE;
                    read_data_reg[0]                <= sreset_out;
                end
                4: begin
                    if(mem_wr_en_reg) begin
                        ddr_addr_offset_out         <= mem_data_reg;
                    end
                    read_data_reg                   <= ddr_addr_offset_out;
                end
                8: begin
                    if(mem_wr_en_reg) begin
                        start_out                   <= mem_data_reg[0];
                        sw_bb_out                   <= mem_data_reg[1];
                    end
                    read_data_reg                   <= DEFAULT_BUS_VALUE;
                    read_data_reg[0]                <= start_out;
                    read_data_reg[1]                <= sw_bb_out;
                end
                12: begin
                    read_data_reg                   <= DEFAULT_BUS_VALUE;
                    read_data_reg[0]                <= done_in;
                    read_data_reg[1]                <= layer_end_in;
                end

                20: begin
                    if(mem_wr_en_reg) begin
                        inst_data_out[0 +: AXI4L_DATA_WIDTH]    <= mem_data_reg;
                    end
                    read_data_reg                   <= inst_data_out[0 +: AXI4L_DATA_WIDTH];
                end
                24: begin
                    if(mem_wr_en_reg) begin
                        inst_data_out[AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH]    <= mem_data_reg;
                    end
                    read_data_reg                   <= inst_data_out[AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                28: begin
                    if(mem_wr_en_reg) begin
                        inst_data_out[2*AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH]    <= mem_data_reg;
                    end
                    read_data_reg                   <= inst_data_out[2*AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                32: begin
                    if(mem_wr_en_reg) begin
                        inst_addr_out               <= mem_data_reg;
                        inst_wr_en_out              <= 1'b1;
                    end
                    read_data_reg                   <= inst_addr_out;
                end

                48: begin
                    read_data_reg                   <= ctrl_state_vec_in;
                end
                52: begin
                    read_data_reg                   <= mem_rd_state_vec_in;
                end
                56: begin
                    read_data_reg                   <= mem_wr_state_vec_in;
                end
                60: begin
                    read_data_reg                   <= loop_state_in;
                end
                64: begin
                    read_data_reg                   <= cp_header_in[0 +: AXI4L_DATA_WIDTH];
                end
                68: begin
                    read_data_reg                   <= cp_header_in[AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                72: begin
                    read_data_reg                   <= rd_state_in[0 +: AXI4L_DATA_WIDTH];
                end
                76: begin
                    read_data_reg                   <= rd_state_in[AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                80: begin
                    read_data_reg                   <= rd_state_in[2*AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                84: begin
                    read_data_reg                   <= wr_state_in[0 +: AXI4L_DATA_WIDTH];
                end
                88: begin
                    read_data_reg                   <= wr_state_in[AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                92: begin
                    read_data_reg                   <= wr_state_in[2*AXI4L_DATA_WIDTH +: AXI4L_DATA_WIDTH];
                end
                96 : begin
                    read_data_reg                   <= line_buff_col_count_in;
                end
                100 : begin
                    read_data_reg                   <= line_buff_row_count_in;
                end
                104 : begin
                    read_data_reg                   <= cache_writer_col_count_in;
                end
                108 : begin
                    read_data_reg                   <= cache_writer_row_count_in;
                end
                112 : begin
                    read_data_reg                   <= conv_stream_state_vec_in;
                end
                116 : begin
                    read_data_reg                   <= conv_layer_rx_pix_count_in;
                end
                120 : begin
                    read_data_reg                   <= ctrl_data_counts_in[31:0];
                end
                124 : begin
                    read_data_reg                   <= ctrl_data_counts_in[63:32];
                end
                128 : begin
                    read_data_reg                   <= ctrl_cp_if_stats_in;
                end
                132 : begin
                    read_data_reg                   <= bb_xywh_in[31:0];
                end
                136 : begin
                    read_data_reg                   <= bb_xywh_in[63:32];
                end
                140 : begin
                    read_data_reg                   <= bb_rslt_data_in;
                end
                default: begin
                    read_data_reg                   <= DEFAULT_BUS_VALUE;
                end
            endcase
        end
    end
endmodule
