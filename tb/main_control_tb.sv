`timescale 1ns/1ps
module main_control_tb;
    logic [6:0] opcode;
    logic reg_write, mem_write, mem_to_reg, alu_src, branch, jump;
    logic [1:0] alu_op, wb_sel;

    main_control dut (.*);

    initial begin
        opcode = 7'b0000011; #1;
        if (!reg_write || !alu_src || !mem_to_reg || wb_sel != 2'b01 || alu_op != 2'b00)
            $fatal(1, "LOAD control failed");

        opcode = 7'b0100011; #1;
        if (mem_write !== 1'b1 || alu_src !== 1'b1 || reg_write !== 1'b0)
            $fatal(1, "STORE control failed");

        opcode = 7'b0110011; #1;
        if (!reg_write || alu_op != 2'b10 || alu_src || mem_write)
            $fatal(1, "R-type control failed");

        opcode = 7'b1101111; #1;
        if (!reg_write || !jump || wb_sel != 2'b10)
            $fatal(1, "JAL control failed");

        opcode = 7'b0010111; #1;
        if (!reg_write || wb_sel != 2'b11)
            $fatal(1, "AUIPC control failed");

        $display("PASS main_control_tb");
        $finish;
    end
endmodule
