#!/usr/bin/env python3
"""Assemble an RV32I program into machine.hex format (one word per line,
with the address and disassembly as a // comment).

Usage: asm2hex.py program.s output.hex

Needs the RISC-V GNU binutils (riscv64-unknown-elf-as / objdump).
"""
import re
import subprocess
import sys
import tempfile
import os

PREFIX = "riscv64-unknown-elf-"


def main():
    src, out = sys.argv[1], sys.argv[2]
    with tempfile.TemporaryDirectory() as tmp:
        obj = os.path.join(tmp, "prog.o")
        subprocess.run([PREFIX + "as", "-march=rv32i", "-mabi=ilp32",
                        "-mno-relax", "-o", obj, src], check=True)
        dis = subprocess.run([PREFIX + "objdump", "-d", "-M", "numeric",
                              obj], check=True, capture_output=True,
                             text=True).stdout
    lines = []
    pat = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+(.*)$")
    for line in dis.splitlines():
        m = pat.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        word = m.group(2)
        asm = re.sub(r"\s+<[^>]*>", "", m.group(3)).strip()
        asm = re.sub(r"\s+", " ", asm)
        op, _, args = asm.partition(" ")
        if args:
            args = re.sub(r",(?=\S)", ", ", args)
            asm = f"{op:<5} {args}"
        if addr != 4 * len(lines):
            sys.exit(f"gap in program at 0x{addr:x}")
        lines.append(f"{word}  // 0x{addr:03x}: {asm}")
    # Use the source text for the comments when every source line is one
    # instruction (true unless a pseudo-instruction expands to two).
    src_lines = []
    for raw in open(src):
        code = raw.split("#", 1)[0].strip()
        code = re.sub(r"^[A-Za-z_.][\w.]*:\s*", "", code)
        if code and not code.startswith("."):
            op, _, args = code.partition(" ")
            src_lines.append(f"{op:<5} {args.strip()}" if args else op)
    if len(src_lines) == len(lines):
        lines = [l.split("//")[0] + f"// 0x{4*i:03x}: {a}"
                 for i, (l, a) in enumerate(zip(lines, src_lines))]
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{out}: {len(lines)} instructions")


if __name__ == "__main__":
    main()
