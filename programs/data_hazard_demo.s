# Data hazard demo (no nops).
#
# Without forwarding (FORWARDING_EN = 0) two instructions read a stale
# register value:
#   add a0, t3, t1 : reads t3, written by li 2 instructions earlier
#   sra a1, t3, a0 : reads a0, written by the instruction right before it
# sub x6, x5, x7 reads t0 three instructions after it is written, which the
# write-through register file covers.
# See data_hazard_demo_nops.s for the software fix and
# tb/data_hazard_demo_tb.sv for the simulation.

# ---- initial register values ----
        addi  x6, x0, 4          # t1 = 4
        addi  x7, x0, 1          # t2 = 1
        addi  x5, x0, 100        # t0 = 100 (old value, overwritten below)
        nop
        nop
        nop

# ---- sequence ----
        li    t3, 0xFF           # t3 = 0xff
        add   t0, t1, t2         # t0 = 4 + 1 = 5
        add   a0, t3, t1         # a0 = 0xff + 4 = 0x103      (needs t3)
        sra   a1, t3, a0         # a1 = 0xff >> 3 = 0x1f      (needs a0)
        sub   x6, x5, x7         # x6 = 5 - 1 = 4             (needs t0 = x5)

done:   jal   x0, done
        nop
        nop
        nop
