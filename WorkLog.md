# Журнал работ / 工作日志

Проект №2275 / 项目编号2275

---

## 2026-06-15 (понедельник / 周一)

> RISCOF RV32F/D: 1,021 тест добавлен и запущен. Итог RISCOF IMAFDC: 1,268 ELF, 29.0% — полное превосходство над MicroTESK.
> 天文时间 ~5 часов → 学术时间 ~7.5 часов

### RV32F (342 теста) / RV32F (342 测试)

- 342 .S файла, **342/342 pass** / 全部通过
- Исправление: `-DFLEN=32` в GCC (FLREG→flw, FSREG→fsw) / GCC 加 FLEN=32
- Line: 17.1%, Func: 12.4%, Branch: 2.8% (полный знаменатель)
- Скрипт: `run_riscof_rv32_F.sh`

### RV32D (679 тестов) / RV32D (679 测试)

- 679 .S файлов, **678/679 pass** (1 timeout) / 678/679 通过
- Два исправления / 两个修复:
  1. `-DFLEN=64` в GCC
  2. `model_test.h`: `ALIGNMENT=3` при FLEN==64 — 8-байтовое выравнивание для `fsd`
- Без фикса: misaligned store → trap → бесконечный цикл в epc=0x0 / 否则无限异常循环
- Line: 17.5%, Func: 12.4%, Branch: 2.8%
- Скрипт: `run_riscof_rv32_D.sh`

### Итоговый результат RISCOF FINAL

- **1,268 ELF, 1,293 pass (98.1%)** — RV64 171 + RV32 1,097
- **Line (IMAFDC-фильтр): 29.0%** — +3.1pp над MicroTESK (25.9%)
- **Func (IMAFDC-фильтр): 22.0%** — +1.4pp над MicroTESK (20.6%)
- **Branch (IMAFDC-фильтр): 13.5%** — +1.5pp над MicroTESK (12.0%)
- Полный знаменатель: Line 22.0%, Func 15.6%, Branch 3.7% / 全分母
- RV32F +1.5pp, RV32D +2.5pp → +4.0pp суммарно / 合计增长

### Документация / 文档更新

- `ANALYSIS_RISCOF_IMAFDC.md`: полностью переписан / 完全重写
- `COMPARISON_REPORT_RU.md`: 6 секций обновлены / 6 章节更新
- Три WorkLog файла синхронизированы / 三个 WorkLog 文件同步
- Memory files: cycle-10, coverage-data, next-steps, MEMORY.md, worklog.md

---

## 2026-06-13 (суббота / 周六)

> RISCOF ALL: все 24 расширения ISA. Итог: 669 ELF, 480 pass. IMAFDC 25.2%.
> Астрономическое время ~6 часов → академическое время ~9 часов

### RISCOF ALL / 全部扩展

- RV64 IMAFDC: 171 ELF (159 pass, 12 Zcb fail), 23.4% IMAFDC-фильтр
- RV32 IMAC: 82 ELF (81 pass) — **F/D не компилировались (1021 тест)**
- RV64 Privileged: 204 ELF (204 pass) — pmp, privilege, vm_pmp, vm_sv39/48/57
- RV64 Other: 212 ELF (36 pass) — B,K,Zfh,Zicond,...
- Всего: **24 расширения ISA, 669 ELF, 480 pass** / 合计

### Сравнение покрытия / 覆盖率对比

| | MicroTESK | RISCOF ALL | Δ |
|---|---|---|---|
| Line (IMAFDC) | 25.9% | 25.2% | -0.7pp |
| Func (IMAFDC) | 20.6% | **21.3%** | **+0.7pp** ✨ |
| Branch (IMAFDC) | 12.0% | **12.2%** | **+0.2pp** ✨ |

- RISCOF превосходит по functions и branches / 函数+分支超越
- Привилегированные тесты — уникальное преимущество / 特权测试是独特优势
- 1021 RV32F/D не компилируются → если исправить, обгонит по всем метрикам

### Документация / 文档

