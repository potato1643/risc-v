# Тестовый стенд RISC-V: инструкция по использованию

## 1. Общее описание

Тестовый стенд предназначен для запуска и сравнения трёх наборов тестов RISC-V на едином gcov-инструментированном симуляторе Spike:

| Набор | ISA | Тип тестов | Кол-во |
|-------|:---:|------------|:------:|
| **MicroTESK** | RV64IMAFDC+RV32 | Алгоритмические (ELF) | 214 |
| **RISCOF** | RV64I | Поинструкционные ISA (.S) | 50 |
| **Imperas** | RV32I | Сигнатурные (.S) | 48 |

Стенд развёрнут в двух контейнерах Docker. Все инструменты предустановлены.

| Контейнер | Назначение |
|-----------|------------|
| `riscv-env` | Spike (gcov), Sail C, RISCOF, MicroTESK, lcov |
| `compiler-lab` | Sail C, Imperas Test Suite |

---

## 2. Запуск MicroTESK (RV64IMAFDC + RV32) со сбором gcov-покрытия

214 ELF-программ. Покрытие расширений I, M, A, C, F, D. Алгоритмические тесты + compliance-тесты. Включая RV32F/D/C.

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
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file /tmp/microtesk_coverage.info \
     --ignore-errors gcov,source

# Шаг 4: HTML-отчёт
genhtml --rc genhtml_branch_coverage=1 /tmp/microtesk_coverage.info \
        --output-directory /tmp/microtesk_coverage_html

echo "Отчёт: /tmp/microtesk_coverage_html/index.html"
'
```

**Ожидаемый результат:** Line Coverage 19.6%, Function Coverage 14.6%, Branch Coverage 3.2%

> IMAFDC-фильтр: Line 25.9%, Function 20.6%, Branch 12.0%

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
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file /tmp/riscof_rv64_coverage.info \
     --ignore-errors gcov,source

echo "Отчёт собран: /tmp/riscof_rv64_coverage.info"
'
```

**Ожидаемый результат:** Line Coverage 15.5%, Function Coverage 11.8%, Branch Coverage 2.6%

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
lcov --rc lcov_branch_coverage=1 --capture --directory "$BUILD_DIR" \
     --output-file /tmp/imperas_rv32_coverage.info \
     --ignore-errors gcov,source

echo "Отчёт собран: /tmp/imperas_rv32_coverage.info"
'
```

**Ожидаемый результат:** Line Coverage 15.7%, Function Coverage 12.3%, Branch Coverage 2.7%

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
7. Выводит сводную таблицу Line/Function/Branch Coverage

---

## 6. Расчёт объединённого покрытия

Для вычисления покрытия, даваемого всеми тремя наборами вместе:

```bash
docker exec riscv-env sh -c '
# Объединить три .info файла
lcov --rc lcov_branch_coverage=1 -a /tmp/microtesk_coverage.info \
     -a /tmp/riscof_rv64_coverage.info \
     -a /tmp/imperas_rv32_coverage.info \
     -o /tmp/merged_coverage.info

# Просмотр сводки
lcov --rc lcov_branch_coverage=1 --summary /tmp/merged_coverage.info

# Только исходники Spike (без системных заголовков)
lcov --rc lcov_branch_coverage=1 --extract /tmp/merged_coverage.info "/opt/riscv-isa-sim/*" \
     --output-file /tmp/spike_merged.info
lcov --rc lcov_branch_coverage=1 --summary /tmp/spike_merged.info
'
```

**Ожидаемый результат:** Line Coverage 19.9% (общий), 19.0% (Spike); Function Coverage 15.0%; Branch Coverage 3.3% (общий), 1.9% (Spike)

---

## 7. Просмотр результатов

```bash
# Скопировать HTML-отчёт MicroTESK на хост
docker cp riscv-env:/tmp/microtesk_coverage_html ./microtesk_coverage
open ./microtesk_coverage/index.html

# Сводка покрытия в текстовом виде
docker exec riscv-env lcov --rc lcov_branch_coverage=1 --summary /tmp/microtesk_coverage.info
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

