# Forwarding test program.
#
# Runs on the processor with forwarding but without flushing (FLUSH_EN = 0),
# see tb/forwarding_test_tb.sv. Data hazards need no nops; what is still
# done in software:
#   Load-use hazard: the instruction right after a load must not read the
#                    loaded register, so 1 nop is placed there.
#   Control hazard : branches and jumps are resolved in the MEM stage, so
#                    3 nops follow every branch and jump.
#
# Section B exercises every forwarding path (EX hazard, MEM hazard, both
# operands, double hazard, store data, store address, branch operands, JALR
# base, LUI/AUIPC results, x0, loads followed by one nop) and stores each
# result in data memory at 0x40..0x70. The other sections cover the RV32I
# instructions (ALU, loads/stores, branches, jumps).
#
# On success x24 = 0 and the processor ends in the self-loop at "done".
# Any wrong-path instruction that executes writes a non-zero value to x24.

# ---------------- A. back-to-back dependency ----------------
        addi  x2, x0, 7          # x2 = 7
        addi  x3, x0, 8          # x3 = 8
        addi  x5, x0, 3          # x5 = 3
        add   x1, x2, x3         # x1 = 15  x3 from MEM, x2 from WB
        sub   x4, x1, x5         # x4 = 12  x1 from MEM (no nops needed now)

# ---------------- B. forwarding cases (results stored at 0x40..0x70) ----------------
        addi  x8, x0, 0x40       # x8 = base address of the results
        addi  x9, x0, 5          # x9 = 5
        addi  x10, x9, 1         # x10 = 6   rs1 from MEM (EX hazard)
        add   x11, x9, x10       # x11 = 11  rs1 from WB (MEM hazard), rs2 from MEM
        sub   x12, x11, x9       # x12 = 6   rs1 from MEM, x9 from the register file
        add   x12, x12, x12      # x12 = 12  both operands from MEM
        sw    x12, 0(x8)         # [0x40] = 12  store data from MEM
        addi  x9, x0, 1          # x9 = 1
        addi  x9, x9, 1          # x9 = 2
        addi  x9, x9, 1          # x9 = 3    double hazard: MEM (2) and WB (1) both
                                 #           write x9, the newer value (MEM) wins
        sw    x9, 4(x8)          # [0x44] = 3
        addi  x13, x8, 8         # x13 = 0x48
        sw    x11, 0(x13)        # [0x48] = 11  store address from MEM
        lui   x14, 0xabcde       # x14 = 0xabcde000
        addi  x14, x14, 0x123    # x14 = 0xabcde123  LUI result from MEM
        sw    x14, 12(x8)        # [0x4c] = 0xabcde123
        auipc x15, 0             # x15 = address of this instruction (0x54)
        addi  x16, x0, 3         # x16 = 3
        sub   x15, x15, x16      # x15 = 0x51  AUIPC result from WB, x16 from MEM
        sw    x15, 16(x8)        # [0x50] = 0x51
        addi  x0, x0, 7          # writes x0, must be ignored
        add   x16, x0, x0        # x16 = 0   x0 is never forwarded
        sw    x16, 20(x8)        # [0x54] = 0
        addi  x9, x0, 9          # x9 = 9
        addi  x10, x0, 10        # x10 = 10
        addi  x11, x0, 11        # x11 = 11
        add   x12, x9, x10       # x12 = 19  x9 3 back (register file write-through), x10 from WB
        sw    x12, 24(x8)        # [0x58] = 19

        # branch operands from the forwarding paths
        addi  x9, x0, -3         # x9 = -3
        addi  x10, x0, 4         # x10 = 4
        bge   x9, x10, fail      # not taken: x9 from WB, x10 from MEM
        nop
        nop
        nop
        addi  x9, x9, 7          # x9 = 4
        bne   x9, x10, fail      # not taken: x9 from MEM
        nop
        nop
        nop
        addi  x10, x10, 1        # x10 = 5
        blt   x9, x10, fb1       # taken: x10 from MEM
        nop
        nop
        nop
        addi  x24, x0, 5         # skipped

        # JALR base address from the forwarding path
