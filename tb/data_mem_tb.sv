`timescale 1ns/1ps
module data_mem_tb;
 logic clk=0,reset_n=0,mem_write=0;logic [31:0] addr=0,wdata=0,rdata;logic [2:0] funct3=2;
 always #5 clk=~clk;
 data_mem dut(.*);
 task automatic store(input logic [31:0] a,d,input logic [2:0] f);
  @(negedge clk);addr=a;wdata=d;funct3=f;mem_write=1;
  @(posedge clk);#1;mem_write=0;
 endtask
 initial begin
  #2;reset_n=1;
  store(0,32'h12345678,2);
  addr=0;funct3=2;#1;if(rdata!==32'h12345678)$fatal(1,"lw failed");
  addr=1;funct3=4;#1;if(rdata!==32'h56)$fatal(1,"lbu failed");
  store(1,32'hff,0);
  addr=1;funct3=0;#1;if(rdata!==32'hffffffff)$fatal(1,"lb sign extension failed");
  addr=0;funct3=2;#1;if(rdata!==32'h1234ff78)$fatal(1,"byte mask failed");
  $display("PASS data_mem_tb");$finish;
 end
endmodule
