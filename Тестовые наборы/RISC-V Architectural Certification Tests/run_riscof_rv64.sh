#!/bin/bash
# Сбор покрытия кода Spike (gcov/lcov) для тестового набора RISCOF (RV64I)
# Spike должен быть собран с флагами --coverage

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
ELF_DIR="/opt/riscv-arch-test/riscof-plugins/rv64/riscof_work"
REPORT_DIR="/tmp/riscof_coverage"

mkdir -p "$REPORT_DIR"

echo "=== RISCOF RV64I: сбор покрытия Spike ==="

# Очистка счётчиков
echo "Очистка старых .gcda..."
find "$BUILD_DIR" -name "*.gcda" -delete

# Прогон всех ELF-файлов RISCOF RV64I
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done
echo "RISCOF RV64I: pass=$pass fail=$fail"

# Сбор покрытия
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/riscof_coverage.info" \
     --ignore-errors gcov,source

# HTML-отчёт
genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/riscof_coverage.info" \
        --output-directory "$REPORT_DIR/html" \
        --ignore-errors source

echo ""
echo "=== Результаты RISCOF RV64I ==="
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/riscof_coverage.info" 2>&1 | grep -E "lines|functions|branches"
echo "HTML-отчёт: $REPORT_DIR/html/index.html"
