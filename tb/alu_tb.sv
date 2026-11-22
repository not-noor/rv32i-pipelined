`timescale 1ns/1ps
module alu_tb;
 logic [31:0] op1,op2,alu_result;logic [3:0] alu_ctrl;logic zero,less;
 alu dut(.*);
 task automatic check(input logic [31:0] a,b,expected,input logic [3:0] ctrl);
  op1=a;op2=b;alu_ctrl=ctrl;#1;
  if(alu_result!==expected)$fatal(1,"ALU ctrl=%h got=%h expected=%h",ctrl,alu_result,expected);
 endtask
 initial begin
  check(10,5,15,0);check(10,5,5,8);check(3,1,6,1);check(1,2,1,2);
  check(1,2,1,3);check(5,3,6,4);check(8,1,4,5);check(32'hfffffff8,1,32'hfffffffc,13);
  check(4,1,5,6);check(7,3,3,7);check(5,5,0,8);
  if(!zero)$fatal(1,"zero flag failed");
  $display("PASS alu_tb");$finish;
 end
endmodule
