#!/bin/bash

# ===========================================================
# Рекурсивный запуск всех ELF-файлов (любой глубины)
# ===========================================================

ELF_ROOT="/opt/microtesk-riscv/output"
LOG_ROOT="/opt/microtesk-riscv/logs"

mkdir -p "$LOG_ROOT"

echo "Рекурсивный поиск ELF-файлов..."

find "$ELF_ROOT" -type f -name "*.elf" | while read elf; do

    rel_path="${elf#$ELF_ROOT/}"

    log_file="$LOG_ROOT/${rel_path}.log"

    mkdir -p "$(dirname "$log_file")"

    echo "Запуск: $rel_path"

    spike -l "$elf" > "$log_file" 2>&1
done

echo "Все ELF-тесты завершены."
