// Hazard controller (control path).
//
// Control hazards: branches and jumps are resolved in the MEM stage
// (pc_sel_mem). By the time a taken branch or a jump reaches MEM, the three
// instructions behind it have already been fetched:
//
//     EXE : instruction 1 after the branch -> flushed by exe_mem_reg
//     ID  : instruction 2 after the branch -> flushed by id_exe_reg
//     IF  : instruction 3 after the branch -> flushed by if_id_reg
//
// When pc_sel_mem = 1 the controller clears those three pipeline registers
// on the same clock edge on which the PC loads the target address, so the
// wrong-path instructions turn into bubbles before they can write a register
// or the data memory. The branch itself moves on to WB normally (a JAL /
// JALR still writes its link register), so mem_wb_reg is never flushed.
// A branch that is not taken (pc_sel_mem = 0) flushes nothing: the
// instructions behind it are the correct ones.
//
// Data hazards are handled by the forwarding unit; the load-use hazard is
// still handled in software.
module hazard_controller (
    input  logic pc_sel_mem,          // branch taken or jump, in MEM
    output logic flush_if_id_reg,
    output logic flush_id_exe_reg,
    output logic flush_exe_mem_reg
);
    assign flush_if_id_reg   = pc_sel_mem;
    assign flush_id_exe_reg  = pc_sel_mem;
    assign flush_exe_mem_reg = pc_sel_mem;
endmodule
