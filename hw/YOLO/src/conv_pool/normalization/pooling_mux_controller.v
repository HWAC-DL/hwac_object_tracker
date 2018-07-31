`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/19/2018 09:40:19 AM
// Design Name:
// Module Name: pooling_mux_controller
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


module pooling_mux_controller(
    clk,
    reset,

    pixel_data_valid,
    bram_data_1,
    bram_data_2,
    bram_data_3,
    bram_data_4,

    pool_data_out,
    pool_data_valid,

    image_width,
    image_hight,
    pooling_stride
    );

    `include "conv_pool/normalization/normalization_defs.v"

    input                                           clk;
    input                                           reset;
    input                                           pixel_data_valid;

    input       [BRAM_DATA_WIDTH-1:0]               bram_data_1;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_2;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_3;
    input       [BRAM_DATA_WIDTH-1:0]               bram_data_4;

    output      [BRAM_DATA_WIDTH-1:0]               pool_data_out;
    output                                          pool_data_valid;

    input       [IMAGE_SIZE_WIDTH-1 : 0]            image_width;
    input       [IMAGE_SIZE_WIDTH-1 : 0]            image_hight;
    input       [1:0]                               pooling_stride;


    wire      [BRAM_DATA_WIDTH-1:0]               bram_data_1_int;
    wire      [BRAM_DATA_WIDTH-1:0]               bram_data_2_int;
    wire      [BRAM_DATA_WIDTH-1:0]               bram_data_3_int;
    wire      [BRAM_DATA_WIDTH-1:0]               bram_data_4_int;
    wire      [3:0]                               data_valid_int;

    reg       [BRAM_DATA_WIDTH-1:0]               bram_data_1_r;
    reg       [BRAM_DATA_WIDTH-1:0]               bram_data_2_r;
    reg       [BRAM_DATA_WIDTH-1:0]               bram_data_3_r;
    reg       [BRAM_DATA_WIDTH-1:0]               bram_data_4_r;
    reg       [3:0]                               data_valid_r;


    reg       [IMAGE_SIZE_WIDTH-1 : 0]            row_count_reg;
    reg       [IMAGE_SIZE_WIDTH-1 : 0]            column_count_reg;


    reg       [3:0]                               state;


    localparam                                                      STATE_WAIT                              = 0;
    localparam                                                      STATE_STRIDE_0                          = 1;
    localparam                                                      STATE_STRIDE_1                          = 2;
    localparam                                                      STATE_STRIDE_2                          = 3;
    localparam                                                      STATE_LAST                              = 4;

    assign  bram_data_1_int = bram_data_1_r;
    assign  bram_data_2_int = bram_data_2_r;
    assign  bram_data_3_int = bram_data_3_r;
    assign  bram_data_4_int = bram_data_4_r;
    assign data_valid_int   = data_valid_r;

    always @(posedge clk) begin
            if (reset) begin
                bram_data_1_r    <= {BRAM_DATA_WIDTH{1'b0}};
                bram_data_2_r    <= {BRAM_DATA_WIDTH{1'b0}};
                bram_data_3_r    <= {BRAM_DATA_WIDTH{1'b0}};
                bram_data_4_r    <= {BRAM_DATA_WIDTH{1'b0}};
            end
            else begin
                bram_data_1_r    <= bram_data_1;
                bram_data_2_r    <= bram_data_2;
                bram_data_3_r    <= bram_data_3;
                bram_data_4_r    <= bram_data_4;
            end
    end


    always @(posedge clk) begin
        if (reset)begin
            data_valid_r                        <= 4'b0000;
            row_count_reg                       <= 0;
            column_count_reg                    <= 0;
            state                               <= STATE_WAIT;
        end
        else begin
            case (state)
                STATE_WAIT : begin
                    row_count_reg               <= 0;
                    column_count_reg            <= 0;
                    data_valid_r                <= 4'b0000;
                    if (pixel_data_valid) begin
                        if (pooling_stride == 0) begin
                            state               <= STATE_STRIDE_0;
                            data_valid_r <= 4'b0001;                        
                            column_count_reg        <= column_count_reg + 1;
                        end
                        if (pooling_stride == 1) begin
                            state               <= STATE_STRIDE_1;
                            data_valid_r <= 4'b1111;
                        end
                        if (pooling_stride == 2) begin
                            state               <= STATE_STRIDE_2;
                            data_valid_r <= 4'b1111;
                        end
                        //column_count_reg        <= column_count_reg + 1;
                     end
                end

                STATE_STRIDE_0 : begin
                    if (row_count_reg == image_hight - 1) begin
                        if (column_count_reg == image_width) begin
                            state               <= STATE_LAST;
                            data_valid_r                <= 4'b0000;
                        end
                        else begin
                            state               <= STATE_STRIDE_0;
                            column_count_reg    <= column_count_reg + 1;
                            if (row_count_reg[0] == 0) begin
                                if (column_count_reg[0] == 0)
                            data_valid_r                <= 4'b0001;
                                else
                                    data_valid_r                <= 4'b0010;
                            end
                            else begin
                                if (column_count_reg[0] == 0)
                                    data_valid_r                <= 4'b0100;
                                else
                                    data_valid_r                <= 4'b1000;
                        end
                    end
                    end
                    else if (column_count_reg == image_width) begin
                        state                   <= STATE_STRIDE_0;
                        column_count_reg        <= 1;
                        row_count_reg           <= row_count_reg +1;
                        if (row_count_reg[0]==0) begin
                            if (column_count_reg[0] == 0)
                                data_valid_r                <= 4'b1000;
                            else
                                data_valid_r                <= 4'b0100;
                        end
                        else begin
                            if (column_count_reg[0] == 0)
                                data_valid_r                <= 4'b0010;
                            else
                        data_valid_r                <= 4'b0001;
                    end
                    end
                    else  begin
                        column_count_reg        <= column_count_reg + 1;
                        state                   <= STATE_STRIDE_0;
                        if (row_count_reg[0] == 0) begin
                            if (column_count_reg[0] == 0)
                        data_valid_r                <= 4'b0001;
                            else
                                data_valid_r                <= 4'b0010;
                        end
                        else begin
                            if (column_count_reg[0] == 0)
                                data_valid_r                <= 4'b0100;
                            else
                                data_valid_r                <= 4'b1000;
                        end
                    end
                    
                end
                STATE_STRIDE_2 : begin
                    if (column_count_reg == ((image_width>>1)-1)) begin
                        if (row_count_reg == ((image_hight>>1)-1))begin
                            state               <= STATE_LAST;
                            data_valid_r                <= 4'b0000;
                        end
                        else begin
                            row_count_reg       <= row_count_reg + 1;
                            data_valid_r                <= 4'b1111;
                            state               <= STATE_STRIDE_2;
                        end
                        column_count_reg        <= 0;
                    end
                    else begin
                        column_count_reg        <= column_count_reg + 1;
                        state                   <= STATE_STRIDE_2;
                        data_valid_r                <= 4'b1111;
                    end
                    
                end

                STATE_STRIDE_1 : begin
                    if (row_count_reg == image_hight-1) begin
                        if (column_count_reg == image_width-1) begin
                            data_valid_r        <= 4'b0000;
                            state               <= STATE_LAST;
                        end
                        else if (column_count_reg == image_width-2)begin 
                            data_valid_r        <= 4'b0001;
                            state               <= STATE_STRIDE_1;  
                            column_count_reg    <= column_count_reg + 1;                      
                        end
                        else begin
                            data_valid_r        <= 4'b0011;
                            state               <= STATE_STRIDE_1;
                            column_count_reg    <= column_count_reg + 1;
                        end
                    end
                    else if (column_count_reg == image_width-2) begin
                        data_valid_r            <= 4'b0101;
                        state                   <= STATE_STRIDE_1;
                        column_count_reg        <= column_count_reg + 1;
                    end                    
                    else if (column_count_reg == image_width-1) begin
                        
                        if (row_count_reg == image_hight-2) begin
                            data_valid_r        <= 4'b0011;
                            state               <=  STATE_STRIDE_1;
                        end
                        else begin    
                            data_valid_r            <= 4'b1111;
                            state                   <= STATE_STRIDE_1;
                        end 
                        column_count_reg        <= 0;
                        row_count_reg           <= row_count_reg +1;
                    end
                    else  begin
                        column_count_reg        <= column_count_reg + 1;
                        state                   <= STATE_STRIDE_1;
                        data_valid_r            <= 4'b1111;
                    end
                end

                STATE_LAST : begin
                    state                       <= STATE_WAIT;
                    data_valid_r                <= 4'b0000;
                    column_count_reg            <= 0;
                    row_count_reg               <= 0;
                end

            endcase
            end
        end


        pool_max
        pool_max_inst
        (
                .clk(clk),
                .reset(reset),
                .bram_data_1(bram_data_1_int),
                .bram_data_2(bram_data_2_int),
                .bram_data_3(bram_data_3_int),
                .bram_data_4(bram_data_4_int),

                .data_valid_1(data_valid_int[0]),
                .data_valid_2(data_valid_int[1]),
                .data_valid_3(data_valid_int[2]),
                .data_valid_4(data_valid_int[3]),

                .pool_data_out(pool_data_out),
                .pool_data_valid(pool_data_valid)

            );

endmodule
