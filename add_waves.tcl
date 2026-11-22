# Adds the main pipeline signals to the waveform, grouped by stage.
# Run it in the Tcl console after the behavioral simulation has opened:
#   source /path/to/rv32i-pipelined/add_waves.tcl
# Works for any testbench that names the processor "dut" (rv32i_top_tb,
# forwarding_test_tb).

# Find the testbench of the simulation that is actually running (not the
# project's top setting, which only changes after a relaunch).
set top ""
foreach s [get_scopes /*] {
    if {![catch {get_scopes $s/dut/dp} r] && [llength $r] > 0} {
        set top $s
        break
    }
}
if {$top eq ""} {
    error "No /<testbench>/dut/dp found in the running simulation. This script works for rv32i_top_tb and forwarding_test_tb. If you just changed the top, close the simulation and run Run Behavioral Simulation again first."
}
puts "Adding waves for $top"
set dp $top/dut/dp

add_wave_divider "IF"
add_wave -radix hex $dp/current_pc_if $dp/inst_if $dp/next_pc_if

add_wave_divider "ID"
add_wave -radix hex $dp/current_pc_id $dp/inst_id $dp/rs1_data_id $dp/rs2_data_id $dp/imm_id
add_wave -radix unsigned $dp/rd_addr_id
add_wave $dp/reg_write_id $dp/mem_write_id $dp/branch_id $dp/jump_id

add_wave_divider "EXE"
add_wave -radix hex $dp/current_pc_exe $dp/rs1_data_exe $dp/rs2_data_exe
add_wave -radix unsigned $dp/rs1_addr_exe $dp/rs2_addr_exe
add_wave -radix bin $dp/forward_a_exe $dp/forward_b_exe
add_wave -radix hex $dp/rs1_fwd_data_exe $dp/rs2_fwd_data_exe $dp/alu_op2_exe $dp/alu_result_exe $dp/target_pc_exe
add_wave -radix unsigned $dp/rd_addr_exe
add_wave $dp/branch_cond_exe

add_wave_divider "MEM"
add_wave -radix hex $dp/alu_result_mem $dp/fwd_result_mem $dp/rs2_data_mem $dp/mem_rdata_mem $dp/target_pc_mem
add_wave -radix unsigned $dp/rd_addr_mem
add_wave $dp/mem_write_mem $dp/pc_sel_mem

add_wave_divider "Hazard controller (flush)"
add_wave $dp/flush_if_id_reg $dp/flush_id_exe_reg $dp/flush_exe_mem_reg

add_wave_divider "WB"
add_wave $dp/reg_write_wb
add_wave -radix unsigned $dp/rd_addr_wb
add_wave -radix hex $dp/writeback_data_wb

restart
run all
