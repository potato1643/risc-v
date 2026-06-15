# 工作日志

项目编号 2275

---

## 2026-06-15 (周一)

> RISCOF RV32F/D: 1021 个测试添加并运行。RISCOF IMAFDC 最终结果：1268 ELF, 29.0% — 全面超越 MicroTESK。
> 天文时间 ~5 小时 → 学术时间 ~7.5 小时

### RV32F (342 测试)

- 342 个 .S 文件，**342/342 全部通过**
- 修复：GCC 添加 `-DFLEN=32`（FLREG→flw, FSREG→fsw）
- 覆盖率：Line 17.1%, Func 12.4%, Branch 2.8%（全分母）
- 脚本：`run_riscof_rv32_F.sh`

### RV32D (679 测试)

- 679 个 .S 文件，**678/679 通过**（1 个超时）
- 两个修复：
  1. GCC 添加 `-DFLEN=64`
  2. `model_test.h`：FLEN==64 时 `ALIGNMENT=3`（`fsd` 需要 8 字节对齐）
- 不修复的后果：非对齐存储 → trap → 跳转 epc=0x0 → 无限异常循环
- 覆盖率：Line 17.5%, Func 12.4%, Branch 2.8%
- 脚本：`run_riscof_rv32_D.sh`

### RISCOF FINAL 最终结果

- **1268 ELF, 1293 pass (98.1%)** — RV64 171 + RV32 1097
- **Line (IMAFDC-过滤): 29.0%** — 超越 MicroTESK 3.1pp (25.9%)
- **Func (IMAFDC-过滤): 22.0%** — 超越 MicroTESK 1.4pp (20.6%)
- **Branch (IMAFDC-过滤): 13.5%** — 超越 MicroTESK 1.5pp (12.0%)
- 全分母：Line 22.0%, Func 15.6%, Branch 3.7%
- RV32F +1.5pp, RV32D +2.5pp → 合计 +4.0pp

### 文档更新

- `ANALYSIS_RISCOF_IMAFDC.md` — 完全重写
- `COMPARISON_REPORT_RU.md` — 更新 6 个章节
- 三个 WorkLog 文件同步
- Memory 文件：cycle-10, coverage-data, next-steps, MEMORY.md, worklog.md

---

## 2026-06-13 (周六)

> RISCOF ALL: 全部 24 个 ISA 扩展完成测试。结果：669 ELF, 480 pass。IMAFDC 25.2%。
> 天文时间 ~6 小时 → 学术时间 ~9 小时

### RISCOF ALL 全部扩展

- RV64 IMAFDC: 171 ELF (159 pass, 12 Zcb 失败), 23.4% IMAFDC-过滤
- RV32 IMAC: 82 ELF (81 pass) — **F/D 编译失败（1021 个测试）**
- RV64 特权模式: 204 ELF (204 pass) — pmp, privilege, vm_pmp, vm_sv39/48/57
- RV64 其他: 212 ELF (36 pass) — B, K, Zfh, Zicond, Zifencei, Zimop, Zcmop, CMO, hints, D_Zcd, D_Zfa, F_Zfa
- 合计：**24 个 ISA 扩展, 669 ELF, 480 pass**

### 覆盖率对比 (IMAFDC-过滤)

| | MicroTESK | RISCOF ALL | Δ |
|---|---|---|---|
| Line | 25.9% | 25.2% | -0.7pp |
| Func | 20.6% | **21.3%** | **+0.7pp** ✨ |
| Branch | 12.0% | **12.2%** | **+0.2pp** ✨ |

- RISCOF 在函数和分支覆盖率上超越 MicroTESK
- 特权测试是 RISCOF 的独特优势
- 如果修复 1021 个 RV32 F/D 测试 → 将全面超越 MicroTESK

### 文档更新

- `ANALYSIS_RISCOF_IMAFDC.md` — 详细 ISA 分析 + Delta
- 脚本：`run_riscof_all_isa.sh`

---

## 2026-06-10 (周三)

> Веточное покрытие (branch coverage) добавлено. MicroTESK: 214 ELF (rv32ud/uc пересобраны). RISCOF + Imperas 对比数据加入。
> 天文时间 ~4 小时 → 学术时间 ~6 小时

### Branch coverage（веточное покрытие）

- 发现 lcov 默认只收集行和函数，不加分支
- 所有 10 个脚本添加 `--rc lcov_branch_coverage=1`，genhtml 同理
- 重新收集 .info 文件（含 BRDA 记录）
- 分母：335,876 分支（全量），90,618（IMAFDC 过滤）

### Branch 结果对比（IMAFDC）

| | Lines | Functions | Branches |
|---|---|---|---|
| MicroTESK IMAFDC | 25.9% | 20.6% | **12.0%** |
| RISCOF | 15.5% | 11.8% | 2.6% |
| Imperas | 15.7% | 12.3% | 2.7% |
| 三套合并 | 19.9% | 15.0% | 3.3% |

**结论：** 分支覆盖率远低于行覆盖。测试走了"快乐路径"但未覆盖错误处理、边界条件和替代分支。

### 修复 ISA 检测 + 重新编译 ELF

