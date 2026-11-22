module inst_mem #(parameter WIDTH=32, IMEM_DEPTH=256, INIT_FILE="machine.hex") (input logic [WIDTH-1:0] addr,output logic [31:0] inst);
 logic [31:0] imem [0:IMEM_DEPTH-1];
 initial begin
  for(int i=0;i<IMEM_DEPTH;i++) imem[i]=32'h00000013;
  $readmemh(INIT_FILE,imem);
 end
 always_comb begin
  inst=32'h00000013;
  if ((addr[1:0]==0) && ((addr>>2)<IMEM_DEPTH)) inst=imem[addr>>2];
 end
endmodule
