`timescale 1ns/1ps
// Checks that instructions move through the pipeline one stage per cycle,
// then checks that the first dependent instructions of machine.hex get their
// operands through forwarding (no nops between them):
//   0x00 addi x2, x0, 7
//   0x04 addi x3, x0, 8
//   0x08 addi x5, x0, 3
//   0x0c add  x1, x2, x3   x3 from MEM, x2 from WB
//   0x10 sub  x4, x1, x5   x1 from MEM, x5 from WB
module data_path_tb;
 logic clk=0,reset_n;
 logic reg_write_id,mem_write_id,mem_to_reg_id,alu_src_id,branch_id,jump_id;
 logic [1:0] alu_op_id,wb_sel_id;logic [3:0] alu_ctrl_id;
 logic [1:0] forward_a_exe,forward_b_exe;
 logic [4:0] rs1_addr_exe,rs2_addr_exe,rd_addr_mem,rd_addr_wb;
 logic reg_write_mem,reg_write_wb;
 logic pc_sel_mem,flush_if_id_reg,flush_id_exe_reg,flush_exe_mem_reg;
 logic [31:0] current_pc_if,inst_if,inst_id;
 always #5 clk=~clk;
 data_path dut(.*);
 control_unit cu(.inst(inst_id),.reg_write(reg_write_id),.mem_write(mem_write_id),.mem_to_reg(mem_to_reg_id),
                 .alu_src(alu_src_id),.branch(branch_id),.jump(jump_id),.alu_op(alu_op_id),.wb_sel(wb_sel_id),.alu_ctrl(alu_ctrl_id),
                 .rs1_addr_exe(rs1_addr_exe),.rs2_addr_exe(rs2_addr_exe),.reg_write_mem(reg_write_mem),.rd_addr_mem(rd_addr_mem),
                 .reg_write_wb(reg_write_wb),.rd_addr_wb(rd_addr_wb),.forward_a_exe(forward_a_exe),.forward_b_exe(forward_b_exe),
                 .pc_sel_mem(pc_sel_mem),.flush_if_id_reg(flush_if_id_reg),.flush_id_exe_reg(flush_id_exe_reg),.flush_exe_mem_reg(flush_exe_mem_reg));
 initial begin
  reset_n=0;@(posedge clk);@(negedge clk);reset_n=1;
  // after 4 rising edges the first instruction is in WB
  repeat(4) @(posedge clk);#1;
  if(current_pc_if!==16 || dut.current_pc_id!==12 || dut.current_pc_exe!==8 || dut.pc_plus4_mem!==8 || dut.pc_plus4_wb!==4)
   $fatal(1,"pipeline PCs wrong: if=%0d id=%0d exe=%0d mem(pc+4)=%0d wb(pc+4)=%0d",
          current_pc_if,dut.current_pc_id,dut.current_pc_exe,dut.pc_plus4_mem,dut.pc_plus4_wb);
  if(!dut.reg_write_wb || dut.rd_addr_wb!==2 || dut.writeback_data_wb!==7)
   $fatal(1,"first instruction (addi x2,x0,7) not in WB");
  if(dut.rf.regs[2]!==0)$fatal(1,"x2 written too early");
  @(posedge clk);#1;
  if(dut.rf.regs[2]!==7)$fatal(1,"x2 not written");
  // add x1,x2,x3 is now in EXE, addi x5 in MEM, addi x3 in WB:
  // x2 comes from the register file, x3 is forwarded from WB
  if(dut.current_pc_exe!==12)$fatal(1,"add not in EXE");
  if(forward_a_exe!==2'b00 || forward_b_exe!==2'b01 || dut.alu_result_exe!==15)
   $fatal(1,"add x1,x2,x3: forward_a=%b forward_b=%b result=%0d",forward_a_exe,forward_b_exe,dut.alu_result_exe);
  @(posedge clk);#1;
  // sub x4,x1,x5 in EXE: x1 from MEM (add), x5 from WB (addi x5)
  if(forward_a_exe!==2'b10 || forward_b_exe!==2'b01 || dut.alu_result_exe!==12)
   $fatal(1,"sub x4,x1,x5: forward_a=%b forward_b=%b result=%0d",forward_a_exe,forward_b_exe,dut.alu_result_exe);
  repeat(3) @(posedge clk);#1;
  if(dut.rf.regs[1]!==15 || dut.rf.regs[4]!==12)$fatal(1,"add/sub without nops failed: x1=%0d x4=%0d",dut.rf.regs[1],dut.rf.regs[4]);
  $display("PASS data_path_tb");$finish;
 end
endmodule