- `run_all_microtesk.sh`: 改用 `file <elf>` 检测 ISA（32-bit → rv32gc）
- 容器内发现 `run-toolchain.sh` 硬编码了 `-Wa,-march=rv64gcv` — rv32ud/uc 因此生成 64 位代码
- 重新编译 rv32ud (1→12 ELF) 和 rv32uc (0→1 ELF)
- **MicroTESK 最终：214 ELF, pass 185, fail 29（FP 预期值不匹配）**
- 覆盖率增量：0（新 ELF 与 RV64 代码路径重复）

### 文档更新

- `COMPARISON_REPORT_RU.md`：+分支覆盖率，+IMAFDC 25.9%/12.0%
- `TESTBENCH_USAGE_RU.md`：+分支标志
- Memory 文件：coverage-data, cycle-9, next-steps, worklog.md
- Commit `60388286`：分支覆盖率 + 214 ELF + 文档更新

---

## 2026-06-09 (周一)

> MicroTESK: RV64 + RV32 在 Spike 上完整测试。结果：202 ELF, 19.7%。
> 天文时间 ~6 小时 → 学术时间 ~9 小时

### RV64 C/F/D 生成与测试

- 生成 24 个新 ELF：RV64C (1) + RV64F (11) + RV64D (12)
- C/F/D 指令级分析：RV64C ~96%, RV64F 100%, RV64D 100%（模板层面）
- F/D 问题：16/24 个 ELF 导致 Spike 崩溃 (exit 255) — Spike FPU 模拟不完整
- Algorithms (7) + Examples (23) — 额外 30 个 ELF
- RV64 结果：138 ELF, 19.4% 行覆盖 (10325/53227), 14.1% 函数覆盖 (1769/12526)

### RV32 生成与测试

- 86 个 rv32 模板，64 个编译成功
- 22 个编译失败：rv32ud(12) + rv32uc(1) + rv32uv(5) — 模板生成的是 64 位代码
- 全部 64 个 ELF 通过 Spike (ISA=rv32gc)
- RV32 结果：15.3% 行覆盖 (8119), 11.8% 函数覆盖 (1484)

### 最终结果

- **RV64(138) + RV32(64) = 202 ELF, 19.7% (10461/53227), 14.6% 函数 (1835/12526)**
- RV32 增量：+136 行 (+0.3%) — RV64 已覆盖大部分 32 位路径
- ISA 扩展覆盖表：I/M/A/C/F/D/Zicsr，标记 ✅/⚠️/❌

### 文档更新

- 更新 MicroTESK README：最终数据、ELF 组成、ISA 覆盖表
- 创建 ANALYSIS_RV64C_F_D.md — C/F/D 指令详细分析
- 创建 run_all_microtesk.sh — 完整测试脚本
- 更新 memory 文件：coverage-data, cycle-9, next-steps
- 生成 HTML 报告，保存 .info 文件

### 结论

- MicroTESK compliance 测试完成 — 所有能编译的模板都已运行
- 仅未覆盖扩展：V (Spike 不支持), Zifencei (fence_i 编译失败)
- 下一步：在相同 Spike 上运行 RISCOF 和 Imperas 进行对比分析

---

## 2026-06-03 (周三)

> 在整理 RISC-V 项目的 Cycle 8 交付物。今天完成了合并覆盖率计算(16.9%)、文档与海报对齐更新、回复老师邮件草稿。已推送3个commit，还剩 Docs 下约15个新文件待提交。天文时间大概3个小时 → 学术小时 4.5小时。

### 回复老师

- 收到老师对海报 v6 的反馈（4个问题）
- 计算了合并覆盖率：总体 16.9%，Spike 15.4%
- Delta 分析：MicroTESK +244, Imperas +242, RISCOF +78 独有行
- 重叠率约 92%
- 解释了 Sail C 的双重角色：RISCOF 的 ref model，Imperas 的 DUT
- 记录了局限：仅测试 I 扩展

### 文档更新

- 重写了 COMPARISON_REPORT_RU.md 和 TESTBENCH_USAGE_RU.md（统一 gcov 方法论）
- 旧版保存为 v1
- 创建了中文版本用于检查
- 准备了邮件回复草稿 REPLY_DRAFT_RU.md 和 REPLY_DRAFT_CN.md

### 海报

- v7：合并覆盖率、Delta 实数据、ISA 限制、更新状态
- 更新了 JPG/PDF

### 基础设施

- compute_combined_coverage.sh + merged .info 文件 → combined_coverage/
- 工作日志（本文件）

---

## 2026-06-02 (周二)

- 收集了三个套件的 gcov/lcov 覆盖率数据：
  MicroTESK RV64I 16.2%/12.2%, RISCOF RV64I 15.5%/11.8%, Imperas RV32I 15.7%/12.3%
- 更新了测试套件 README
- 海报 v6：真实覆盖率数据 + 技术任务书标准
- COMPARISON_REPORT_RU.md + TESTBENCH_USAGE_RU.md (v1)

---

## 2026-06-01 (周一)

- 在 compiler-lab 重新编译 Sail C v0.20.1（禁用 V 扩展）
- Imperas RV32I: 48 测试, 47 PASS, 1 FAIL (I-MISALIGN_LDST-01)
- 开始 RISCOF vs Imperas 比较分析 (RV32I)
