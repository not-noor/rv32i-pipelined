#!/bin/sh
# Runs every testbench with Icarus Verilog (iverilog 11 or newer).
# Usage: ./run_tests.sh            (from the project directory)
# The simulations run in build/, where the program .hex files are copied.
set -e
cd "$(dirname "$0")"
mkdir -p build
cp machine.hex programs/*.hex build/
SRC=$(sed 's#^#../#' rtl/files.f)
cd build
fail=0
for tb in ../tb/*_tb.sv; do
    name=$(basename "$tb" .sv)
    if iverilog -g2012 -s "$name" -o "$name.vvp" $SRC "$tb" 2>"$name.compile.log" &&
       vvp -n "$name.vvp" > "$name.log" 2>&1 &&
       grep -q "^PASS" "$name.log"; then
        echo "PASS  $name"
    else
        echo "FAIL  $name   (see build/$name.log)"
        fail=1
    fi
done
exit $fail
