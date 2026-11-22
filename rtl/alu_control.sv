// ALU decoder. ALU encodings match alu.sv:
// 0 ADD, 8 SUB, 1 SLL, 2 SLT, 3 SLTU, 4 XOR,
// 5 SRL, 13 SRA, 6 OR, 7 AND.
module alu_control (
    input  logic [1:0] alu_op,
    input  logic [2:0] funct3,
    input  logic       funct7_5,
    output logic [3:0] alu_ctrl
);
    always_comb begin
        alu_ctrl = 4'h0;
        case (alu_op)
            2'b00: alu_ctrl = 4'h0; // address generation: ADD
            2'b01: alu_ctrl = 4'h8; // branch comparison: SUB
            2'b10: alu_ctrl = {funct7_5, funct3}; // R-type
            2'b11: begin // I-type arithmetic/logical
                case (funct3)
                    3'b000: alu_ctrl = 4'h0; // ADDI
                    3'b001: alu_ctrl = 4'h1; // SLLI
                    3'b010: alu_ctrl = 4'h2; // SLTI
                    3'b011: alu_ctrl = 4'h3; // SLTIU
                    3'b100: alu_ctrl = 4'h4; // XORI
                    3'b101: alu_ctrl = {funct7_5, funct3}; // SRLI/SRAI
                    3'b110: alu_ctrl = 4'h6; // ORI
                    3'b111: alu_ctrl = 4'h7; // ANDI
                    default: alu_ctrl = 4'h0;
                endcase
            end
            default: alu_ctrl = 4'h0;
        endcase
    end
endmodule
