`timescale 1ns / 1ps
// coverage never

module fsm_monitor
    (
        clk,
        reset,

        state_in,
        state_vector_out
    );

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter                               INTSTATE_WIDTH          = 8;
    parameter                               INTSTATE_VECTOR_WIDTH   = 32;

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam                              INTSTATE_REG_COUNT      = INTSTATE_VECTOR_WIDTH / INTSTATE_WIDTH;

//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                   clk;
    input                                   reset;

    input  [INTSTATE_WIDTH-1:0]             state_in;
    output reg [INTSTATE_VECTOR_WIDTH-1:0]  state_vector_out;

//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg  [INTSTATE_WIDTH-1:0]               state_reg[INTSTATE_REG_COUNT-1:0];

//---------------------------------------------------------------------------------------------------------------------
// Implmentation
//---------------------------------------------------------------------------------------------------------------------
    initial begin
        if (INTSTATE_VECTOR_WIDTH % INTSTATE_WIDTH != 0) begin
            $dsiplay("INTSTATE_VECTOR_WIDTH (%0d) must be a multiple of INTSTATE_WIDTH (%0d)", INTSTATE_VECTOR_WIDTH, INTSTATE_WIDTH);
            $finish(1);
        end
    end

    always @(*) begin : state_vector_async
        integer i, j;
        for(i = 0; i < INTSTATE_REG_COUNT; i = i + 1) begin
            for(j = 0; j < INTSTATE_WIDTH; j = j + 1) begin
                state_vector_out[i*INTSTATE_WIDTH + j] = state_reg[i][j];
            end
        end
    end

    always @(posedge clk) begin : state_shiftreg
        integer i;
        if(reset) begin
            //state_reg[0] <= 0;
            for(i = 0; i < INTSTATE_REG_COUNT; i = i + 1) begin
               state_reg[i] <= 0;
            end
        end
        else begin
            if(state_in != state_reg[0]) begin
                state_reg[0] <= state_in;
                for(i = 0; i < INTSTATE_REG_COUNT-1; i = i + 1) begin
                    state_reg[i+1] <= state_reg[i];
                end
            end
        end
    end

endmodule
