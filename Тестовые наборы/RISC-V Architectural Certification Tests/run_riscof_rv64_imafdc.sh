#!/bin/bash
# ============================================================================
# RISCOF RV64 IMAFDC — Compile + Run + Coverage
# ============================================================================
# Compiles RV64 .S tests for each ISA (I, M, A, C, F, D),
# runs through gcov-instrumented Sail simulator (build_sailcov), and collects
# per-ISA C-level coverage + Sail spec-level coverage.
#
# Usage: bash run_riscof_rv64_imafdc.sh [spike|sail] [isa1 isa2 ...]
#   SIMULATOR=sail bash run_riscof_rv64_imafdc.sh
# ============================================================================

set -e

# --- Simulator selection ---
SIMULATOR="${SIMULATOR:-sail}"
if [ $# -gt 0 ]; then
    case "$1" in
        spike|sail)
            SIMULATOR="$1"
            shift
            ;;
    esac
fi

case "$SIMULATOR" in
    spike)
        SIM_BIN="/opt/riscv-isa-sim/build/spike"
        BUILD_DIR="/opt/riscv-isa-sim/build"
        APPLY_IMAFDC_FILTER=true
        ;;
    sail)
        SIM_BIN="/opt/sail-riscv/build_sailcov/c_emulator/sail_riscv_sim"
        BUILD_DIR="/opt/sail-riscv/build_sailcov"
        SAIL_CONFIG="/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json"
        APPLY_IMAFDC_FILTER=false
        ;;
    *)
        echo "ERROR: unknown simulator '$SIMULATOR'. Use spike or sail."
        exit 1
        ;;
esac

CONTAINER="riscv-env"
SAIL_ENV="/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env"
LINKER_SCRIPT="$SAIL_ENV/link.ld"
ENV_INCLUDE="/opt/riscv-arch-test/riscv-test-suite/env"
TEST_SUITE="/opt/riscv-arch-test/riscv-test-suite/rv64i_m"
ELF_BASE="/tmp/riscof_rv64_elf"
OUTPUT_BASE="/tmp/riscof_rv64_results"
LOCAL_OUT="/Users/xiaoyubai/WorkSpace/2275/risc-v/Тестовые наборы/RISC-V Architectural Certification Tests"

# ISA → march mapping
get_march() {
    case "$1" in
        I) echo "rv64i" ;;
        M) echo "rv64im" ;;
        A) echo "rv64ima" ;;
        C) echo "rv64ic" ;;
        F) echo "rv64if" ;;
        D) echo "rv64ifd" ;;
        *) echo "rv64i" ;;
    esac
}

# ISA → extra GCC defines
get_defines() {
    case "$1" in
        F) echo "-DTEST_CASE_1=True -DXLEN=64 -DFLEN=32" ;;
        D) echo "-DTEST_CASE_1=True -DXLEN=64 -DFLEN=64" ;;
        *) echo "-DTEST_CASE_1=True -DXLEN=64" ;;
    esac
}

# ISA → mabi mapping
get_mabi() {
    case "$1" in
        I|M|A|C) echo "lp64" ;;
        F) echo "lp64f" ;;
        D) echo "lp64d" ;;
        *) echo "lp64" ;;
    esac
}

# GCC path
GCC="/opt/riscv/bin/riscv64-unknown-elf-gcc"

ALL_ISAS="I M A C F D"

