// Top level of the 5-stage pipelined RV32I processor with forwarding and
// control hazard handling.
// The control path (control_unit) decodes the instruction in the decode
// stage, drives the forwarding multiplexers of the execute stage (forwarding
// unit) and flushes the pipeline behind a taken branch or a jump (hazard
// controller). The data path carries the decoded control signals (*_id)
// through the pipeline registers.
//
// Parameters
//   IMEM_INIT     : program loaded into the instruction memory
//   FORWARDING_EN : 1 = forwarding on (default), 0 = no forwarding
//   FLUSH_EN      : 1 = flushing on (default),   0 = no flushing
module rv32i_top #(
    parameter     IMEM_INIT     = "machine.hex",
    parameter bit FORWARDING_EN = 1'b1,
    parameter bit FLUSH_EN      = 1'b1
) (
    input  logic        clk,
    input  logic        reset_n,
    output logic [31:0] current_pc,   // PC of the instruction being fetched
    output logic [31:0] inst          // instruction being fetched
);
    // decode-stage control signals
    logic        reg_write_id, mem_write_id, mem_to_reg_id, alu_src_id;
    logic        branch_id, jump_id;
    logic [1:0]  alu_op_id, wb_sel_id;
    logic [3:0]  alu_ctrl_id;

    // forwarding
    logic [4:0]  rs1_addr_exe, rs2_addr_exe, rd_addr_mem, rd_addr_wb;
    logic        reg_write_mem, reg_write_wb;
    logic [1:0]  forward_a_exe, forward_b_exe;

    // control hazards
    logic        pc_sel_mem;
    logic        flush_if_id_reg, flush_id_exe_reg, flush_exe_mem_reg;

    logic [31:0] current_pc_if, inst_if, inst_id;

    control_unit #(.FORWARDING_EN(FORWARDING_EN), .FLUSH_EN(FLUSH_EN)) cu (
        .inst(inst_id),
        .reg_write(reg_write_id),
        .mem_write(mem_write_id),
        .mem_to_reg(mem_to_reg_id),
        .alu_src(alu_src_id),
        .branch(branch_id),
        .jump(jump_id),
        .alu_op(alu_op_id),
        .wb_sel(wb_sel_id),
        .alu_ctrl(alu_ctrl_id),
        .rs1_addr_exe(rs1_addr_exe),
        .rs2_addr_exe(rs2_addr_exe),
        .reg_write_mem(reg_write_mem),
        .rd_addr_mem(rd_addr_mem),
        .reg_write_wb(reg_write_wb),
        .rd_addr_wb(rd_addr_wb),
        .forward_a_exe(forward_a_exe),
        .forward_b_exe(forward_b_exe),
        .pc_sel_mem(pc_sel_mem),
        .flush_if_id_reg(flush_if_id_reg),
        .flush_id_exe_reg(flush_id_exe_reg),
        .flush_exe_mem_reg(flush_exe_mem_reg)
    );

    data_path #(.IMEM_INIT(IMEM_INIT)) dp (
        .clk(clk),
        .reset_n(reset_n),
        .reg_write_id(reg_write_id),
        .mem_write_id(mem_write_id),
        .alu_src_id(alu_src_id),
        .branch_id(branch_id),
        .jump_id(jump_id),
        .wb_sel_id(wb_sel_id),
        .alu_ctrl_id(alu_ctrl_id),
        .forward_a_exe(forward_a_exe),
        .forward_b_exe(forward_b_exe),
        .flush_if_id_reg(flush_if_id_reg),
        .flush_id_exe_reg(flush_id_exe_reg),
        .flush_exe_mem_reg(flush_exe_mem_reg),
        .pc_sel_mem(pc_sel_mem),
        .rs1_addr_exe(rs1_addr_exe),
        .rs2_addr_exe(rs2_addr_exe),
        .reg_write_mem(reg_write_mem),
        .rd_addr_mem(rd_addr_mem),
        .reg_write_wb(reg_write_wb),
        .rd_addr_wb(rd_addr_wb),
        .current_pc_if(current_pc_if),
        .inst_if(inst_if),
        .inst_id(inst_id)
    );

    assign current_pc = current_pc_if;
    assign inst       = inst_if;
endmodule
