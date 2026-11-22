# Control hazard demo, resolved in software with nops.
#
# Branches are resolved in the MEM stage, so 3 instructions after every
# branch are fetched before the decision is known. Three nops after each
# branch make those 3 instructions harmless whichever way it goes:
#   beq x1, x2, branch1 : 3 nops (not taken here, but it could be)
#   bne x6, x0, branch2 : 3 nops (taken: or x9 is no longer executed and
#                         xor runs only once)
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

# ---- sequence, with nops ----
        li    x1, 10             # x1 = 10
        li    x2, 20             # x2 = 20
        beq   x1, x2, branch1    # not taken
        nop                      # stall: beq in ID
        nop                      # stall: beq in EXE
        nop                      # stall: beq in MEM, decision made
        add   x3, x4, x5         # x3 = 3
branch1: sub  x6, x7, x8         # x6 = 5
        bne   x6, x0, branch2    # taken
        nop
        nop
        nop
        or    x9, x10, x11       # skipped: x9 stays 0
branch2: xor  x12, x13, x14      # x12 = 0xff

done:   jal   x0, done
        nop
        nop
        nop
