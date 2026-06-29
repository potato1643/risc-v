# Документация проекта №2275

**Тестовый стенд для исследования тестовых наборов RISC-V**

---

## Основной отчёт

| Файл | Назначение |
|------|-----------|
| **[COMPARISON_REPORT_RU.md](COMPARISON_REPORT_RU.md)** | **👈 Главный документ.** Сравнительный анализ трёх тестовых наборов (RISCOF, MicroTESK, Imperas) на двух симуляторах (Spike, Sail). Все ключевые цифры — здесь. |

---

## Детальные анализы (дополняют основной отчёт)

| Файл | Что внутри | Когда читать |
|------|-----------|-------------|
| [DELTA_ANALYSIS.md](DELTA_ANALYSIS.md) | Попарное комбинирование покрытия Spike, уникальный вклад каждого набора | Нужны детали: кто сколько строк добавил, перекрытие наборов |
| [SAIL_SPEC_COVERAGE.md](SAIL_SPEC_COVERAGE.md) | Sail C-симулятор: двухуровневое покрытие (C-код + спецификация), трёхсторонняя дельта | Нужна методология spec-level coverage, детализация по ISA |
| [SPIKE_VS_SAIL_COMPARISON.md](SPIKE_VS_SAIL_COMPARISON.md) | Прямое сравнение Spike и Sail как объектов покрытия | Нужно понять разницу между симуляторами |

---

## Инструкции

| Файл | Назначение |
|------|-----------|
| [TESTBENCH_USAGE_RU.md](TESTBENCH_USAGE_RU.md) | Инструкция по развёртыванию и запуску тестового стенда |
| [TESTBENCH_USAGE_CN.md](TESTBENCH_USAGE_CN.md) | То же, на китайском |

---

## Быстрая навигация

| Вопрос | Куда смотреть |
|--------|--------------|
| Какое покрытие у RISCOF на Spike? | [COMPARISON_REPORT_RU.md §3.2](COMPARISON_REPORT_RU.md) |
| Какое покрытие у трёх наборов вместе? | [COMPARISON_REPORT_RU.md §3.3](COMPARISON_REPORT_RU.md) (Spike), [§6.1](COMPARISON_REPORT_RU.md) (Sail) |
| Какой вклад каждого набора? | [DELTA_ANALYSIS.md](DELTA_ANALYSIS.md) |
| Что такое spec-level покрытие Sail? | [SAIL_SPEC_COVERAGE.md](SAIL_SPEC_COVERAGE.md) |
| Чем отличается покрытие Spike от Sail? | [SPIKE_VS_SAIL_COMPARISON.md](SPIKE_VS_SAIL_COMPARISON.md) |
| Как запустить стенд? | [TESTBENCH_USAGE_RU.md](TESTBENCH_USAGE_RU.md) |
| Где лежат исходные .info файлы? | [`../Инструменты сбора покрытия/combined_coverage/`](../Инструменты%20сбора%20покрытия/combined_coverage/) |


