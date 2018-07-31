`timescale 1ns / 1ps

module sigmoid_ram_wrapper
    (
        clk,
        reset_n,
		x_axis_data_in,
		read_value_in,
		y_axis_data_out,
		y_axis_valid_out
    );
    
//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
    
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter                                           X_DATA_WIDTH	             =   12;
    parameter                                           Y_DATA_WIDTH                 =   16;
    parameter                                           INPUT_DATA_WIDTH             =   16;
        
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam 											STATE_COUNT 				 = 5;
	
	localparam 											STATE_BEGIN 				 = 0;
	localparam 											STATE_WAIT_1 				 = 1;
	localparam 											STATE_WAIT_2			     = 2;
	localparam 											STATE_READ	  		         = 3;
	
	localparam                                          READ_BUF_WIDTH               = 2;
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                               clk;
    input                                               reset_n;
    
    input      [INPUT_DATA_WIDTH-1 : 0]                 x_axis_data_in;
    input      						                  	read_value_in;
    
    output reg [Y_DATA_WIDTH-1 : 0]                  	y_axis_data_out;
    output reg                                          y_axis_valid_out;
    
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg 		[STATE_COUNT-1 : 0] 					state;
    
	reg 												enable;
	wire 												write_enable;
	wire 		[Y_DATA_WIDTH-1 : 0] 					read_data;
	wire        [X_DATA_WIDTH-1 : 0]                    generated_index;
	wire                                                generated_index_valid;
	wire                                                generated_overflow;
	
	reg         [X_DATA_WIDTH-1 : 0]                    generated_index_shift;
	reg         [X_DATA_WIDTH-1 : 0]                    index_shift_temp;
	reg                                                 shift_index_valid;
	
	reg 		[X_DATA_WIDTH-1 : 0]					read_addr;
	reg 		[Y_DATA_WIDTH-1 : 0]					write_data;
	
	reg         [READ_BUF_WIDTH-1 : 0]                  read_buffer_1;
	reg         [READ_BUF_WIDTH-1 : 0]                  read_buffer_2;
	reg         [READ_BUF_WIDTH-1 : 0]                  read_buffer_3;
	reg         [READ_BUF_WIDTH-1 : 0]                  read_buffer_4;
	
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//--------------------------------------------------------------------------------------------------------------------- 
    always @(posedge clk) begin
        if (!reset_n) begin
            shift_index_valid               <= 1'b0;
        end
        else begin
            if (generated_index_valid)begin
                if (generated_index[X_DATA_WIDTH-1] == 1'b0) begin
                    if (generated_overflow) begin
                        generated_index_shift   <= 12'h7ff;
                    end
                    else begin
                        generated_index_shift       <= generated_index[X_DATA_WIDTH - 2 : 0] + 12'h400;
                    end
                end
                else begin
                    if (generated_overflow) begin
                        generated_index_shift   <= 12'h0;
                    end
                    else begin
                        generated_index_shift[10:0]  <= 12'h400 - ((~generated_index[10 : 0]) + 1'b1);
                        generated_index_shift[11]   <= 1'b0;
                    end                                  
                end
                
                shift_index_valid               <= 1'b1;
            end
            else begin
                shift_index_valid               <= 1'b0;
            end
        end
    end
	
	always @(posedge clk) begin
		if (!reset_n) begin
			state 							<= STATE_BEGIN;
			
			y_axis_data_out 				<= {Y_DATA_WIDTH{1'b0}};
			y_axis_valid_out 				<= 1'b0;
			read_buffer_1                   <= 1'b0;
			read_buffer_2                   <= 1'b0;
			read_buffer_3                   <= 1'b0;
			read_buffer_4 					<= 1'b0;
		end
		else begin
			case(state)
				STATE_BEGIN: begin
					if (shift_index_valid) begin
						state 				                                <= STATE_BEGIN;
						
						read_addr 			                                <= generated_index_shift;
						enable 				                                <= 1'b1;
						
						if (read_buffer_1 == 0)       read_buffer_1         <= 1;
						else if (read_buffer_2 == 0)  read_buffer_2         <= 1;
						else if (read_buffer_3 == 0)  read_buffer_3         <= 1;
						else 						  read_buffer_4 	    <= 1;
					end
					
					if (read_buffer_1 == 1)           read_buffer_1         <= 2;
					if (read_buffer_2 == 1)           read_buffer_2         <= 2;
					if (read_buffer_3 == 1)           read_buffer_3         <= 2;
					if (read_buffer_4 == 1)           read_buffer_4         <= 2;

                    if (read_buffer_1 == 2)           read_buffer_1         <= 3;
					if (read_buffer_2 == 2)           read_buffer_2         <= 3;
					if (read_buffer_3 == 2)           read_buffer_3         <= 3;
					if (read_buffer_4 == 2)           read_buffer_4         <= 3;
					
					if (read_buffer_1 == 3) begin           
					   read_buffer_1                                        <= 0;
					   
					   y_axis_data_out 		                                <= read_data;
                       y_axis_valid_out                                     <= 1'b1;
                    end
                    else if (read_buffer_2 == 3) begin
                       read_buffer_2                                        <= 0;
                       
                       y_axis_data_out 		                                <= read_data;
                       y_axis_valid_out                                     <= 1'b1;
                    end
                    else if (read_buffer_3 == 3) begin           
                       read_buffer_3                                        <= 0;
                       
                       y_axis_data_out 		                                <= read_data;
                       y_axis_valid_out                                     <= 1'b1;
                    end
					else if (read_buffer_4 == 3) begin           
                       read_buffer_4                                        <= 0;
                       
                       y_axis_data_out 		                                <= read_data;
                       y_axis_valid_out                                     <= 1'b1;
                    end
                    else begin
                        y_axis_valid_out                                    <= 1'b0;
                    end
				end
			endcase
		end
	end
    
//---------------------------------------------------------------------------------------------------------------------
// Instantiation of block ram module
//--------------------------------------------------------------------------------------------------------------------- 
	blk_mem_gen_0 sigmoid_bram (
	  .clka					(clk),    				// input wire clka
	  .ena					(enable),      			// input wire ena
	  .wea					(write_enable),      	// input wire [0 : 0] wea
	  .addra				(read_addr),  			// input wire [10 : 0] addra
	  .dina					(write_data),    		// input wire [15 : 0] dina
	  .douta				(read_data)  			// output wire [15 : 0] douta
	);
	 
//---------------------------------------------------------------------------------------------------------------------
// Instantiation of index generator
//--------------------------------------------------------------------------------------------------------------------- 
    bram_address_generator address_generator
    (
        .clk 								(clk),
        .reset_n							(reset_n),
		.x_axis_data_in 					(x_axis_data_in),
		.read_value_in 						(read_value_in),
		.index_out 							(generated_index),
		.index_valid_out 					(generated_index_valid),
		.index_overflow_out                 (generated_overflow)
    );
  
    
endmodule
