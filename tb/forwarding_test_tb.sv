`timescale 1ns/1ps
// Forwarding test: runs programs/forwarding_test.s with forwarding on and
// flushing off (FLUSH_EN = 0). The program has no nops for data hazards;
// only load-use hazards (1 nop) and control hazards (3 nops after each
// branch / jump) are handled in software. A section of the program
// exercises every forwarding path.
//
// The testbench runs the program until it reaches the self-loop at "done",
// lets the pipeline drain, checks every register and the data memory, and
// prints how often each forwarding path was used.
//
// In Vivado use "Run All" (or type "run all" in the Tcl console); the
// testbench ends the simulation by itself.
module forwarding_test_tb;
    logic        clk = 0;
    logic        reset_n;
    logic [31:0] current_pc, inst;

    localparam logic [31:0] DONE_PC    = 32'h294;   // address of "done: jal x0, done"
    localparam int          MAX_CYCLES = 1000;

    int errors = 0;
    int cycles = 0;

    always #5 clk = ~clk;

    rv32i_top #(.IMEM_INIT("forwarding_test.hex"), .FLUSH_EN(1'b0)) dut (.*);

    // ------------------------------------------------------------------
    // Expected results (from programs/forwarding_test.s)
    // ------------------------------------------------------------------
    logic [31:0] exp_reg [0:31];
    initial begin
        exp_reg[0]  = 32'h00000000;
        exp_reg[1]  = 32'h0000024c;   // return address of "jal x1, func"
        exp_reg[2]  = 32'h00000007;
        exp_reg[3]  = 32'h00000008;
        exp_reg[4]  = 32'h0000000c;   // sub x4, x1, x5 = 15 - 3 (x1 forwarded)
        exp_reg[5]  = 32'h00000003;
        exp_reg[6]  = 32'hfffffff0;
        exp_reg[7]  = 32'h00000002;
        exp_reg[8]  = 32'hffffffc0;   // sll
        exp_reg[9]  = 32'h3ffffffc;   // srl
        exp_reg[10] = 32'hfffffffc;   // sra
        exp_reg[11] = 32'h00000001;   // slt
        exp_reg[12] = 32'h00000000;   // sltu
        exp_reg[13] = 32'hfffffff2;   // xor
        exp_reg[14] = 32'hfffffff2;   // or
        exp_reg[15] = 32'h00000000;   // and
        exp_reg[16] = 32'h000000f0;   // andi
        exp_reg[17] = 32'h12345678;   // lui + ori
        exp_reg[18] = 32'h0000016c;   // auipc
        exp_reg[19] = 32'hfffffff8;   // srai
        exp_reg[20] = 32'h00000020;   // slli
        exp_reg[21] = 32'h12345678;   // lw
        exp_reg[22] = 32'h00000012;   // lb
        exp_reg[23] = 32'h000000f0;   // lbu
        exp_reg[24] = 32'h00000000;   // stays 0 unless a wrong-path instruction ran
        exp_reg[25] = 32'hfffffff0;   // lh
        exp_reg[26] = 32'h0000fff0;   // lhu
        exp_reg[27] = 32'hfff00002;   // lw after sb + sh
        exp_reg[28] = 32'h00000004;   // loop counter
        exp_reg[29] = 32'h0000000a;   // 1 + 2 + 3 + 4
        exp_reg[30] = 32'h00000004;
        exp_reg[31] = 32'h00000055;   // written inside func
    end

    // ------------------------------------------------------------------
    // Monitors: register writes, stores, and forwarding path usage
    // ------------------------------------------------------------------
    int fwd_a_mem = 0, fwd_a_wb = 0, fwd_b_mem = 0, fwd_b_wb = 0;
    int flushes = 0;

    always @(posedge clk) begin
        if (reset_n && dut.dp.reg_write_wb && dut.dp.rd_addr_wb != 0)
            $display("[%0t] WB : x%0d <= 0x%08h", $time,
                     dut.dp.rd_addr_wb, dut.dp.writeback_data_wb);
        if (reset_n && dut.dp.mem_write_mem)
            $display("[%0t] MEM: store addr=0x%08h data=0x%08h funct3=%0d", $time,
                     dut.dp.alu_result_mem, dut.dp.rs2_data_mem, dut.dp.funct3_mem);
        if (reset_n) begin
            if (dut.forward_a_exe == 2'b10) fwd_a_mem++;
            if (dut.forward_a_exe == 2'b01) fwd_a_wb++;
            if (dut.forward_b_exe == 2'b10) fwd_b_mem++;
            if (dut.forward_b_exe == 2'b01) fwd_b_wb++;
            if (dut.flush_if_id_reg || dut.flush_id_exe_reg || dut.flush_exe_mem_reg) flushes++;
        end
    end

    task automatic check_reg(input int r);
        if (dut.dp.rf.regs[r] !== exp_reg[r]) begin
            $display("ERROR: x%0d = 0x%08h, expected 0x%08h", r, dut.dp.rf.regs[r], exp_reg[r]);
            errors++;
        end
    endtask

    task automatic check_mem(input int byte_addr, input logic [31:0] expected);
        if (dut.dp.dm.dmem[byte_addr >> 2] !== expected) begin
            $display("ERROR: mem[0x%02h] = 0x%08h, expected 0x%08h",
                     byte_addr, dut.dp.dm.dmem[byte_addr >> 2], expected);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("forwarding_test.vcd");
        $dumpvars(0, dut);

        // make sure the program was loaded (an empty memory reads as nops)
        #1;
        if (dut.dp.im.imem[0] === 32'h00000013)
            $fatal(1, "forwarding_test.hex was not loaded into inst_mem. Copy programs/*.hex into the simulation run directory (<project>.sim/sim_1/behav/xsim).");

        // hold reset over two rising edges so every register is cleared
        reset_n = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;

        // run until the program reaches the self-loop
        while (current_pc !== DONE_PC && cycles < MAX_CYCLES) begin
            @(negedge clk);
            cycles++;
        end
        if (cycles >= MAX_CYCLES)
            $fatal(1, "Timeout: PC never reached the done loop (PC = 0x%08h)", current_pc);

        // let the last instructions leave the pipeline
        repeat (10) @(negedge clk);

        for (int r = 0; r < 32; r++) check_reg(r);

        // sections C to G
        check_mem(32'h00, 32'h12345678);   // sw
        check_mem(32'h04, 32'hfff00002);   // sb + sh into the same word
        check_mem(32'h08, 32'h00000020);   // sw
        check_mem(32'h0c, 32'h0000000a);   // sw after the function call

        // section B: forwarding cases
        check_mem(32'h40, 32'h0000000c);   // both operands from MEM, store data from MEM
        check_mem(32'h44, 32'h00000003);   // double hazard: newest value wins
        check_mem(32'h48, 32'h0000000b);   // store address from MEM
        check_mem(32'h4c, 32'habcde123);   // LUI result from MEM
        check_mem(32'h50, 32'h00000051);   // AUIPC result from WB
        check_mem(32'h54, 32'h00000000);   // x0 is never forwarded
        check_mem(32'h58, 32'h00000013);   // register file write-through + WB
        check_mem(32'h5c, 32'h00000010);   // JALR base from MEM
        check_mem(32'h60, 32'h00000070);   // load (+1 nop) -> ALU
        check_mem(32'h64, 32'h00000003);   // load (+1 nop) -> store data
        check_mem(32'h68, 32'h00000003);   // load (+1 nop) -> load address
        check_mem(32'h70, 32'h00000040);   // store address from MEM

        // In the self-loop the fetch stage keeps fetching done, done+4,
        // done+8 and done+12 (the 3 nops) until the jal reaches MEM and
        // sends the PC back to done, so the PC must stay in that window.
        if (current_pc < DONE_PC || current_pc > DONE_PC + 12) begin
            $display("ERROR: PC = 0x%08h, expected to stay in the done loop (0x%08h..0x%08h)",
                     current_pc, DONE_PC, DONE_PC + 12);
            errors++;
        end

        // every forwarding path must have been used at least once
        $display("Forwarding used (cycles): A from MEM = %0d, A from WB = %0d, B from MEM = %0d, B from WB = %0d",
                 fwd_a_mem, fwd_a_wb, fwd_b_mem, fwd_b_wb);
        if (fwd_a_mem == 0 || fwd_a_wb == 0 || fwd_b_mem == 0 || fwd_b_wb == 0) begin
            $display("ERROR: a forwarding path was never used");
            errors++;
        end

        // flushing is off: the pipeline must never be cleared
        if (flushes != 0) begin
            $display("ERROR: the pipeline was flushed %0d times with FLUSH_EN = 0", flushes);
            errors++;
        end

        if (errors == 0)
            $display("PASS forwarding_test_tb (program finished after %0d cycles)", cycles);
        else
            $fatal(1, "FAIL forwarding_test_tb: %0d error(s)", errors);
        $finish;
    end
endmodule
