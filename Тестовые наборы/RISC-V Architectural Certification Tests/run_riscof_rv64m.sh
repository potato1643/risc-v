#!/bin/bash
# Скрипт запуска RISCOF RV64M тестов со сбором gcov-покрытия
# Использование: bash run_riscof_rv64m.sh
# Требования: riscv-env контейнер с RISCOF и gcov-Spike

set -e

echo "========================================="
echo "  RISCOF RV64M — запуск + gcov"
echo "========================================="

docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike
ELF_DIR=/opt/riscv-arch-test/riscof-plugins/rv64/riscof_work_M

echo ">>> Очистка счётчиков gcov..."
find "$BUILD_DIR" -name "*.gcda" -delete

echo ">>> Запуск 13 RV64M тестов..."
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "ref.elf"); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
    [ $? -eq 0 ] && pass=$((pass+1)) || fail=$((fail+1))
done
echo "RISCOF RV64M: pass=$pass fail=$fail"

echo ">>> Сбор покрытия..."
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" --output-file /tmp/riscof_rv64m_coverage.info --ignore-errors gcov,source
lcov --rc lcov_branch_coverage=1 --summary /tmp/riscof_rv64m_coverage.info 2>&1 | grep -E "lines|functions|branches"
'
echo "Готово: /tmp/riscof_rv64m_coverage.info"
