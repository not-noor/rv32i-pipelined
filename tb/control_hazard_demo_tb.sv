`timescale 1ns/1ps
// Control hazard demo: runs the same short sequence on three processors at
// the same time.
//
//   dut_hw_none  : control_hazard_demo.hex (no nops), FLUSH_EN = 0
//                  -> no control-hazard handling. bne x6, x0, branch2 is
//                     taken, but or x9, x10, x11 behind it has already been
//                     fetched and executes: x9 = 0x11 instead of 0.
//                     xor x12 runs twice.
//   dut_sw_nops  : control_hazard_demo_nops.hex (3 nops after each branch), FLUSH_EN = 0
//                  -> hazards resolved in software, all results correct
//   dut_hw_flush : control_hazard_demo.hex (no nops), FLUSH_EN = 1
//                  -> hazards resolved by flushing, all results correct
//
// Correct results: x1 = 10, x2 = 20, x3 = 3, x6 = 5, x9 = 0, x12 = 0xff.
// The testbench also counts how many times xor x12 is written back, and
// compares how many cycles the nop version and the flush version need until
// xor x12 (the last instruction of the sequence) is written back.
module control_hazard_demo_tb;
    logic clk = 0, reset_n;
    logic [31:0] pc0, inst0, pc1, inst1, pc2, inst2;
    int errors = 0;

    always #5 clk = ~clk;

    rv32i_top #(.IMEM_INIT("control_hazard_demo.hex"), .FLUSH_EN(1'b0))
        dut_hw_none  (.clk(clk), .reset_n(reset_n), .current_pc(pc0), .inst(inst0));
    rv32i_top #(.IMEM_INIT("control_hazard_demo_nops.hex"),       .FLUSH_EN(1'b0))
        dut_sw_nops  (.clk(clk), .reset_n(reset_n), .current_pc(pc1), .inst(inst1));
    rv32i_top #(.IMEM_INIT("control_hazard_demo.hex"), .FLUSH_EN(1'b1))
        dut_hw_flush (.clk(clk), .reset_n(reset_n), .current_pc(pc2), .inst(inst2));

    // number of write-backs to x12 (the xor) and the cycle of the last one
    int xor_wb_none = 0, xor_wb_sw = 0, xor_wb_flush = 0;
    int done_sw = 0, done_flush = 0;
    int cycle = 0;
    always @(posedge clk) if (reset_n) begin
        cycle++;
        if (dut_hw_none.dp.reg_write_wb  && dut_hw_none.dp.rd_addr_wb  == 12) xor_wb_none++;
        if (dut_sw_nops.dp.reg_write_wb  && dut_sw_nops.dp.rd_addr_wb  == 12) begin
            xor_wb_sw++;
            done_sw = cycle;
        end
        if (dut_hw_flush.dp.reg_write_wb && dut_hw_flush.dp.rd_addr_wb == 12) begin
            xor_wb_flush++;
            done_flush = cycle;
        end
    end

    `define CH_CHECK(DUT, R, EXP) \
        if (DUT.dp.rf.regs[R] !== EXP) begin \
            $display("  %s x%0d = 0x%08h, expected 0x%08h  <-- wrong", \
                     `"DUT`", R, DUT.dp.rf.regs[R], EXP); \
            wrong++; \
        end else \
            $display("  %s x%0d = 0x%08h", `"DUT`", R, DUT.dp.rf.regs[R]);

    `define CH_CHECK_ALL(DUT) \
        `CH_CHECK(DUT,  1, 32'h0000000a) \
        `CH_CHECK(DUT,  2, 32'h00000014) \
        `CH_CHECK(DUT,  3, 32'h00000003) \
        `CH_CHECK(DUT,  6, 32'h00000005) \
        `CH_CHECK(DUT,  9, 32'h00000000) \
        `CH_CHECK(DUT, 12, 32'h000000ff)

    initial begin
        int wrong;
        $dumpfile("control_hazard_demo.vcd");
        $dumpvars(0, control_hazard_demo_tb);

        #1;
        if (dut_hw_none.dp.im.imem[0] === 32'h00000013 ||
            dut_sw_nops.dp.im.imem[0] === 32'h00000013)
            $fatal(1, "control_hazard_demo.hex / control_hazard_demo_nops.hex not loaded. Copy them into the simulation run directory.");

        reset_n = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;
        repeat (50) @(negedge clk);   // all three programs are done by now

        // ---- no flushing, no nops: or x9 executes on the wrong path
        $display("No control hazard handling, sequence without nops:");
        wrong = 0;
        `CH_CHECK_ALL(dut_hw_none)
        $display("  xor x12 written back %0d times", xor_wb_none);
        if (wrong != 1 || dut_hw_none.dp.rf.regs[9] !== 32'h11) begin
            $display("ERROR: expected exactly or x9, x10, x11 to execute wrongly (x9 = 0x11)");
            errors++;
        end else
            $display("  -> as predicted, only or x9, x10, x11 (behind the taken bne) is wrong");

        // ---- no flushing, with nops: correct
        $display("No control hazard handling, sequence with nops (software fix):");
        wrong = 0;
        `CH_CHECK_ALL(dut_sw_nops)
        $display("  xor x12 written back %0d times", xor_wb_sw);
        errors += wrong + (xor_wb_sw != 1);

        // ---- flushing, no nops: correct
        $display("Flushing, sequence without nops (hardware fix):");
        wrong = 0;
        `CH_CHECK_ALL(dut_hw_flush)
        $display("  xor x12 written back %0d times", xor_wb_flush);
        errors += wrong + (xor_wb_flush != 1);

        // The nop version always pays 3 cycles per branch. Flushing only pays
        // them when the branch is taken (bne), not for beq (not taken).
        $display("Cycles until xor x12 is written back: software nops = %0d, hardware flush = %0d",
                 done_sw, done_flush);
        if (done_sw - done_flush != 3) begin
            $display("ERROR: the flushing version should be 3 cycles faster (beq is not taken)");
            errors++;
        end

        if (errors == 0) $display("PASS control_hazard_demo_tb");
        else             $fatal(1, "FAIL control_hazard_demo_tb: %0d error(s)", errors);
        $finish;
    end
endmodule

`undef CH_CHECK_ALL
`undef CH_CHECK
