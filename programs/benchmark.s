# Benchmark for the full processor (forwarding and flushing): the same
# program as benchmark_nops.s with every nop removed. No loaded register is
# used right after its load, so no load-use nop is needed.
# tb/benchmark_tb.sv runs both versions and compares the cycle counts.
#
# On success x24 = 0 and the processor ends in the self-loop at "done".
# Any wrong-path instruction that executes writes a non-zero value to x24.

# ---------------- A. back-to-back dependency ----------------
        addi  x2, x0, 7          # x2 = 7
        addi  x3, x0, 8          # x3 = 8
        addi  x5, x0, 3          # x5 = 3
        add   x1, x2, x3         # x1 = 15
        sub   x4, x1, x5         # x4 = 12

# ---------------- B. ALU operations (R-type, I-type, U-type) ----------------
        addi  x6, x0, -16        # x6 = 0xfffffff0
        addi  x7, x0, 2          # x7 = 2
        sll   x8,  x6, x7        # x8  = 0xffffffc0
        srl   x9,  x6, x7        # x9  = 0x3ffffffc
        sra   x10, x6, x7        # x10 = 0xfffffffc
        slt   x11, x6, x7        # x11 = 1
        sltu  x12, x6, x7        # x12 = 0
        xor   x13, x6, x7        # x13 = 0xfffffff2
        or    x14, x6, x7        # x14 = 0xfffffff2
        and   x15, x6, x7        # x15 = 0
        andi  x16, x6, 0xff      # x16 = 0xf0
        lui   x17, 0x12345       # x17 = 0x12345000
        auipc x18, 0             # x18 = address of this instruction
        ori   x17, x17, 0x678    # x17 = 0x12345678
        srai  x19, x6, 1         # x19 = 0xfffffff8
        slli  x20, x7, 4         # x20 = 0x20

# ---------------- C. stores and loads ----------------
        sw    x17, 0(x0)         # mem[0x0] = 0x12345678
        sb    x7,  4(x0)         # byte 0x4 = 0x02
        sh    x6,  6(x0)         # half 0x6 = 0xfff0 -> word 0x4 = 0xfff00002
        sw    x20, 8(x0)         # mem[0x8] = 0x20
        lw    x21, 0(x0)         # x21 = 0x12345678
        lb    x22, 3(x0)         # x22 = 0x12
        lbu   x23, 6(x0)         # x23 = 0xf0
        lh    x25, 6(x0)         # x25 = 0xfffffff0
        lhu   x26, 6(x0)         # x26 = 0x0000fff0
        lw    x27, 4(x0)         # x27 = 0xfff00002

# ---------------- D. branches (taken and not taken) ----------------
        beq   x21, x17, b1       # taken
        addi  x24, x0, 1         # skipped
b1:     bne   x2, x3, b2         # taken
        addi  x24, x0, 2         # skipped
b2:     blt   x6, x7, b3         # taken (-16 < 2)
        addi  x24, x0, 3         # skipped
b3:     bge   x6, x7, fail       # not taken
        bltu  x7, x6, b4         # taken (2 < 0xfffffff0)
        addi  x24, x0, 4         # skipped
b4:     bgeu  x7, x6, fail       # not taken
        beq   x2, x3, fail       # not taken

# ---------------- E. backward branch loop: x29 = 1+2+3+4 ----------------
        addi  x28, x0, 0         # i = 0
        addi  x29, x0, 0         # sum = 0
        addi  x30, x0, 4         # n = 4
loop:   addi  x28, x28, 1        # i = i + 1
        add   x29, x29, x28      # sum = sum + i
        bne   x28, x30, loop     # repeat while i != n

# ---------------- F. jal / jalr ----------------
        jal   x1, func           # x1 = return address
        sw    x29, 12(x0)        # mem[0xc] = 10 (after returning)
        jal   x0, done

func:   addi  x31, x0, 0x55      # x31 = 0x55
        jalr  x0, 0(x1)          # return (x1 written long before)

fail:   addi  x24, x0, -1        # x24 = 0xffffffff marks a failure
        jal   x0, fail

done:   jal   x0, done           # self-loop, end of program
