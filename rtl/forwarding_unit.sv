// Forwarding unit (control path, execute stage).
//
// Compares the source registers of the instruction in the execute stage
// (rs1_addr_exe, rs2_addr_exe, carried by id_exe_reg) with the destination
// registers of the two instructions ahead of it:
//   * the instruction in the memory stage    (exe_mem_reg: rd_addr_mem)
//   * the instruction in the write back stage (mem_wb_reg:  rd_addr_wb)
// and selects where each ALU operand comes from.
//
// forward_a_exe / forward_b_exe encoding:
//   2'b00 : value read from the register file in the decode stage
//   2'b10 : result of the instruction in the MEM stage (EX hazard)
//   2'b01 : result of the instruction in the WB stage  (MEM hazard)
//
// The MEM-stage value has priority because it is the most recent write to
// that register. Register x0 is never forwarded.
//
// Load-use hazard: a load only has its data at the end of the MEM stage, so
// a load in MEM cannot forward to the instruction right behind it. That
// case is not handled here and must still be solved in software (one nop
// between the load and the instruction that uses the loaded register).
module forwarding_unit (
    input  logic [4:0] rs1_addr_exe,
    input  logic [4:0] rs2_addr_exe,
    input  logic       reg_write_mem,
    input  logic [4:0] rd_addr_mem,
    input  logic       reg_write_wb,
    input  logic [4:0] rd_addr_wb,
    output logic [1:0] forward_a_exe,
    output logic [1:0] forward_b_exe
);
    logic ex_hazard_a, ex_hazard_b, mem_hazard_a, mem_hazard_b;

    // EX hazard: the instruction in MEM writes the register we read
    assign ex_hazard_a = reg_write_mem && (rd_addr_mem != 5'd0) &&
                         (rd_addr_mem == rs1_addr_exe);
    assign ex_hazard_b = reg_write_mem && (rd_addr_mem != 5'd0) &&
                         (rd_addr_mem == rs2_addr_exe);

    // MEM hazard: the instruction in WB writes the register we read, and the
    // instruction in MEM does not write a newer value of it
    assign mem_hazard_a = reg_write_wb && (rd_addr_wb != 5'd0) &&
                          (rd_addr_wb == rs1_addr_exe) && !ex_hazard_a;
    assign mem_hazard_b = reg_write_wb && (rd_addr_wb != 5'd0) &&
                          (rd_addr_wb == rs2_addr_exe) && !ex_hazard_b;

    always_comb begin
        if (ex_hazard_a)       forward_a_exe = 2'b10;
        else if (mem_hazard_a) forward_a_exe = 2'b01;
        else                   forward_a_exe = 2'b00;

        if (ex_hazard_b)       forward_b_exe = 2'b10;
        else if (mem_hazard_b) forward_b_exe = 2'b01;
        else                   forward_b_exe = 2'b00;
    end
endmodule
