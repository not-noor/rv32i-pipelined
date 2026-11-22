`timescale 1ns/1ps
// Data hazard demo: runs the same short sequence on three processors at the
// same time.
//
//   dut_hw_none : data_hazard_demo.hex (no nops), FORWARDING_EN = 0
//                 -> no hazard handling. Two instructions read stale values:
//                       add a0, t3, t1  reads old t3 = 0   -> a0 = 0x004
//                       sra a1, t3, a0  reads old a0 = 0   -> a1 = 0x0ff
//   dut_sw_nops : data_hazard_demo_nops.hex (nops added), FORWARDING_EN = 0
//                 -> hazards resolved in software, all results correct
//   dut_hw_fwd  : data_hazard_demo.hex (no nops), FORWARDING_EN = 1
//                 -> hazards resolved by forwarding, all results correct
//
// Correct results: t0 (x5) = 5, x6 = 4, t2 (x7) = 1, a0 (x10) = 0x103,
//                  a1 (x11) = 0x1f, t3 (x28) = 0xff
module data_hazard_demo_tb;
    logic clk = 0, reset_n;
    logic [31:0] pc0, inst0, pc1, inst1, pc2, inst2;
    int errors = 0;

    always #5 clk = ~clk;

    rv32i_top #(.IMEM_INIT("data_hazard_demo.hex"), .FORWARDING_EN(1'b0))
        dut_hw_none (.clk(clk), .reset_n(reset_n), .current_pc(pc0), .inst(inst0));
    rv32i_top #(.IMEM_INIT("data_hazard_demo_nops.hex"),       .FORWARDING_EN(1'b0))
        dut_sw_nops (.clk(clk), .reset_n(reset_n), .current_pc(pc1), .inst(inst1));
    rv32i_top #(.IMEM_INIT("data_hazard_demo.hex"), .FORWARDING_EN(1'b1))
        dut_hw_fwd  (.clk(clk), .reset_n(reset_n), .current_pc(pc2), .inst(inst2));

    `define DH_CHECK(DUT, R, NAME, EXP) \
        if (DUT.dp.rf.regs[R] !== EXP) begin \
            $display("  %s %s (x%0d) = 0x%08h, expected 0x%08h  <-- wrong", \
                     `"DUT`", NAME, R, DUT.dp.rf.regs[R], EXP); \
            wrong++; \
        end else \
            $display("  %s %s (x%0d) = 0x%08h", `"DUT`", NAME, R, DUT.dp.rf.regs[R]);

    initial begin
        int wrong;
        $dumpfile("data_hazard_demo.vcd");
        $dumpvars(0, data_hazard_demo_tb);

        #1;
        if (dut_hw_none.dp.im.imem[0] === 32'h00000013 ||
            dut_sw_nops.dp.im.imem[0] === 32'h00000013)
            $fatal(1, "data_hazard_demo.hex / data_hazard_demo_nops.hex not loaded. Copy them into the simulation run directory.");

        reset_n = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;
        repeat (40) @(negedge clk);   // all three programs are done by now

        // ---- no forwarding, no nops: exactly the two identified instructions fail
        $display("No forwarding, sequence without nops:");
        wrong = 0;
        `DH_CHECK(dut_hw_none, 28, "t3", 32'h000000ff)
        `DH_CHECK(dut_hw_none,  5, "t0", 32'h00000005)
        `DH_CHECK(dut_hw_none, 10, "a0", 32'h00000103)
        `DH_CHECK(dut_hw_none, 11, "a1", 32'h0000001f)
        `DH_CHECK(dut_hw_none,  6, "x6", 32'h00000004)
        if (wrong != 2 || dut_hw_none.dp.rf.regs[10] !== 32'h004 ||
                          dut_hw_none.dp.rf.regs[11] !== 32'h0ff) begin
            $display("ERROR: expected exactly add a0 (a0 = 0x4) and sra a1 (a1 = 0xff) to fail");
            errors++;
        end else
            $display("  -> as predicted, only add a0,t3,t1 and sra a1,t3,a0 are wrong");

        // ---- no forwarding, with nops: everything correct
        $display("No forwarding, sequence with nops (software fix):");
        wrong = 0;
        `DH_CHECK(dut_sw_nops, 28, "t3", 32'h000000ff)
        `DH_CHECK(dut_sw_nops,  5, "t0", 32'h00000005)
        `DH_CHECK(dut_sw_nops, 10, "a0", 32'h00000103)
        `DH_CHECK(dut_sw_nops, 11, "a1", 32'h0000001f)
        `DH_CHECK(dut_sw_nops,  6, "x6", 32'h00000004)
        errors += wrong;

        // ---- forwarding, no nops: everything correct
        $display("Forwarding, sequence without nops (hardware fix):");
        wrong = 0;
        `DH_CHECK(dut_hw_fwd, 28, "t3", 32'h000000ff)
        `DH_CHECK(dut_hw_fwd,  5, "t0", 32'h00000005)
        `DH_CHECK(dut_hw_fwd, 10, "a0", 32'h00000103)
        `DH_CHECK(dut_hw_fwd, 11, "a1", 32'h0000001f)
        `DH_CHECK(dut_hw_fwd,  6, "x6", 32'h00000004)
        errors += wrong;

        if (errors == 0) $display("PASS data_hazard_demo_tb");
        else             $fatal(1, "FAIL data_hazard_demo_tb: %0d error(s)", errors);
        $finish;
    end
endmodule

`undef DH_CHECK
