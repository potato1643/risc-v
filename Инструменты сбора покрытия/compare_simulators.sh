#!/bin/bash
# ============================================================================
# Cross-Simulator Coverage Comparison: Spike vs Sail
# ============================================================================
# Compares gcov/lcov coverage results between Spike and Sail for the same
# test suites (MicroTESK, RISCOF, Imperas).
#
# Usage:
#   bash compare_simulators.sh <spike_report_dir> <sail_report_dir>
#
# Example:
#   bash compare_simulators.sh \
#       /tmp/coverage_reports_spike \
#       /tmp/coverage_reports_sail
#
# Important caveat: Spike and Sail are different codebases. Absolute coverage
# percentages are NOT directly comparable. What IS comparable:
#   - Relative ranking of test suites within each simulator
#   - Which ISA features are exercised in each simulator
# ============================================================================

set -e

SPIKE_DIR="${1:-/tmp/coverage_reports_spike}"
SAIL_DIR="${2:-/tmp/coverage_reports_sail}"

if [ ! -d "$SPIKE_DIR" ] || [ ! -d "$SAIL_DIR" ]; then
    echo "ERROR: Coverage report directories not found."
    echo "Usage: bash compare_simulators.sh <spike_dir> <sail_dir>"
    echo ""
    echo "Checking:"
    echo "  Spike dir: $SPIKE_DIR ($([ -d "$SPIKE_DIR" ] && echo 'exists' || echo 'MISSING'))"
    echo "  Sail dir:  $SAIL_DIR ($([ -d "$SAIL_DIR" ] && echo 'exists' || echo 'MISSING'))"
    echo ""
    echo "Run coverage collection first:"
    echo "  SIMULATOR=spike bash run_coverage.sh"
    echo "  SIMULATOR=sail bash run_coverage.sh"
    exit 1
fi

echo "=============================================="
echo "  Cross-Simulator Coverage Comparison"
echo "  Spike vs Sail C Simulator"
echo "=============================================="
echo ""
echo "Spike reports: $SPIKE_DIR"
echo "Sail reports:  $SAIL_DIR"
echo ""

# Extract coverage metrics from lcov summary
extract_metrics() {
    local info_file="$1"
    if [ -f "$info_file" ]; then
        lcov --rc lcov_branch_coverage=1 --summary "$info_file" 2>&1 | grep -E "lines|functions|branches" | \
            awk '{printf "%s|%s|%s", $1, $2, $NF}' | tr -d '():'
    else
        echo "MISSING"
    fi
}

# Print comparison table for one test suite
compare_suite() {
    local suite="$1"
    local spike_info="$SPIKE_DIR/${suite}_coverage.info"
    local sail_info="$SAIL_DIR/${suite}_coverage.info"

    echo "--- $suite ---"
    printf "%-12s %-20s %-20s\n" "" "Spike" "Sail"
    printf "%-12s %-20s %-20s\n" "----------" "--------------------" "--------------------"

    local spike_metrics=$(extract_metrics "$spike_info")
    local sail_metrics=$(extract_metrics "$sail_info")

    # Parse and compare
    if [ "$spike_metrics" = "MISSING" ]; then
        echo "  Spike data: MISSING"
    fi
    if [ "$sail_metrics" = "MISSING" ]; then
        echo "  Sail data: MISSING"
    fi

    if [ "$spike_metrics" != "MISSING" ] && [ "$sail_metrics" != "MISSING" ]; then
        # Extract line coverage
        spike_line=$(echo "$spike_metrics" | grep "^lines" | cut -d'|' -f3 | tr -d '% ')
        sail_line=$(echo "$sail_metrics" | grep "^lines" | cut -d'|' -f3 | tr -d '% ')
        spike_func=$(echo "$spike_metrics" | grep "^functions" | cut -d'|' -f3 | tr -d '% ')
        sail_func=$(echo "$sail_metrics" | grep "^functions" | cut -d'|' -f3 | tr -d '% ')
        spike_branch=$(echo "$spike_metrics" | grep "^branches" | cut -d'|' -f3 | tr -d '% ')
        sail_branch=$(echo "$sail_metrics" | grep "^branches" | cut -d'|' -f3 | tr -d '% ')

        printf "%-12s %-20s %-20s\n" "Line:" "${spike_line:-N/A}%" "${sail_line:-N/A}%"
        printf "%-12s %-20s %-20s\n" "Function:" "${spike_func:-N/A}%" "${sail_func:-N/A}%"
        printf "%-12s %-20s %-20s\n" "Branch:" "${spike_branch:-N/A}%" "${sail_branch:-N/A}%"
    fi
    echo ""
}

echo "=============================================="
echo "  Per-Suite Comparison"
echo "=============================================="
echo ""
echo "NOTE: Absolute % values are NOT comparable between simulators"
echo "      (different codebases). Compare rankings and patterns."
echo ""

compare_suite "microtesk"
compare_suite "riscof_rv64"
compare_suite "imperas_rv32"

# Combined ranking
echo "=============================================="
echo "  Ranking Within Each Simulator"
echo "=============================================="
echo ""

for sim_dir in "$SPIKE_DIR" "$SAIL_DIR"; do
    sim_name=$(echo "$sim_dir" | grep -q "sail" && echo "Sail" || echo "Spike")
    echo "--- $sim_name ---"
    printf "%-15s %-10s %-10s %-10s\n" "Suite" "Line%" "Func%" "Branch%"

    for suite in microtesk riscof_rv64 imperas_rv32; do
        info="$sim_dir/${suite}_coverage.info"
        if [ -f "$info" ]; then
            metrics=$(extract_metrics "$info")
            line=$(echo "$metrics" | grep "^lines" | cut -d'|' -f3 | tr -d '% ')
            func=$(echo "$metrics" | grep "^functions" | cut -d'|' -f3 | tr -d '% ')
            branch=$(echo "$metrics" | grep "^branches" | cut -d'|' -f3 | tr -d '% ')
            printf "%-15s %-10s %-10s %-10s\n" "$suite" "${line:-N/A}%" "${func:-N/A}%" "${branch:-N/A}%"
        fi
    done
    echo ""
done

echo "=============================================="
echo "  Observations"
echo "=============================================="
echo ""
echo "1. Spike coverage is measured on hand-written C++ instruction implementations."
echo "   Sail coverage is measured on auto-generated C code from formal Sail spec."
echo ""
echo "2. For both simulators, higher ELF count → higher coverage."
echo "   RISCOF (1,268 ELF) should dominate MicroTESK (214 ELF)."
echo ""
echo "3. Sail coverage % tends to be higher because its code is more centralized"
echo "   (generated from spec) — fewer 'dead' code paths reachable only through"
echo "   specific execution modes."
echo ""
echo "4. Key comparison dimension: which test suites find more UNIQUE code paths"
echo "   in each simulator (Delta analysis)."
echo ""
echo "DONE"
