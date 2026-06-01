# Тестовый стенд RISC-V: инструкция по использованию

## 1. Общее описание

Тестовый стенд предназначен для запуска и сравнения трёх наборов тестов RISC-V:
- **RISCOF** (RISC-V Compliance Framework) — покадровая верификация ISA
- **Imperas** — поинструкционная проверка сигнатур
- **MicroTESK** — алгоритмические тесты со сбором строчного покрытия

Стенд развёрнут в двух контейнерах Docker. Все инструменты предустановлены,
дополнительная настройка не требуется. Для работы необходим только Docker.

### Системные требования

- Docker Engine 20.10+
- Свободное место на диске: ~5 ГБ
- ОЗУ: рекомендуется 4 ГБ+

### Контейнеры стенда

| Контейнер | Назначение | Ключевые компоненты |
|-----------|-----------|-------------------|
| `riscv-env` | RISCOF + MicroTESK | Spike, Sail C, RISCOF v1.25.3, riscv-isac, GCC, LCOV |
| `compiler-lab` | Imperas + сборка Sail | Sail C v0.20.1, Imperas Test Suite, GCC |

---

## 2. Запуск тестов RISCOF

RISCOF — основной набор тестов, основанный на покрытии точек ISA (coverpoints).
Результат — процент покрытых точек спецификации.

### 2.1 RV32I: базовые целочисленные инструкции (32-bit)

**Количество:** 38 исходных файлов, 11 305 точек покрытия
**Время выполнения:** ~10 минут

```bash
docker exec riscv-env sh -c '
export PATH="/opt/riscv/bin:$PATH"
cd /opt/riscv-arch-test/riscof-plugins/rv32
rm -rf riscof_work
riscof coverage --config=config.ini \
  --cgf-file ../../coverage/dataset.cgf \
  --cgf-file ../../coverage/i/rv32i.cgf \
  --suite ../../riscv-test-suite/rv32i_m/I \
  --env ../../riscv-test-suite/env \
  -h ../../coverage/header_file.yaml --no-browser
'
```

**Как читать результаты:**
```bash
# Сводка по группам инструкций
docker exec riscv-env cat \
  /opt/riscv-arch-test/riscof-plugins/rv32/riscof_work/coverage.md
```

### 2.2 RV64I: базовые целочисленные инструкции (64-bit)

**Количество:** 50 исходных файлов, 13 624 точки покрытия
**Время выполнения:** ~12 минут

```bash
docker exec riscv-env sh -c '
export PATH="/opt/riscv/bin:$PATH"
cd /opt/riscv-arch-test/riscof-plugins/rv64
rm -rf riscof_work
riscof coverage --config=config.ini \
  --cgf-file ../../coverage/dataset.cgf \
  --cgf-file ../../coverage/i/rv64i.cgf \
  --suite ../../riscv-test-suite/rv64i_m/I \
  --env ../../riscv-test-suite/env \
  -h ../../coverage/header_file.yaml --no-browser
'
```

### 2.3 RV64M: расширение умножения и деления

**Количество:** 13 исходных файлов, 7 428 точек покрытия
**Время выполнения:** ~5 минут

```bash
docker exec riscv-env sh -c '
export PATH="/opt/riscv/bin:$PATH"
cd /opt/riscv-arch-test/riscof-plugins/rv64
rm -rf riscof_work
riscof coverage --config=config.ini \
  --cgf-file ../../coverage/dataset.cgf \
  --cgf-file ../../coverage/m/rv64m.cgf \
  --suite ../../riscv-test-suite/rv64i_m/M \
  --env ../../riscv-test-suite/env \
  -h ../../coverage/header_file.yaml --no-browser
'
```

### 2.4 Другие расширения RISCOF

RISCOF поддерживает 28+ расширений ISA. Для запуска других расширений замените
параметры `--cgf-file` и `--suite`:

