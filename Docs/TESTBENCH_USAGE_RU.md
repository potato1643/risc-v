# Тестовый стенд RISC-V: инструкция по использованию

## 1. Общее описание

Тестовый стенд предназначен для запуска и сравнения трёх наборов тестов RISC-V на едином gcov-инструментированном симуляторе Spike:

| Набор | ISA | Тип тестов | Кол-во |
|-------|:---:|------------|:------:|
| **MicroTESK** | RV64I | Алгоритмические (ELF) | 30 |
| **RISCOF** | RV64I | Поинструкционные ISA (.S) | 50 |
| **Imperas** | RV32I | Сигнатурные (.S) | 48 |

Стенд развёрнут в двух контейнерах Docker. Все инструменты предустановлены.

| Контейнер | Назначение |
|-----------|------------|
| `riscv-env` | Spike (gcov), Sail C, RISCOF, MicroTESK, lcov |
| `compiler-lab` | Sail C, Imperas Test Suite |

---

## 2. Запуск MicroTESK (RV64I) со сбором gcov-покрытия

30 ELF-программ. Алгоритмические тесты: сортировка, деление, работа с регистрами.

```bash
docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike
ELF_DIR=/opt/microtesk-riscv/output

# Шаг 1: очистить счётчики gcov
find "$BUILD_DIR" -name "*.gcda" -delete

# Шаг 2: запустить все ELF
for elf in $(find "$ELF_DIR" -name "*.elf"); do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
done

# Шаг 3: собрать покрытие
lcov --capture --directory "$BUILD_DIR" \
     --output-file /tmp/microtesk_coverage.info \
     --ignore-errors gcov,source

# Шаг 4: HTML-отчёт
genhtml /tmp/microtesk_coverage.info \
        --output-directory /tmp/microtesk_coverage_html

echo "Отчёт: /tmp/microtesk_coverage_html/index.html"
'
```

**Ожидаемый результат:** Line Coverage 16.2%, Function Coverage 12.2%

---

## 3. Запуск RISCOF (RV64I) со сбором gcov-покрытия

50 ассемблерных файлов RV64I. Поинструкционное тестирование.

```bash
docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike

# Шаг 1: очистить счётчики gcov
find "$BUILD_DIR" -name "*.gcda" -delete

# Шаг 2: скомпилировать и запустить тесты RISCOF
export PATH="/opt/riscv/bin:$PATH"
cd /opt/riscv-arch-test/riscof-plugins/rv64
rm -rf riscof_work

riscof run --config=config.ini \
  --suite ../../riscv-test-suite/rv64i_m/I \
  --env ../../riscv-test-suite/env

# Шаг 3: запустить скомпилированные ELF на Spike
find riscof_work -name "*.elf" | while read elf; do
    timeout 10 "$SPIKE" -l "$elf" > /dev/null 2>&1
done

# Шаг 4: собрать покрытие
lcov --capture --directory "$BUILD_DIR" \
     --output-file /tmp/riscof_rv64_coverage.info \
     --ignore-errors gcov,source

echo "Отчёт собран: /tmp/riscof_rv64_coverage.info"
'
```

**Ожидаемый результат:** Line Coverage 15.5%, Function Coverage 11.8%

---

## 4. Запуск Imperas (RV32I) со сбором gcov-покрытия

48 ассемблерных файлов RV32I. Сравнение сигнатур с riscvOVPsim.

> **Примечание:** Imperas RV32I запускается с флагом `--isa=rv32i`, т.к. открытая версия содержит тесты только для RV32I.

