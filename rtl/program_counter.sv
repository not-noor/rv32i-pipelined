module program_counter #(parameter WIDTH=32)(input logic clk,reset_n,input logic [WIDTH-1:0] data_in,output logic [WIDTH-1:0] data_o);
 always_ff @(posedge clk or negedge reset_n) if(!reset_n) data_o <= '0; else data_o <= data_in;
endmodule
