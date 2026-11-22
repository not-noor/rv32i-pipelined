# Main test program (assembled into machine.hex, run by tb/rv32i_top_tb.sv).
#
# Runs on the full processor: forwarding and flushing. The only hazard left
# to software is the load-use hazard: the instruction right after a load
# must not read the loaded register, so 1 nop is placed there. There are no
# nops after branches or jumps.
#
# The instructions right behind every taken branch / jump are real
# instructions on the wrong path (mostly "addi x24, ..." markers, but also
# stores, branches and jumps). They must all be flushed.
#
# Section B exercises every forwarding path, section C the control hazard
# cases (taken and not taken branches, a taken branch to the next
# instruction, a branch or jump in the shadow of a taken branch, branches on
# forwarded and loaded values, chains of jumps, a loop). Results are stored
# at 0x40..0x70 and 0x80..0x88. Sections D to H cover the RV32I instructions.
#
# On success x24 = 0 and the processor ends in the self-loop at "done".
# Any wrong-path instruction that executes writes a non-zero value to x24,
# or jumps to "fail" (which writes x24 = 0xffffffff).

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
        addi  x9, x9, 7          # x9 = 4
        bne   x9, x10, fail      # not taken: x9 from MEM
        addi  x10, x10, 1        # x10 = 5
        blt   x9, x10, fb1       # taken: x10 from MEM
        addi  x24, x0, 5         # skipped (flushed)

        # JALR base address from the forwarding path
fb1:    auipc x13, 0             # x13 = P (address of this auipc)
        addi  x13, x13, 16       # x13 = P + 16   AUIPC result from MEM
        jalr  x14, 0(x13)        # jump to P + 16, base from MEM; x14 = P + 12
        addi  x24, x0, 6         # P + 12: skipped
        sub   x15, x13, x14      # P + 16: x15 = 4
        sw    x15, 28(x8)        # [0x5c] = 4  store data from MEM

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
        addi  x9, x8, 0x30       # x9 = 0x70
        sw    x8, 0(x9)          # [0x70] = 0x40  store address from MEM
        lw    x10, 0(x9)         # x10 = 0x40     load address from WB
        nop                      # load-use hazard (software)
        lw    x11, 4(x10)        # x11 = [0x44] = 3  address = loaded value (from WB)
        nop                      # load-use hazard (software)
        sw    x11, 40(x8)        # [0x68] = 3

# ---------------- C. control hazard cases (results stored at 0x80..0x88) ----------------
        addi  x8, x0, 0x80       # x8 = base address of the results
        addi  x9, x0, 0          # x9 counts the instructions that must run

        # taken branch: the 3 instructions behind it are flushed, even a
        # store and a jump
        beq   x0, x0, c1         # taken
        addi  x24, x0, 0x11      # flushed (in EXE when beq is in MEM)
        sw    x8, 0(x8)          # flushed (in ID)
        jal   x0, fail           # flushed (in IF)
c1:     addi  x9, x9, 1          # x9 = 1

        # branch not taken: the instructions behind it are correct and must
        # not be flushed
        bne   x0, x0, fail       # not taken
        addi  x9, x9, 1          # x9 = 2  must run
        addi  x9, x9, 1          # x9 = 3  must run
        addi  x9, x9, 1          # x9 = 4  must run

        # taken branch to the next instruction: that instruction is flushed
        # once and fetched again, so it runs exactly once
        beq   x9, x9, c2         # taken
c2:     addi  x9, x9, 1          # x9 = 5  (once, not twice)

        # a branch and a jump in the shadow of a taken jump must not change
        # the PC
        jal   x0, c3             # taken
        beq   x0, x0, fail       # flushed (would be taken)
        jal   x0, fail           # flushed
        addi  x24, x0, 0x13      # flushed
