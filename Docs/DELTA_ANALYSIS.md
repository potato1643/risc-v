# Delta Analysis — Combined Coverage & Unique Contributions

**Date:** 2026-06-22
**Project:** №2275, ISP RAS
**Author:** Bai Xiaoyu

---

## 1. Methodology

Delta analysis identifies the **unique coverage contribution** of each test suite by:
1. Running each suite independently on the same gcov-instrumented simulator
2. Merging coverage data: `lcov --add-tracefile`
3. Computing incremental contributions: merged(N+1) − merged(N)

The analysis was performed on **Spike** (53,227 lines denominator) — the reference RISC-V simulator.

---

## 2. Spike Coverage Data (full denominator, 53,227 lines)

### 2.1 Individual Suite Coverage

| Test Suite | ELF | Lines | Line% | Functions | Func% |
|------------|:---:|:-----:|:-----:|:---------:|:-----:|
| RISCOF ALL (IMAFDC) | 1,268 | 9,464 | **17.8%** | 1,701 | 13.6% |
| MicroTESK | 214 | 10,461 | **19.7%** | 1,835 | 14.6% |
| Imperas RV32I | 48 | 8,380 | **15.7%** | 1,546 | 12.3% |

### 2.2 Pairwise Merged Coverage

| Combination | Lines | Line% |
|-------------|:-----:|:-----:|
| RISCOF + MicroTESK | 10,837 | 20.4% |
| RISCOF + Imperas | 9,710 | 18.2% |
| MicroTESK + Imperas | 10,622 | 20.0% |
| **ALL merged** | **10,991** | **20.6%** |

### 2.3 Incremental (Delta) Contributions

| Added Suite | Base | Added Lines | +pp | Notes |
|-------------|------|:-----------:|:---:|-------|
| **MicroTESK** | RISCOF | **+1,373** | **+2.6pp** | Largest incremental gain |
| RISCOF | MicroTESK | +376 | +0.7pp | MT already covers most RISCOF paths |
| Imperas | RISCOF | +246 | +0.5pp | Nearly redundant with RISCOF |
| Imperas | RISCOF+MT | +154 | +0.3pp | Minimal unique contribution |
| MicroTESK | RISCOF+Imperas | +1,281 | +2.4pp | Consistent gain regardless of base |

---

## 3. IMAFDC-Filtered Analysis (40,374 lines)

| Test Suite | Lines | Line% |
|------------|------|:-----:|
| RISCOF ALL (IMAFDC-filtered) | 11,711 | **29.0%** |
| MicroTESK (IMAFDC-filtered) | 10,440 | **25.9%** |
| Delta (RISCOF − MT) | +1,271 | **+3.1pp** |

---

## 4. Key Findings

### 4.1 MicroTESK Is More Efficient Per-ELF

MicroTESK achieves **19.7%** with only 214 ELFs vs RISCOF's **17.8%** with 1,268 ELFs on the full denominator. Per-ELF efficiency:
- MicroTESK: 19.7% / 214 = **0.092pp per ELF**
- RISCOF: 17.8% / 1,268 = **0.014pp per ELF** (6.6× less efficient)

### 4.2 RISCOF Dominates IMAFDC-Specific Code

On IMAFDC-filtered code (40,374 lines), RISCOF leads with **29.0%** vs MicroTESK's **25.9%** (+3.1pp). This means RISCOF's broad ISA coverage excels at exercising IMAFDC-specific execution paths, while MicroTESK's algorithmic/example tests exercise more general infrastructure code.

### 4.3 Imperas Adds Minimal Unique Value

Imperas (48 ELFs, RV32I only) adds only **+0.3pp to +0.5pp** incremental coverage over existing suites. Its covered lines are almost entirely a subset of what RISCOF and MicroTESK already cover.

### 4.4 Combined Coverage Ceiling

The three suites combined reach **20.6%** — only **+0.9pp** above MicroTESK alone (19.7%). This suggests:
- Coverage is approaching a ceiling for the current test methodology
- Remaining ~80% of Spike code requires fundamentally different test approaches (privileged modes, interrupts, MMU, debug, etc.)

### 4.5 The "Full vs Filtered" Paradox

| Metric | Full (53K) | IMAFDC (40K) |
|--------|:----------:|:------------:|
| RISCOF | 17.8% | **29.0%** |
| MicroTESK | **19.7%** | 25.9% |
| Winner | **MicroTESK** | **RISCOF** |

RISCOF leads on IMAFDC code, MicroTESK leads on the full codebase. This demonstrates **complementary value**: RISCOF better exercises IMAFDC instruction implementations, while MicroTESK's algorithmic tests exercise more general simulator infrastructure.

---

## 5. Sail Perspective

| Test Suite | ELF | Sail Line% |
|------------|:---:|:----------:|
| RISCOF RV64+RV32 IMAFDC | 1,262 | **29.2%** |
| MicroTESK | 214 | **28.9%** |
| RISCOF RV32 IMAFDC | 1,103 | **28.3%** |
| Imperas RV32I | 48 | 25.3% |

On Sail (monolithic auto-generated code, build_sailcov 412K lines), RISCOF RV64+RV32 leads at 29.2%, with MicroTESK close behind at 28.9% despite 6× fewer tests — confirming MT's higher per-ELF efficiency. RISCOF achieves comparable coverage through sheer test volume (1,262 ELFs).

---

## 6. Recommendations

1. **Use both RISCOF and MicroTESK for maximum coverage** — they are complementary: RISCOF for IMAFDC breadth, MicroTESK for infrastructure depth
2. **Imperas can be deprioritized** — adds only +0.3pp over the other two
3. **To break the ~20% ceiling**: add privileged-mode tests (PMP, VM, interrupts) or use directed fuzzing
4. **The IMAFDC filter is essential** for fair ISA-level comparison
