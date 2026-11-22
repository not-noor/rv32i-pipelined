`timescale 1ns/1ps
// Unit test for hazard_controller: a taken branch / jump in MEM flushes the
// three pipeline registers behind it, otherwise nothing is flushed.
module hazard_controller_tb;
    logic pc_sel_mem;
    logic flush_if_id_reg, flush_id_exe_reg, flush_exe_mem_reg;

    hazard_controller dut (.*);

    initial begin
        pc_sel_mem = 1'b0; #1;
        if (flush_if_id_reg || flush_id_exe_reg || flush_exe_mem_reg)
            $fatal(1, "flush without a taken branch / jump");

        pc_sel_mem = 1'b1; #1;
        if (!flush_if_id_reg || !flush_id_exe_reg || !flush_exe_mem_reg)
            $fatal(1, "taken branch / jump must flush if_id, id_exe and exe_mem");

        $display("PASS hazard_controller_tb");
        $finish;
    end
endmodule
