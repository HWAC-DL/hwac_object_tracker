`timescale 1ns / 1ps

module bb_cache_block
    (
        clk,
        reset,

        //port a
        port_a_wrt_data_in,
        port_a_wrt_addr_in,
        port_a_wrt_en_in,
        port_a_rd_addr_in,
        port_a_rd_data_out,
        port_a_chip_sel_in,

        //port b
        port_b_av_out,
        port_b_rd_addr_in,
        port_b_rd_data_out,
        port_b_chip_sel_in
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
   `include   "util_funcs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter                                                   DATA_WIDTH       = 16;
    parameter                                                   BB_CACHE_DEPTH   = 170;
    parameter                                                   BB_CACHE_COUNT   = 5;
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam                                                  BB_CACHE_DELAY          = 2;
    localparam                                                  BB_CACHE_ADDR_WIDTH     = clog2(BB_CACHE_DEPTH);
    localparam                                                  BB_CACHE_CHIP_SEL_WIDTH = clog2(BB_CACHE_COUNT);
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    //port a
    input       [DATA_WIDTH-1 : 0]                              port_a_wrt_data_in;
    input       [BB_CACHE_ADDR_WIDTH-1 : 0]                     port_a_wrt_addr_in;
    input                                                       port_a_wrt_en_in;
    input       [BB_CACHE_ADDR_WIDTH-1 : 0]                     port_a_rd_addr_in;
    output      [DATA_WIDTH-1 : 0]                              port_a_rd_data_out;
    input       [BB_CACHE_COUNT-1: 0]                           port_a_chip_sel_in;

    //port b
    output reg  [BB_CACHE_COUNT-1:0]                            port_b_av_out;
    input       [BB_CACHE_ADDR_WIDTH-1 : 0]                     port_b_rd_addr_in;
    output      [DATA_WIDTH-1 : 0]                              port_b_rd_data_out;
    input       [BB_CACHE_COUNT-1: 0]                           port_b_chip_sel_in;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg         [BB_CACHE_COUNT-1: 0]                           port_a_chip_sel_reg;
    reg         [BB_CACHE_COUNT-1: 0]                           port_a_chip_sel_delayed;
    reg         [BB_CACHE_COUNT-1: 0]                           port_b_chip_sel_delayed;

    wire        [BB_CACHE_COUNT * BB_CACHE_ADDR_WIDTH-1 : 0]    rd_addr;
    wire        [BB_CACHE_COUNT * DATA_WIDTH-1 : 0]             rd_data;

    wire        [BB_CACHE_CHIP_SEL_WIDTH-1 : 0]                 port_a_chip_sel_code;
    wire        [BB_CACHE_CHIP_SEL_WIDTH-1 : 0]                 port_b_chip_sel_code;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
    //delayes chip select to sync with data out from cache
    /*
    shift_reg #(
        .CLOCK_CYCLES   (BB_CACHE_DELAY),
        .DATA_WIDTH     (2 * BB_CACHE_COUNT) //chip_sel
    )
    u_pixel_shift_reg_b (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        ({port_b_chip_sel_in, port_a_chip_sel_in}),
        .data_out       ({port_b_chip_sel_delayed, port_a_chip_sel_delayed})
        );
    */
    always@(posedge clk) begin
        if(reset) begin
            port_a_chip_sel_delayed <= {BB_CACHE_COUNT{1'b0}};
            port_b_chip_sel_delayed <= {BB_CACHE_COUNT{1'b0}};
        end
        else begin
            port_a_chip_sel_delayed <= port_a_chip_sel_in;
            port_b_chip_sel_delayed <= port_b_chip_sel_in;
        end
    end

    genvar i;
    generate
        for(i=0;i<BB_CACHE_COUNT;i=i+1) begin : cache_blk
            assign rd_addr[i*BB_CACHE_ADDR_WIDTH +: BB_CACHE_ADDR_WIDTH]
                                                = (port_a_chip_sel_in[i] == 1'b1) ? port_a_rd_addr_in : port_b_rd_addr_in;  //rd addr mux
            bmem_16_10_dp
            u_bb_cache
            (
                .clka               (clk),
                .ena                (1'b1),
                .wea                ((port_a_wrt_en_in && port_a_chip_sel_in[i])),
                .addra              (port_a_wrt_addr_in),
                .dina               (port_a_wrt_data_in),

                .clkb               (clk),
                .enb                (1'b1),
                .addrb              (rd_addr[i*BB_CACHE_ADDR_WIDTH +: BB_CACHE_ADDR_WIDTH]),
                .doutb              (rd_data[i*DATA_WIDTH +: DATA_WIDTH])
             );
        end
    endgenerate

    //convert chip sel to chip idx
    vector2index
    #(
        .VECTOR_WIDTH               (BB_CACHE_COUNT)
    )
    u_port_a_chip_sel_code_converter
    (
        .vector_in                  (port_a_chip_sel_delayed),
        .index_out                  (port_a_chip_sel_code),
        .contains_valid_index_out   ()
    );

    vector2index
    #(
        .VECTOR_WIDTH               (BB_CACHE_COUNT)
    )
    u_port_b_chip_sel_code_converter
    (
        .vector_in                  (port_b_chip_sel_delayed),
        .index_out                  (port_b_chip_sel_code),
        .contains_valid_index_out   ()
    );

    //rd data out demux
    assign port_a_rd_data_out  = rd_data[port_a_chip_sel_code * DATA_WIDTH +: DATA_WIDTH];
    assign port_b_rd_data_out  = rd_data[port_b_chip_sel_code * DATA_WIDTH +: DATA_WIDTH];

    //port b chip av logic
    integer j;
    always@(posedge clk) begin
        if(reset) begin
            port_a_chip_sel_reg    <= {BB_CACHE_COUNT{1'b0}};
            port_b_av_out          <= {BB_CACHE_COUNT{1'b0}};
        end
        else begin
            port_a_chip_sel_reg    <= port_a_chip_sel_in;
            for(j=0;j<BB_CACHE_COUNT;j=j+1) begin
                if(~port_a_chip_sel_in[j] && port_a_chip_sel_reg[j]) begin    //chip transition edge
                    port_b_av_out[j]  <= 1'b1;
                end
                else if(port_a_chip_sel_in[j]) begin
                    port_b_av_out[j]  <= 1'b0;
                end
                else if(port_b_chip_sel_in[j]) begin
                    port_b_av_out[j]  <= 1'b0;
                end
            end
        end
    end

endmodule