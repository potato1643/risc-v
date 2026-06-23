#!/bin/bash
# ============================================================================
# Sail Spec-Level Coverage Analysis
# ============================================================================
# Analyzes .sailcov.txt files (Sail spec-level coverage) and compares
# against C-level gcov coverage (.info files)
#
# Usage: bash analyze_sail_spec_cov.sh
# ============================================================================

set -e

LOCAL_DIR="$(cd "$(dirname "$0")/../Тестовые наборы/RISC-V Architectural Certification Tests" && pwd)"
BRANCH_INFO_DOCKER="/opt/sail-riscv/build_sailcov/sail_riscv_model.branch_info"
CONTAINER="riscv-env"

# Copy static branch_info for reference
echo "=== Copying static branch_info ==="
docker cp "$CONTAINER:$BRANCH_INFO_DOCKER" "$LOCAL_DIR/sail_riscv_model.branch_info" 2>/dev/null
echo "Static branch_info: $(wc -l < "$LOCAL_DIR/sail_riscv_model.branch_info") points"

echo ""
echo "============================================"
echo "  Sail Spec-Level Coverage Analysis"
echo "============================================"
echo ""

# Process each ISA
echo "ISA        | ELFs | C-Line% | Sail-Cov% | Fn-Cov% | Br-Cov% | Sail Lines"
echo "-----------|------|---------|-----------|---------|---------|-----------"

STATIC_TOTAL=$(wc -l < "$LOCAL_DIR/sail_riscv_model.branch_info" | tr -d ' ')
STATIC_F=$(grep "^F" "$LOCAL_DIR/sail_riscv_model.branch_info" | wc -l | tr -d ' ')
STATIC_B=$(grep "^B" "$LOCAL_DIR/sail_riscv_model.branch_info" | wc -l | tr -d ' ')
STATIC_T=$(grep "^T" "$LOCAL_DIR/sail_riscv_model.branch_info" | wc -l | tr -d ' ')

for isa in I M A C F D; do
    sailcov="$LOCAL_DIR/riscof_sail_rv32_${isa}_sailcov.txt"
    info="$LOCAL_DIR/riscof_sail_rv32_${isa}_coverage.info"

    # Sail spec coverage
    if [ -f "$sailcov" ]; then
        unique=$(sort -u "$sailcov" | wc -l | tr -d ' ')
        sail_pct=$(echo "scale=1; $unique * 100 / $STATIC_TOTAL" | bc)
        sail_lines=$(wc -l < "$sailcov" | tr -d ' ')
    else
        unique=0
        sail_pct="0.0"
        sail_lines=0
    fi

    # C-level gcov coverage
    if [ -f "$info" ]; then
        # Parse lcov summary (run in docker for lcov)
        c_line_pct=$(lcov --rc lcov_branch_coverage=1 --summary "$info" 2>&1 | grep "lines" | awk '{print $2}' | sed 's/%//')
        [ -z "$c_line_pct" ] && c_line_pct="N/A"
    else
        c_line_pct="N/A"
    fi

    # ELF count
    elf_count="?"
    case $isa in
        I) elf_count=38 ;;
        M) elf_count=8 ;;
        A) elf_count=9 ;;
        C) elf_count=27 ;;
        F) elf_count=342 ;;
        D) elf_count=679 ;;
    esac

    printf "%-10s | %4s | %6s%% | %7s%% | %7s | %7s | %s\n" \
        "$isa" "$elf_count" "$c_line_pct" "$sail_pct" "-" "-" "$sail_lines"
done

echo ""
echo "--- Static reference ---"
echo "Total points: $STATIC_TOTAL (F:$STATIC_F B:$STATIC_B T:$STATIC_T)"

# Combined dedup across all ISAs
echo ""
echo "============================================"
echo "  Combined Sail Spec Coverage (dedup)"
echo "============================================"

COMBINED="/tmp/sail_spec_combined.txt"
rm -f "$COMBINED"
for isa in I M A C F D; do
    sailcov="$LOCAL_DIR/riscof_sail_rv32_${isa}_sailcov.txt"
    [ -f "$sailcov" ] && cat "$sailcov" >> "$COMBINED"
done

COMBINED_UNIQUE=$(sort -u "$COMBINED" | wc -l | tr -d ' ')
COMBINED_PCT=$(echo "scale=1; $COMBINED_UNIQUE * 100 / $STATIC_TOTAL" | bc)

echo "Combined unique points: $COMBINED_UNIQUE / $STATIC_TOTAL ($COMBINED_PCT%)"
echo ""
echo "By type:"
sort -u "$COMBINED" | cut -c1 | sort | uniq -c | sort -rn | while read count type; do
    case $type in
        F) static=$STATIC_F ;;
        B) static=$STATIC_B ;;
        T) static=$STATIC_T ;;
    esac
    pct=$(echo "scale=1; $count * 100 / $static" | bc)
    echo "  $type: $count / $static ($pct%)"
done

echo ""
echo "Top 15 covered Sail source files:"
sort -u "$COMBINED" | cut -d'"' -f2 | sort | uniq -c | sort -rn | head -15

# Save combined unique
sort -u "$COMBINED" > "$LOCAL_DIR/sail_spec_imafdc_combined_unique.txt"
echo ""
echo "Combined unique saved to: $LOCAL_DIR/sail_spec_imafdc_combined_unique.txt"
