// Branch comparator (execute stage).
// In the single-cycle design this comparison was done inside control_unit.
// In the pipeline the register operands are only available in the execute
// stage, so the comparison is done here and the result (branch_cond) is
// carried to the memory stage, where it is ANDed with the branch control
// signal to produce pc_sel.
module branch_comp (
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    input  logic [2:0]  funct3,
    output logic        branch_cond
);
    always_comb begin
        case (funct3)
            3'b000:  branch_cond = (rs1_data == rs2_data);                    // BEQ
            3'b001:  branch_cond = (rs1_data != rs2_data);                    // BNE
            3'b100:  branch_cond = ($signed(rs1_data) <  $signed(rs2_data)); // BLT
            3'b101:  branch_cond = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
            3'b110:  branch_cond = (rs1_data <  rs2_data);                    // BLTU
            3'b111:  branch_cond = (rs1_data >= rs2_data);                    // BGEU
            default: branch_cond = 1'b0;
        endcase
    end
endmodule
