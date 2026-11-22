`timescale 1ns/1ps
module alu_control_tb;
    logic [1:0] alu_op;
    logic [2:0] funct3;
    logic funct7_5;
    logic [3:0] alu_ctrl;

    alu_control dut (.*);

    initial begin
        alu_op = 2'b10; funct3 = 3'b000; funct7_5 = 1'b1; #1;
        if (alu_ctrl !== 4'h8) $fatal(1, "SUB decode failed");

        alu_op = 2'b10; funct3 = 3'b000; funct7_5 = 1'b0; #1;
        if (alu_ctrl !== 4'h0) $fatal(1, "ADD decode failed");

        alu_op = 2'b11; funct3 = 3'b101; funct7_5 = 1'b1; #1;
        if (alu_ctrl !== 4'hd) $fatal(1, "SRAI decode failed");

        alu_op = 2'b01; funct3 = 3'b000; funct7_5 = 1'b0; #1;
        if (alu_ctrl !== 4'h8) $fatal(1, "Branch SUB decode failed");

        $display("PASS alu_control_tb");
        $finish;
    end
endmodule
