#!/bin/bash
# Сбор покрытия кода Spike (gcov/lcov) для тестового набора Imperas (RV32I)
# Требует предварительного копирования ELF-файлов из compiler-lab:
#   docker exec compiler-lab tar czf /tmp/imperas_elf.tar.gz -C /opt/imperas-riscv-tests/work/rv32i_m/I .
#   docker cp compiler-lab:/tmp/imperas_elf.tar.gz /tmp/imperas_elf.tar.gz
#   docker cp /tmp/imperas_elf.tar.gz riscv-env:/tmp/
#   docker exec riscv-env sh -c 'mkdir -p /tmp/imperas_elf && tar xzf /tmp/imperas_elf.tar.gz -C /tmp/imperas_elf'
# Spike должен быть собран с флагами --coverage

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
ELF_DIR="/tmp/imperas_elf"
REPORT_DIR="/tmp/imperas_coverage"

mkdir -p "$REPORT_DIR"

echo "=== Imperas RV32I: сбор покрытия Spike ==="

# Проверка наличия ELF-файлов
if [ ! -d "$ELF_DIR" ] || [ -z "$(ls -A "$ELF_DIR"/*.elf 2>/dev/null)" ]; then
    echo "ОШИБКА: ELF-файлы Imperas не найдены в $ELF_DIR"
    echo "Скопируйте их из контейнера compiler-lab (см. комментарий в начале скрипта)"
    exit 1
fi

# Очистка счётчиков
echo "Очистка старых .gcda..."
find "$BUILD_DIR" -name "*.gcda" -delete

# Прогон всех ELF-файлов Imperas (RV32I — флаг --isa=rv32i)
pass=0; fail=0
for elf in $(find "$ELF_DIR" -name "*.elf" 2>/dev/null); do
    timeout 10 "$SPIKE" --isa=rv32i -l "$elf" > /dev/null 2>&1
    if [ $? -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done
echo "Imperas RV32I: pass=$pass fail=$fail"

# Сбор покрытия
lcov --capture --directory "$BUILD_DIR" \
     --output-file "$REPORT_DIR/imperas_coverage.info" \
     --ignore-errors gcov,source

# HTML-отчёт
genhtml "$REPORT_DIR/imperas_coverage.info" \
        --output-directory "$REPORT_DIR/html" \
        --ignore-errors source

echo ""
echo "=== Результаты Imperas RV32I ==="
lcov --summary "$REPORT_DIR/imperas_coverage.info" 2>&1 | grep -E "lines|functions"
echo "HTML-отчёт: $REPORT_DIR/html/index.html"