- `ANALYSIS_RISCOF_IMAFDC.md` — детальный ISA-анализ + Delta / ISA 分析 + Delta
- Все скрипты для RV64: `run_riscof_all_isa.sh`

---

## 2026-06-10 (среда / 周三)

> Веточное покрытие (branch coverage). MicroTESK: 214 ELF (rv32ud/uc пересобраны).
> Астрономическое время ~4 часа → академическое время ~6 часов

### Branch coverage /  веточное покрытие

- Во все скрипты добавлен `--rc lcov_branch_coverage=1` / 所有脚本添加
- Знаменатель: 335,876 ветвей (полный), 90,618 (IMAFDC)
- MicroTESK IMAFDC: 12.0% branch, RISCOF: 2.6%, Imperas: 2.7%
- Merged all 3: 3.3% branch (полный), 1.9% (Spike-only)

### Исправление ISA-детекции / 修复 ISA 检测

- `run_all_microtesk.sh`: детекция по `file <elf>` (32-bit → rv32gc, иначе rv64)
- Пересобраны rv32ud (1→12 ELF) и rv32uc (0→1 ELF) / 重新编译
- **MicroTESK итог: 214 ELF, pass 185, fail 29 (FP expected value mismatch)**
- Прирост покрытия: 0 (дублирование RV64 путей) / 覆盖率无增长

### Документация / 文档

- `COMPARISON_REPORT_RU.md`: +веточное покрытие, +IMAFDC 25.9%/12.0%
- Memory: coverage-data, cycle-9, next-steps, worklog.md / Memory 更新

---

## 2026-06-09 (понедельник / 周一)

> MicroTESK: полный прогон RV64 + RV32 на Spike. Итог: 202 ELF, 19.7%.
> 天文时间 ~6 часов → 学术时间 ~9 часов

### Генерация и запуск RV64 C/F/D / 生成并运行 RV64 C/F/D

- Сгенерированы 24 новых ELF: RV64C (1) + RV64F (11) + RV64D (12) / 生成 24 个新 ELF
- Инструментальный анализ C/F/D: RV64C ~96%, RV64F 100%, RV64D 100% покрытия инструкций в шаблонах / C/F/D 指令级分析
- Проблема: 16/24 F/D ELF крашат Spike (exit 255) — FPU эмуляция Spike неполная / F/D 测试崩溃 Spike
- Algorithms (7) + Examples (23) — дополнительные 30 ELF / 算法和示例测试
- Результат RV64: 138 ELF, 19.4% строк (10325/53227), 14.1% функций (1769/12526) / RV64 结果

### Генерация и запуск RV32 / 生成并运行 RV32

- 86 шаблонов rv32, 64 успешно скомпилированы / 86 个 RV32 模板，64 个编译成功
- 22 не скомпилировались: rv32ud(12) + rv32uc(1) + rv32uv(5) — генерируют 64-битный код / 22 个失败（生成 64 位代码）
- Все 64 ELF прошли на Spike (ISA=rv32gc) без ошибок / 全部 64 个 ELF 通过
- Результат RV32: 15.3% строк (8119), 11.8% функций (1484) / RV32 覆盖率

### Итоговый результат / 最终结果

- **RV64(138) + RV32(64) = 202 ELF, 19.7% (10461/53227), 14.6% функций (1835/12526)**
- Прирост от RV32: +136 строк (+0.3%) — небольшая дельта, т.к. RV64 уже покрывает 32-битные пути / RV32 增量小
- Таблица охвата расширений ISA: I/M/A/C/F/D/Zicsr с пометками ✅/⚠️/❌

### Документация / 文档更新

- Обновлён README MicroTESK: финальные данные, состав ELF, таблица ISA / 更新 MicroTESK README
- Создан ANALYSIS_RV64C_F_D.md — детальный анализ C/F/D инструкций / C/F/D 指令分析文档
- Создан run_all_microtesk.sh — скрипт полного прогона / 完整测试脚本
- Обновлены memory files: coverage-data, cycle-9, next-steps / 更新 memory 文件
- Сгенерированы HTML-отчёты: coverage_html_rv64_full/, coverage_html_combined/ / HTML 报告
- Сохранены .info файлы: microtesk_all_coverage.info (19.4%), microtesk_rv64_rv32_combined.info (19.7%) / 保存 lcov 数据

