#!/bin/bash
# Скрипт автоматизированного сбора покрытия кода Spike (gcov/lcov)
# для трёх тестовых наборов: MicroTESK, RISCOF RV64I, Imperas RV32I
#
# Использование: bash run_coverage.sh
# Требования: Spike собран с флагами --coverage, установлены lcov и genhtml

set -e

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
MICROTESK_ELF_DIR="/opt/microtesk-riscv/output"
RISCOF_RV64_ELF_DIR="/opt/riscv-arch-test/riscof-plugins/rv64/riscof_work"
IMPERAS_ELF_DIR="/tmp/imperas_elf"
REPORT_DIR="/tmp/coverage_reports"

mkdir -p "$REPORT_DIR"

echo "========================================="
echo "  Сбор покрытия кода Spike (gcov/lcov)"
echo "  Тестовые наборы: MicroTESK, RISCOF, Imperas"
echo "========================================="

for suite in microtesk riscof_rv64 imperas_rv32; do
    echo ""
    echo ">>> Запуск: $suite"

    # Очистка счётчиков gcov перед каждым набором
    find "$BUILD_DIR" -name "*.gcda" -delete

    case $suite in
        microtesk)
            ELF_DIR="$MICROTESK_ELF_DIR"
            ISA_FLAG=""
            SUITE_NAME="MicroTESK (RV64I)"
            ;;
        riscof_rv64)
            ELF_DIR="$RISCOF_RV64_ELF_DIR"
            ISA_FLAG=""
            SUITE_NAME="RISCOF RV64I"
            ;;
        imperas_rv32)
            ELF_DIR="$IMPERAS_ELF_DIR"
            ISA_FLAG="--isa=rv32i"
            SUITE_NAME="Imperas RV32I"
            ;;
    esac

    pass=0
    fail=0

    for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
        timeout 10 "$SPIKE" $ISA_FLAG -l "$elf" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
        fi
    done

    echo "  $SUITE_NAME: pass=$pass fail=$fail"

    # Генерация отчёта lcov
    lcov --capture --directory "$BUILD_DIR" \
         --output-file "$REPORT_DIR/${suite}_coverage.info" \
         --ignore-errors gcov,source 2>&1 | tail -1

    # Генерация HTML-отчёта
    genhtml "$REPORT_DIR/${suite}_coverage.info" \
            --output-directory "$REPORT_DIR/${suite}_html" \
            --ignore-errors source 2>&1 | tail -1

    echo "  Отчёт: $REPORT_DIR/${suite}_html/index.html"
done

echo ""
echo "========================================="
echo "  ИТОГОВАЯ СВОДКА"
echo "========================================="
for suite in microtesk riscof_rv64 imperas_rv32; do
    echo ""
    echo "--- $suite ---"
    lcov --summary "$REPORT_DIR/${suite}_coverage.info" 2>&1 | grep -E "lines|functions"
done

echo ""
echo "Готово. HTML-отчёты в $REPORT_DIR/"
