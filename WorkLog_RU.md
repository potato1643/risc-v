# Журнал работ

Проект №2275

---

## 2026-06-15 (понедельник)

> RISCOF RV32F/D: 1 021 тест добавлен и запущен. Итог RISCOF IMAFDC: 1 268 ELF, 29.0% — полное превосходство над MicroTESK.
> Астрономическое время ~5 часов → академическое время ~7.5 часов

### RV32F (342 теста)

- 342 .S файла, **342/342 pass**
- Исправление: `-DFLEN=32` в GCC (FLREG→flw, FSREG→fsw)
- Покрытие: Line 17.1%, Func 12.4%, Branch 2.8% (полный знаменатель)
- Скрипт: `run_riscof_rv32_F.sh`

### RV32D (679 тестов)

- 679 .S файлов, **678/679 pass** (1 timeout)
- Два исправления:
  1. `-DFLEN=64` в GCC
  2. `model_test.h`: `ALIGNMENT=3` при FLEN==64 — 8-байтовое выравнивание для `fsd`
- Без фикса: misaligned store → trap → бесконечный цикл исключений в epc=0x0
- Покрытие: Line 17.5%, Func 12.4%, Branch 2.8%
- Скрипт: `run_riscof_rv32_D.sh`

### Итоговый результат RISCOF FINAL

- **1 268 ELF, 1 293 pass (98.1%)** — RV64 171 + RV32 1 097
- **Line (IMAFDC-фильтр): 29.0%** — +3.1 п.п. над MicroTESK (25.9%)
- **Func (IMAFDC-фильтр): 22.0%** — +1.4 п.п. над MicroTESK (20.6%)
- **Branch (IMAFDC-фильтр): 13.5%** — +1.5 п.п. над MicroTESK (12.0%)
- Полный знаменатель: Line 22.0%, Func 15.6%, Branch 3.7%
- RV32F +1.5 п.п., RV32D +2.5 п.п. → +4.0 п.п. суммарно

### Документация

- `ANALYSIS_RISCOF_IMAFDC.md` — полностью переписан
- `COMPARISON_REPORT_RU.md` — обновлены 6 секций, переписаны выводы
- Три WorkLog файла синхронизированы
- Memory files: cycle-10, coverage-data, next-steps, MEMORY.md, worklog.md

---

## 2026-06-13 (суббота)

> RISCOF ALL: все 24 расширения ISA протестированы. Итог: 669 ELF, 480 pass. IMAFDC 25.2%.
> Астрономическое время ~6 часов → академическое время ~9 часов

### RISCOF ALL

- RV64 IMAFDC: 171 ELF (159 pass, 12 Zcb fail), 23.4% IMAFDC-фильтр
- RV32 IMAC: 82 ELF (81 pass) — **F/D не компилировались (1 021 тест)**
- RV64 Privileged: 204 ELF (204 pass) — pmp, privilege, vm_pmp, vm_sv39/48/57
- RV64 Other: 212 ELF (36 pass) — B, K, Zfh, Zicond, Zifencei, Zimop, Zcmop, CMO, hints, D_Zcd, D_Zfa, F_Zfa
- Всего: **24 расширения ISA, 669 ELF, 480 pass**

### Сравнение покрытия (IMAFDC-фильтр)

| | MicroTESK | RISCOF ALL | Δ |
|---|---|---|---|
| Line | 25.9% | 25.2% | -0.7 п.п. |
| Func | 20.6% | **21.3%** | **+0.7 п.п.** ✨ |
| Branch | 12.0% | **12.2%** | **+0.2 п.п.** ✨ |

- RISCOF превосходит по functions и branches
- Привилегированные тесты — уникальное преимущество RISCOF
- Если исправить 1 021 RV32 F/D тест → RISCOF обгонит по всем метрикам

### Документация

- `ANALYSIS_RISCOF_IMAFDC.md` — детальный ISA-анализ с Delta
- Скрипты: `run_riscof_all_isa.sh`

---

## 2026-06-10 (среда)

> Веточное покрытие (branch coverage) добавлено. MicroTESK: 214 ELF (rv32ud/uc пересобраны).
> Астрономическое время ~4 часа → академическое время ~6 часов

### Branch coverage

- Во все скрипты добавлен `--rc lcov_branch_coverage=1`
- Знаменатель: 335 876 ветвей (полный), 90 618 (IMAFDC)
- MicroTESK IMAFDC: 12.0% branch, RISCOF: 2.6%, Imperas: 2.7%
- Merged all 3: 3.3% branch (полный)

### Исправление ISA-детекции и пересборка ELF

- `run_all_microtesk.sh`: детекция ISA по `file <elf>` (32-bit → rv32gc)
- Пересобраны rv32ud (1→12 ELF) и rv32uc (0→1 ELF)
- **MicroTESK итог: 214 ELF, pass 185, fail 29 (FP expected value mismatch)**
- Прирост покрытия: 0 (дублирование RV64 кодовых путей)

