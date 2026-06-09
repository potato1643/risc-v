### Тестовые наборы RISC-V

| Набор | ISA | Тестов | Статус | Line Cov. | Func Cov. |
|-------|-----|:------:|--------|:---------:|:---------:|
| **MicroTESK I** | RV64I | 52 ELF | ✅ | 16.7% | 12.7% |
| **MicroTESK I+M** | RV64IM | 65 ELF | ✅ | 16.9% | 12.8% |
| **MicroTESK I+M+A** | RV64IMA | 84 ELF | ✅ | **17.2%** | **13.3%** |
| **RISCOF** | RV64I | 50 .S | ✅ | 15.5% | 11.8% |
| **Imperas** | RV32I | 48 .S | ✅ | 15.7% | 12.3% |
| RISCV-DV | — | — | Планируется | — | — |

#### Инструкциональный охват MicroTESK (72 I + 13 M + 22 A = 107 инструкций)

| Группа | Всего | Покрыто | % |
|--------|:---:|:---:|:---:|
| RV32I пользовательский режим | 35 | 27 | 77.1% |
| RV32I системный режим | 2 | 1 | 50.0% |
| RV64I-специфичные | 15 | 3 | 20.0% |
| Zicsr + Zifencei | 10 | 3 | 30.0% |
| Привилегированные (MRET и др.) | 10 | 1 | 10.0% |
| **RV64I итого** | **72** | **35** | **48.6%** |
| **M-расширение** | **13** | **13** | **100.0%** |
| **A-расширение** | **22** | **20** | **90.9%** |
| **MicroTESK всего** | **107** | **68** | **63.6%** |

### Структура каталогов

```
MicroTESK/
  ├── run_microtesk_rv64.sh          — скрипт сбора покрытия RV64I
  ├── run_microtesk_rv64m.sh         — скрипт сбора покрытия RV64M
  ├── run_microtesk_rv64a.sh         — скрипт сбора покрытия RV64A
  ├── microtesk_rv64i.info           — lcov данные RV64I (52 ELF)
  ├── microtesk_rv64im.info          — lcov данные I+M (65 ELF)
  ├── microtesk_rv64ima.info         — lcov данные I+M+A (84 ELF)
  ├── ANALYSIS_RV64I_M.md           — анализ RV64I + RV64M
  ├── ANALYSIS_RV64A.md             — анализ RV64A
  └── coverage_html_rv64/            — HTML-отчёт

RISC-V Architecture Test SIG/
  ├── run_riscof_rv64.sh             — скрипт сбора покрытия
  ├── riscof_rv64_coverage.info      — данные lcov
  └── coverage_html_rv64/            — HTML-отчёт

Imperas RISC-V test suite/
  ├── run_imperas_rv32.sh            — скрипт сбора покрытия
  ├── imperas_rv32_coverage.info     — данные lcov
  └── coverage_html_rv32/            — HTML-отчёт
```

### Почему Imperas — RV32I, а не RV64I?

Открытая (open-source) версия Imperas RISC-V Test Suite содержит тесты только для RV32I. Тесты RV64I описаны в документации Imperas, но исходные файлы `.S` доступны исключительно в коммерческой версии пакета. Поэтому Imperas запущен с флагом `--isa=rv32i`, а MicroTESK и RISCOF — в режиме RV64 по умолчанию Spike.

### Методика сбора покрытия

Все тестовые наборы запускаются на едином инструментированном симуляторе Spike (собран с флагами `--coverage`). После прогона каждого набора gcov/lcov собирает метрики Line Coverage и Function Coverage кода Spike. Подробнее см. скрипты `run_*_rv*.sh`.
