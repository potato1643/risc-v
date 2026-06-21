#!/bin/bash
# Полный сбор покрытия MicroTESK: I+M+A+C+F+D + algorithms + examples + RV32
# Симулятор (Spike или Sail) должен быть собран с --coverage
#
# Использование:
#   bash run_all_microtesk.sh [spike|sail]
#   SIMULATOR=sail bash run_all_microtesk.sh
#
# Состав ELF:
#   RV64: I(52) + M(13) + A(19) + C(1) + F(11) + D(12) + Algorithms(7) + Examples(23) = 138
#   RV32: I(37) + M(8) + A(10) + F(8) + D(12) + C(1) = 76
#   Всего: 214 ELF
#
# Примечание: F/D тесты (24 ELF) частично не проходят проверку результата
# (MicroTESK генерирует ожидаемые значения, не совпадающие с IEEE 754),
# но gcov-покрытие собирается корректно. Подробнее: ANALYSIS_FP_CRASH_ROOT_CAUSE.md

# --- Выбор симулятора ---
SIMULATOR="${1:-${SIMULATOR:-spike}}"

case "$SIMULATOR" in
    spike)
        SIM_BIN="/opt/riscv-isa-sim/build/spike"
        BUILD_DIR="/opt/riscv-isa-sim/build"
        SOURCE_FILTER="/opt/riscv-isa-sim/*"
        # IMAFDC filter paths (Spike-specific per-instruction files)
        IMAFDC_EXCLUDE_PATHS=(
            '/opt/riscv-isa-sim/riscv/insns/v*'
            '/opt/riscv-isa-sim/riscv/insns/aes*'
            '/opt/riscv-isa-sim/riscv/insns/sha*'
            '/opt/riscv-isa-sim/riscv/insns/sm*'
            '/opt/riscv-isa-sim/riscv/insns/*_b.h'
            '/opt/riscv-isa-sim/riscv/insns/*_h.h'
            '/opt/riscv-isa-sim/riscv/insns/*_q.h'
            '/opt/riscv-isa-sim/riscv/insns/cbo_*'
            '/opt/riscv-isa-sim/riscv/insns/cm_*'
            '/opt/riscv-isa-sim/riscv/insns/czero_*'
            '/opt/riscv-isa-sim/riscv/insns/hlv*'
            '/opt/riscv-isa-sim/riscv/insns/hsv*'
            '/opt/riscv-isa-sim/riscv/insns/hfence*'
            '/opt/riscv-isa-sim/riscv/insns/*bf16*'
            '/opt/riscv-isa-sim/riscv/insns/*zfa*'
            '/opt/riscv-isa-sim/riscv/insns/*zv*'
            '/opt/riscv-isa-sim/riscv/insns/v*'
            '/opt/riscv-isa-sim/build/v*'
        )
        APPLY_IMAFDC_FILTER=true
        ;;
    sail)
        SIM_BIN="/opt/sail-riscv/build_cov/c_emulator/sail_riscv_sim"
        BUILD_DIR="/opt/sail-riscv/build_cov"
        SAIL_CONFIG_RV64="/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json"
        SAIL_CONFIG_RV32="/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env/sail_config.json"
        SOURCE_FILTER="/opt/sail-riscv/*"
        APPLY_IMAFDC_FILTER=false  # Sail generates monolithic code; per-insn filter not applicable
        ;;
    *)
        echo "ERROR: неизвестный симулятор '$SIMULATOR'. Используйте spike или sail."
        exit 1
        ;;
esac

ELF_BASE="/opt/microtesk-riscv/output"
REPORT_DIR="/tmp/microtesk_full_coverage_${SIMULATOR}"
HOST_REPORT_DIR="/Users/xiaoyubai/WorkSpace/2275/risc-v/Тестовые наборы/MicroTESK"

mkdir -p "$REPORT_DIR"

echo "=============================================="
echo " MicroTESK Full Coverage Run"
echo " Simulator: $SIMULATOR"
echo " Total ELFs: 214 (RV64: 138 + RV32: 76)"
echo "=============================================="

# Clear old gcda files
echo ""
echo "[1/5] Clearing old .gcda counter files..."
find "$BUILD_DIR" -name "*.gcda" -delete 2>/dev/null
echo "Done."

# --- Run functions ---
run_on_spike() {
    local elf="$1"
    local isa="$2"
    timeout 15 "$SIM_BIN" --isa="$isa" -l "$elf" > /dev/null 2>&1
}

