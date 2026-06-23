#!/bin/bash
# Скрипт автоматизированного сбора покрытия кода симулятора (gcov/lcov)
# для трёх тестовых наборов: MicroTESK, RISCOF RV64I, Imperas RV32I
#
# Использование:
#   bash run_coverage.sh [spike|sail]
#   SIMULATOR=sail bash run_coverage.sh    (альтернативный способ)
#
# Требования: симулятор собран с флагами --coverage, установлены lcov и genhtml

set -e

# --- Выбор симулятора ---
SIMULATOR="${1:-${SIMULATOR:-spike}}"

case "$SIMULATOR" in
    spike)
        SIM_BIN="/opt/riscv-isa-sim/build/spike"
        BUILD_DIR="/opt/riscv-isa-sim/build"
        RUN_SIM="run_spike"
        ;;
    sail)
        SIM_BIN="/opt/sail-riscv/build_sailcov/c_emulator/sail_riscv_sim"
        BUILD_DIR="/opt/sail-riscv/build_sailcov"
        SAIL_CONFIG_RV64="/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json"
        SAIL_CONFIG_RV32="/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env/sail_config.json"
        RUN_SIM="run_sail"
        ;;
    *)
        echo "ERROR: неизвестный симулятор '$SIMULATOR'. Используйте spike или sail."
        exit 1
        ;;
esac

MICROTESK_ELF_DIR="/opt/microtesk-riscv/output"
RISCOF_RV64_ELF_DIR="/opt/riscv-arch-test/riscof-plugins/rv64/riscof_work"
IMPERAS_ELF_DIR="/tmp/imperas_elf"
REPORT_DIR="/tmp/coverage_reports_${SIMULATOR}"

mkdir -p "$REPORT_DIR"

# --- Функции запуска на симуляторе ---
run_spike() {
    local elf="$1"
    local isa_flag="$2"
    timeout 10 "$SIM_BIN" $isa_flag -l "$elf" > /dev/null 2>&1
}

run_sail() {
    local elf="$1"
    local config="$2"   # путь к JSON-конфигу Sail
    timeout 10 "$SIM_BIN" --config="$config" --test-signature=/dev/null "$elf" > /dev/null 2>&1
}

echo "========================================="
echo "  Сбор покрытия кода ($SIMULATOR simulator, gcov/lcov)"
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
            SAIL_CONFIG="$SAIL_CONFIG_RV64"
            SUITE_NAME="MicroTESK (RV64I)"
            ;;
        riscof_rv64)
            ELF_DIR="$RISCOF_RV64_ELF_DIR"
            ISA_FLAG=""
            SAIL_CONFIG="$SAIL_CONFIG_RV64"
            SUITE_NAME="RISCOF RV64I"
            ;;
        imperas_rv32)
            ELF_DIR="$IMPERAS_ELF_DIR"
            ISA_FLAG="--isa=rv32i"
            SAIL_CONFIG="$SAIL_CONFIG_RV32"
            SUITE_NAME="Imperas RV32I"
            ;;
    esac

    pass=0
    fail=0

    for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
        if [ "$SIMULATOR" = "spike" ]; then
            run_spike "$elf" "$ISA_FLAG"
        else
            run_sail "$elf" "$SAIL_CONFIG"
        fi
        if [ $? -eq 0 ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
        fi
    done

    echo "  $SUITE_NAME: pass=$pass fail=$fail"

    # Генерация отчёта lcov
    lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
         --output-file "$REPORT_DIR/${suite}_coverage.info" \
         --ignore-errors gcov,source 2>&1 | tail -1

    # Генерация HTML-отчёта
    genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/${suite}_coverage.info" \
            --output-directory "$REPORT_DIR/${suite}_html" \
            --ignore-errors source 2>&1 | tail -1

    echo "  Отчёт: $REPORT_DIR/${suite}_html/index.html"
done

echo ""
echo "========================================="
echo "  ИТОГОВАЯ СВОДКА ($SIMULATOR)"
echo "========================================="
for suite in microtesk riscof_rv64 imperas_rv32; do
    echo ""
    echo "--- $suite ---"
    lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/${suite}_coverage.info" 2>&1 | grep -E "lines|functions|branches"
done

echo ""
echo "Готово. HTML-отчёты в $REPORT_DIR/"
