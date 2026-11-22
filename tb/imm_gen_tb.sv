`timescale 1ns/1ps
module imm_gen_tb;
 logic [31:0] inst,imm;
 imm_gen dut(.*);
 initial begin
  inst=32'h00a00293;#1;if(imm!==10)$fatal(1,"I immediate failed");
  inst=32'hfff00293;#1;if(imm!==32'hffffffff)$fatal(1,"negative I immediate failed");
  inst=32'h0000006f;#1;if(imm!==0)$fatal(1,"J immediate failed");
  $display("PASS imm_gen_tb");$finish;
 end
endmodule
