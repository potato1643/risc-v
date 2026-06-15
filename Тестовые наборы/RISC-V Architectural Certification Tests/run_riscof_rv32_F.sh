#!/bin/bash
# ============================================================================
# RISCOF RV32 F — Compile + Run + Coverage
# ============================================================================
# Compiles RV32 F .S tests, runs through gcov-Spike, collects coverage.
#
# Usage: bash run_riscof_rv32_F.sh
# ============================================================================

set -e

CONTAINER="riscv-env"
TEST_SUITE="/opt/riscv-arch-test/riscv-test-suite/rv32i_m"
SAIL_ENV="/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env"
LINKER_SCRIPT="$SAIL_ENV/link.ld"
ENV_INCLUDE="/opt/riscv-arch-test/riscv-test-suite/env"
SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
ELF_BASE="/tmp/riscof_rv32_f_elf"
OUTPUT_BASE="/tmp/riscof_rv32_f_results"
LOCAL_OUT="/Users/xiaoyubai/WorkSpace/2275/risc-v/Тестовые наборы/RISC-V Architectural Certification Tests"

ISA="F"
MARCH="rv32if"
MABI="ilp32f"
GCC="/opt/riscv/bin/riscv32-unknown-elf-gcc"

SRC_DIR="$TEST_SUITE/$ISA/src"

echo "============================================"
echo "  RISCOF RV32 F Coverage Collection"
echo "============================================"
echo "ISA: $ISA  march: $MARCH  mabi: $MABI"
echo "Source: $SRC_DIR"
echo ""

# ========================================================================
# Phase 1: Compile
# ========================================================================
echo "============================================"
echo "  Phase 1: Compile RV32F ELF files"
echo "============================================"

s_count=$(docker exec "$CONTAINER" sh -c "find '$SRC_DIR' -name '*.S' 2>/dev/null | wc -l" | tr -d ' ')
if [ "$s_count" -eq 0 ]; then
    echo "ERROR: No .S files found in $SRC_DIR"
    exit 1
fi
echo "Source files: $s_count"

docker exec "$CONTAINER" sh -c "rm -rf '$ELF_BASE' && mkdir -p '$ELF_BASE'"

compiled=0
failed=0
file_list=$(docker exec "$CONTAINER" sh -c "find '$SRC_DIR' -name '*.S' | sort")
for src in $file_list; do
    [ -z "$src" ] && continue
    test_name=$(basename "$src" .S)
    elf_path="$ELF_BASE/$test_name.elf"
    if docker exec "$CONTAINER" bash -c "
        $GCC \
            -march=$MARCH \
            -static -mcmodel=medany -fvisibility=hidden \
            -nostdlib -nostartfiles \
            -T '$LINKER_SCRIPT' \
            -I '$SAIL_ENV' \
            -I '$ENV_INCLUDE' \
            -mabi=$MABI \
            '$src' -o '$elf_path' \
            -DTEST_CASE_1=True -DXLEN=32 -DFLEN=32 2>&1
    " 2>/dev/null; then
        compiled=$((compiled + 1))
    else
        failed=$((failed + 1))
        if [ $failed -le 5 ]; then
            echo "  FAIL: $test_name"
        fi
    fi
done
echo "  Compiled: $compiled/$s_count (fail: $failed)"

# ========================================================================
# Phase 2: Run + Collect Coverage
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 2: Run RV32F Tests & Collect Coverage"
echo "============================================"

docker exec "$CONTAINER" sh -c "mkdir -p '$OUTPUT_BASE'"

elf_count=$(docker exec "$CONTAINER" sh -c "find '$ELF_BASE' -name '*.elf' 2>/dev/null | wc -l" | tr -d ' ')
if [ "$elf_count" -eq 0 ]; then
    echo "ERROR: No ELF files compiled"
    exit 1
fi

echo "ELF files: $elf_count"
echo "  Clearing gcov..."
docker exec "$CONTAINER" sh -c "find '$BUILD_DIR' -name '*.gcda' -delete"

echo "  Running tests..."
run_result=$(docker exec "$CONTAINER" sh -c "
    pass=0; fail=0; timeout_fail=0
    for elf in \$(find '$ELF_BASE' -name '*.elf' | sort); do
        timeout 10 '$SPIKE' --isa=rv32gc -l \"\$elf\" > /dev/null 2>&1
        rc=\$?
        if [ \$rc -eq 0 ]; then
            pass=\$((pass + 1))
        elif [ \$rc -eq 124 ]; then
            timeout_fail=\$((timeout_fail + 1))
        else
            fail=\$((fail + 1))
        fi
    done
    echo \"pass=\$pass fail=\$fail timeout=\$timeout_fail\"
")
echo "  Result: $run_result"

echo "  Collecting lcov..."
OUTPUT_INFO="$OUTPUT_BASE/riscof_rv32_F_coverage.info"
docker exec "$CONTAINER" sh -c "
    lcov --rc lcov_branch_coverage=1 \
         --capture --directory '$BUILD_DIR' \
         --output-file '$OUTPUT_INFO' \
         --ignore-errors gcov,source 2>&1 | tail -3
"

echo "  Coverage:"
docker exec "$CONTAINER" sh -c "
    lcov --rc lcov_branch_coverage=1 --summary '$OUTPUT_INFO' 2>&1 | grep -E 'lines|functions|branches'
"

docker cp "$CONTAINER:$OUTPUT_INFO" "$LOCAL_OUT/riscof_rv32_F_coverage.info" 2>/dev/null
echo "  Saved: riscof_rv32_F_coverage.info"

echo ""
echo "============================================"
echo "  DONE — RV32F"
echo "============================================"
ls -la "$LOCAL_OUT/riscof_rv32_F_coverage.info" 2>/dev/null | awk '{printf "  %s (%s)\n", $NF, $5}'
