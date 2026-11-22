`timescale 1ns/1ps
module reg_file_tb;
 logic clk=0,reset_n=0,reg_write=0;logic [4:0] raddr1=5,raddr2=0,waddr=5;logic [31:0] wdata=123,rdata1,rdata2;
 always #5 clk=~clk;
 reg_file dut(.*);
 initial begin
  @(posedge clk);#1;reset_n=1;
  if(rdata1!==0)$fatal(1,"reset failed");
  // write-through: the value being written is visible on the read port
  // in the same cycle (WB and ID of the pipeline overlap)
  reg_write=1;#1;
  if(rdata1!==123)$fatal(1,"write-through (bypass) failed");
  @(posedge clk);#1;
  reg_write=0;#1;
  if(rdata1!==123)$fatal(1,"register write/read failed");
  reg_write=1;waddr=0;wdata=55;#1;
  if(rdata2!==0)$fatal(1,"x0 bypass must read 0");
  @(posedge clk);#1;
  if(rdata2!==0)$fatal(1,"x0 changed");
  $display("PASS reg_file_tb");$finish;
 end
endmodule
