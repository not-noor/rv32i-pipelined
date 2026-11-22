`timescale 1ns/1ps
module inst_mem_tb;
 logic [31:0] addr=0,inst;
 inst_mem dut(.*);
 initial begin
  #2;if(inst!==32'h00700113)$fatal(1,"Instruction at 0 incorrect");   // addi x2,x0,7
  addr=4;#2;if(inst!==32'h00800193)$fatal(1,"Instruction at 4 incorrect"); // addi x3,x0,8
  addr=12;#2;if(inst!==32'h003100b3)$fatal(1,"Instruction at 12 incorrect"); // add x1,x2,x3
  $display("PASS inst_mem_tb");$finish;
 end
endmodule
