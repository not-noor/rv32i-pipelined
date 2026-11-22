# Data hazard demo, resolved in software with nops.
#
# Without forwarding, an instruction may read a register only if it is at
# least 3 instructions after the instruction that writes it (write-through
# register file: the producer's WB and the consumer's ID share a cycle).
#
#   li  t3      -> add a0 reads t3 at distance 2  : 1 nop added
#   add a0      -> sra a1 reads a0 at distance 1  : 2 nops added
#   add t0      -> sub x6 reads t0 at distance 6  : no hazard
#   li  t3      -> sra a1 reads t3 at distance 5  : no hazard

# ---- initial register values ----
        addi  x6, x0, 4          # t1 = 4
        addi  x7, x0, 1          # t2 = 1
        addi  x5, x0, 100        # t0 = 100 (old value, overwritten below)
        nop
        nop
        nop

# ---- sequence, with nops ----
        li    t3, 0xFF           # t3 = 0xff
        add   t0, t1, t2         # t0 = 5
        nop                      # stall: li reaches WB when add a0 is in ID
        add   a0, t3, t1         # a0 = 0x103
        nop                      # stall
        nop                      # stall: add a0 in WB when sra is in ID
        sra   a1, t3, a0         # a1 = 0x1f
        sub   x6, x5, x7         # x6 = 4

done:   jal   x0, done
        nop
        nop
        nop