### Выводы / 结论

- MicroTESK compliance тестирование завершено — все шаблоны, способные скомпилироваться, запущены / 合规测试完成
- Единственные неохваченные расширения: V (нет в Spike), Zifencei (fence_i не компилируется) / 仅 V/Zifencei 未覆盖
- Дальше: запуск RISCOF и Imperas на том же Spike для сравнительного анализа / 下一步：RISCOF/Imperas

---

## 2026-06-03 (среда / 周三)

> recap: 在整理 RISC-V 项目的 Cycle 8
  交付物。今天完成了合并覆盖率计算(16.9%)、文档与海报对齐更新、回复老师邮件草稿。已推送3个commit，还剩 Docs
  下约15个新文件待提交。
  recap: 正在整理 Cycle 8 
  收尾工作。今天计算了合并覆盖率(16.9%)、更新了海报v7、重写了两个俄语文档、准备了回复老师邮件。下一步：提交 Docs 
  目录剩余文件到远程仓库。
  天文时间大概3个小时=》学术小时 4.5小时

### Ответ преподавателю / 回复老师

- Получена обратная связь по постеру v6 (4 вопроса) / 收到老师对海报 v6 的反馈（4个问题）
- Вычислено объединённое покрытие: 16.9% общее, 15.4% Spike / 计算了合并覆盖率：总体 16.9%，Spike 15.4%
- Delta-анализ: MicroTESK +244, Imperas +242, RISCOF +78 уник. строк / Delta 分析：各套件独有行数
- Перекрытие ~92% / 重叠率约 92%
- Объяснена роль Sail C: ref model для RISCOF, DUT для Imperas / 解释了 Sail C 的双重角色
- Задокументировано ограничение: только расширение I / 记录了局限：仅测试 I 扩展

### Документы / 文档更新

- Переписаны COMPARISON_REPORT_RU.md и TESTBENCH_USAGE_RU.md (единая методика gcov) / 重写了两个俄语文檔（统一 gcov 方法论）
- Старые версии → `_v1` / 旧版保存为 v1
- Созданы CN-версии для проверки / 创建了中文版本
- Подготовлены REPLY_DRAFT_RU.md и REPLY_DRAFT_CN.md / 准备了邮件回复草稿

### Постер / 海报

- v7: объединённое покрытие, Delta-данные, ограничение ISA, обновлён статус / v7：合并覆盖率、Delta 实数据、ISA 限制、更新状态
- Обновлены JPG/PDF / 更新了 JPG/PDF

### Инфраструктура / 基础设施

- compute_combined_coverage.sh + merged .info файлы → combined_coverage/ / 脚本和数据文件保存至仓库
- Рабочий лог (этот файл) / 工作日志（本文件）

---

## 2026-06-02 (вторник / 周二)

- Собраны данные gcov/lcov для трёх наборов / 收集了三个套件的 gcov/lcov 覆盖率数据:
  MicroTESK RV64I 16.2%/12.2%, RISCOF RV64I 15.5%/11.8%, Imperas RV32I 15.7%/12.3%
- Обновлён README тестовых наборов / 更新了测试套件 README
- Постер v6: реальные данные покрытия + критерии ТК / 海报 v6：真实覆盖率数据 + 技术任务书标准
- COMPARISON_REPORT_RU.md + TESTBENCH_USAGE_RU.md (v1) / 比较报告和使用指南初版

---

## 2026-06-01 (понедельник / 周一)

- Пересобрана Sail C v0.20.1 в compiler-lab (расширение V отключено) / 重新编译 Sail C（禁用 V 扩展）
- Imperas RV32I: 48 тестов, 47 PASS, 1 FAIL (I-MISALIGN_LDST-01) / Imperas 测试 47/48 通过
- Начат сравнительный анализ RISCOF vs Imperas (RV32I) / 开始 RISCOF vs Imperas 比较分析
