`timescale 1ns / 1ps

module bram_address_generator
    (
        clk,
        reset_n,
		x_axis_data_in,
		read_value_in,
		index_out,
		index_valid_out,
		index_overflow_out
    );
    
//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
    
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter                                          DATA_WIDTH	             =   16;
        
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                               clk;
    input                                               reset_n;
    
    input      [DATA_WIDTH-1 : 0]                  	    x_axis_data_in;
    input      						                  	read_value_in;
    
    output reg  [DATA_WIDTH - 1:0]                      index_out;
    output reg                                          index_valid_out;
    output reg                                          index_overflow_out;
   
    
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
	wire        [DATA_WIDTH-1 : 0]                    index_float_value;
	wire         	                    			  index_float_valid;
	wire                                              index_overflow;
	
	reg 		[DATA_WIDTH-1 : 0]					  read_addr;
	reg 		[DATA_WIDTH-1 : 0]					  write_data;
	
	reg        	[DATA_WIDTH-1 : 0]                    index_fixed_value;
    wire        [DATA_WIDTH-1 : 0]                    index_out_wire;
    wire                                              index_valid_out_wire;
	
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//--------------------------------------------------------------------------------------------------------------------- 
    
	always @(posedge clk) begin
		if (!reset_n) begin
			index_valid_out 							<= 1'b0;
		end
		else begin
		      index_out                                 <= index_out_wire;
		      index_valid_out                           <= index_valid_out_wire;
		      index_overflow_out                        <= index_overflow;
		end
	end
//---------------------------------------------------------------------------------------------------------------------
// Instantiation of converters
//--------------------------------------------------------------------------------------------------------------------- 
		
	floating_point_sig_conv float_to_fixed (
		.aclk						(clk),                     		// input wire aclk
		.aresetn 					(reset_n),
		.s_axis_a_tvalid			(index_float_valid),          	// input wire s_axis_a_tvalid
		.s_axis_a_tdata				(index_float_value),           	// input wire [15 : 0] s_axis_a_tdata
		.m_axis_result_tvalid		(index_valid_out_wire),  	    // output wire m_axis_result_tvalid
		.m_axis_result_tdata		(index_out_wire),    			// output wire [15 : 0] m_axis_result_tdata
		.m_axis_result_tuser        (index_overflow)        // output wire [0 : 0] m_axis_result_tuser
	);
	
	floating_point_sig_div float_division (
		.aclk						(clk),                     		// input wire aclk
		.aresetn 					(reset_n),
		.s_axis_a_tvalid			(read_value_in),          		// input wire s_axis_a_tvalid
		.s_axis_a_tdata				(x_axis_data_in),           	// input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid            (read_value_in),                // input wire s_axis_b_tvalid
        .s_axis_b_tdata             (16'b0001111000100101),        // input wire [15 : 0] s_axis_b_tdata [0.006]
		.m_axis_result_tvalid		(index_float_valid),  			// output wire m_axis_result_tvalid
		.m_axis_result_tdata		(index_float_value)    			// output wire [15 : 0] m_axis_result_tdata
	);
    
endmodule
