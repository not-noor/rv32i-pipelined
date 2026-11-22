`timescale 1ns/1ps
// Unit test for n_bit_reg: asynchronous reset, load, and the synchronous
// clear used to flush a pipeline register.
module n_bit_reg_tb;
    logic        clk = 0, reset_n, clear;
    logic [63:0] data_in, data_out;

    always #5 clk = ~clk;

    n_bit_reg #(.n(64)) dut (.*);

    initial begin
        reset_n = 0; clear = 0; data_in = 64'hdead_beef_cafe_f00d;
        @(posedge clk); #1;
        if (data_out !== 64'd0) $fatal(1, "reset failed");

        reset_n = 1;
        @(posedge clk); #1;
        if (data_out !== 64'hdead_beef_cafe_f00d) $fatal(1, "load failed");

        data_in = 64'h1234_5678_9abc_def0; #1;
        if (data_out !== 64'hdead_beef_cafe_f00d) $fatal(1, "output changed before the clock edge");
        @(posedge clk); #1;
        if (data_out !== 64'h1234_5678_9abc_def0) $fatal(1, "second load failed");

        // clear is synchronous: nothing happens until the clock edge
        clear = 1; #1;
        if (data_out !== 64'h1234_5678_9abc_def0) $fatal(1, "clear acted before the clock edge");
        @(posedge clk); #1;
        if (data_out !== 64'd0) $fatal(1, "clear failed");

        // clear has priority over data_in; release it and load again
        clear = 0;
        @(posedge clk); #1;
        if (data_out !== 64'h1234_5678_9abc_def0) $fatal(1, "load after clear failed");

        $display("PASS n_bit_reg_tb");
        $finish;
    end
endmodule