| Расширение | CGF-файл | Папка тестов |
|-----------|----------|-------------|
| C (сжатые инструкции) | `../../coverage/c/rv64c.cgf` | `../../riscv-test-suite/rv64i_m/C` |
| F (float) | `../../coverage/cgfs_fext/rv64f.cgf` | `../../riscv-test-suite/rv64i_m/F` |
| D (double) | `../../coverage/cgfs_fext/rv64d.cgf` | `../../riscv-test-suite/rv64i_m/D` |
| Zicsr | `../../coverage/priv/rv32Zicsr.cgf` | `../../riscv-test-suite/rv32i_m/Zicsr` |

Пример для расширения C:
```bash
docker exec riscv-env sh -c '
export PATH="/opt/riscv/bin:$PATH"
cd /opt/riscv-arch-test/riscof-plugins/rv64
rm -rf riscof_work
riscof coverage --config=config.ini \
  --cgf-file ../../coverage/dataset.cgf \
  --cgf-file ../../coverage/c/rv64c.cgf \
  --suite ../../riscv-test-suite/rv64i_m/C \
  --env ../../riscv-test-suite/env \
  -h ../../coverage/header_file.yaml --no-browser
'
```

---

## 3. Запуск тестов Imperas

Imperas использует метод сравнения сигнатур с коммерческим симулятором riscvOVPsim.

### 3.1 RV32I (открытая версия)

**Количество:** 48 тестов
**Время выполнения:** ~5 минут
**Примечание:** открытая версия содержит только тесты RV32I. Тесты RV64I
присутствуют в документации, но исходные файлы `.S` доступны только в
коммерческой версии.

```bash
docker exec compiler-lab sh -c '
export PATH="/usr/local/bin:$PATH"
cd /opt/imperas-riscv-tests
rm -rf work/rv32i_m
make RISCV_TARGET=sail-riscv-c RISCV_DEVICE=I XLEN=32 RISCV_TARGET_FLAGS="--rv32"
'
```

**Ожидаемый результат:**
```
Check ADD-01                   ... OK
Check ADDI-01                  ... OK
...
Check I-MISALIGN_LDST-01       ... FAIL
Check XORI-01                  ... OK
--------------------------------
 FAIL: 1/48 RISCV_TARGET=sail-riscv-c XLEN=32 ...
```

---

## 4. Запуск тестов MicroTESK

MicroTESK использует алгоритмические тесты (сортировка, целочисленные операции,
работа с регистрами) и собирает строчное покрытие кода симулятора Spike
через gcov/LCOV.

**Количество:** 30 ELF-файлов
**Время выполнения:** ~3 минуты

```bash
docker exec riscv-env sh -c '
cd /opt/riscv-isa-sim/build

# Шаг 1: очистить старые данные покрытия
find . -name "*.gcda" -delete

# Шаг 2: запустить все ELF-файлы на Spike с трассировкой
find /opt/microtesk-riscv/output -name "*.elf" | while read elf; do
    echo "Running: $elf"
    /opt/riscv-isa-sim/build/spike -l "$elf" > "${elf}.log" 2>&1
    echo "Exit code: $?"
done

# Шаг 3: собрать покрытие LCOV
lcov --capture --directory . \
     --output-file /tmp/microtesk_coverage.info \
     --ignore-errors gcov,source

# Шаг 4: сгенерировать HTML-отчёт
genhtml /tmp/microtesk_coverage.info \
        --output-directory /tmp/microtesk_coverage_html

echo "Coverage report: /tmp/microtesk_coverage_html/index.html"
'
```

**Просмотр результатов покрытия:**
```bash
# Скопировать HTML-отчёт на хост-машину
docker cp riscv-env:/tmp/microtesk_coverage_html ./microtesk_coverage
open ./microtesk_coverage/index.html
```

---

## 5. Просмотр результатов

### RISCOF

```bash
# Текстовый отчёт
docker exec riscv-env cat \
  /opt/riscv-arch-test/riscof-plugins/rv32/riscof_work/coverage.md

# HTML-отчёт (скопировать на хост)
docker cp riscv-env:/opt/riscv-arch-test/riscof-plugins/rv32/riscof_work/coverage.html \
  ./riscof_rv32i_coverage.html
open ./riscof_rv32i_coverage.html
```

