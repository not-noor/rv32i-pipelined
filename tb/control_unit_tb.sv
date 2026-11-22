`timescale 1ns/1ps
// Control path test. The branch decision is not made here (see
// branch_comp_tb). Checks the decoded control signals and that the
// forwarding unit and the hazard controller inside the control path drive
// forward_a/b_exe and the flush signals.
module control_unit_tb;
    logic [31:0] inst;
    logic reg_write, mem_write, mem_to_reg, alu_src, branch, jump;
    logic [1:0] alu_op, wb_sel;
    logic [3:0] alu_ctrl;
    logic [4:0] rs1_addr_exe, rs2_addr_exe, rd_addr_mem, rd_addr_wb;
    logic       reg_write_mem, reg_write_wb;
    logic [1:0] forward_a_exe, forward_b_exe;
    logic       pc_sel_mem, flush_if_id_reg, flush_id_exe_reg, flush_exe_mem_reg;

    control_unit dut (.*);

    initial begin
        inst = 32'h00628463; #1; // beq x5,x6,+8
        if (!branch || jump || reg_write || mem_write || alu_ctrl !== 4'h8)
            $fatal(1, "BEQ control decode failed");

        inst = 32'h40628333; #1; // sub x6,x5,x6
        if (!reg_write || alu_src || alu_ctrl !== 4'h8 || wb_sel != 2'b00)
            $fatal(1, "SUB control decode failed");

        inst = 32'h0002a383; #1; // lw x7,0(x5)
        if (!reg_write || !alu_src || wb_sel != 2'b01 || alu_ctrl !== 4'h0)
            $fatal(1, "LW control decode failed");

        inst = 32'h0072a023; #1; // sw x7,0(x5)
        if (reg_write || !mem_write || !alu_src || alu_ctrl !== 4'h0)
            $fatal(1, "SW control decode failed");

        inst = 32'h000000ef; #1; // jal x1,0
        if (!jump || branch || !reg_write || wb_sel != 2'b10)
            $fatal(1, "JAL decode failed");

        inst = 32'h00008067; #1; // jalr x0,0(x1)
        if (!jump || !alu_src || alu_ctrl !== 4'h0 || wb_sel != 2'b10)
            $fatal(1, "JALR decode failed");

        inst = 32'h00000000; #1; // all zero (pipeline bubble after reset)
        if (reg_write || mem_write || branch || jump)
            $fatal(1, "Bubble must not write or change the PC");

        // forwarding: rs1 matches the MEM destination, rs2 the WB destination
        rs1_addr_exe = 5'd3; rs2_addr_exe = 5'd4;
        reg_write_mem = 1'b1; rd_addr_mem = 5'd3;
        reg_write_wb  = 1'b1; rd_addr_wb  = 5'd4; #1;
        if (forward_a_exe !== 2'b10 || forward_b_exe !== 2'b01)
            $fatal(1, "forwarding selects wrong: a=%b b=%b", forward_a_exe, forward_b_exe);
        reg_write_mem = 1'b0; reg_write_wb = 1'b0; #1;
        if (forward_a_exe !== 2'b00 || forward_b_exe !== 2'b00)
            $fatal(1, "forwarding without reg_write");

        // hazard controller: flush the 3 registers behind a taken branch / jump
        pc_sel_mem = 1'b0; #1;
        if (flush_if_id_reg || flush_id_exe_reg || flush_exe_mem_reg)
            $fatal(1, "flush without a taken branch / jump");
        pc_sel_mem = 1'b1; #1;
        if (!flush_if_id_reg || !flush_id_exe_reg || !flush_exe_mem_reg)
            $fatal(1, "taken branch / jump did not flush");

        $display("PASS control_unit_tb");
        $finish;
    end
endmodule
