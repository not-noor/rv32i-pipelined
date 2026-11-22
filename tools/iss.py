#!/usr/bin/env python3
"""Tiny RV32I instruction-set simulator (no pipeline) used as a reference
model: runs a machine.hex program until it reaches a 'jal x0, 0' self-loop
and prints the final registers and the non-zero data memory words.

Usage: iss.py program.hex [max_steps]
"""
import sys

M = 0xffffffff


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def load_hex(path):
    words = []
    for line in open(path):
        line = line.split("//")[0].strip()
        if line:
            words.append(int(line, 16))
    return words


def run(words, max_steps=100000):
    x = [0] * 32
    mem = {}
    pc = 0
    executed = []

    def rd_byte(a):
        return (mem.get(a >> 2, 0) >> (8 * (a & 3))) & 0xff

    def wr_byte(a, b):
        w = mem.get(a >> 2, 0)
        sh = 8 * (a & 3)
        mem[a >> 2] = (w & ~(0xff << sh) & M) | ((b & 0xff) << sh)

    for _ in range(max_steps):
        inst = words[pc >> 2] if (pc >> 2) < len(words) else 0x13
        if inst == 0x0000006f:          # jal x0, 0 : done
            return x, mem, pc, executed
        executed.append(pc)
        op = inst & 0x7f
        rd = (inst >> 7) & 31
        f3 = (inst >> 12) & 7
        rs1 = (inst >> 15) & 31
        rs2 = (inst >> 20) & 31
        f7 = inst >> 25
        a, b = x[rs1], x[rs2]
        imm_i = sx(inst >> 20, 12)
        imm_s = sx(((inst >> 25) << 5) | ((inst >> 7) & 31), 12)
        imm_b = sx((((inst >> 31) & 1) << 12) | (((inst >> 7) & 1) << 11) |
                   (((inst >> 25) & 0x3f) << 5) | (((inst >> 8) & 0xf) << 1), 13)
        imm_u = inst & 0xfffff000
        imm_j = sx((((inst >> 31) & 1) << 20) | (((inst >> 12) & 0xff) << 12) |
                   (((inst >> 20) & 1) << 11) | (((inst >> 21) & 0x3ff) << 1), 21)
        npc = (pc + 4) & M
        res = None

        def alu(a, b, f3, alt):
            sh = b & 31
            if f3 == 0:
                return (a - b) & M if alt else (a + b) & M
            if f3 == 1:
                return (a << sh) & M
            if f3 == 2:
                return int(sx(a, 32) < sx(b, 32))
            if f3 == 3:
                return int(a < b)
            if f3 == 4:
                return a ^ b
            if f3 == 5:
                return (sx(a, 32) >> sh) & M if alt else a >> sh
            if f3 == 6:
                return a | b
            return a & b

        if op == 0x33:
            res = alu(a, b, f3, f7 == 0x20)
        elif op == 0x13:
            res = alu(a, imm_i & M, f3, f3 == 5 and f7 == 0x20)
        elif op == 0x37:
            res = imm_u
        elif op == 0x17:
            res = (pc + imm_u) & M
        elif op == 0x6f:
            res = npc
            npc = (pc + imm_j) & M
        elif op == 0x67:
            res = npc
            npc = (a + imm_i) & M & ~1
        elif op == 0x63:
            c = {0: a == b, 1: a != b, 4: sx(a, 32) < sx(b, 32),
                 5: sx(a, 32) >= sx(b, 32), 6: a < b, 7: a >= b}[f3]
            if c:
                npc = (pc + imm_b) & M
        elif op == 0x03:
            ad = (a + imm_i) & M
            if f3 == 0:
                res = sx(rd_byte(ad), 8) & M
            elif f3 == 1:
                res = sx(rd_byte(ad) | rd_byte(ad + 1) << 8, 16) & M
            elif f3 == 2:
                res = mem.get(ad >> 2, 0)
            elif f3 == 4:
                res = rd_byte(ad)
            elif f3 == 5:
                res = rd_byte(ad) | rd_byte(ad + 1) << 8
        elif op == 0x23:
            ad = (a + imm_s) & M
            n = {0: 1, 1: 2, 2: 4}[f3]
            for i in range(n):
                wr_byte(ad + i, b >> (8 * i))
        else:
            raise SystemExit(f"unknown instruction {inst:08x} at {pc:x}")
        if res is not None and rd != 0:
            x[rd] = res & M
        pc = npc
    raise SystemExit("did not reach the done loop")


if __name__ == "__main__":
    words = load_hex(sys.argv[1])
    x, mem, pc, ex = run(words)
    print(f"done at 0x{pc:x}, {len(ex)} instructions executed")
    for i in range(32):
        print(f"x{i} = 0x{x[i]:08x}")
    for k in sorted(mem):
        if mem[k]:
            print(f"mem word {k} = 0x{mem[k]:08x}")
