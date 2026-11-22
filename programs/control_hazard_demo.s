# Control hazard demo (no nops).
#
# Branches and jumps are resolved in the MEM stage, so the 3 instructions
# after a branch are always fetched before the branch decision is known.
#
#   beq x1, x2, branch1 : 10 != 20, NOT taken. The 3 instructions behind it
#                         (add, sub, bne) are the correct next instructions,
#                         so nothing goes wrong here.
#   bne x6, x0, branch2 : x6 = x7 - x8 = 5, TAKEN. The 3 instructions behind
#                         it are or, xor and the instruction after xor.
#                         or x9, x10, x11 is on the wrong path but still
#                         executes and writes x9. xor is also fetched
#                         in the branch shadow and then fetched again from
#                         branch2, so it executes twice (same result here,
#                         but it would be wrong for e.g. addi x12, x12, 1).
#
# On a processor without control-hazard handling (FLUSH_EN = 0) x9 ends up
# 0x11 instead of 0. See control_hazard_demo_nops.s for the fixed version and
# tb/control_hazard_demo_tb.sv for the simulation.
#
# Data hazards (li x2 -> beq, sub x6 -> bne) are covered by forwarding.

# ---- initial register values ----
        addi  x4, x0, 1          # x4  = 1
        addi  x5, x0, 2          # x5  = 2
        addi  x7, x0, 9          # x7  = 9
        addi  x8, x0, 4          # x8  = 4   (x7 != x8, so bne is taken)
        addi  x10, x0, 0x10      # x10 = 0x10
        addi  x11, x0, 0x01      # x11 = 0x01
        addi  x13, x0, 0xf0      # x13 = 0xf0
        addi  x14, x0, 0x0f      # x14 = 0x0f

# ---- sequence ----
        li    x1, 10             # x1 = 10
        li    x2, 20             # x2 = 20
        beq   x1, x2, branch1    # not taken
        add   x3, x4, x5         # x3 = 3
branch1: sub  x6, x7, x8         # x6 = 5
        bne   x6, x0, branch2    # taken
        or    x9, x10, x11       # skipped: x9 must stay 0
branch2: xor  x12, x13, x14      # x12 = 0xff

done:   jal   x0, done
        nop
        nop
        nop
