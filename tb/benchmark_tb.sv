`timescale 1ns/1ps
// Benchmark: the same program on two configurations of the processor, side
// by side.
//
//   dut_base : programs/benchmark_nops.s on a pipeline without hazard
//              hardware (FORWARDING_EN = 0, FLUSH_EN = 0). Every hazard is
//              resolved with nops (105 instructions, 49 of them nops).
//   dut_full : programs/benchmark.s, the same program without the nops,
//              on the full processor (56 instructions).
//
// The run time of each is measured up to the cycle in which the program's
// last instruction before the final jump (sw x29, 12(x0)) reaches the MEM
// stage. Both runs must give the same results.
module benchmark_tb;
    logic        clk = 0, reset_n;
    logic [31:0] pc_base, inst_base, pc_full, inst_full;
    int          errors = 0;
    int          cycle = 0, end_base = 0, end_full = 0;

    always #5 clk = ~clk;

    rv32i_top #(.IMEM_INIT("benchmark_nops.hex"), .FORWARDING_EN(1'b0), .FLUSH_EN(1'b0))
        dut_base (.clk(clk), .reset_n(reset_n), .current_pc(pc_base), .inst(inst_base));
    rv32i_top #(.IMEM_INIT("benchmark.hex"))
        dut_full (.clk(clk), .reset_n(reset_n), .current_pc(pc_full), .inst(inst_full));

    // the last instruction of the program is the store to address 0xc
    always @(posedge clk) if (reset_n) begin
        cycle++;
        if (dut_base.dp.mem_write_mem && dut_base.dp.alu_result_mem == 32'hc && end_base == 0)
            end_base = cycle;
        if (dut_full.dp.mem_write_mem && dut_full.dp.alu_result_mem == 32'hc && end_full == 0)
            end_full = cycle;
    end

    initial begin
        #1;
        if (dut_base.dp.im.imem[0] === 32'h00000013 || dut_full.dp.im.imem[0] === 32'h00000013)
            $fatal(1, "benchmark_nops.hex / benchmark.hex not loaded. Copy programs/*.hex into the simulation run directory.");

        reset_n = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;
        repeat (200) @(negedge clk);

        // same results (x1 and x18 hold code addresses, which differ)
        for (int r = 0; r < 32; r++) begin
            if (r != 1 && r != 18 && dut_base.dp.rf.regs[r] !== dut_full.dp.rf.regs[r]) begin
                $display("ERROR: x%0d differs: 0x%08h (nops) vs 0x%08h (full)",
                         r, dut_base.dp.rf.regs[r], dut_full.dp.rf.regs[r]);
                errors++;
            end
        end
        for (int w = 0; w < 4; w++) begin
            if (dut_base.dp.dm.dmem[w] !== dut_full.dp.dm.dmem[w]) begin
                $display("ERROR: mem word %0d differs", w);
                errors++;
            end
        end
        if (dut_full.dp.rf.regs[24] !== 0 || dut_full.dp.dm.dmem[3] !== 32'd10) begin
            $display("ERROR: program did not complete correctly");
            errors++;
        end
        if (end_base == 0 || end_full == 0 || end_full >= end_base) begin
            $display("ERROR: cycle counts wrong (nops = %0d, full = %0d)", end_base, end_full);
            errors++;
        end

        $display("Cycles: software nops = %0d, hardware forwarding + flushing = %0d (%0d%% fewer)",
                 end_base, end_full, (100 * (end_base - end_full) + end_base / 2) / end_base);
        if (errors == 0) $display("PASS benchmark_tb");
        else             $fatal(1, "FAIL benchmark_tb: %0d error(s)", errors);
        $finish;
    end
endmodule