c3:     addi  x9, x9, 1          # x9 = 6

        # taken branch on forwarded operands
        addi  x10, x0, 7         # x10 = 7
        addi  x11, x0, 7         # x11 = 7
        beq   x10, x11, c4       # taken: x10 from WB, x11 from MEM
        addi  x24, x0, 0x14      # flushed
        addi  x24, x0, 0x15      # flushed
        addi  x24, x0, 0x16      # flushed
c4:     addi  x9, x9, 1          # x9 = 7

        # branches on a loaded value (1 nop for the load-use hazard)
        sw    x10, 4(x8)         # [0x84] = 7
        lw    x12, 4(x8)         # x12 = 7
        nop                      # load-use hazard (software)
        bne   x12, x10, fail     # not taken: load data from WB
        beq   x12, x10, c5       # taken
        sw    x0, 4(x8)          # flushed: [0x84] stays 7
        addi  x24, x0, 0x17      # flushed
        addi  x24, x0, 0x18      # flushed
c5:     addi  x9, x9, 1          # x9 = 8

        # chain of jumps: c5 -> c6 -> c7 -> c8. Each jal still writes its
        # link register although the instructions behind it are flushed.
        jal   x13, c6            # x13 = address of the next instruction
        addi  x24, x0, 0x19      # flushed
c7:     jal   x0, c8             # flushed the first time, reached from c6
        addi  x24, x0, 0x1a      # flushed
        addi  x24, x0, 0x1b      # flushed
c6:     jal   x14, c7            # x14 = c6 + 4
        addi  x24, x0, 0x1c      # flushed
        addi  x24, x0, 0x1d      # flushed
        addi  x24, x0, 0x1e      # flushed
c8:     sub   x15, x14, x13      # x15 = (c6 + 4) - (c5 + 8) = 20
        sw    x15, 8(x8)         # [0x88] = 20

        # backward loop without nops: the branch is taken 4 times
        addi  x10, x0, 5         # x10 = 5
c9:     addi  x9, x9, 1          # runs 5 times: x9 = 13
        addi  x10, x10, -1       # x10 = x10 - 1
        bne   x10, x0, c9        # taken while x10 != 0
        sw    x9, 0(x8)          # [0x80] = 13  (flushed 4 times, runs once)

# ---------------- D. ALU operations (R-type, I-type, U-type) ----------------
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

# ---------------- E. stores and loads ----------------
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

# ---------------- F. branches (taken and not taken) ----------------
        beq   x21, x17, b1       # taken
        addi  x24, x0, 1         # skipped (flushed)
b1:     bne   x2, x3, b2         # taken
        addi  x24, x0, 2         # skipped (flushed)
b2:     blt   x6, x7, b3         # taken (-16 < 2)
        addi  x24, x0, 3         # skipped (flushed)
b3:     bge   x6, x7, fail       # not taken
        bltu  x7, x6, b4         # taken (2 < 0xfffffff0)
        addi  x24, x0, 4         # skipped (flushed)
b4:     bgeu  x7, x6, fail       # not taken
        beq   x2, x3, fail       # not taken

# ---------------- G. backward branch loop: x29 = 1+2+3+4 ----------------
        addi  x28, x0, 0         # i = 0
        addi  x29, x0, 0         # sum = 0
        addi  x30, x0, 4         # n = 4
loop:   addi  x28, x28, 1        # i = i + 1
        add   x29, x29, x28      # sum = sum + i     x28 from MEM
        bne   x28, x30, loop     # repeat while i != n   x28 from WB

# ---------------- H. jal / jalr ----------------
        jal   x1, func           # x1 = return address
        sw    x29, 12(x0)        # mem[0xc] = 10 (after returning)
        jal   x0, done

func:   addi  x31, x0, 0x55      # x31 = 0x55
        jalr  x0, 0(x1)          # return

fail:   addi  x24, x0, -1        # x24 = 0xffffffff marks a failure
        jal   x0, fail

done:   jal   x0, done           # self-loop, end of program
