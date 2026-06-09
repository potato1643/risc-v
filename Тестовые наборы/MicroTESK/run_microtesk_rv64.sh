#!/bin/bash
# Сбор покрытия кода Spike (gcov/lcov) для тестового набора MicroTESK (RV64I)
# Spike должен быть собран с флагами --coverage
#
# Покрытие инструкций RV64I (72 инструкции):
#   - Пользовательский режим: 27/35 покрыто (77.1%)
#   - RV64I-специфичные:      3/15 покрыто (20.0%)
#   - Zicsr:                  3/6  покрыто (50.0%)
#   - Привилегированные:      1/10 покрыто (10.0%)
#   - Итого:                  35/72 (48.6%)
#
# Основные пробелы:
#   - Сдвиги (SLL/SRL/SRA и W-варианты): 12 инструкций — 0 выполнений
#   - Беззнаковые операции (BLTU/BGEU/LBU/LHU/LWU/SLTU/SLTIU): 7 инстр.
#   - JAL: 0 выполнений (используется только JALR)
#
# Результат (собран 2026-06-02):
#   30 ELF, 29 pass / 1 fail
#   Line Coverage: 16.2%, Function Coverage: 12.2%

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
ELF_DIR="/opt/microtesk-riscv/output"
REPORT_DIR="/tmp/microtesk_coverage"

mkdir -p "$REPORT_DIR"

echo "=== MicroTESK RV64I: сбор покрытия Spike ==="

# Очистка счётчиков
echo "Очистка старых .gcda..."
find "$BUILD_DIR" -name "*.gcda" -delete

# Прогон всех ELF-файлов
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done
echo "MicroTESK: pass=$pass fail=$fail"

# Сбор покрытия
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/microtesk_coverage.info" \
     --ignore-errors gcov,source

# HTML-отчёт
genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/microtesk_coverage.info" \
        --output-directory "$REPORT_DIR/html" \
        --ignore-errors source

echo ""
echo "=== Результаты MicroTESK ==="
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_coverage.info" 2>&1 | grep -E "lines|functions|branches"
echo "HTML-отчёт: $REPORT_DIR/html/index.html"
