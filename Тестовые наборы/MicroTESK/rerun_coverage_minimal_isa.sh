#!/bin/bash
# =============================================================================
# Пересбор покрытия MicroTESK с минимальной ISA для каждого расширения
# =============================================================================
# Проблема: старые .info файлы собраны с ISA по умолчанию (rv64imafdc_zicntr_zihpm),
#   что включает код неиспользуемых расширений (F, D, M в RV64I и т.д.) — ~14% шума.
# Решение: для каждого расширения указываем минимальную ISA:
#   RV64I → --isa=rv64ic       (I + C, C обязателен для toolchain)
#   RV64M → --isa=rv64imc      (I + M + C)
#   RV64A → --isa=rv64iac      (I + A + C)
#
# Использование: bash rerun_coverage_minimal_isa.sh
# Требования: riscv-env контейнер с MicroTESK и gcov-Spike
# =============================================================================

SPIKE="/opt/riscv-isa-sim/build/spike"
BUILD_DIR="/opt/riscv-isa-sim/build"
MICROTESK_HOME="/opt/microtesk-riscv"
TEMPLATE_DIR="$MICROTESK_HOME/arch/riscv/templates/compliance"
OUTPUT_DIR="$MICROTESK_HOME/output/compliance"
REPORT_BASE="/tmp/microtesk_minimal_isa"

mkdir -p "$REPORT_BASE"

export MICROTESK_HOME
export PATH="/opt/riscv/bin:$PATH"

echo "========================================="
echo "  MicroTESK: пересбор покрытия"
echo "  с минимальной ISA"
echo "========================================="

# =============================================================================
# Функция: генерация ELF (без clean — только если ELF нет)
# =============================================================================
generate_elfs() {
    local ext=$1
    local template=$2
    local dir="$OUTPUT_DIR/$template"

    local existing=$(find "$dir" -name "*.elf" 2>/dev/null | wc -l)
    if [ "$existing" -gt 0 ]; then
        echo ">>> $ext: уже $existing ELF, пропускаем генерацию"
        return 0
    fi

    echo ">>> Генерация $ext ELF (шаблон: $template)..."
    cd "$TEMPLATE_DIR/$template"
    make all 2>&1 | tail -5
    local count=$(find "$dir" -name "*.elf" 2>/dev/null | wc -l)
    echo "    Сгенерировано ELF: $count"
}

# =============================================================================
# Функция: запуск тестов и сбор покрытия
# =============================================================================
run_and_collect() {
    local label=$1
    local isa=$2
    local elf_subdirs=$3
    local out_file="$REPORT_BASE/microtesk_${label}_coverage_minimal.info"

    echo ""
    echo "========================================="
    echo "  $label (--isa=$isa)"
    echo "========================================="

    # Очистка счётчиков
    find "$BUILD_DIR" -name "*.gcda" -delete 2>/dev/null || true

    # Сбор всех ELF
    local all_elfs=""
    for subdir in $elf_subdirs; do
        local dir="$OUTPUT_DIR/$subdir"
        if [ -d "$dir" ]; then
            all_elfs="$all_elfs $(find "$dir" -name '*.elf' 2>/dev/null)"
        fi
    done

    if [ -z "$all_elfs" ]; then
        echo "ПРЕДУПРЕЖДЕНИЕ: ELF не найдены в: $elf_subdirs"
        return 1
    fi

    local total=$(echo $all_elfs | wc -w)
    echo "  Найдено ELF: $total"

    # Прогон
    local pass=0 fail=0
    for elf in $all_elfs; do
        timeout 10 "$SPIKE" --isa="$isa" -l "$elf" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            echo "  FAIL: $(basename $(dirname $elf))/$(basename $elf)"
        fi
    done
    echo "  Результат: pass=$pass fail=$fail"

    # Сбор покрытия
    lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
         --output-file "$out_file" \
         --ignore-errors gcov,source 2>/dev/null

    echo "  Покрытие:"
    lcov --rc lcov_branch_coverage=1 --summary "$out_file" 2>&1 | grep -E "lines|functions|branches"

    echo "  Сохранено: $out_file"
}

# =============================================================================
# Шаг 1: Генерация ELF (только для отсутствующих)
# =============================================================================
echo ""
echo "=== Шаг 1: Проверка/генерация ELF ==="

generate_elfs "RV64I (user)"       "rv64ui"
generate_elfs "RV64I (machine)"    "rv64mi"
generate_elfs "RV64I (supervisor)" "rv64si"
generate_elfs "RV64M"              "rv64um"
generate_elfs "RV64A"              "rv64ua"

# =============================================================================
# Шаг 2: Запуск и сбор покрытия
# =============================================================================
echo ""
echo "=== Шаг 2: Запуск тестов и сбор покрытия ==="

run_and_collect "rv64i" "rv64ic" "rv64ui rv64mi rv64si"
run_and_collect "rv64m" "rv64imc" "rv64um"
run_and_collect "rv64a" "rv64iac" "rv64ua"

# =============================================================================
# Шаг 3: Сводка
# =============================================================================
echo ""
echo "========================================="
echo "  Сводка результатов"
echo "========================================="
for info in "$REPORT_BASE"/*.info; do
    [ -f "$info" ] || continue
    echo ""
    echo "--- $(basename $info) ---"
    lcov --rc lcov_branch_coverage=1 --summary "$info" 2>&1 | grep -E "lines|functions|branches"
done

echo ""
echo "Все .info файлы: $REPORT_BASE/"
ls -lh "$REPORT_BASE/"*.info 2>/dev/null
echo ""
echo "=== Готово ==="