## 10. Запуск тестов на Sail C Simulator

Все скрипты запуска тестов поддерживают выбор симулятора через переменную `SIMULATOR` или первый аргумент командной строки.

### 10.1 Выбор симулятора

```bash
# Способ 1: переменная окружения
SIMULATOR=sail bash run_riscof_all_isa.sh A C F D

# Способ 2: первый аргумент
bash run_riscof_all_isa.sh sail A C F D
```

Поддерживаемые значения: `spike` (по умолчанию) или `sail`.

### 10.2 Доступные скрипты

| Скрипт | Назначение | ELF (Spike) | ELF (Sail) |
|--------|------------|:-----------:|:----------:|
| `run_riscof_all_isa.sh` | RV64 IMAFDC + Privileged | 312 | 312 |
| `run_riscof_rv32_imafdc.sh` | RV32 IMAFDC (из исходников) | 1,103 | 1,103 |
| `run_all_microtesk.sh` | MicroTESK алгоритмические | 214 | 214 |
| `run_imperas_rv32.sh` | Imperas RV32I | 48 | 48 |

### 10.3 Пример: RISCOF RV32 IMAFDC на Sail

```bash
cd "Тестовые наборы/RISC-V Architectural Certification Tests"

# Запустить все RV32 IMAFDC на Sail
SIMULATOR=sail bash run_riscof_rv32_imafdc.sh sail I M A C F D
```

Вывод:
```
============================================
  RISCOF RV32 IMAFDC Coverage Collection
  Simulator: sail
============================================
ISAs: I M A C F D

--- ISA I: 38 ELFs ---
  Compiled: 38/38
  Running tests on sail...
  Result: pass=38 fail=0 timeout=0
  Coverage:
  lines......: 20.2% (75264 of 372297 lines)
  functions..: 40.1% (9188 of 22912 functions)
  branches...: 3.6% (11343 of 313342 branches)
  Saved: riscof_sail_rv32_I_coverage.info
...
============================================
  Phase 3: Combined RV32 + RV64 IMAFDC
============================================
RV32 IMAFDC combined:
  lines......: 29.5% (109673 of 372297 lines)
  functions..: 41.8% (9576 of 22912 functions)
  branches...: 8.3% (25969 of 313342 branches)
```

### 10.4 Пример: Привилегированные тесты на Sail

```bash
cd "Тестовые наборы/RISC-V Architectural Certification Tests"
SIMULATOR=sail bash run_riscof_all_isa.sh sail pmp privilege vm_pmp vm_sv39 vm_sv48 vm_sv57
```

204 ELF. Результат: IMAFDC+Privileged = 30.5%, ALL = 32.2%.

### 10.5 Просмотр покрытия Sail

**Текстовый формат (lcov summary):**
```bash
docker exec riscv-env sh -c "
lcov --rc lcov_branch_coverage=1 --summary /tmp/riscof_rv32_results/riscof_sail_rv32_imafdc.info 2>&1 | grep -E 'lines|functions|branches'
"
# lines......: 29.5% (109673 of 372297 lines)
# functions..: 41.8% (9576 of 22912 functions)
# branches...: 8.3% (25969 of 313342 branches)
```

**HTML-отчёт (в браузере):**
```bash
# HTML-отчёт генерируется автоматически скриптом run_riscof_all_isa.sh
# находится в:
open "Тестовые наборы/RISC-V Architectural Certification Tests/coverage_html_riscof_sail_combined/index.html"
```

**Сгенерировать HTML вручную:**
```bash
docker exec riscv-env sh -c "
genhtml --rc genhtml_branch_coverage=1 \
    /tmp/riscof_rv32_results/riscof_sail_rv32_imafdc.info \
    --output-directory /tmp/sail_html
"
docker cp riscv-env:/tmp/sail_html ./sail_html
open ./sail_html/index.html
```

### 10.6 Файлы покрытия Sail (.info)

