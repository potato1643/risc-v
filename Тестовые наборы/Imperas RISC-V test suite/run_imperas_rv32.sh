#!/bin/bash
# Сбор покрытия кода симулятора (gcov/lcov) для тестового набора Imperas (RV32I)
# Требует предварительного копирования ELF-файлов из compiler-lab:
#   docker exec compiler-lab tar czf /tmp/imperas_elf.tar.gz -C /opt/imperas-riscv-tests/work/rv32i_m/I .
#   docker cp compiler-lab:/tmp/imperas_elf.tar.gz /tmp/imperas_elf.tar.gz
#   docker cp /tmp/imperas_elf.tar.gz riscv-env:/tmp/
#   docker exec riscv-env sh -c 'mkdir -p /tmp/imperas_elf && tar xzf /tmp/imperas_elf.tar.gz -C /tmp/imperas_elf'
# Симулятор должен быть собран с флагами --coverage
#
# Использование:
#   bash run_imperas_rv32.sh [spike|sail]
#   SIMULATOR=sail bash run_imperas_rv32.sh

# --- Выбор симулятора ---
SIMULATOR="${1:-${SIMULATOR:-spike}}"

case "$SIMULATOR" in
    spike)
        SIM_BIN="/opt/riscv-isa-sim/build/spike"
        BUILD_DIR="/opt/riscv-isa-sim/build"
        ;;
    sail)
        SIM_BIN="/opt/sail-riscv/build_sailcov/c_emulator/sail_riscv_sim"
        BUILD_DIR="/opt/sail-riscv/build_sailcov"
        SAIL_CONFIG="/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env/sail_config.json"
        ;;
    *)
        echo "ERROR: неизвестный симулятор '$SIMULATOR'. Используйте spike или sail."
        exit 1
        ;;
esac

ELF_DIR="/tmp/imperas_elf"
REPORT_DIR="/tmp/imperas_coverage_${SIMULATOR}"

mkdir -p "$REPORT_DIR"

echo "=== Imperas RV32I: сбор покрытия ($SIMULATOR) ==="

# Проверка наличия ELF-файлов
if [ ! -d "$ELF_DIR" ] || [ -z "$(ls -A "$ELF_DIR"/*.elf 2>/dev/null)" ]; then
    echo "ОШИБКА: ELF-файлы Imperas не найдены в $ELF_DIR"
    echo "Скопируйте их из контейнера compiler-lab (см. комментарий в начале скрипта)"
    exit 1
fi

# Очистка счётчиков
echo "Очистка старых .gcda..."
find "$BUILD_DIR" -name "*.gcda" -delete

# Прогон всех ELF-файлов Imperas (RV32I)
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
    if [ "$SIMULATOR" = "spike" ]; then
        timeout 10 "$SIM_BIN" --isa=rv32i -l "$elf" > /dev/null 2>&1
    else
        timeout 10 "$SIM_BIN" --config="$SAIL_CONFIG" --test-signature=/dev/null "$elf" > /dev/null 2>&1
    fi
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done
echo "Imperas RV32I ($SIMULATOR): pass=$pass fail=$fail"

# Сбор покрытия
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/imperas_coverage.info" \
     --ignore-errors gcov,source

# HTML-отчёт
genhtml --rc genhtml_branch_coverage=1 "$REPORT_DIR/imperas_coverage.info" \
        --output-directory "$REPORT_DIR/html" \
        --ignore-errors source

echo ""
echo "=== Результаты Imperas RV32I ($SIMULATOR) ==="
lcov --rc lcov_branch_coverage=1 --summary "$REPORT_DIR/imperas_coverage.info" 2>&1 | grep -E "lines|functions|branches"
echo "HTML-отчёт: $REPORT_DIR/html/index.html"
