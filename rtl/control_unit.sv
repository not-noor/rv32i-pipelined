// Control path.
//
// Decode stage: main_control + alu_control decode the instruction that is in
// the decode stage (inst). These outputs are "_id" signals; the data path
// carries them down the pipeline through id_exe_reg, exe_mem_reg and
// mem_wb_reg.
//
// Execute stage: forwarding_unit compares the source registers of the
// instruction in EXE with the destination registers of the instructions in
// MEM and WB, and generates the select signals of the two forwarding
// multiplexers in the data path (forward_a_exe, forward_b_exe).
//
// Memory stage: hazard_controller watches the branch / jump decision
// (pc_sel_mem) and flushes the three pipeline registers behind a taken
// branch or a jump (flush_if_id_reg, flush_id_exe_reg, flush_exe_mem_reg).
//
// FORWARDING_EN = 0 forces both forwarding selects to 2'b00 (always use the
// register file value). FLUSH_EN = 0 keeps all flush signals at 0. Both are
// 1 by default; the demo and benchmark testbenches clear them to compare
// against a pipeline without that hazard hardware.
module control_unit #(
    parameter bit FORWARDING_EN = 1'b1,
    parameter bit FLUSH_EN      = 1'b1
) (
    // ---------------- decode stage ----------------
    input  logic [31:0] inst,
    output logic        reg_write,
    output logic        mem_write,
    output logic        mem_to_reg,
    output logic        alu_src,
    output logic        branch,
    output logic        jump,
    output logic [1:0]  alu_op,
    output logic [1:0]  wb_sel,
    output logic [3:0]  alu_ctrl,

    // ---------------- forwarding (execute stage) ----------------
    input  logic [4:0]  rs1_addr_exe,
    input  logic [4:0]  rs2_addr_exe,
    input  logic        reg_write_mem,
    input  logic [4:0]  rd_addr_mem,
    input  logic        reg_write_wb,
    input  logic [4:0]  rd_addr_wb,
    output logic [1:0]  forward_a_exe,
    output logic [1:0]  forward_b_exe,

    // ---------------- hazard controller (memory stage) ----------------
    input  logic        pc_sel_mem,
    output logic        flush_if_id_reg,
    output logic        flush_id_exe_reg,
    output logic        flush_exe_mem_reg
);
    main_control mc (
        .opcode(inst[6:0]),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op),
        .alu_src(alu_src),
        .branch(branch),
        .jump(jump),
        .wb_sel(wb_sel)
    );

    alu_control ac (
        .alu_op(alu_op),
        .funct3(inst[14:12]),
        .funct7_5(inst[30]),
        .alu_ctrl(alu_ctrl)
    );

    logic [1:0] fu_forward_a, fu_forward_b;

    forwarding_unit fu (
        .rs1_addr_exe(rs1_addr_exe),
        .rs2_addr_exe(rs2_addr_exe),
        .reg_write_mem(reg_write_mem),
        .rd_addr_mem(rd_addr_mem),
        .reg_write_wb(reg_write_wb),
        .rd_addr_wb(rd_addr_wb),
        .forward_a_exe(fu_forward_a),
        .forward_b_exe(fu_forward_b)
    );

    assign forward_a_exe = FORWARDING_EN ? fu_forward_a : 2'b00;
    assign forward_b_exe = FORWARDING_EN ? fu_forward_b : 2'b00;

    hazard_controller hc (
        .pc_sel_mem(pc_sel_mem & FLUSH_EN),
        .flush_if_id_reg(flush_if_id_reg),
        .flush_id_exe_reg(flush_id_exe_reg),
        .flush_exe_mem_reg(flush_exe_mem_reg)
    );
endmodule
