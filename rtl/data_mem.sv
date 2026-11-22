module data_mem #(parameter DMEM_DEPTH=1024)(input logic clk,reset_n,mem_write,input logic [31:0] addr,wdata,input logic [2:0] funct3,output logic [31:0] rdata);
 logic [31:0] dmem[0:DMEM_DEPTH-1];
 logic [31:0] raw_word,aligned_store_data;
 logic [3:0] wsel;
 wire in_range=((addr>>2)<DMEM_DEPTH);
 always_comb begin
  raw_word=0;
  if(in_range) raw_word=dmem[addr>>2];
 end
 mem_alignment align(.raw_word(raw_word),.store_data(wdata),.offset(addr[1:0]),.funct3(funct3),.load_data(rdata),.aligned_store_data(aligned_store_data),.wsel(wsel));
 always_ff @(posedge clk or negedge reset_n) begin
  if(!reset_n) for(int i=0;i<DMEM_DEPTH;i++) dmem[i]<=0;
  else if(mem_write && in_range)
   for(int j=0;j<4;j++) if(wsel[j]) dmem[addr>>2][8*j+:8]<=aligned_store_data[8*j+:8];
 end
endmodule