| Файл | Содержание | Строки | % |
|------|-----------|:------:|:--:|
| `riscof_sail_rv32_imafdc.info` | RV32 IMAFDC | 109,673 | 29.5% |
| `riscof_sail_imafdc_combined.info` | RV64 IMAFDC | 107,598 | 28.9% |
| `riscof_sail_imafdc_priv_combined.info` | IMAFDC+Privileged | 113,503 | 30.5% |
| `riscof_sail_everything.info` | ALL (RV64+RV32+Priv) | 119,788 | **32.2%** |

Все файлы в: `Тестовые наборы/RISC-V Architectural Certification Tests/riscof_sail_*.info`

### 10.7 Сводка покрытия Sail по наборам тестов

| Тестовый набор | ELF | Line% | Func% | Branch% |
|----------------|:---:|:-----:|:-----:|:------:|
| RISCOF ALL (RV64+RV32+Priv) | 1,415 | **32.2%** | 43.4% | 10.0% |
| RISCOF IMAFDC + Privileged | 312 | 30.5% | 42.6% | 9.0% |
| MicroTESK | 214 | **29.7%** | **42.5%** | **8.6%** |
| RISCOF RV32 IMAFDC | 1,103 | 29.5% | 41.8% | 8.3% |
| RISCOF RV64 IMAFDC | 108 | 28.9% | 41.7% | 8.0% |
| Imperas RV32I | 48 | 26.3% | 40.9% | 6.4% |

> **Примечание:** Sail — автосгенерированный C-код из формальной спецификации (372,297 строк). Процент покрытия НЕ сопоставим напрямую со Spike (ручной C++, 53,227 строк). Сравнивать можно относительный рейтинг тестовых наборов внутри каждого симулятора.

### 10.8 Сборка Sail с gcov (при необходимости)

Подробная инструкция: `Симуляторы/sail_build_notes.md`

```bash
docker exec riscv-env sh -c '
export PATH="/opt/sail/bin:$PATH"
cd /opt/sail-riscv
mkdir -p build_cov && cd build_cov
cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_FLAGS="--coverage -g -O0" \
    -DCMAKE_CXX_FLAGS="--coverage -g -O0" \
    -DCMAKE_EXE_LINKER_FLAGS="--coverage"
cmake --build . -j$(nproc)
'
# Бинарный файл: /opt/sail-riscv/build_cov/c_emulator/sail_riscv_sim
```

---

## 11. Примечания

### Imperas — RV32I

Открытая версия Imperas содержит тесты только для RV32I. Тесты RV64I описаны в документации, но исходные файлы `.S` доступны исключительно в коммерческой версии. M, C, F, D директории существуют, но пусты.

### Sail C simulator

Используется как эталонная модель RISC-V в фреймворке RISCOF и как тестируемое устройство для Imperas. В compiler-lab пересобран 01.06.2026 с отключённым расширением V (из-за ошибки типа в Sail v0.20.1).

**Сбор покрытия на Sail:** Все скрипты запуска тестов поддерживают параметр `SIMULATOR=sail` для сбора покрытия на Sail C вместо Spike. Подробнее см. раздел 10 «Запуск тестов на Sail C Simulator».

### Ограничение покрытия

По состоянию на 2026-06-22 gcov-покрытие собрано для расширений **I, M, A, C, F, D** и **привилегированного режима** (pmp, privilege, vm_pmp, vm_sv39/48/57):
- Spike: 20.6% линий (полный), 29.0% (IMAFDC-фильтр)
- Sail: 32.2% линий (рекорд), 10.0% ветвей

Не протестированы: V (векторное), B (битовые операции), Crypto, Hypervisor, Zfh, Zfa, CBO и др.

- **Branch coverage** (веточное покрытие) добавлено 2026-06-09: все скрипты обновлены флагом `--rc lcov_branch_coverage=1`
- F/D тесты MicroTESK покрывают инструкции FPU, но проверка ожидаемых значений не проходит (подробнее: `ANALYSIS_FP_CRASH_ROOT_CAUSE.md`)
- **Delta-анализ:** `Docs/DELTA_ANALYSIS.md` — объединённое покрытие трёх наборов (20.6%), уникальный вклад каждого
