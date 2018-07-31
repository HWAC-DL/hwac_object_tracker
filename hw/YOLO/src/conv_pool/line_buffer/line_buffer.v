`timescale 1ns / 1ps

module line_buffer
    (
        clk,
        reset,

        im_cols_in,
        im_rows_in,
        padding_mask_in,
        padding_val_in,
        conv_size_in,

        pixel_in,
        pixel_valid_in,
        pixel_last_in,

        window_out,
        window_valid_out,

        stat_row_addr_out,
        stat_col_addr_out
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
   `include "../src/tiny_yolo_params.v"
   `include   "common/common_defs.v"
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter                                                   WINDOW_DIM          = 3;
    //parameter                                                   IMG_COLS            = MAX_COL;
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    //parameter                                                   IM_COL_ADDR_WIDTH   = $clog2(IMG_COLS);
    localparam                                                  BLOCK_RAM_DELAY     = 2;

    //localparam                                                  IM_CACHE_SIZE       = 52 * 208;
    //parameter                                                   IM_CACHE_SIZE_WIDTH = $clog2(IM_CACHE_SIZE);
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                                       clk;
    input                                                       reset;

    input       [DIM_WIDTH-1 : 0]                               im_cols_in;
    input       [DIM_WIDTH-1 : 0]                               im_rows_in;
    input       [PADDING_WIDTH-1 : 0]                           padding_mask_in;
    input       [DATA_WIDTH-1 : 0]                              padding_val_in;
    input       [CONV_SIZE_WIDTH-1 : 0]                         conv_size_in;

    input       [DATA_WIDTH-1 : 0]                              pixel_in;
    input                                                       pixel_valid_in;
    input                                                       pixel_last_in;

    output reg  [WINDOW_DIM * WINDOW_DIM * DATA_WIDTH -1 : 0]   window_out;
    output reg                                                  window_valid_out;

    output      [DIM_WIDTH-1 : 0]                               stat_row_addr_out;
    output      [DIM_WIDTH-1 : 0]                               stat_col_addr_out;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    wire                                                        pad_top;
    wire                                                        pad_right;
    wire                                                        pad_bottom;
    wire                                                        pad_left;

    reg         [DIM_WIDTH-1 : 0]                               max_col_offset;
    reg         [DIM_WIDTH-1 : 0]                               max_row_offset;

    reg         [DIM_WIDTH-1 : 0]                               col_addr;
    reg         [DIM_WIDTH-1 : 0]                               row_addr;

    wire        [DATA_WIDTH-1 : 0]                              pixel_reg;
    wire                                                        pixel_valid_reg;
    wire                                                        pixel_last_reg;
    wire        [DIM_WIDTH-1 : 0]                               row_addr_delayed;
    wire        [DIM_WIDTH-1 : 0]                               col_addr_delayed;
    reg         [DIM_WIDTH-1 : 0]                               row_addr_reg;
    reg         [DIM_WIDTH-1 : 0]                               col_addr_reg;

    wire        [WINDOW_DIM * DATA_WIDTH-1 : 0]                 line_buff_dout;
    wire        [WINDOW_DIM * DATA_WIDTH-1 : 0]                 line_buff_din;
    reg         [WINDOW_DIM * WINDOW_DIM * DATA_WIDTH -1 : 0]   window_reg;
    reg                                                         window_valid_reg;

    //reg         [TOTAL_PXL_WIDTH-1 : 0]                         start_valid_pix;
    reg         [DIM_WIDTH-1 : 0]                               start_row;
    //reg         [IM_CACHE_SIZE_WIDTH-1 : 0]                     pix_count;
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

    //init logic
    always@(posedge clk) begin : init_blk
        if(reset) begin
            max_col_offset    <= {DIM_WIDTH{1'b0}};
            max_row_offset    <= {DIM_WIDTH{1'b0}};
            start_row         <= {DIM_WIDTH{1'b0}};
        end
        else begin
            max_col_offset    <= im_cols_in - 1;
            max_row_offset    <= im_rows_in + pad_bottom - 1;
            start_row         <= CONV_KERNEL_DIM - pad_top - 1;
        end
    end

    //pipeline stage 1 start
    //assign {pad_top, pad_left, pad_bottom, pad_right} = padding_mask_in;
    assign {pad_right, pad_left, pad_bottom, pad_top} = padding_mask_in;
    shift_reg
    #(
        .CLOCK_CYCLES   (BLOCK_RAM_DELAY),
        .DATA_WIDTH     (2*DIM_WIDTH + DATA_WIDTH + 2)    //+2 for valid,last
    )
    u_shift_reg
    (
        .clk        (clk),

        .enable     (1'b1),
        .data_in    ({pixel_last_in, pixel_valid_in, row_addr, col_addr, pixel_in}),
        .data_out   ({pixel_last_reg, pixel_valid_reg, row_addr_delayed, col_addr_delayed, pixel_reg})
    );

    always@(posedge clk) begin : addr_gen_blk
        if(reset) begin
            row_addr                <= {DIM_WIDTH{1'b0}};
            col_addr                <= {DIM_WIDTH{1'b0}};
        end
        else begin
            if(pixel_valid_in) begin
                if(col_addr == max_col_offset) begin
                    col_addr        <= {DIM_WIDTH{1'b0}};
                    if(row_addr == max_row_offset) begin
                        row_addr    <= {DIM_WIDTH{1'b0}};
                    end
                    else begin
                        row_addr    <= row_addr + 1'b1;
                    end
                end
                else begin
                    col_addr        <= col_addr + 1'b1;
                end
            end
            else if(pixel_valid_reg && pixel_last_reg) begin
                row_addr            <= {DIM_WIDTH{1'b0}};
                col_addr            <= {DIM_WIDTH{1'b0}};
            end
        end
    end

    genvar i;
    generate
        assign line_buff_din = {pixel_reg, line_buff_dout[DATA_WIDTH +: 2 * DATA_WIDTH]};    //shift op
        for(i=0;i<WINDOW_DIM;i=i+1) begin : line_buff_blk
            line_buffer_106
            u_conv_line_buff
            (
                .clka       (clk),

                .wea        (1'b0),
                .addra      (col_addr),
                .dina       ({DATA_WIDTH{1'b0}}),
                .douta      (line_buff_dout [i*DATA_WIDTH +: DATA_WIDTH]),

                .clkb       (clk),
                .web        (pixel_valid_reg),
                .addrb      (col_addr_delayed),
                .dinb       (line_buff_din  [i*DATA_WIDTH +: DATA_WIDTH]),
                .doutb      ()
            );
        end
    endgenerate

    //pipeline stage 1 end

    //pipeline stage 2 start
    integer k;
    always @(posedge clk) begin
        if(reset) begin
            window_reg <= {(WINDOW_DIM * WINDOW_DIM * DATA_WIDTH){1'b0}};
        end
        else begin
            for(k=0;k<WINDOW_DIM * WINDOW_DIM;k=k+1) begin
                if(pixel_valid_reg) begin
                    if(k%WINDOW_DIM == 0) begin
                        window_reg[DATA_WIDTH * (WINDOW_DIM + k -1) +: DATA_WIDTH]  <= line_buff_din[(k/WINDOW_DIM) * DATA_WIDTH +: DATA_WIDTH];
                    end
                    else begin
                        window_reg[DATA_WIDTH * (k-1) +: DATA_WIDTH]                <= window_reg[DATA_WIDTH * k +: DATA_WIDTH];
                    end
                end
            end
        end
    end

    always@(posedge clk) begin : window_valid_blk
        if(reset) begin
            row_addr_reg                    <= {DIM_WIDTH{1'b0}};
            col_addr_reg                    <= {DIM_WIDTH{1'b0}};
            window_valid_reg                <= 1'b0;
            //pix_count                       <= {IM_CACHE_SIZE_WIDTH{1'b0}};
        end
        else begin
            row_addr_reg                    <= row_addr_delayed;
            col_addr_reg                    <= col_addr_delayed;
            if(pixel_valid_reg) begin
                //pix_count                   <= pix_count + 1'b1;
                //if(pix_count >= start_valid_pix) begin
                if(row_addr_delayed >= start_row) begin
                    if(col_addr_delayed == 0) begin
                        window_valid_reg    <= (pad_right && (row_addr_delayed>start_row)) ? 1'b1 : 1'b0;
                    end
                    else if(col_addr_delayed == 1) begin
                        window_valid_reg    <= (pad_left)  ? 1'b1 : 1'b0;
                    end
                    else begin
                        window_valid_reg    <= 1'b1;
                    end
                end
                else if(pixel_last_reg && pad_right) begin
                    window_valid_reg        <= 1'b1;
                end
                else begin
                    window_valid_reg        <= 1'b0;
                end
            end
            else begin
                window_valid_reg            <= 1'b0;
            end
        end
    end

    //pipeline stage 2 end

    //pipeline stage 3 start
    integer j;
    always@(posedge clk) begin : padding_blk
        if(reset) begin
            window_out                                         <= {(WINDOW_DIM * WINDOW_DIM * DATA_WIDTH){1'b0}};
            window_valid_out                                   <= 1'b0;
        end
        else begin
            if(conv_size_in == CONV_SIZE_1_1) begin
                window_out[0 +: DATA_WIDTH]                    <= pixel_in;
                window_out[DATA_WIDTH +: (WINDOW_DIM * WINDOW_DIM - 1) * DATA_WIDTH]
                                                               <= {((WINDOW_DIM * WINDOW_DIM - 1) * DATA_WIDTH) {1'b0}};
                window_valid_out                               <= pixel_valid_in;
            end
            else if(conv_size_in == CONV_SIZE_3_3) begin
                window_out                                     <= window_reg;
                window_valid_out                               <= window_valid_reg;
                for(j=0;j<WINDOW_DIM * WINDOW_DIM;j=j+1) begin
                    if(pad_top && row_addr_reg == 1 && (j/CONV_KERNEL_DIM==0)) begin
                        window_out[j*DATA_WIDTH +: DATA_WIDTH] <= (padding_val_in[0]==1'b1) ? window_reg[(j+WINDOW_DIM)*DATA_WIDTH +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
                    end
                    if(pad_bottom && row_addr_reg == im_rows_in && (j/CONV_KERNEL_DIM==2))begin //row_addr_reg == im_rows_in, since an additional row is generated by conv stream
                        window_out[j*DATA_WIDTH +: DATA_WIDTH] <= (padding_val_in[0]==1'b1) ? window_reg[(j-WINDOW_DIM)*DATA_WIDTH +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
                    end
                    if(pad_left && col_addr_reg == 1 && (j%CONV_KERNEL_DIM==0)) begin
                        window_out[j*DATA_WIDTH +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                    end
                    if(pad_right && col_addr_reg == 0 && (j%CONV_KERNEL_DIM==2)) begin
                        window_out[j*DATA_WIDTH +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                    end
                end
            end
        end
    end
    //pipeline stage 3 start

    //stat
    assign stat_col_addr_out    = col_addr_reg;
    assign stat_row_addr_out    = row_addr_reg;
endmodule