```bash
docker exec riscv-env sh -c '
BUILD_DIR=/opt/riscv-isa-sim/build
SPIKE=/opt/riscv-isa-sim/build/spike

# Шаг 1: скомпилировать тесты Imperas
docker exec compiler-lab sh -c "
export PATH=/usr/local/bin:\$PATH
cd /opt/imperas-riscv-tests
rm -rf work/rv32i_m
make RISCV_TARGET=sail-riscv-c RISCV_DEVICE=I XLEN=32 RISCV_TARGET_FLAGS=\"--rv32\"
"

# Шаг 2: скопировать ELF в riscv-env
docker cp compiler-lab:/opt/imperas-riscv-tests/work/rv32i_m /tmp/imperas_elf

# Шаг 3: очистить счётчики gcov
find "$BUILD_DIR" -name "*.gcda" -delete

# Шаг 4: запустить ELF на Spike (с флагом --isa=rv32i)
find /tmp/imperas_elf -name "*.elf" | while read elf; do
    timeout 10 "$SPIKE" --isa=rv32i -l "$elf" > /dev/null 2>&1
done

# Шаг 5: собрать покрытие
lcov --capture --directory "$BUILD_DIR" \
     --output-file /tmp/imperas_rv32_coverage.info \
     --ignore-errors gcov,source

echo "Отчёт собран: /tmp/imperas_rv32_coverage.info"
'
```

**Ожидаемый результат:** Line Coverage 15.7%, Function Coverage 12.3%

---

## 5. Автоматизированный сбор покрытия (одна команда)

Скрипт `run_coverage.sh` в `Инструменты сбора покрытия/` автоматизирует весь цикл:

```bash
# Запустить все три набора с единой методикой
bash Инструменты\ сбора\ покрытия/run_coverage.sh
```

Скрипт последовательно:
1. Очищает счётчики gcov
2. Запускает MicroTESK → lcov
3. Очищает счётчики gcov
4. Запускает RISCOF → lcov
5. Очищает счётчики gcov
6. Запускает Imperas → lcov
7. Выводит сводную таблицу Line/Function Coverage

---

## 6. Расчёт объединённого покрытия

Для вычисления покрытия, даваемого всеми тремя наборами вместе:

```bash
docker exec riscv-env sh -c '
# Объединить три .info файла
lcov -a /tmp/microtesk_coverage.info \
     -a /tmp/riscof_rv64_coverage.info \
     -a /tmp/imperas_rv32_coverage.info \
     -o /tmp/merged_coverage.info

# Просмотр сводки
lcov --summary /tmp/merged_coverage.info

# Только исходники Spike (без системных заголовков)
lcov --extract /tmp/merged_coverage.info "/opt/riscv-isa-sim/*" \
     --output-file /tmp/spike_merged.info
lcov --summary /tmp/spike_merged.info
'
```

**Ожидаемый результат:** Line Coverage 16.9% (общий), 15.4% (Spike); Function Coverage 13.3%

---

## 7. Просмотр результатов

```bash
# Скопировать HTML-отчёт MicroTESK на хост
docker cp riscv-env:/tmp/microtesk_coverage_html ./microtesk_coverage
open ./microtesk_coverage/index.html

# Сводка покрытия в текстовом виде
docker exec riscv-env lcov --summary /tmp/microtesk_coverage.info
```

---

## 8. Контейнеры стенда

| Контейнер | Архитектура | Ключевые инструменты |
|-----------|:-----------:|---------------------|
| `riscv-env` | ARM64 | Spike (gcov), Sail C, RISCOF v1.25.3, riscv-isac, GCC, LCOV |
| `compiler-lab` | x86-64 | Sail C v0.20.1, Imperas Test Suite, GCC |

### Проверка статуса

```bash
docker ps -a | grep -E "riscv-env|compiler-lab"
docker start riscv-env    # запустить если остановлен
docker start compiler-lab
```

---

## 9. Примечания

### Imperas — RV32I

Открытая версия Imperas содержит тесты только для RV32I. Тесты RV64I описаны в документации, но исходные файлы `.S` доступны исключительно в коммерческой версии.

### Sail C simulator

Используется как эталонная модель RISC-V в фреймворке RISCOF и как тестируемое устройство для Imperas. В compiler-lab пересобран 01.06.2026 с отключённым расширением V (из-за ошибки типа в Sail v0.20.1).

### Ограничение покрытия

На данный момент gcov-покрытие собрано только для расширения **I** (базовые целочисленные инструкции). Расширения M, A, C, F, D и др. не протестированы на gcov-инструментированном Spike. Для их запуска используйте RISCOF с соответствующими CGF-файлами.
