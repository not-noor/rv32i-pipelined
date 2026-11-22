// Main opcode decoder for the single-cycle RV32I core.
// wb_sel: 00=ALU result, 01=data memory, 10=PC+4, 11=LUI/AUIPC.
module main_control (
    input  logic [6:0] opcode,
    output logic       reg_write,
    output logic       mem_write,
    output logic       mem_to_reg,
    output logic [1:0] alu_op,
    output logic       alu_src,
    output logic       branch,
    output logic       jump,
    output logic [1:0] wb_sel
);
    always_comb begin
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        alu_op    = 2'b00;
        alu_src   = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        wb_sel    = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type arithmetic/logical
                reg_write = 1'b1;
                alu_op    = 2'b10;
            end
            7'b0010011: begin // I-type arithmetic/logical
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b11;
            end
            7'b0000011: begin // Loads
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                wb_sel    = 2'b01;
            end
            7'b0100011: begin // Stores
                mem_write = 1'b1;
                alu_src  = 1'b1;
                alu_op   = 2'b00;
            end
            7'b1100011: begin // Conditional branches
                branch = 1'b1;
                alu_op = 2'b01;
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump      = 1'b1;
                wb_sel    = 2'b10;
            end
            7'b1100111: begin // JALR
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
                wb_sel    = 2'b10;
            end
            7'b0110111: begin // LUI
                reg_write = 1'b1;
                wb_sel    = 2'b11;
            end
            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                wb_sel    = 2'b11;
            end
            default: begin
                // Keep all control signals in their safe default state.
            end
        endcase
    end
endmodule
