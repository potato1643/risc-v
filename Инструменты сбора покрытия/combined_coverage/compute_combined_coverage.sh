#!/bin/bash
# Скрипт вычисления объединённого покрытия (Union Coverage) трёх тестовых наборов
# путём слияния .info-файлов через lcov --add-tracefile.
#
# Использование:
#   bash compute_combined_coverage.sh <microtesk.info> <riscof.info> <imperas.info>
#
# Пример:
#   bash compute_combined_coverage.sh \
#     ../microtesk_coverage.info \
#     ../riscof_rv64_coverage.info \
#     ../imperas_rv32_coverage.info
#
# Требования: lcov установлен (входит в riscv-env Docker-контейнер).

set -e

MICROTESK_INFO="${1:-../microtesk_coverage.info}"
RISCOF_INFO="${2:-../riscof_rv64_coverage.info}"
IMPERAS_INFO="${3:-../imperas_rv32_coverage.info}"
OUTDIR="${4:-.}"

mkdir -p "$OUTDIR"

echo "========================================="
echo "  Вычисление объединённого покрытия"
echo "  MicroTESK (RV64I) + RISCOF (RV64I) + Imperas (RV32I)"
echo "========================================="

# --- Шаг 1: индивидуальные сводки ---
echo ""
echo ">>> Индивидуальное покрытие"

for label in microtesk riscof imperas; do
    case $label in
        microtesk) INFO="$MICROTESK_INFO"; NAME="MicroTESK (RV64I)" ;;
        riscof)    INFO="$RISCOF_INFO";    NAME="RISCOF (RV64I)" ;;
        imperas)   INFO="$IMPERAS_INFO";   NAME="Imperas (RV32I)" ;;
    esac
    echo ""
    echo "--- $NAME ---"
    lcov --summary "$INFO" 2>&1 | grep -E "lines|functions"
done

# --- Шаг 2: полное объединение (все файлы) ---
echo ""
echo "========================================="
echo ">>> Шаг 2: объединение трёх .info (все файлы)"
echo "========================================="

lcov -a "$MICROTESK_INFO" -a "$RISCOF_INFO" -a "$IMPERAS_INFO" \
     -o "$OUTDIR/merged_all.info" 2>&1 | tail -1

echo ""
echo "--- Объединённое покрытие (все файлы) ---"
lcov --summary "$OUTDIR/merged_all.info" 2>&1 | grep -E "lines|functions"

# --- Шаг 3: объединение только исходников Spike ---
echo ""
echo "========================================="
echo ">>> Шаг 3: фильтрация — только исходники Spike"
echo "========================================="

lcov --extract "$OUTDIR/merged_all.info" "/opt/riscv-isa-sim/*" \
     --output-file "$OUTDIR/spike_merged.info" 2>&1 | tail -1

echo ""
echo "--- Объединённое покрытие (только Spike) ---"
lcov --summary "$OUTDIR/spike_merged.info" 2>&1 | grep -E "lines|functions"

# --- Шаг 4: Delta-анализ (попарные объединения) ---
echo ""
echo "========================================="
echo ">>> Шаг 4: Delta-анализ (уникальный вклад)"
echo "========================================="

# Фильтрация индивидуальных до Spike-only
for label in microtesk riscof imperas; do
    case $label in
        microtesk) INFO="$MICROTESK_INFO"; NAME="MicroTESK" ;;
        riscof)    INFO="$RISCOF_INFO";    NAME="RISCOF" ;;
        imperas)   INFO="$IMPERAS_INFO";   NAME="Imperas" ;;
    esac
    lcov --extract "$INFO" "/opt/riscv-isa-sim/*" \
         --output-file "$OUTDIR/${label}_spike.info" 2>&1 | tail -1
done

# Попарные объединения
echo ""
echo "--- Попарные объединения (Spike-only) ---"

lcov -a "$OUTDIR/microtesk_spike.info" -a "$OUTDIR/riscof_spike.info" \
     -o "$OUTDIR/m_r_spike.info" 2>&1 | tail -1
MR=$(lcov --summary "$OUTDIR/m_r_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)

lcov -a "$OUTDIR/microtesk_spike.info" -a "$OUTDIR/imperas_spike.info" \
     -o "$OUTDIR/m_i_spike.info" 2>&1 | tail -1
MI=$(lcov --summary "$OUTDIR/m_i_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)

lcov -a "$OUTDIR/riscof_spike.info" -a "$OUTDIR/imperas_spike.info" \
     -o "$OUTDIR/r_i_spike.info" 2>&1 | tail -1
RI=$(lcov --summary "$OUTDIR/r_i_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)

ALL3=$(lcov --summary "$OUTDIR/spike_merged.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)

MICROTESK_LINES=$(lcov --summary "$OUTDIR/microtesk_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)
RISCOF_LINES=$(lcov --summary "$OUTDIR/riscof_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)
IMPERAS_LINES=$(lcov --summary "$OUTDIR/imperas_spike.info" 2>&1 | grep "lines" | grep -oE "[0-9]+" | head -1)

# Уникальный вклад = All3 - (сумма двух других без этого)
UNIQ_MICROTESK=$(( ALL3 - RI ))
UNIQ_RISCOF=$(( ALL3 - MI ))
UNIQ_IMPERAS=$(( ALL3 - MR ))
OVERLAP=$(( ALL3 - UNIQ_MICROTESK - UNIQ_RISCOF - UNIQ_IMPERAS ))

echo ""
echo "========================================="
echo "  РЕЗУЛЬТАТЫ DELTA-АНАЛИЗА"
echo "========================================="
echo ""
echo "Покрыто строк (Spike-only):"
echo "  MicroTESK:  $MICROTESK_LINES"
echo "  RISCOF:     $RISCOF_LINES"
echo "  Imperas:    $IMPERAS_LINES"
echo "  Все три:    $ALL3"
echo ""
echo "Уникальный вклад (строки, покрытые только этим набором):"
echo "  MicroTESK:  +$UNIQ_MICROTESK"
echo "  RISCOF:     +$UNIQ_RISCOF"
echo "  Imperas:    +$UNIQ_IMPERAS"
echo "  Перекрытие:  $OVERLAP (>=2 наборов)"
echo ""
echo "========================================="
echo "  ГОТОВО"
echo "========================================="
echo "Выходные файлы в $OUTDIR/:"
echo "  merged_all.info        — полное объединение"
echo "  spike_merged.info      — только Spike"
echo "  microtesk_spike.info   — MicroTESK (Spike)"
echo "  riscof_spike.info      — RISCOF (Spike)"
echo "  imperas_spike.info     — Imperas (Spike)"
echo "  m_r_spike.info         — MicroTESK + RISCOF"
echo "  m_i_spike.info         — MicroTESK + Imperas"
echo "  r_i_spike.info         — RISCOF + Imperas"