run_on_sail() {
    local elf="$1"
    local config="$2"
    timeout 15 "$SIM_BIN" --config="$config" --test-signature=/dev/null "$elf" > /dev/null 2>&1
}

# Run all ELFs
echo ""
echo "[2/5] Running all ELFs on $SIMULATOR..."
pass=0
fail=0
total=0
failed_elfs=""

for elf in $(find "$ELF_BASE" -name "*.elf" -type f 2>/dev/null | sort); do
    total=$((total + 1))
    # Detect ISA from ELF bitness
    if file "$elf" | grep -q "32-bit"; then
        if [ "$SIMULATOR" = "spike" ]; then
            elf_isa="rv32gc"
            run_on_spike "$elf" "$elf_isa"
        else
            run_on_sail "$elf" "$SAIL_CONFIG_RV32"
        fi
    else
        if [ "$SIMULATOR" = "spike" ]; then
            elf_isa="rv64imafdc_zicntr_zihpm"
            run_on_spike "$elf" "$elf_isa"
        else
            run_on_sail "$elf" "$SAIL_CONFIG_RV64"
        fi
    fi
    if [ $? -eq 0 ]; then
        echo "  OK:  $elf"
        pass=$((pass + 1))
    else
        echo "  FAIL: $elf"
        fail=$((fail + 1))
        failed_elfs="$failed_elfs\n  $elf"
    fi
done

echo ""
echo "Total: $total, Pass: $pass, Fail: $fail"
if [ $fail -gt 0 ]; then
    echo "Failed ELFs:"
    echo -e "$failed_elfs"
    if [ "$SIMULATOR" = "spike" ]; then
        echo "  (F/D failures: ожидаемые значения MicroTESK != IEEE 754, покрытие собрано)"
    fi
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

# Apply IMAFDC filter (Spike only)
if [ "$APPLY_IMAFDC_FILTER" = true ]; then
    echo ""
    echo "[4/5] Applying IMAFDC filter (excluding V/Crypto/B/Zfh/Hypervisor/Zfa/CBO insns)..."
    lcov --rc lcov_branch_coverage=1 --remove "$REPORT_DIR/microtesk_all.info" \
         "${IMAFDC_EXCLUDE_PATHS[@]}" \
         --output-file "$REPORT_DIR/microtesk_imafdc.info" \
         --ignore-errors source 2>/dev/null

    echo ""
    echo "IMAFDC-filtered coverage:"
    lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_imafdc.info" 2>&1 | grep -E "lines|functions|branches"

    INFO_MAIN="$REPORT_DIR/microtesk_imafdc.info"
    HTML_MAIN="$REPORT_DIR/html_imafdc"
else
    # For Sail, no IMAFDC filter; use full coverage
    echo ""
    echo "[4/5] Skipping IMAFDC filter (not applicable for $SIMULATOR)"
    INFO_MAIN="$REPORT_DIR/microtesk_all.info"
    HTML_MAIN="$REPORT_DIR/html_full"
fi

# Generate HTML reports
echo ""
echo "[5/5] Generating HTML reports..."
genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/microtesk_all.info" \
        --output-directory "$REPORT_DIR/html_full" \
        --ignore-errors source 2>&1 | tail -3

if [ "$APPLY_IMAFDC_FILTER" = true ]; then
    genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/microtesk_imafdc.info" \
            --output-directory "$REPORT_DIR/html_imafdc" \
            --ignore-errors source 2>&1 | tail -3
fi

# Copy info files to host
echo ""
echo "=== Results ($SIMULATOR) ==="
lcov --rc lcov_branch_coverage=1 --summary "$INFO_MAIN" 2>&1
echo ""
echo "HTML reports:"
echo "  Full: $REPORT_DIR/html_full/index.html"
if [ "$APPLY_IMAFDC_FILTER" = true ]; then
    echo "  IMAFDC: $REPORT_DIR/html_imafdc/index.html"
fi

# Copy to host-accessible location
cp "$REPORT_DIR/microtesk_all.info" "$HOST_REPORT_DIR/microtesk_all_${SIMULATOR}.info" 2>/dev/null
if [ "$APPLY_IMAFDC_FILTER" = true ]; then
    cp "$REPORT_DIR/microtesk_imafdc.info" "$HOST_REPORT_DIR/microtesk_imafdc_filtered_${SIMULATOR}.info" 2>/dev/null
fi
echo ""
echo "Info files copied to: $HOST_REPORT_DIR/"
