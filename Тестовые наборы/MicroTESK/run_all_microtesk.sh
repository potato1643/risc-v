#!/bin/bash
# Полный сбор покрытия MicroTESK: I+M+A+C+F+D + algorithms + examples + RV32
# Spike должен быть собран с --coverage
#
# Состав ELF:
#   RV64: I(52) + M(13) + A(19) + C(1) + F(11) + D(12) + Algorithms(7) + Examples(23) = 138
#   RV32: I(37) + M(8) + A(10) + F(8) + D(12) + C(1) = 76
#   Всего: 214 ELF
#
# Примечание: F/D тесты (24 ELF) частично не проходят проверку результата
# (MicroTESK генерирует ожидаемые значения, не совпадающие с IEEE 754),
# но gcov-покрытие собирается корректно. Подробнее: ANALYSIS_FP_CRASH_ROOT_CAUSE.md

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
ELF_BASE="/opt/microtesk-riscv/output"
REPORT_DIR="/tmp/microtesk_full_coverage"
HOST_REPORT_DIR="/Users/xiaoyubai/WorkSpace/2275/risc-v/Тестовые наборы/MicroTESK"

mkdir -p "$REPORT_DIR"

ISA_DEFAULT="rv64imafdc_zicntr_zihpm"

echo "=============================================="
echo " MicroTESK Full Coverage Run"
echo " ISA: $ISA_DEFAULT"
echo " Total ELFs: 214 (RV64: 138 + RV32: 76)"
echo "=============================================="

# Clear old gcda files
echo ""
echo "[1/5] Clearing old .gcda counter files..."
find "$BUILD_DIR" -name "*.gcda" -delete 2>/dev/null
echo "Done."

# Run all ELFs
echo ""
echo "[2/5] Running all ELFs on Spike..."
pass=0
fail=0
total=0
failed_elfs=""

run_elf() {
    local elf="$1"
    local isa="$2"
    local timeout_sec=15
    if timeout $timeout_sec "$SPIKE" --isa="$isa" -l "$elf" > /dev/null 2>&1; then
        echo "  OK:  $elf"
        return 0
    else
        echo "  FAIL: $elf"
        return 1
    fi
}

for elf in $(find "$ELF_BASE" -name "*.elf" -type f 2>/dev/null | sort); do
    total=$((total + 1))
    # Detect ISA from ELF bitness: 32-bit -> rv32gc, 64-bit -> rv64
    if file "$elf" | grep -q "32-bit"; then
        elf_isa="rv32gc"
    else
        elf_isa="rv64imafdc_zicntr_zihpm"
    fi
    if run_elf "$elf" "$elf_isa"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        failed_elfs="$failed_elfs\n  $elf"
    fi
done

echo ""
echo "Total: $total, Pass: $pass, Fail: $fail"
if [ $fail -gt 0 ]; then
    echo "Failed ELFs:"
    echo -e "$failed_elfs"
    echo "  (F/D failures: ожидаемые значения MicroTESK != IEEE 754, покрытие собрано)"
fi

# Collect coverage
echo ""
echo "[3/5] Collecting lcov coverage data..."
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/microtesk_all.info" \
     --ignore-errors gcov,source 2>&1 | tail -5

echo ""
echo "Overall coverage (full denominator):"
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_all.info" 2>&1 | grep -E "lines|functions|branches"

# Apply IMAFDC filter
echo ""
echo "[4/5] Applying IMAFDC filter (excluding V/Crypto/B/Zfh/Hypervisor/Zfa/CBO insns)..."
lcov --rc lcov_branch_coverage=1 --remove "$REPORT_DIR/microtesk_all.info" \
     '/opt/riscv-isa-sim/riscv/insns/v*' \
     '/opt/riscv-isa-sim/riscv/insns/aes*' \
     '/opt/riscv-isa-sim/riscv/insns/sha*' \
     '/opt/riscv-isa-sim/riscv/insns/sm*' \
     '/opt/riscv-isa-sim/riscv/insns/*_b.h' \
     '/opt/riscv-isa-sim/riscv/insns/*_h.h' \
     '/opt/riscv-isa-sim/riscv/insns/*_q.h' \
     '/opt/riscv-isa-sim/riscv/insns/cbo_*' \
     '/opt/riscv-isa-sim/riscv/insns/cm_*' \
     '/opt/riscv-isa-sim/riscv/insns/czero_*' \
     '/opt/riscv-isa-sim/riscv/insns/hlv*' \
     '/opt/riscv-isa-sim/riscv/insns/hsv*' \
     '/opt/riscv-isa-sim/riscv/insns/hfence*' \
     '/opt/riscv-isa-sim/riscv/insns/*bf16*' \
     '/opt/riscv-isa-sim/riscv/insns/*zfa*' \
     '/opt/riscv-isa-sim/riscv/insns/*zv*' \
     '/opt/riscv-isa-sim/riscv/insns/v*' \
     '/opt/riscv-isa-sim/build/v*' \
     --output-file "$REPORT_DIR/microtesk_imafdc.info" \
     --ignore-errors source 2>/dev/null

echo ""
echo "IMAFDC-filtered coverage:"
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_imafdc.info" 2>&1 | grep -E "lines|functions|branches"

# Generate HTML reports
echo ""
echo "[5/5] Generating HTML reports..."
genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/microtesk_all.info" \
        --output-directory "$REPORT_DIR/html_full" \
        --ignore-errors source 2>&1 | tail -3

genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/microtesk_imafdc.info" \
        --output-directory "$REPORT_DIR/html_imafdc" \
        --ignore-errors source 2>&1 | tail -3

# Copy info files to host
echo ""
echo "=== Results ==="
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_all.info" 2>&1
echo ""
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_imafdc.info" 2>&1
echo ""
echo "HTML reports:"
echo "  Full: $REPORT_DIR/html_full/index.html"
echo "  IMAFDC: $REPORT_DIR/html_imafdc/index.html"

# Copy to host-accessible location
cp "$REPORT_DIR/microtesk_all.info" "$HOST_REPORT_DIR/microtesk_all_coverage.info" 2>/dev/null
cp "$REPORT_DIR/microtesk_imafdc.info" "$HOST_REPORT_DIR/microtesk_imafdc_filtered.info" 2>/dev/null
echo ""
echo "Info files copied to: $HOST_REPORT_DIR/"
