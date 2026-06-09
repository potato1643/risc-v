#!/bin/bash
# Скрипт генерации и запуска MicroTESK RV64A тестов со сбором gcov-покрытия
# Использование: bash run_microtesk_rv64a.sh
# Требования: riscv-env контейнер с MicroTESK и gcov-Spike
#
# A-расширение (Atomic, атомарные операции) — только пользовательский режим
# Инструкции RV64A (22 всего):
#   LR.W, LR.D          — Load Reserved (загрузка с резервированием)
#   SC.W, SC.D          — Store Conditional (условная запись)
#   AMOSWAP.W/D         — атомарный обмен
#   AMOADD.W/D          — атомарное сложение
#   AMOAND.W/D          — атомарное И
#   AMOOR.W/D           — атомарное ИЛИ
#   AMOXOR.W/D          — атомарное исключающее ИЛИ
#   AMOMAX.W/D          — атомарный максимум (знаковый)
#   AMOMAXU.W/D         — атомарный максимум (беззнаковый)
#   AMOMIN.W/D          — атомарный минимум (знаковый)
#   AMOMINU.W/D         — атомарный минимум (беззнаковый)
# Все инструкции A — чисто пользовательский режим (x-регистры + память)
#
# Результат (собран 2026-06-08):
#   19 ELF, 19 pass / 0 fail
#   Line Coverage: 16.3%, Function Coverage: 12.5%
#   Инструкциональный охват: 20/22 (90.9%)
#   Пробел: LR.D и SC.D (шаблон lrsc.rb генерирует только 32-битные версии)

set -e

echo "========================================="
echo "  MicroTESK RV64A — генерация + gcov"
echo "========================================="

# Шаг 1: генерация ELF из шаблонов
echo ">>> Генерация RV64A тестов..."
docker exec riscv-env sh -c '
export MICROTESK_HOME=/opt/microtesk-riscv
export PATH="/opt/riscv/bin:$PATH"
cd /opt/microtesk-riscv/arch/riscv/templates/compliance/rv64ua
make all
'
echo ""

# Шаг 2: подсчёт сгенерированных ELF
ELF_COUNT=$(docker exec riscv-env sh -c '
find /opt/microtesk-riscv/output/compliance/rv64ua -name "*.elf" 2>/dev/null | wc -l
')
echo "Сгенерировано ELF: $ELF_COUNT"

# Шаг 3: запуск на gcov-Spike и сбор покрытия
echo ">>> Запуск на gcov-Spike..."
docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike
ELF_DIR=/opt/microtesk-riscv/output/compliance/rv64ua
REPORT_DIR=/tmp/microtesk_rv64a_coverage

mkdir -p "$REPORT_DIR"
find "$BUILD_DIR" -name "*.gcda" -delete

pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        echo "  FAIL: $(basename $elf)"
    fi
done
echo "MicroTESK RV64A: pass=$pass fail=$fail"

# Сбор покрытия
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/microtesk_rv64a_coverage.info" \
     --ignore-errors gcov,source 2>/dev/null

lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/microtesk_rv64a_coverage.info" 2>&1 | grep -E "lines|functions|branches"
'
echo ""
echo "=== Готово ==="
echo "Файл покрытия в контейнере: /tmp/microtesk_rv64a_coverage"
