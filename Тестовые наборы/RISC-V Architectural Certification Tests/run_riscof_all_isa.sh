#!/bin/bash
# ============================================================================
# RISCOF Architectural Certification Tests — Multi-ISA Coverage Collection
# ============================================================================
# Runs all ELF files for each ISA extension through gcov-instrumented simulator,
# collecting per-ISA and combined coverage data.
#
# Usage: bash run_riscof_all_isa.sh [spike|sail] [isa1 isa2 ...]
#   First argument: simulator (spike or sail, default: spike)
#   Remaining arguments: ISA extensions to test (default: ALL)
#   Examples:
#     bash run_riscof_all_isa.sh sail
#     bash run_riscof_all_isa.sh spike A C F D
#     SIMULATOR=sail bash run_riscof_all_isa.sh A F D
#
# ISA extensions and their compatibility:
#   IMAFDC core:  A, C, F, D  — supported by both Spike and Sail
#   Already done:  I, M       — previously tested
#   Experimental:  B, Zfh, Zicond, Zimop, Zcmop, CMO, Zifencei, hints
#   Privileged:    pmp, privilege, vm_pmp, vm_sv39, vm_sv48, vm_sv57
#   FP variants:   D_Zcd, D_Zfa, F_Zfa
#   Crypto:        K
# ============================================================================

set -e

# --- Simulator selection ---
# Check if first argument is a simulator name
SIMULATOR="${SIMULATOR:-spike}"
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
        RUN_CMD_PREFIX="timeout 10 '$SIM_BIN' -l"
        ;;
    sail)
        SIM_BIN="/opt/sail-riscv/build_sailcov/c_emulator/sail_riscv_sim"
        BUILD_DIR="/opt/sail-riscv/build_sailcov"
        SAIL_CONFIG_RV64="/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json"
        SAIL_CONFIG_RV32="/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env/sail_config.json"
        ;;
    *)
        echo "ERROR: unknown simulator '$SIMULATOR'. Use spike or sail."
        exit 1
        ;;
esac

DOCKER_CONTAINER="riscv-env"
# Local ISA-separated ELF source directory
LOCAL_ELF_BASE="$(cd "$(dirname "$0")" && pwd)/riscof_work"
# Docker temp directory for ELF files
DOCKER_ELF_BASE="/tmp/riscof_elf_cache"
# Output directory inside Docker
DOCKER_OUTPUT_BASE="/tmp/riscof_isa_results"
# Local output directory for .info files
LOCAL_OUTPUT="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# All available ISAs (ordered by priority)
ALL_ISAS=(
    # IMAFDC core — highest priority (I, M already done)
    "A" "C" "F" "D"
    # FP variants
    "D_Zcd" "D_Zfa" "F_Zfa"
    # Other ratified extensions
    "B" "Zfh" "Zicond" "Zifencei" "Zimop" "Zcmop" "CMO" "hints"
    # Crypto
    "K"
    # Privileged (may need system-level emulation)
    "pmp" "privilege" "vm_pmp" "vm_sv39" "vm_sv48" "vm_sv57"
)

