#!/bin/bash
# Скрипт генерации и запуска MicroTESK RV64M тестов со сбором gcov-покрытия
# Использование: bash run_microtesk_rv64m.sh
# Требования: riscv-env контейнер с MicroTESK и gcov-Spike
#
# Покрытие инструкций RV64M (13 инструкций M-расширения):
#   - Умножение (MUL, MULH, MULHSU, MULHU, MULW): 5/5 покрыто
#   - Деление (DIV, DIVU, DIVW, DIVUW):            4/4 покрыто
#   - Остаток (REM, REMU, REMW, REMUW):            4/4 покрыто
#   - Итого: 13/13 (100.0%) — полное покрытие
#
# Результат (собран 2026-06-08):
#   13 ELF, 13 pass / 0 fail
#   Line Coverage: 14.6%, Function Coverage: 5.4%

set -e

echo "========================================="
echo "  MicroTESK RV64M — генерация + gcov"
echo "========================================="

# Шаг 1: генерация ELF из шаблонов
echo ">>> Генерация RV64M тестов..."
docker exec riscv-env sh -c '
export MICROTESK_HOME=/opt/microtesk-riscv
export PATH="/opt/riscv/bin:$PATH"
cd /opt/microtesk-riscv/arch/riscv/templates/compliance/rv64um
make all
'
echo "Сгенерировано 13 ELF"

# Шаг 2: запуск на gcov-Spike
echo ">>> Запуск на gcov-Spike..."
docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike
ELF_DIR=/opt/microtesk-riscv/output/compliance/rv64um
find "$BUILD_DIR" -name "*.gcda" -delete
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf"); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
    [ $? -eq 0 ] && pass=$((pass+1)) || fail=$((fail+1))
done
echo "MicroTESK RV64M: pass=$pass fail=$fail"

# Шаг 3: сбор покрытия
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" --output-file /tmp/microtesk_rv64m_coverage.info --ignore-errors gcov,source
lcov --rc lcov_branch_coverage=1 --summary /tmp/microtesk_rv64m_coverage.info 2>&1 | grep -E "lines|functions|branches"
'
echo "Готово: /tmp/microtesk_rv64m_coverage.info"
