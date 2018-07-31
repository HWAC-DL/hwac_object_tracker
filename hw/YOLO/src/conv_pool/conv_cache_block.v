`timescale 1ns / 1ps

module conv_cache_blk
    (
        clk,
        reset,

        cache_blk_sel_in,

        cache_port_a_wrt_data_in,
        cache_port_a_wrt_addr_in,
        cache_port_a_wrt_sel_in,
        cache_port_a_wrt_en_in,

        cache_port_a_rd_addr_in,
        cache_port_a_rd_sel_in,
        cache_port_a_rd_data_out,

        cache_port_b_rd_addr_in,
        cache_port_b_rd_data_out
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
   `include   "common/common_defs.v"
   `include   "common/util_funcs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam                                                  IM_CACHE_ADDR_WIDTH         = clog2(IM_CACHE_DEPTH);
    localparam                                                  IM_CACHE_SEL_WIDTH          = clog2(IM_CACHE_COUNT);
    localparam                                                  IM_CACHE_ADDR_BUS_WIDTH     = IM_CACHE_ADDR_WIDTH * IM_CACHE_COUNT;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [DATA_WIDTH-1 : 0]                              cache_port_a_wrt_data_in;
    input       [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_port_a_wrt_addr_in;
    input                                                       cache_blk_sel_in;
    input       [IM_CACHE_COUNT-1 : 0]                          cache_port_a_wrt_sel_in;
    input                                                       cache_port_a_wrt_en_in;

    input       [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_port_a_rd_addr_in;
    input       [IM_CACHE_COUNT-1 : 0]                          cache_port_a_rd_sel_in;
    output reg  [DATA_WIDTH-1 : 0]                              cache_port_a_rd_data_out;

    input       [IM_CACHE_ADDR_BUS_WIDTH-1 : 0]                 cache_port_b_rd_addr_in;
    output      [IM_CACHE_DATA_BUS_WIDTH-1 : 0]                 cache_port_b_rd_data_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    //wire        [DATA_WIDTH-1 : 0]                              cache_wrt_data_bus;
    //wire        [IM_CACHE_ADDR_WIDTH-1 : 0]                     cache_wrt_addr_bus;
    reg                                                         cache_blk_sel_reg;
    wire        [1:0]                                           cache_wrt_en_bus;

    //wire        [IM_CACHE_DATA_WIDTH-1 : 0]                     cache_port_a_rd_data_bus;
    wire        [IM_CACHE_COUNT-1 : 0]                          cache_port_a_rd_sel_delayed;


    wire        [2*IM_CACHE_ADDR_BUS_WIDTH-1 : 0]               cache_rd_addr_bus;
    wire        [2*IM_CACHE_DATA_BUS_WIDTH-1 : 0]               cache_rd_data_bus;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

     shift_reg #(
        .CLOCK_CYCLES   (IM_CACHE_DELAY),
        .DATA_WIDTH     (IM_CACHE_COUNT)    //data+wr_en
    )
    u_pixel_shift_reg_b (
        .clk            (clk),
        .enable         (1'b1),
        .data_in        (cache_port_a_rd_sel_in),
        .data_out       (cache_port_a_rd_sel_delayed)
    );

    always@(posedge clk) begin
        if(reset) begin
            cache_blk_sel_reg   <= 1'b0;
        end
        else begin
            cache_blk_sel_reg   <= cache_blk_sel_in;
        end
    end

    genvar i;
    genvar k;
    generate
        //assign cache_wrt_en_bus = 2'b0;
        always @(*) begin
            case(cache_port_a_rd_sel_delayed)
                'h1 : begin
                    cache_port_a_rd_data_out = (cache_blk_sel_reg) ? cache_rd_data_bus[(IM_CACHE_DATA_BUS_WIDTH + 0 * DATA_WIDTH) +: DATA_WIDTH] : cache_rd_data_bus[(0 * DATA_WIDTH) +: DATA_WIDTH];
                end
                'h2 : begin
                    cache_port_a_rd_data_out = (cache_blk_sel_reg) ? cache_rd_data_bus[(IM_CACHE_DATA_BUS_WIDTH + 1 * DATA_WIDTH) +: DATA_WIDTH] : cache_rd_data_bus[(1 * DATA_WIDTH) +: DATA_WIDTH];
                end
                'h4 : begin
                    cache_port_a_rd_data_out = (cache_blk_sel_reg) ? cache_rd_data_bus[(IM_CACHE_DATA_BUS_WIDTH + 2 * DATA_WIDTH) +: DATA_WIDTH] : cache_rd_data_bus[(2 * DATA_WIDTH) +: DATA_WIDTH];
                end
                'h8 : begin
                    cache_port_a_rd_data_out = (cache_blk_sel_reg) ? cache_rd_data_bus[(IM_CACHE_DATA_BUS_WIDTH + 3 * DATA_WIDTH) +: DATA_WIDTH] : cache_rd_data_bus[(3 * DATA_WIDTH) +: DATA_WIDTH];
                end
                default : begin
                    cache_port_a_rd_data_out = {DATA_WIDTH{1'b0}};
                end
            endcase
        end

        //assign cache_port_a_rd_data_out = (cache_blk_sel_reg) ? cache_rd_data_bus[(IM_CACHE_DATA_WIDTH + cache_port_a_rd_sel_delayed * DATA_WIDTH) +: IM_CACHE_DATA_WIDTH] : cache_rd_data_bus[(cache_port_a_rd_sel_delayed * DATA_WIDTH) +: IM_CACHE_DATA_WIDTH];
        assign cache_port_b_rd_data_out = (~cache_blk_sel_reg) ? cache_rd_data_bus[IM_CACHE_DATA_BUS_WIDTH +: IM_CACHE_DATA_BUS_WIDTH] : cache_rd_data_bus[0 +: IM_CACHE_DATA_BUS_WIDTH];
        for(i=0; i<2; i=i+1) begin
            assign cache_wrt_en_bus [i] = (i==cache_blk_sel_reg) ? cache_port_a_wrt_en_in : 1'b0;
            for(k=0;k<IM_CACHE_COUNT;k=k+1) begin : cache_split_blk
                assign cache_rd_addr_bus[(i*IM_CACHE_ADDR_BUS_WIDTH + k*IM_CACHE_ADDR_WIDTH) +: IM_CACHE_ADDR_WIDTH]
                                        = (i==cache_blk_sel_reg) ? cache_port_a_rd_addr_in : cache_port_b_rd_addr_in[k*IM_CACHE_ADDR_WIDTH +: IM_CACHE_ADDR_WIDTH];
                conv_cache_bram
                u_conv_cache
                (
                    .clka               (clk),
                    .wea                ((cache_wrt_en_bus[i] && cache_port_a_wrt_sel_in[k])),
                    .addra              (cache_port_a_wrt_addr_in),
                    .dina               (cache_port_a_wrt_data_in),

                    .clkb               (clk),
                    .addrb              (cache_rd_addr_bus[(i*IM_CACHE_ADDR_BUS_WIDTH + k*IM_CACHE_ADDR_WIDTH) +: IM_CACHE_ADDR_WIDTH]),
                    .doutb              (cache_rd_data_bus[((i * IM_CACHE_DATA_BUS_WIDTH) + k*DATA_WIDTH) +: DATA_WIDTH])
                 );
            end
        end
    endgenerate



endmodule
