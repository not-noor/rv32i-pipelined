`timescale 1ns/1ps
module branch_comp_tb;
    logic [31:0] rs1_data, rs2_data;
    logic [2:0]  funct3;
    logic        branch_cond;

    branch_comp dut (.*);

    task automatic check(input logic [2:0] f3, input logic [31:0] a, b, input logic expected);
        funct3 = f3; rs1_data = a; rs2_data = b; #1;
        if (branch_cond !== expected)
            $fatal(1, "funct3=%b rs1=%h rs2=%h: got %b expected %b", f3, a, b, branch_cond, expected);
    endtask

    initial begin
        check(3'b000, 5, 5, 1);                       // BEQ
        check(3'b000, 5, 6, 0);
        check(3'b001, 5, 6, 1);                       // BNE
        check(3'b001, 5, 5, 0);
        check(3'b100, 32'hfffffff0, 2, 1);            // BLT  (-16 < 2)
        check(3'b100, 2, 32'hfffffff0, 0);
        check(3'b101, 2, 32'hfffffff0, 1);            // BGE
        check(3'b101, 3, 3, 1);
        check(3'b110, 2, 32'hfffffff0, 1);            // BLTU (2 < 0xfffffff0)
        check(3'b110, 32'hfffffff0, 2, 0);
        check(3'b111, 32'hfffffff0, 2, 1);            // BGEU
        check(3'b111, 2, 32'hfffffff0, 0);
        check(3'b010, 5, 5, 0);                       // not a branch funct3
        $display("PASS branch_comp_tb");
        $finish;
    end
endmodule
