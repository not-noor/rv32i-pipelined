module alu(input logic [31:0] op1,op2,input logic [3:0] alu_ctrl,output logic [31:0] alu_result,output logic zero,less);
 always_comb begin
  case(alu_ctrl)
   4'h0: alu_result=op1+op2;
   4'h8: alu_result=op1-op2;
   4'h1: alu_result=op1 << op2[4:0];
   4'h2: alu_result=($signed(op1)<$signed(op2))?32'd1:0;
   4'h3: alu_result=(op1<op2)?32'd1:0;
   4'h4: alu_result=op1^op2;
   4'h5: alu_result=op1>>op2[4:0];
   4'hd: alu_result=$signed(op1)>>>op2[4:0];
   4'h6: alu_result=op1|op2;
   4'h7: alu_result=op1&op2;
   default: alu_result=0;
  endcase
 end
 assign zero=(alu_result==0);
 assign less=(alu_ctrl==4'h3)?(op1<op2):($signed(op1)<$signed(op2));
endmodule
