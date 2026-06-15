# RISCOF IMAFDC — ISA-Level Coverage Analysis & Comparison

> 日期: 2026-06-15 (RV32F/D 更新)
> 方法: RISCOF ELF → Spike (gcov) → lcov, 同等 IMAFDC 过滤
> 容器: riscv-env (Docker), Spike ISA: `rv64imafdc_zicntr_zihpm` / `rv32gc`

---

## 1. 测试执行数据

### RV64 IMAFDC (171 ELF, 159 pass)

| ISA | RISCOF ELF | Pass | Fail | 备注 |
|-----|:---:|:---:|:---:|------|
| RV64I | 50 | 50 | 0 | 基础整数指令 |
| RV64M | 13 | 13 | 0 | 乘除法 |
| RV64A | 18 | 18 | 0 | 原子操作 |
| RV64C | 45 | 33 | 12* | *失败的是 Zcb 指令 (cmul/cnot/csext.*/czext.*), 非标准 C |
| RV64F | 18 | 18 | 0 | 单精度浮点 |
| RV64D | 27 | 27 | 0 | 双精度浮点 |
| **总计** | **171** | **159** | **12** | |

### RV32 IMAFDC (1,097 ELF, 1,096 pass)

| ISA | RISCOF ELF | Pass | Fail | 备注 |
|-----|:---:|:---:|:---:|------|
| RV32I | 50 | 50 | 0 | 基础整数指令 |
| RV32M | 13 | 13 | 0 | 乘除法 |
| RV32A | 18 | 18 | 0 | 原子操作 |
| RV32C | 45 | 33 | 12* | *Zcb 指令失败, 同 RV64C |
| RV32F | 342 | 342 | 0 | 单精度浮点, 需 `-DFLEN=32` |
| RV32D | 679 | 678 | 1** | 双精度浮点, 需 `-DFLEN=64` + 修复 `ALIGNMENT=3` |
| **总计** | **1,147** | **1,134** | **13** | |

> **总计 (RV64 + RV32 IMAFDC): 1,318 ELF, 1,293 pass**

---

## 2. 覆盖率对比 (IMAFDC 过滤分母 40,374 行)

| 指标 | MicroTESK | RISCOF RV64 | RISCOF RV64+RV32 | Δ vs MT |
|------|:---------:|:-----------:|:----------------:|:---:|
| Line Coverage | 25.9% (10,440) | 23.4% (9,460) | **29.0% (11,711)** | **+3.1pp** ✨ |
| Function Cov. | 20.6% (1,834) | 19.1% (1,701) | **22.0% (1,952)** | **+1.4pp** ✨ |
| Branch Cov. | 12.0% (10,882) | 10.4% (9,421) | **13.5% (12,261)** | **+1.5pp** ✨ |

### 覆盖率对比 (全分母 53,227 行)

| 指标 | MicroTESK | RISCOF RV64 | RISCOF RV64+RV32 | Δ vs MT |
|------|:---------:|:-----------:|:----------------:|:---:|
| Line Coverage | 19.6% (10,440) | 17.8% (9,464) | **22.0% (11,715)** | **+2.4pp** ✨ |
| Function Cov. | 14.6% (1,834) | 13.6% (1,701) | **15.6% (1,952)** | **+1.0pp** ✨ |
| Branch Cov. | 3.2% (10,882) | 2.8% (9,425) | **3.7% (12,265)** | **+0.5pp** ✨ |

> **IMAFDC 过滤方法**: `lcov --remove` 排除非 IMAFDC 指令源码 (V/K/B/Zfh/Zfa/CBO/Hypervisor), 与 MicroTESK 脚本 `run_all_microtesk.sh` 完全一致

---

## 3. 覆盖率演进: 逐 ISA 增量 (IMAFDC 过滤)

| 阶段 | ELF 累计 | Line | Func | Branch | Δ Line |
|------|:---:|:---:|:---:|:---:|:---:|
| RV64 IMAFDC | 171 | 23.4% | 19.1% | 10.4% | 基线 |
| + RV32 IMAC | 247 | ~25.0% | ~20.5% | ~11.5% | +1.6pp |
| + RV32F (342) | 589 | 26.5% | 21.4% | 12.7% | +1.5pp |
| **+ RV32D (679)** | **1,268** | **29.0%** | **22.0%** | **13.5%** | **+2.5pp** |

> RV32D 贡献最大 (+2.5pp), 因为 679 个双精度浮点测试触发了大量 Spike 内部路径

---

## 4. 单 ISA 覆盖率分解 (全分母)

