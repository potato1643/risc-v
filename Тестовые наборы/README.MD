### Тестовые наборы RISC-V

| Набор | ISA | Тестов | Статус | Line Cov. | Func Cov. |
|-------|-----|:------:|--------|:---------:|:---------:|
| **MicroTESK** | RV64I | 30 ELF | ✅ Запущен | 16.2% | 12.2% |
| **RISCOF** | RV64I | 50 .S | ✅ Запущен | 15.5% | 11.8% |
| **Imperas** | RV32I | 48 .S | ✅ Запущен | 15.7% | 12.3% |
| RISCV-DV | — | — | Планируется | — | — |

### Структура каталогов

```
MicroTESK/
  ├── run_microtesk_rv64.sh          — скрипт сбора покрытия
  ├── microtesk_coverage.info        — данные lcov
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

### Методика сбора покрытия

Все тестовые наборы запускаются на едином инструментированном симуляторе Spike (собран с флагами `--coverage`). После прогона каждого набора gcov/lcov собирает метрики Line Coverage и Function Coverage кода Spike. Подробнее см. скрипты `run_*_rv*.sh`.
