# Creates the Vivado project for the 5-stage pipelined RV32I processor.
#
# Usage (Vivado Tcl console, or Tools > Run Tcl Script...):
#   source /path/to/rv32i-pipelined/create_project.tcl
#
# The project is created in rv32i-pipelined/vivado/ and uses the source
# files in rtl/ and tb/ in place (they are not copied), so edits you make in
# Vivado are saved straight into rtl/ and tb/.

set root      [file normalize [file dirname [info script]]]
set proj_name rv32i-pipelined
set proj_dir  [file join $root vivado]
set part      xc7k70tfbv676-1

create_project -force $proj_name $proj_dir -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# design sources
add_files -norecurse -fileset sources_1 [lsort [glob [file join $root rtl *.sv]]]
set_property top rv32i_top [get_filesets sources_1]

# simulation sources
add_files -norecurse -fileset sim_1 [lsort [glob [file join $root tb *.sv]]]
set_property top rv32i_top_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# the main program needs about 2.4 us; log every signal so any internal
# signal can be added to the waveform without re-running
set_property -name {xsim.simulate.runtime}         -value {3000ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true}   -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# inst_mem reads its program (machine.hex, or programs/*.hex for the
# demo and benchmark testbenches) from the simulator's run directory
set xsim_dir [file join $proj_dir $proj_name.sim sim_1 behav xsim]
file mkdir $xsim_dir
file copy -force [file join $root machine.hex] $xsim_dir
foreach hex [glob [file join $root programs *.hex]] {
    file copy -force $hex $xsim_dir
}

puts ""
puts "Project created: [file join $proj_dir $proj_name.xpr]"
puts "machine.hex and programs/*.hex copied to: $xsim_dir"
puts "Next: Flow Navigator > Run Simulation > Run Behavioral Simulation"
