// Parameterized n-bit register used for the pipeline registers
// (if_id_reg, id_exe_reg, exe_mem_reg and mem_wb_reg).
//
// reset_n : asynchronous, active low. Clears the register at power-up.
// clear   : synchronous, active high. Used to flush the register: on the
//           next rising clock edge the register is loaded with zeros instead
//           of data_in. All control signals are then 0 (no register write,
//           no memory write, no branch / jump), so the instruction that was
//           about to enter this stage becomes a bubble.
module n_bit_reg #(
    parameter int n = 32
) (
    input  logic         clk,
    input  logic         reset_n,
    input  logic         clear,
    input  logic [n-1:0] data_in,
    output logic [n-1:0] data_out
);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            data_out <= '0;
        else if (clear)
            data_out <= '0;
        else
            data_out <= data_in;
    end
endmodule
