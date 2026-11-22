`timescale 1ns/1ps
// Unit test for forwarding_unit: checks the EX hazard, MEM hazard, the
// priority of the newer value (double hazard), x0, and the write enables.
module forwarding_unit_tb;
    logic [4:0] rs1_addr_exe, rs2_addr_exe, rd_addr_mem, rd_addr_wb;
    logic       reg_write_mem, reg_write_wb;
    logic [1:0] forward_a_exe, forward_b_exe;
    int errors = 0;

    forwarding_unit dut (.*);

    task automatic check(input string name, input logic [1:0] exp_a, exp_b);
        #1;
        if (forward_a_exe !== exp_a || forward_b_exe !== exp_b) begin
            $display("ERROR %s: forward_a = %b (exp %b), forward_b = %b (exp %b)",
                     name, forward_a_exe, exp_a, forward_b_exe, exp_b);
            errors++;
        end
    endtask

    initial begin
        // no hazard
        rs1_addr_exe = 1; rs2_addr_exe = 2;
        reg_write_mem = 1; rd_addr_mem = 3; reg_write_wb = 1; rd_addr_wb = 4;
        check("no hazard", 2'b00, 2'b00);

        // EX hazard on rs1, then on rs2, then on both
        rd_addr_mem = 1;                          check("EX rs1",  2'b10, 2'b00);
        rd_addr_mem = 2;                          check("EX rs2",  2'b00, 2'b10);
        rs1_addr_exe = 2;                         check("EX both", 2'b10, 2'b10);

        // MEM hazard on rs1 / rs2
        rs1_addr_exe = 4; rs2_addr_exe = 5; rd_addr_mem = 3;
        check("MEM rs1", 2'b01, 2'b00);
        rs1_addr_exe = 1; rs2_addr_exe = 4;       check("MEM rs2", 2'b00, 2'b01);

        // one operand from MEM, the other from WB
        rs1_addr_exe = 4; rs2_addr_exe = 3;       check("WB rs1 + MEM rs2", 2'b01, 2'b10);

        // double hazard: MEM and WB write the same register -> MEM (newer) wins
        rs1_addr_exe = 6; rs2_addr_exe = 6; rd_addr_mem = 6; rd_addr_wb = 6;
        check("double hazard", 2'b10, 2'b10);
        // ... unless the MEM instruction does not write a register
        reg_write_mem = 0;                        check("double, MEM no write", 2'b01, 2'b01);

        // no forwarding when the producer does not write
        reg_write_wb = 0;                         check("no reg_write", 2'b00, 2'b00);

        // x0 is never forwarded
        reg_write_mem = 1; reg_write_wb = 1;
        rs1_addr_exe = 0; rs2_addr_exe = 0; rd_addr_mem = 0; rd_addr_wb = 0;
        check("x0", 2'b00, 2'b00);

        if (errors == 0) $display("PASS forwarding_unit_tb");
        else             $fatal(1, "FAIL forwarding_unit_tb: %0d error(s)", errors);
        $finish;
    end
endmodule