if [ $# -gt 0 ]; then
    ISAS_TO_RUN="$*"
else
    ISAS_TO_RUN="$ALL_ISAS"
fi

echo "============================================"
echo "  RISCOF RV64 IMAFDC Coverage Collection"
echo "  Simulator: $SIMULATOR"
echo "============================================"
echo "ISAs: $ISAS_TO_RUN"
echo ""

# ========================================================================
# Phase 1: Compile
# ========================================================================
echo "============================================"
echo "  Phase 1: Compile RV64 ELF files"
echo "============================================"

for isa in $ISAS_TO_RUN; do
    src_dir="$TEST_SUITE/$isa/src"
    elf_dir="$ELF_BASE/$isa"
    march=$(get_march "$isa")
    mabi=$(get_mabi "$isa")

    echo ""
    echo "--- ISA $isa: march=$march mabi=$mabi ---"

    s_count=$(docker exec "$CONTAINER" sh -c "find '$src_dir' -name '*.S' 2>/dev/null | wc -l" | tr -d ' ')
    if [ "$s_count" -eq 0 ]; then
        echo "  WARNING: No .S files, skipping"
        continue
    fi
    echo "  Source files: $s_count"

    docker exec "$CONTAINER" sh -c "rm -rf '$elf_dir' && mkdir -p '$elf_dir'"

    compiled=0
    failed=0
    # Get file list
    file_list=$(docker exec "$CONTAINER" sh -c "find '$src_dir' -name '*.S' | sort")
    for src in $file_list; do
        [ -z "$src" ] && continue
        test_name=$(basename "$src" .S)
        elf_path="$elf_dir/$test_name.elf"
        if docker exec "$CONTAINER" bash -c "
            $GCC \
                -march=$march \
                -static -mcmodel=medany -fvisibility=hidden \
                -nostdlib -nostartfiles \
                -T '$LINKER_SCRIPT' \
                -I '$SAIL_ENV' \
                -I '$ENV_INCLUDE' \
                -mabi=$mabi \
                '$src' -o '$elf_path' \
                $(get_defines $isa) 2>&1
        " 2>/dev/null; then
            compiled=$((compiled + 1))
        else
            failed=$((failed + 1))
            if [ $failed -le 3 ]; then
                echo "  FAIL: $test_name"
            fi
        fi
    done
    echo "  Compiled: $compiled/$s_count (fail: $failed)"
done

# ========================================================================
# Phase 2: Run + Collect
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 2: Run RV64 Tests & Collect Coverage"
echo "============================================"

docker exec "$CONTAINER" sh -c "mkdir -p '$OUTPUT_BASE'"

for isa in $ISAS_TO_RUN; do
    elf_dir="$ELF_BASE/$isa"
    output_info="$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_${isa}_coverage.info"

    elf_count=$(docker exec "$CONTAINER" sh -c "find '$elf_dir' -name '*.elf' 2>/dev/null | wc -l" | tr -d ' ')
    if [ "$elf_count" -eq 0 ]; then
        echo "ISA $isa: No ELF files, skipping"
        continue
    fi

    echo ""
    echo "--- ISA $isa: $elf_count ELFs ---"
    echo "  Clearing gcov..."
    docker exec "$CONTAINER" sh -c "find '$BUILD_DIR' -name '*.gcda' -delete"

    echo "  Running tests on $SIMULATOR..."
    if [ "$SIMULATOR" = "spike" ]; then
        run_result=$(docker exec "$CONTAINER" sh -c "
            pass=0; fail=0; timeout_fail=0
            for elf in \$(find '$elf_dir' -name '*.elf' | sort); do
                timeout 10 '$SIM_BIN' --isa=rv64gc -l \"\$elf\" > /dev/null 2>&1
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
    else
        # Sail: use RV64 config; sail_coverage accumulates per-ISA
        run_result=$(docker exec "$CONTAINER" sh -c "
            cd '$OUTPUT_BASE'
            rm -f sail_coverage
            pass=0; fail=0; timeout_fail=0
            for elf in \$(find '$elf_dir' -name '*.elf' | sort); do
                timeout 10 '$SIM_BIN' --config='$SAIL_CONFIG' --test-signature=/dev/null \"\$elf\" > /dev/null 2>&1
                rc=\$?
                if [ \$rc -eq 0 ]; then
                    pass=\$((pass + 1))
                elif [ \$rc -eq 124 ]; then
                    timeout_fail=\$((timeout_fail + 1))
                else
                    fail=\$((fail + 1))
                fi
            done
            if [ -f sail_coverage ]; then
                mv sail_coverage riscof_${SIMULATOR}_rv64_${isa}_sailcov.txt
            fi
            echo \"pass=\$pass fail=\$fail timeout=\$timeout_fail\"
        ")
    fi
    echo "  Result: $run_result"

    echo "  Collecting lcov..."
    docker exec "$CONTAINER" sh -c "
        lcov --rc lcov_branch_coverage=1 \
             --capture --directory '$BUILD_DIR' \
             --output-file '$output_info' \
             --ignore-errors gcov,source 2>&1 | tail -3
    "

    echo "  Coverage:"
    docker exec "$CONTAINER" sh -c "
        lcov --rc lcov_branch_coverage=1 --summary '$output_info' 2>&1 | grep -E 'lines|functions|branches'
    "

    docker cp "$CONTAINER:$output_info" "$LOCAL_OUT/riscof_${SIMULATOR}_rv64_${isa}_coverage.info" 2>/dev/null
    echo "  Saved: riscof_${SIMULATOR}_rv64_${isa}_coverage.info"

    # Collect Sail spec-level coverage
    if [ "$SIMULATOR" = "sail" ]; then
        sailcov_docker="$OUTPUT_BASE/riscof_sail_rv64_${isa}_sailcov.txt"
        sailcov_local="$LOCAL_OUT/riscof_sail_rv64_${isa}_sailcov.txt"
        docker cp "$CONTAINER:$sailcov_docker" "$sailcov_local" 2>/dev/null
        if [ -f "$sailcov_local" ]; then
            echo "  Sail spec cov: $(wc -l < "$sailcov_local" | tr -d ' ') lines"
        fi
    fi
done

# ========================================================================
# Phase 3: Combine
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 3: Combined RV64 + RV32 IMAFDC"
echo "============================================"

# Build lcov combine command for RV64
RV64_ARGS=""
first=""
for isa in $ISAS_TO_RUN; do
    f="$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_${isa}_coverage.info"
    exists=$(docker exec "$CONTAINER" sh -c "test -f '$f' && echo yes || echo no")
    if [ "$exists" = "yes" ]; then
        if [ -z "$first" ]; then
            first="$f"
        else
            RV64_ARGS="$RV64_ARGS --add-tracefile $f"
        fi
    fi
done

if [ -n "$first" ]; then
    echo "--- Combining RV64 IMAFDC ---"
    docker exec "$CONTAINER" sh -c "
        lcov --rc lcov_branch_coverage=1 \
             --add-tracefile '$first' \
             $RV64_ARGS \
             --output-file '$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_imafdc.info' \
             --ignore-errors source,empty 2>&1 | tail -3
    "
    echo "RV64 IMAFDC combined:"
    docker exec "$CONTAINER" sh -c "lcov --rc lcov_branch_coverage=1 --summary '$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_imafdc.info' 2>&1 | grep -E 'lines|functions|branches'"
    docker cp "$CONTAINER:$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_imafdc.info" "$LOCAL_OUT/riscof_${SIMULATOR}_rv64_imafdc.info" 2>/dev/null

    # Merge RV32 + RV64 (if RV32 data exists from run_riscof_rv32_imafdc.sh)
    RV32_INFO="/tmp/riscof_rv32_results/riscof_${SIMULATOR}_rv32_imafdc.info"
    RV32_EXISTS=$(docker exec "$CONTAINER" sh -c "test -f '$RV32_INFO' && echo yes || echo no")
    if [ "$RV32_EXISTS" = "yes" ]; then
        echo ""
        echo "--- Combining RV64 + RV32 ---"
        docker exec "$CONTAINER" sh -c "
            lcov --rc lcov_branch_coverage=1 \
                 --add-tracefile '$OUTPUT_BASE/riscof_${SIMULATOR}_rv64_imafdc.info' \
                 --add-tracefile '$RV32_INFO' \
                 --output-file '$OUTPUT_BASE/riscof_${SIMULATOR}_all_imafdc.info' \
                 --ignore-errors source,empty 2>&1 | tail -3
        "
        echo "RV64+RV32 full denominator:"
        docker exec "$CONTAINER" sh -c "lcov --rc lcov_branch_coverage=1 --summary '$OUTPUT_BASE/riscof_${SIMULATOR}_all_imafdc.info' 2>&1 | grep -E 'lines|functions|branches'"

        # Copy combined
        docker cp "$CONTAINER:$OUTPUT_BASE/riscof_${SIMULATOR}_all_imafdc.info" "$LOCAL_OUT/riscof_${SIMULATOR}_all_imafdc.info" 2>/dev/null
        echo "Saved: riscof_${SIMULATOR}_all_imafdc.info"
    else
        echo "  (RV32 data not found at $RV32_INFO — skipping RV64+RV32 merge)"
    fi
fi

echo ""
echo "============================================"
echo "  DONE — Local files:"
echo "============================================"
ls -la "$LOCAL_OUT"/riscof_*.info 2>/dev/null | awk '{printf "  %s (%s)\n", $NF, $5}'