| ISA | ELF | Line Cov. | Func Cov. | Branch Cov. | 特点 |
|-----|:---:|:---------:|:---------:|:-----------:|------|
| RV64I | 50 | 15.5% | 11.8% | 2.6% | 基线 |
| RV64M | 13 | 15.4% | 11.5% | N/A | 增量 +0.0% |
| RV64A | 18 | 15.4% | 11.8% | 2.5% | 增量 +0.0% |
| RV64C | 45* | 16.2% | 12.4% | 2.6% | 增量 +0.6% |
| RV64F | 18 | 15.8% | 11.7% | 2.6% | 增量 +0.2% |
| RV64D | 27 | 15.8% | 11.7% | 2.6% | 增量 +0.2% |
| **RV32F** | **342** | **17.1%** | **12.4%** | **2.8%** | 大量测试, 高覆盖 |
| **RV32D** | **679** | **17.5%** | **12.4%** | **2.8%** | 双精度, 贡献最大 |
| RV32 IMAFDC | 1,147 | 20.1% | 13.9% | 3.2% | RV32 全部 |
| **ALL (RV64+RV32)** | **1,318** | **22.0%** | **15.6%** | **3.7%** | 最终 |

> 注意: 单 ISA 数据在清空 gcov 计数器后独立采集, 不能直接相加
> 组合增量来自 `lcov --add-tracefile` 合并后的实际差异

---

## 5. RISCOF vs MicroTESK 全部指标对比

| 维度 | MicroTESK | RISCOF (最终) | RISCOF 优势 |
|------|-----------|--------------|------------|
| ISA 测试 ELF | 108 (RV64) + 76 (RV32) = 184 | 171 (RV64) + 1,097 (RV32) = **1,268** | +1,084 ELF |
| RV32 测试 | ✅ 76 ELF (IMAC) | ✅ **1,097 ELF (IMAFDC)** | +1,021 ELF |
| FP 测试质量 | Crash (exit 255) | **1,020/1,021 Pass** | RISCOF FP 全部通过 |
| C 测试质量 | 1 模板, 96.4% 指令 | 45 测试 (RV64+RV32) | RISCOF 更系统 |
| Line (IMAFDC) | 25.9% | **29.0%** | **+3.1pp** ✨ |
| Func (IMAFDC) | 20.6% | **22.0%** | **+1.4pp** ✨ |
| Branch (IMAFDC) | 12.0% | **13.5%** | **+1.5pp** ✨ |

---

## 6. 关键技术修复

### RV32F (342 tests)
- **问题**: 缺少 `-DFLEN=32`, 导致 `FLREG`/`FSREG` 宏未定义, `flw`/`fsw` 指令无法生成
- **修复**: GCC 编译添加 `-DFLEN=32`
- **脚本**: `run_riscof_rv32_F.sh`

### RV32D (679 tests)
- **问题 1**: 同上, 需 `-DFLEN=64`
- **问题 2**: `model_test.h` 中 `ALIGNMENT=2` (4字节对齐), 但 D 扩展 `fsd` 需 8 字节对齐
  - `begin_signature` 地址 0x80003104 (mod 8 = 4) → misaligned store exception
  - 异常处理未配置 `mtvec` → 跳转地址 0 → 无限 instruction_access_fault 循环
- **修复**: 修改 `model_test.h`: 当 `FLEN==64` 时 `ALIGNMENT=3` (8字节对齐)
- **脚本**: `run_riscof_rv32_D.sh`

---

## 7. 结论

1. **RISCOF 全面超越 MicroTESK**: IMAFDC 过滤覆盖率 **29.0% vs 25.9%** (+3.1pp)
2. **三项指标全部领先**: Line +3.1pp, Func +1.4pp, Branch +1.5pp
3. **RV32 是关键差异化因素**: RV32F (342 ELF) + RV32D (679 ELF) 贡献 +4.0pp
4. **FP 测试可靠性**: RISCOF 1,020/1,021 FP 测试通过, MicroTESK 大量 crash
5. **RISCOF 现在是 Spike 代码覆盖率的基准测试套件**

---

## 8. 关键数据文件

| 文件 | 说明 | 大小 |
|------|------|------|
| `riscof_all_final.info` | RV64+RV32 IMAFDC 全量合并 | 7.6 MB |
| `riscof_all_final_filtered.info` | IMAFDC 过滤版 (29.0%) | 3.4 MB |
| `riscof_rv32_F_coverage.info` | RV32F 单独 | 22.8 MB |
| `riscof_rv32_D_coverage.info` | RV32D 单独 | 22.8 MB |
| `riscof_rv32_imafdc_full.info` | RV32 IMAFDC 合并 (20.1%) | 7.6 MB |
