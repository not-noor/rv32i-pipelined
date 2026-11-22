`timescale 1ns/1ps
module program_counter_tb;
 logic clk=0,reset_n; logic [31:0] data_in=32'h40,data_o;
 always #5 clk=~clk;
 program_counter dut(.*);
 initial begin
  reset_n=0; @(posedge clk); #1;           // hold reset over a clock edge
  if(data_o!==0) $fatal(1,"PC reset failed");
  reset_n=1; @(posedge clk); #1;
  if(data_o!==32'h40) $fatal(1,"PC update failed");
  $display("PASS program_counter_tb");$finish;
 end
endmodule
