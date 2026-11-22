// 5-stage pipelined RV32I data path.
//
//   IF  : program counter, PC + 4, instruction memory, next-PC mux
//   ID  : register file read, immediate generator (control is decoded
//         outside, in control_unit, from inst_id)
//   EXE : ALU, branch comparator, branch/jump target, LUI/AUIPC value
//   MEM : data memory, branch/jump decision (pc_sel_mem)
//   WB  : write-back mux, register file write
//
// Pipeline registers: if_id_reg, id_exe_reg, exe_mem_reg, mem_wb_reg.
// Every signal name ends with the stage it belongs to
// (_if, _id, _exe, _mem, _wb).
//
// Data hazards are handled by forwarding and control hazards by flushing.
//
// Data hazards: forwarding.
// Two forwarding multiplexers in the EXE stage pick each source operand
// from one of:
//   2'b00 : rs*_data_exe      (register file, read in ID)
//   2'b10 : fwd_result_mem    (result of the instruction now in MEM)
//   2'b01 : writeback_data_wb (result of the instruction now in WB)
// The select signals (forward_a_exe, forward_b_exe) come from the
// forwarding unit in the control path (control_unit.sv).
// A producer 3 instructions ahead is covered by the write-through register
// file (WB and ID in the same cycle).
//
// Control hazards: flushing. Branches and jumps are resolved in the MEM
// stage (pc_sel_mem). When pc_sel_mem = 1 the hazard controller in the
// control path raises flush_if_id_reg, flush_id_exe_reg and
// flush_exe_mem_reg. These are synchronous clears of the pipeline registers,
// so on the same clock edge on which the PC loads the target, the three
// wrong-path instructions behind the branch become bubbles.
//
// Still handled in software:
//   * load-use hazard: a load's data is only ready at the end of MEM, so the
//                      instruction right after a load must not use the
//                      loaded register (1 nop).
module data_path #(
    parameter IMEM_INIT = "machine.hex"
) (
    input  logic        clk,
    input  logic        reset_n,

    // control signals generated in the decode stage (control_unit)
    input  logic        reg_write_id,
    input  logic        mem_write_id,
    input  logic        alu_src_id,
    input  logic        branch_id,
    input  logic        jump_id,
    input  logic [1:0]  wb_sel_id,
    input  logic [3:0]  alu_ctrl_id,

    // forwarding mux selects from the forwarding unit (control path)
    input  logic [1:0]  forward_a_exe,
    input  logic [1:0]  forward_b_exe,

    // flush (synchronous clear) of the pipeline registers, from the hazard
    // controller (control path)
    input  logic        flush_if_id_reg,
    input  logic        flush_id_exe_reg,
    input  logic        flush_exe_mem_reg,

    // branch / jump decision, used by the hazard controller
    output logic        pc_sel_mem,

    // register numbers and write enables used by the forwarding unit
    output logic [4:0]  rs1_addr_exe,
    output logic [4:0]  rs2_addr_exe,
    output logic        reg_write_mem,
    output logic [4:0]  rd_addr_mem,
    output logic        reg_write_wb,
    output logic [4:0]  rd_addr_wb,

    output logic [31:0] current_pc_if,
    output logic [31:0] inst_if,
    output logic [31:0] inst_id
);
    localparam logic [6:0] OPCODE_JALR = 7'b1100111;
    localparam logic [6:0] OPCODE_LUI  = 7'b0110111;

    // ------------------------------------------------------------------
    // Signal declarations, grouped by stage
    // ------------------------------------------------------------------
    // IF
    logic [31:0] next_pc_if, pc_plus4_if;

    // ID
    logic [31:0] current_pc_id, pc_plus4_id;
    logic [31:0] rs1_data_id, rs2_data_id, imm_id;
    logic [4:0]  rs1_addr_id, rs2_addr_id, rd_addr_id;
    logic [2:0]  funct3_id;
    logic [6:0]  opcode_id;
    logic        is_jalr_id, is_lui_id;

    // EXE
    logic        reg_write_exe, mem_write_exe, alu_src_exe, branch_exe, jump_exe;
    logic        is_jalr_exe, is_lui_exe;
    logic [1:0]  wb_sel_exe;
    logic [3:0]  alu_ctrl_exe;
    logic [31:0] current_pc_exe, pc_plus4_exe;
    logic [31:0] rs1_data_exe, rs2_data_exe, imm_exe;
    logic [4:0]  rd_addr_exe;
    logic [2:0]  funct3_exe;
    logic [31:0] rs1_fwd_data_exe, rs2_fwd_data_exe;
    logic [31:0] alu_op2_exe, alu_result_exe, pc_plus_imm_exe;
    logic [31:0] target_pc_exe, upper_result_exe;
    logic        branch_cond_exe, zero_exe, less_exe;

    // MEM
    logic        mem_write_mem, branch_mem, jump_mem;
    logic [1:0]  wb_sel_mem;
    logic        branch_cond_mem;
    logic [31:0] target_pc_mem, alu_result_mem, rs2_data_mem;
    logic [31:0] upper_result_mem, pc_plus4_mem, mem_rdata_mem;
    logic [2:0]  funct3_mem;
    logic [31:0] fwd_result_mem;

    // WB
    logic [1:0]  wb_sel_wb;
    logic [31:0] alu_result_wb, mem_rdata_wb, pc_plus4_wb, upper_result_wb;
    logic [31:0] writeback_data_wb;

    // ==================================================================
    // IF : Instruction Fetch
    // ==================================================================
    assign pc_plus4_if = current_pc_if + 32'd4;

    // pc_sel_mem / target_pc_mem come from the memory stage
    assign next_pc_if = pc_sel_mem ? target_pc_mem : pc_plus4_if;

    program_counter pc (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(next_pc_if),
        .data_o(current_pc_if)
    );

    inst_mem #(.INIT_FILE(IMEM_INIT)) im (
        .addr(current_pc_if),
        .inst(inst_if)
    );

    // ------------------------------------------------------------------
    // IF/ID pipeline register
    // ------------------------------------------------------------------
    localparam int IF_ID_W = 32 + 32 + 32;
    logic [IF_ID_W-1:0] obus_if, ibus_id;

    assign obus_if = {inst_if, current_pc_if, pc_plus4_if};

    n_bit_reg #(.n(IF_ID_W)) if_id_reg (
        .clk(clk),
        .reset_n(reset_n),
        .clear(flush_if_id_reg),
        .data_in(obus_if),
        .data_out(ibus_id)
    );

    assign {inst_id, current_pc_id, pc_plus4_id} = ibus_id;

    // ==================================================================
    // ID : Instruction Decode
    // ==================================================================
    assign opcode_id   = inst_id[6:0];
    assign rd_addr_id  = inst_id[11:7];
    assign funct3_id   = inst_id[14:12];
    assign rs1_addr_id = inst_id[19:15];
    assign rs2_addr_id = inst_id[24:20];

    assign is_jalr_id  = (opcode_id == OPCODE_JALR);
    assign is_lui_id   = (opcode_id == OPCODE_LUI);

    // Read ports are in ID, write port is driven by the WB stage
    reg_file rf (
        .clk(clk),
        .reset_n(reset_n),
        .reg_write(reg_write_wb),
        .raddr1(rs1_addr_id),
        .raddr2(rs2_addr_id),
        .waddr(rd_addr_wb),
        .wdata(writeback_data_wb),
        .rdata1(rs1_data_id),
        .rdata2(rs2_data_id)
    );

    imm_gen ig (
        .inst(inst_id),
        .imm(imm_id)
    );

    // ------------------------------------------------------------------
    // ID/EXE pipeline register
    // ------------------------------------------------------------------
    localparam int ID_EXE_CTRL_W = 1 + 1 + 1 + 1 + 1 + 2 + 4 + 1 + 1;   // 13
    localparam int ID_EXE_DATA_W = 32 + 32 + 32 + 32 + 32 + 5 + 5 + 5 + 3;  // 178
    localparam int ID_EXE_W      = ID_EXE_CTRL_W + ID_EXE_DATA_W;
    logic [ID_EXE_W-1:0] obus_id, ibus_exe;

    assign obus_id = {
        // control
        reg_write_id, mem_write_id, alu_src_id, branch_id, jump_id,
        wb_sel_id, alu_ctrl_id, is_jalr_id, is_lui_id,
        // data
        current_pc_id, pc_plus4_id, rs1_data_id, rs2_data_id, imm_id,
        rs1_addr_id, rs2_addr_id, rd_addr_id, funct3_id
    };

    n_bit_reg #(.n(ID_EXE_W)) id_exe_reg (
        .clk(clk),
        .reset_n(reset_n),
        .clear(flush_id_exe_reg),
        .data_in(obus_id),
        .data_out(ibus_exe)
    );

    assign {
        reg_write_exe, mem_write_exe, alu_src_exe, branch_exe, jump_exe,
        wb_sel_exe, alu_ctrl_exe, is_jalr_exe, is_lui_exe,
        current_pc_exe, pc_plus4_exe, rs1_data_exe, rs2_data_exe, imm_exe,
        rs1_addr_exe, rs2_addr_exe, rd_addr_exe, funct3_exe
    } = ibus_exe;

    // ==================================================================
    // EXE : Execute
    // ==================================================================
    // Forwarding multiplexers (selects from the forwarding unit)
    always_comb begin
        case (forward_a_exe)
            2'b10:   rs1_fwd_data_exe = fwd_result_mem;     // from MEM stage
            2'b01:   rs1_fwd_data_exe = writeback_data_wb;  // from WB stage
            default: rs1_fwd_data_exe = rs1_data_exe;       // register file
        endcase
        case (forward_b_exe)
            2'b10:   rs2_fwd_data_exe = fwd_result_mem;
            2'b01:   rs2_fwd_data_exe = writeback_data_wb;
            default: rs2_fwd_data_exe = rs2_data_exe;
        endcase
    end

    // The forwarded operands feed the ALU, the branch comparator and (rs2)
    // the store data that goes on to the memory stage.
    assign alu_op2_exe = alu_src_exe ? imm_exe : rs2_fwd_data_exe;

    alu a (
        .op1(rs1_fwd_data_exe),
        .op2(alu_op2_exe),
        .alu_ctrl(alu_ctrl_exe),
        .alu_result(alu_result_exe),
        .zero(zero_exe),
        .less(less_exe)
    );

    branch_comp bc (
        .rs1_data(rs1_fwd_data_exe),
        .rs2_data(rs2_fwd_data_exe),
        .funct3(funct3_exe),
        .branch_cond(branch_cond_exe)
    );

    // Branch / JAL target = PC + imm, JALR target = (rs1 + imm) & ~1
    // (for JALR the ALU computes rs1 + imm, since alu_src = 1 and ALU = ADD)
    assign pc_plus_imm_exe = current_pc_exe + imm_exe;
    assign target_pc_exe   = is_jalr_exe ? (alu_result_exe & 32'hffff_fffe)
                                         : pc_plus_imm_exe;

    // Value written back by LUI (imm) and AUIPC (PC + imm)
    assign upper_result_exe = is_lui_exe ? imm_exe : pc_plus_imm_exe;

    // ------------------------------------------------------------------
    // EXE/MEM pipeline register
    // ------------------------------------------------------------------
    localparam int EXE_MEM_CTRL_W = 1 + 1 + 1 + 1 + 2;                        // 6
    localparam int EXE_MEM_DATA_W = 1 + 32 + 32 + 32 + 32 + 32 + 5 + 3;      // 169
    localparam int EXE_MEM_W      = EXE_MEM_CTRL_W + EXE_MEM_DATA_W;
    logic [EXE_MEM_W-1:0] obus_exe, ibus_mem;

    assign obus_exe = {
        // control
        reg_write_exe, mem_write_exe, branch_exe, jump_exe, wb_sel_exe,
        // data
        branch_cond_exe, target_pc_exe, alu_result_exe, rs2_fwd_data_exe,
        upper_result_exe, pc_plus4_exe, rd_addr_exe, funct3_exe
    };

    n_bit_reg #(.n(EXE_MEM_W)) exe_mem_reg (
        .clk(clk),
        .reset_n(reset_n),
        .clear(flush_exe_mem_reg),
        .data_in(obus_exe),
        .data_out(ibus_mem)
    );

    assign {
        reg_write_mem, mem_write_mem, branch_mem, jump_mem, wb_sel_mem,
        branch_cond_mem, target_pc_mem, alu_result_mem, rs2_data_mem,
        upper_result_mem, pc_plus4_mem, rd_addr_mem, funct3_mem
    } = ibus_mem;

    // ==================================================================
    // MEM : Memory Access
    // ==================================================================
    data_mem dm (
        .clk(clk),
        .reset_n(reset_n),
        .mem_write(mem_write_mem),
        .addr(alu_result_mem),
        .wdata(rs2_data_mem),
        .funct3(funct3_mem),
        .rdata(mem_rdata_mem)
    );

    // Branch / jump decision, fed back to the next-PC mux in IF
    assign pc_sel_mem = (branch_mem & branch_cond_mem) | jump_mem;

    // Value the MEM-stage instruction will write back, forwarded to EXE.
    // A load's data (wb_sel = 01) is not forwarded from here: that is the
    // load-use hazard, which is still handled in software. For a load the
    // ALU result (the address) is passed instead and is never used, because
    // the program has a nop after every load whose register is used next.
    always_comb begin
        case (wb_sel_mem)
            2'd2:    fwd_result_mem = pc_plus4_mem;      // JAL / JALR
            2'd3:    fwd_result_mem = upper_result_mem;  // LUI / AUIPC
            default: fwd_result_mem = alu_result_mem;    // ALU (and loads)
        endcase
    end

    // ------------------------------------------------------------------
    // MEM/WB pipeline register
    // ------------------------------------------------------------------
    localparam int MEM_WB_W = 1 + 2 + 5 + 32 + 32 + 32 + 32;   // 136
    logic [MEM_WB_W-1:0] obus_mem, ibus_wb;

    assign obus_mem = {
        reg_write_mem, wb_sel_mem, rd_addr_mem,
        alu_result_mem, mem_rdata_mem, pc_plus4_mem, upper_result_mem
    };

    n_bit_reg #(.n(MEM_WB_W)) mem_wb_reg (
        .clk(clk),
        .reset_n(reset_n),
        .clear(1'b0),            // never flushed: the branch / jump itself
                                 // must complete (JAL / JALR write rd)
        .data_in(obus_mem),
        .data_out(ibus_wb)
    );

    assign {
        reg_write_wb, wb_sel_wb, rd_addr_wb,
        alu_result_wb, mem_rdata_wb, pc_plus4_wb, upper_result_wb
    } = ibus_wb;

    // ==================================================================
    // WB : Write Back
    // ==================================================================
    // wb_sel: 00 = ALU result, 01 = data memory, 10 = PC + 4, 11 = LUI/AUIPC
    always_comb begin
        case (wb_sel_wb)
            2'd0:    writeback_data_wb = alu_result_wb;
            2'd1:    writeback_data_wb = mem_rdata_wb;
            2'd2:    writeback_data_wb = pc_plus4_wb;
            2'd3:    writeback_data_wb = upper_result_wb;
            default: writeback_data_wb = 32'd0;
        endcase
    end
endmodule