# Determine which ISAs to run
if [ $# -gt 0 ]; then
    ISAS_TO_RUN=("$@")
else
    ISAS_TO_RUN=("${ALL_ISAS[@]}")
fi

echo "============================================"
echo "  RISCOF Multi-ISA Coverage Collection"
echo "  Simulator: $SIMULATOR"
echo "============================================"
echo "ISAs to test: ${ISAS_TO_RUN[*]}"
echo "Local ELF base: $LOCAL_ELF_BASE"
echo "Output dir: $LOCAL_OUTPUT"
echo ""

mkdir -p "$LOCAL_OUTPUT"

# Check Docker container is running
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${DOCKER_CONTAINER}$"; then
    echo -e "${RED}ERROR: Docker container '${DOCKER_CONTAINER}' is not running${NC}"
    exit 1
fi

# ========================================================================
# Function: Copy ELF files for an ISA from local to Docker
# ========================================================================
copy_elf_to_docker() {
    local isa="$1"
    local local_dir="$LOCAL_ELF_BASE/$isa/src"
    local docker_dir="$DOCKER_ELF_BASE/$isa"

    if [ ! -d "$local_dir" ]; then
        echo -e "${YELLOW}  WARNING: Local dir $local_dir not found, skipping copy${NC}"
        return 1
    fi

    # Count ELF files
    local elf_count=$(find "$local_dir" -name "ref.elf" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$elf_count" -eq 0 ]; then
        echo -e "${YELLOW}  WARNING: No ref.elf files in $local_dir${NC}"
        return 1
    fi

    echo "  Copying $elf_count ELF files for ISA '$isa' to Docker..."
    # Clear old ELF dir in Docker
    docker exec "$DOCKER_CONTAINER" sh -c "rm -rf '$docker_dir' && mkdir -p '$docker_dir'"

    # Copy each ELF file
    find "$local_dir" -name "ref.elf" | while read elf; do
        local test_name=$(basename "$(dirname "$(dirname "$elf")")")
        local docker_path="$docker_dir/$test_name.elf"
        docker cp "$elf" "$DOCKER_CONTAINER:$docker_path" 2>/dev/null || true
    done

    # Verify
    local copied=$(docker exec "$DOCKER_CONTAINER" sh -c "find '$docker_dir' -name '*.elf' | wc -l" | tr -d ' ')
    echo "  Copied: $copied ELF files in $docker_dir"
    return 0
}

# ========================================================================
# Function: Run all ELF files for an ISA and collect coverage
# ========================================================================
run_isa_tests() {
    local isa="$1"
    local elf_dir="$DOCKER_ELF_BASE/$isa"
    local output_info="$DOCKER_OUTPUT_BASE/riscof_${SIMULATOR}_${isa}_coverage.info"

    echo ""
    echo -e "${CYAN}============================================"
    echo "  ISA: $isa"
    echo -e "============================================${NC}"

    # Check ELF directory exists in Docker
    local elf_count=$(docker exec "$DOCKER_CONTAINER" sh -c "find '$elf_dir' -name '*.elf' 2>/dev/null | wc -l" | tr -d ' ')
    if [ "$elf_count" -eq 0 ]; then
        echo -e "${RED}  ERROR: No ELF files for ISA $isa${NC}"
        return 1
    fi
    echo "  ELF files: $elf_count"

    # Clear gcov counters
    echo "  Clearing gcov counters..."
    docker exec "$DOCKER_CONTAINER" sh -c "find '$BUILD_DIR' -name '*.gcda' -delete"

    # Run all ELF files through the simulator
    echo "  Running tests on $SIMULATOR..."
    if [ "$SIMULATOR" = "spike" ]; then
        local run_output=$(docker exec "$DOCKER_CONTAINER" sh -c "
            pass=0; fail=0; timeout_fail=0
            for elf in \$(find '$elf_dir' -name '*.elf' | sort); do
                test_name=\$(basename \"\$elf\" .elf)
                timeout 10 '$SIM_BIN' -l \"\$elf\" > /dev/null 2>&1
                rc=\$?
                if [ \$rc -eq 0 ]; then
                    pass=\$((pass + 1))
                elif [ \$rc -eq 124 ]; then
                    timeout_fail=\$((timeout_fail + 1))
                else
                    fail=\$((fail + 1))
                fi
            done
            echo \"pass=\$pass fail=\$fail timeout=\$timeout_fail total=\$((pass + fail + timeout_fail))\"
        ")
    else
        # Sail: use RV64 config for all ISAs (most permissive)
        # Sail spec coverage writes to ./sail_coverage, so cd to output dir
        local run_output=$(docker exec "$DOCKER_CONTAINER" sh -c "
            mkdir -p '$DOCKER_OUTPUT_BASE'
            cd '$DOCKER_OUTPUT_BASE'
            rm -f sail_coverage
            pass=0; fail=0; timeout_fail=0
            for elf in \$(find '$elf_dir' -name '*.elf' | sort); do
                test_name=\$(basename \"\$elf\" .elf)
                timeout 10 '$SIM_BIN' --config='$SAIL_CONFIG_RV64' --test-signature=/dev/null \"\$elf\" > /dev/null 2>&1
                rc=\$?
                if [ \$rc -eq 0 ]; then
                    pass=\$((pass + 1))
                elif [ \$rc -eq 124 ]; then
                    timeout_fail=\$((timeout_fail + 1))
                else
                    fail=\$((fail + 1))
                fi
            done
            # Rename accumulated sail_coverage
            if [ -f sail_coverage ]; then
                mv sail_coverage riscof_sail_${isa}_sailcov.txt
            fi
            echo \"pass=\$pass fail=\$fail timeout=\$timeout_fail total=\$((pass + fail + timeout_fail))\"
        ")
    fi
    echo "  Results: $run_output"

    # Collect coverage
    echo "  Collecting lcov coverage..."
    docker exec "$DOCKER_CONTAINER" sh -c "
        mkdir -p '$DOCKER_OUTPUT_BASE'
        lcov --rc lcov_branch_coverage=1 \
             --capture --directory '$BUILD_DIR' \
             --output-file '$output_info' \
             --ignore-errors gcov,source 2>&1 | tail -3
    "

    # Show summary
    echo "  Coverage summary:"
    docker exec "$DOCKER_CONTAINER" sh -c "
        lcov --rc lcov_branch_coverage=1 --summary '$output_info' 2>&1 | grep -E 'lines|functions|branches'
    "

    # Copy .info file back to local
    local local_info="$LOCAL_OUTPUT/riscof_${SIMULATOR}_${isa}_coverage.info"
    docker cp "$DOCKER_CONTAINER:$output_info" "$local_info" 2>/dev/null
    echo "  Saved: $local_info"

    # Collect Sail spec-level coverage (if applicable)
    if [ "$SIMULATOR" = "sail" ]; then
        local sailcov_docker="$DOCKER_OUTPUT_BASE/riscof_sail_${isa}_sailcov.txt"
        local sailcov_local="$LOCAL_OUTPUT/riscof_sail_${isa}_sailcov.txt"
        docker cp "$DOCKER_CONTAINER:$sailcov_docker" "$sailcov_local" 2>/dev/null
        if [ -f "$sailcov_local" ]; then
            local sailcov_lines=$(wc -l < "$sailcov_local" | tr -d ' ')
            echo "  Sail spec cov: $sailcov_local ($sailcov_lines lines)"
        fi
    fi

    echo -e "${GREEN}  ISA $isa: DONE${NC}"
    return 0
}

# ========================================================================
# Phase 1: Copy all needed ELF files to Docker
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 1: Copy ELF files to Docker"
echo "============================================"

# Create Docker base directories
docker exec "$DOCKER_CONTAINER" sh -c "mkdir -p '$DOCKER_ELF_BASE' '$DOCKER_OUTPUT_BASE'"

COPIED_ISAS=()
for isa in "${ISAS_TO_RUN[@]}"; do
    if copy_elf_to_docker "$isa"; then
        COPIED_ISAS+=("$isa")
    fi
done

echo ""
echo -e "${GREEN}Successfully copied ${#COPIED_ISAS[@]} ISAs: ${COPIED_ISAS[*]}${NC}"

# ========================================================================
# Phase 2: Run tests and collect coverage per ISA
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 2: Run ISA Tests & Collect Coverage"
echo "============================================"

PASS_ISAS=()
FAIL_ISAS=()
for isa in "${COPIED_ISAS[@]}"; do
    if run_isa_tests "$isa"; then
        PASS_ISAS+=("$isa")
    else
        FAIL_ISAS+=("$isa")
    fi
done

# ========================================================================
# Phase 3: Generate combined IMAFDC coverage
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 3: Combined IMAFDC Coverage"
echo "============================================"

# Combine I + M + A + C + F + D coverage files (those that exist)
COMBINE_ISAS=()
for isa in I M A C F D; do
    local_info="$LOCAL_OUTPUT/riscof_${SIMULATOR}_${isa}_coverage.info"
    docker_info="$DOCKER_OUTPUT_BASE/riscof_${SIMULATOR}_${isa}_coverage.info"
    if [ -f "$local_info" ]; then
        # Ensure Docker has a copy too
        if ! docker exec "$DOCKER_CONTAINER" sh -c "test -f '$docker_info'" 2>/dev/null; then
            docker cp "$local_info" "$DOCKER_CONTAINER:$docker_info" 2>/dev/null || true
        fi
        COMBINE_ISAS+=("$docker_info")
    fi
done

if [ ${#COMBINE_ISAS[@]} -ge 2 ]; then
    echo "Combining: ${COMBINE_ISAS[*]}"
    COMBINED_INFO="$DOCKER_OUTPUT_BASE/riscof_${SIMULATOR}_imafdc_combined.info"
    docker exec "$DOCKER_CONTAINER" sh -c "
        lcov --rc lcov_branch_coverage=1 \
             --add-tracefile ${COMBINE_ISAS[0]} \
             $(for ((i=1; i<${#COMBINE_ISAS[@]}; i++)); do echo -n "--add-tracefile ${COMBINE_ISAS[$i]} "; done) \
             --output-file '$COMBINED_INFO' \
             --ignore-errors source,empty 2>&1 | tail -3
    "
    # Copy combined file
    docker cp "$DOCKER_CONTAINER:$COMBINED_INFO" "$LOCAL_OUTPUT/riscof_${SIMULATOR}_imafdc_combined.info" 2>/dev/null
    echo "Combined IMAFDC coverage:"
    docker exec "$DOCKER_CONTAINER" sh -c "lcov --rc lcov_branch_coverage=1 --summary '$COMBINED_INFO' 2>&1 | grep -E 'lines|functions|branches'"
else
    echo "Not enough ISAs for combined coverage (need at least 2)"
fi

# ========================================================================
# Phase 4: Generate HTML report for combined coverage
# ========================================================================
echo ""
echo "============================================"
echo "  Phase 4: Generate HTML Reports"
echo "============================================"

if [ -f "$LOCAL_OUTPUT/riscof_${SIMULATOR}_imafdc_combined.info" ]; then
    HTML_DIR="$LOCAL_OUTPUT/coverage_html_riscof_${SIMULATOR}_combined"
    mkdir -p "$HTML_DIR"
    docker cp "$LOCAL_OUTPUT/riscof_${SIMULATOR}_imafdc_combined.info" "$DOCKER_CONTAINER:/tmp/riscof_${SIMULATOR}_imafdc_combined.info"
    docker exec "$DOCKER_CONTAINER" sh -c "
        genhtml --rc genhtml_branch_coverage=1 \
                /tmp/riscof_${SIMULATOR}_imafdc_combined.info \
                --output-directory /tmp/riscof_html_combined \
                --ignore-errors source 2>&1 | tail -5
    "
    # Copy HTML
    rm -rf "$HTML_DIR"
    mkdir -p "$HTML_DIR"
    docker cp "$DOCKER_CONTAINER:/tmp/riscof_html_combined/." "$HTML_DIR/" 2>/dev/null
    echo "Combined HTML report: $HTML_DIR/index.html"
fi

# ========================================================================
# Summary
# ========================================================================
echo ""
echo "============================================"
echo "  FINAL SUMMARY"
echo "============================================"
echo -e "${GREEN}Passed ISAs (${#PASS_ISAS[@]}): ${PASS_ISAS[*]}${NC}"
if [ ${#FAIL_ISAS[@]} -gt 0 ]; then
    echo -e "${RED}Failed ISAs (${#FAIL_ISAS[@]}): ${FAIL_ISAS[*]}${NC}"
fi
echo ""
echo "Coverage files in: $LOCAL_OUTPUT/"
ls -la "$LOCAL_OUTPUT"/riscof_${SIMULATOR}_*_coverage.info 2>/dev/null | awk '{print "  " $NF}'
echo ""
echo "DONE"