### Imperas

Результаты выводятся непосредственно в терминал. Пример вывода:
```
Check ADD-01        ... OK
Check ADDI-01       ... OK
...
FAIL: 1/48
```

### MicroTESK

```bash
# Строчное покрытие кода Spike
docker cp riscv-env:/tmp/microtesk_coverage_html ./microtesk_coverage
open ./microtesk_coverage/index.html
```

---

## 6. Устранение неполадок

### RISCOF показывает 0% покрытия

**Причина:** конфигурация Sail C simulator содержит несовместимые с RV32 расширения.

**Решение:** проверьте файл плагина:
```bash
docker exec riscv-env grep -A5 "Disable 64-bit" \
  /opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/riscof_sail_cSim.py
```
Должны присутствовать строки отключения Sv39, Sv48, Sv57, Svrsw60t59b, V и V-crypto расширений.

### Imperas: "32-bit ELF not supported by RV64 model"

**Причина:** Sail-симулятор по умолчанию работает в режиме RV64.

**Решение:** добавить флаг `RISCV_TARGET_FLAGS="--rv32"` к команде `make`.

### Sail: "Fatal error: exception Stack overflow"

**Причина:** ограничение размера стека в Linux (по умолчанию 8 МБ).

**Решение:** добавить `ulimit -s unlimited` перед сборкой:
```bash
docker exec compiler-lab sh -c '
ulimit -s unlimited
cd /opt/sail-riscv
DOWNLOAD_GMP=FALSE ENABLE_RISCV_TESTS=FALSE ./build_simulator.sh
'
```

### Контейнер не запускается

```bash
# Проверить статус контейнеров
docker ps -a | grep -E "riscv-env|compiler-lab"

# Запустить остановленный контейнер
docker start riscv-env
docker start compiler-lab
```

---

## 7. Структура файлов в контейнерах

### riscv-env

| Путь | Описание |
|------|----------|
| `/opt/riscv-isa-sim/build/spike` | Spike симулятор (с coverage) |
| `/opt/sail-riscv/build/c_emulator/sail_riscv_sim` | Sail C симулятор |
| `/opt/riscv/bin/riscv64-unknown-elf-gcc` | RISC-V GCC |
| `/opt/riscv-arch-test/riscof-plugins/` | Конфигурации RISCOF |
| `/opt/riscv-arch-test/riscv-test-suite/` | Исходные файлы тестов |
| `/opt/riscv-arch-test/coverage/` | CGF-файлы покрытия |
| `/opt/microtesk-riscv/output/` | ELF-файлы MicroTESK |

### compiler-lab

| Путь | Описание |
|------|----------|
| `/opt/sail-riscv/build/c_emulator/sail_riscv_sim` | Sail C симулятор (47.9 МБ) |
| `/opt/imperas-riscv-tests/` | Imperas Test Suite |
| `/usr/bin/riscv64-unknown-elf-gcc` | RISC-V GCC |
| `/usr/local/bin/riscv_sim_RV64` | Симлинк на Sail |

---

## 8. Примечания по сборке Sail C модели

Sail C модель в `compiler-lab` была пересобрана 01.06.2026 со следующими
модификациями:

1. **Расширение V отключено** — в Sail v0.20.1 обнаружена ошибка типа в файле
   `model/extensions/V/vext_control.sail` (строка 142: «Could not resolve
   quantifiers for plain_vector_access»). Расширение V и зависимые модули
   (vector_crypto, Zvabd, Zvfbfmin, Zvfbfwma) исключены из сборки.

2. **Изменённые файлы:**
   - `model/riscv.sail_project` — удалены блоки V, vector_crypto, Zvabd,
     Zvfbfmin, Zvfbfwma; удалена зависимость `V_core` из `sys` и `Zicsr`
   - `model/postlude/validate_config.sail` — функция `check_vext_config()`
     заменена на заглушку `= true`
   - `model/sys/sys_control.sail` — закомментирована инициализация V-регистров