fb1:    auipc x13, 0             # x13 = P (address of this auipc)
        addi  x13, x13, 28       # x13 = P + 28   AUIPC result from MEM
        jalr  x14, 0(x13)        # jump to P + 28, base from MEM; x14 = P + 12
        nop
        nop
        nop
        addi  x24, x0, 6         # P + 24: skipped
        sub   x15, x13, x14      # P + 28: x15 = 16
        sw    x15, 28(x8)        # [0x5c] = 16  store data from MEM

        # loads: one nop after each load whose register is used next
        lw    x9, 0(x8)          # x9 = 12
        nop                      # load-use hazard (software)
        addi  x10, x9, 100       # x10 = 112  load data from WB
        sw    x10, 32(x8)        # [0x60] = 112
        lw    x11, 4(x8)         # x11 = 3
        nop                      # load-use hazard (software)
        sw    x11, 36(x8)        # [0x64] = 3  load data from WB as store data
        lw    x12, 8(x8)         # x12 = 11
        nop                      # load-use hazard (software)
        beq   x12, x0, fail      # not taken: load data from WB into the comparator
        nop
        nop
        nop
        addi  x9, x8, 0x30       # x9 = 0x70
        sw    x8, 0(x9)          # [0x70] = 0x40  store address from MEM
        lw    x10, 0(x9)         # x10 = 0x40     load address from WB
        nop                      # load-use hazard (software)
        lw    x11, 4(x10)        # x11 = [0x44] = 3  address = loaded value (from WB)
        nop                      # load-use hazard (software)
        sw    x11, 40(x8)        # [0x68] = 3

# ---------------- C. ALU operations (R-type, I-type, U-type) ----------------
        addi  x6, x0, -16        # x6 = 0xfffffff0
        addi  x7, x0, 2          # x7 = 2
        sll   x8,  x6, x7        # x8  = 0xffffffc0  x6 from WB, x7 from MEM
        srl   x9,  x6, x7        # x9  = 0x3ffffffc  x7 from WB
        sra   x10, x6, x7        # x10 = 0xfffffffc
        slt   x11, x6, x7        # x11 = 1
        sltu  x12, x6, x7        # x12 = 0
        xor   x13, x6, x7        # x13 = 0xfffffff2
        or    x14, x6, x7        # x14 = 0xfffffff2
        and   x15, x6, x7        # x15 = 0
        andi  x16, x6, 0xff      # x16 = 0xf0
        lui   x17, 0x12345       # x17 = 0x12345000
        auipc x18, 0             # x18 = address of this instruction (0x16c)
        ori   x17, x17, 0x678    # x17 = 0x12345678  LUI result from WB
        srai  x19, x6, 1         # x19 = 0xfffffff8
        slli  x20, x7, 4         # x20 = 0x20

# ---------------- D. stores and loads ----------------
        sw    x17, 0(x0)         # mem[0x0] = 0x12345678
        sb    x7,  4(x0)         # byte 0x4 = 0x02
        sh    x6,  6(x0)         # half 0x6 = 0xfff0 -> word 0x4 = 0xfff00002
        sw    x20, 8(x0)         # mem[0x8] = 0x20   x20 from WB
        lw    x21, 0(x0)         # x21 = 0x12345678
        lb    x22, 3(x0)         # x22 = 0x12
        lbu   x23, 6(x0)         # x23 = 0xf0
        lh    x25, 6(x0)         # x25 = 0xfffffff0
        lhu   x26, 6(x0)         # x26 = 0x0000fff0
        lw    x27, 4(x0)         # x27 = 0xfff00002

# ---------------- E. branches (taken and not taken) ----------------
        beq   x21, x17, b1       # taken
        nop
        nop
        nop
        addi  x24, x0, 1         # skipped
b1:     bne   x2, x3, b2         # taken
        nop
        nop
        nop
        addi  x24, x0, 2         # skipped
b2:     blt   x6, x7, b3         # taken (-16 < 2)
        nop
        nop
        nop
        addi  x24, x0, 3         # skipped
b3:     bge   x6, x7, fail       # not taken
        nop
        nop
        nop
        bltu  x7, x6, b4         # taken (2 < 0xfffffff0)
        nop
        nop
        nop
        addi  x24, x0, 4         # skipped
b4:     bgeu  x7, x6, fail       # not taken
        nop
        nop
        nop
        beq   x2, x3, fail       # not taken
        nop
        nop
        nop

# ---------------- F. backward branch loop: x29 = 1+2+3+4 ----------------
        addi  x28, x0, 0         # i = 0
        addi  x29, x0, 0         # sum = 0
        addi  x30, x0, 4         # n = 4
loop:   addi  x28, x28, 1        # i = i + 1
        add   x29, x29, x28      # sum = sum + i     x28 from MEM
        bne   x28, x30, loop     # repeat while i != n   x28 from WB
        nop
        nop
        nop

# ---------------- G. jal / jalr ----------------
        jal   x1, func           # x1 = return address
        nop
        nop
        nop
        sw    x29, 12(x0)        # mem[0xc] = 10 (after returning)
        jal   x0, done
        nop
        nop
        nop

func:   addi  x31, x0, 0x55      # x31 = 0x55
        jalr  x0, 0(x1)          # return
        nop
        nop
        nop

fail:   addi  x24, x0, -1        # x24 = 0xffffffff marks a failure
        jal   x0, fail
        nop
        nop
        nop

done:   jal   x0, done           # self-loop, end of program
        nop
        nop
        nop
