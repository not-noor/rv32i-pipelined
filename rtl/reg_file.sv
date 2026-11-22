// Register file with write-through (internal bypass).
// In the pipeline the write-back stage writes the register file in the same
// clock cycle that the decode stage reads it. If both refer to the same
// register, the read port returns the value being written (wdata) instead of
// the old value. This lets the decode stage see a result that is being
// written back in the same cycle, so two nops between a producer and a
// dependent instruction are enough when forwarding is turned off.
module reg_file(input logic clk,reset_n,reg_write,input logic [4:0] raddr1,raddr2,waddr,input logic [31:0] wdata,output logic [31:0] rdata1,rdata2);
 logic [31:0] regs[0:31];
 always_ff @(posedge clk or negedge reset_n) begin
  if(!reset_n) for(int i=0;i<32;i++) regs[i]<=0;
  else if(reg_write && waddr!=0) regs[waddr]<=wdata;
 end
 assign rdata1=(raddr1==0)?32'd0:((reg_write && (waddr==raddr1))?wdata:regs[raddr1]);
 assign rdata2=(raddr2==0)?32'd0:((reg_write && (waddr==raddr2))?wdata:regs[raddr2]);
endmodule