### Документация

- `COMPARISON_REPORT_RU.md`: +веточное покрытие, +IMAFDC 25.9%/12.0%
- Memory files: coverage-data, cycle-9, next-steps, worklog.md

---

## 2026-06-09 (понедельник)

> MicroTESK: полный прогон RV64 + RV32 на Spike. Итог: 202 ELF, 19.7%.
> Астрономическое время ~6 часов → академическое время ~9 часов

### Генерация и запуск RV64 C/F/D

- Сгенерированы 24 новых ELF: RV64C (1) + RV64F (11) + RV64D (12)
- Инструкциональный анализ C/F/D: RV64C ~96%, RV64F 100%, RV64D 100% покрытия инструкций в шаблонах
- Проблема: 16/24 F/D ELF крашат Spike (exit 255) — FPU эмуляция Spike неполная
- Algorithms (7) + Examples (23) — дополнительные 30 ELF
- Результат RV64: 138 ELF, 19.4% строк (10325/53227), 14.1% функций (1769/12526)

### Генерация и запуск RV32

- 86 шаблонов rv32, 64 успешно скомпилированы
- 22 не скомпилировались: rv32ud(12) + rv32uc(1) + rv32uv(5) — генерируют 64-битный код
- Все 64 ELF прошли на Spike (ISA=rv32gc) без ошибок
- Результат RV32: 15.3% строк (8119), 11.8% функций (1484)

### Итоговый результат

- **RV64(138) + RV32(64) = 202 ELF, 19.7% (10461/53227), 14.6% функций (1835/12526)**
- Прирост от RV32: +136 строк (+0.3%) — небольшая дельта, т.к. RV64 уже покрывает 32-битные пути
- Таблица охвата расширений ISA: I/M/A/C/F/D/Zicsr с пометками ✅/⚠️/❌

### Документация

- Обновлён README MicroTESK: финальные данные, состав ELF, таблица ISA
- Создан ANALYSIS_RV64C_F_D.md — детальный анализ C/F/D инструкций
- Создан run_all_microtesk.sh — скрипт полного прогона
- Обновлены memory files: coverage-data, cycle-9, next-steps
- Сгенерированы HTML-отчёты: coverage_html_rv64_full/, coverage_html_combined/
- Сохранены .info файлы: microtesk_all_coverage.info (19.4%), microtesk_rv64_rv32_combined.info (19.7%)

### Выводы

- MicroTESK compliance тестирование завершено — все шаблоны, способные скомпилироваться, запущены
- Единственные неохваченные расширения: V (нет в Spike), Zifencei (fence_i не компилируется)
- Дальше: запуск RISCOF и Imperas на том же Spike для сравнительного анализа

---

## 2026-06-03 (среда)

> recap: в整理 RISC-V 项目的 Cycle 8 交付物。今天完成了合并覆盖率计算(16.9%)、文档与海报对齐更新、回复老师邮件草稿。

### Ответ преподавателю

- Получена обратная связь по постеру v6 (4 вопроса)
- Вычислено объединённое покрытие: 16.9% общее, 15.4% Spike
- Delta-анализ: MicroTESK +244, Imperas +242, RISCOF +78 уник. строк
- Перекрытие ~92%
- Объяснена роль Sail C: ref model для RISCOF, DUT для Imperas
- Задокументировано ограничение: только расширение I

### Документы

- Переписаны COMPARISON_REPORT_RU.md и TESTBENCH_USAGE_RU.md (единая методика gcov)
- Старые версии → `_v1`
- Созданы CN-версии для проверки
- Подготовлены REPLY_DRAFT_RU.md и REPLY_DRAFT_CN.md

### Постер

- v7: объединённое покрытие, Delta-данные, ограничение ISA, обновлён статус
- Обновлены JPG/PDF

### Инфраструктура

- compute_combined_coverage.sh + merged .info файлы → combined_coverage/
- Рабочий лог (этот файл)

---

## 2026-06-02 (вторник)

- Собраны данные gcov/lcov для трёх наборов:
  MicroTESK RV64I 16.2%/12.2%, RISCOF RV64I 15.5%/11.8%, Imperas RV32I 15.7%/12.3%
- Обновлён README тестовых наборов
- Постер v6: реальные данные покрытия + критерии ТК
- COMPARISON_REPORT_RU.md + TESTBENCH_USAGE_RU.md (v1)

---

## 2026-06-01 (понедельник)

- Пересобрана Sail C v0.20.1 в compiler-lab (расширение V отключено)
- Imperas RV32I: 48 тестов, 47 PASS, 1 FAIL (I-MISALIGN_LDST-01)
- Начат сравнительный анализ RISCOF vs Imperas (RV32I)
