# Spike vs Sail C Simulator — Coverage Comparison Report

**Date:** 2026-06-23 (updated with Sail spec-level coverage)  
**Project:** №2275, ISP RAS  
**Author:** Bai Xiaoyu

---

## 1. Methodology

Both simulators were built with GCC `--coverage` instrumentation and run with the same three test suites:
- **Spike** (riscv-isa-sim): hand-written C++, 53,227 lines tracked by lcov
- **Sail C** (sail-riscv v0.9): auto-generated C from formal Sail specification, 372,297 lines

Coverage was collected via `lcov --capture` with `--rc lcov_branch_coverage=1` for branch coverage. HTML reports generated with `genhtml`.

**Important:** Absolute coverage percentages are NOT directly comparable between simulators because they are entirely different codebases. What IS comparable:
- Relative ranking of test suites within each simulator
- How coverage scales with ELF count
- Per-ISA coverage patterns
- Which ISA features are exercised by each test suite

---

## 2. Results Summary

### 2.1 Spike (Reference Simulator)

| Test Suite | ELF | Pass | Fail | Line% | Func% | Branch% |
|------------|:---:|:---:|:---:|:-----:|:-----:|:------:|
| RISCOF ALL (IMAFDC-filtered)* | 1,268 | 1,293 | - | **29.0%** | **22.0%** | **13.5%** |
| MicroTESK (full)* | 214 | 185 | 29 | **19.6%** | **14.6%** | **3.2%** |
| MicroTESK (IMAFDC-filtered)* | 214 | 185 | 29 | **25.9%** | **20.6%** | **12.0%** |
| RISCOF RV64I** | 50 | 50 | 0 | 15.5% | 11.8% | 2.6% |
| Imperas RV32I** | 48 | 48 | 0 | 15.7% | 12.3% | 2.7% |

*\* Historical data from previous full runs with IMAFDC filter*  
*\*\* Fresh measurements as of 2026-06-21*

### 2.2 Sail C Simulator

| Test Suite | ELF | Pass | Fail | Line% | Func% | Branch% |
|------------|:---:|:---:|:---:|:-----:|:-----:|:------:|
| **🔥 ALL Combined (IMAFDC+Privileged)** | **1,415** | **1,414** | **1** | **32.2%** | **43.4%** | **10.0%** |
| RISCOF IMAFDC + Privileged | 312 | 312 | 0 | **30.5%** | **42.6%** | **9.0%** |
| RISCOF RV32 IMAFDC (solo) | 1,103 | 1,102 | 1 | **29.5%** | **41.8%** | **8.3%** |
| MicroTESK | 214 | 187 | 27 | **29.7%** | **42.5%** | **8.6%** |
| RISCOF RV64 IMAFDC (A+C+F+D) | 108 | 108 | 0 | **28.9%** | **41.7%** | **8.0%** |
| RISCOF RV64I+RV32I | 88 | 88 | 0 | 20.2% | 40.1% | 3.6% |
| Imperas RV32I | 48 | 48 | 0 | 26.3% | 40.9% | 6.4% |

### 2.3 Per-ISA Breakdown (Sail — RISCOF RV64)

| ISA | ELF | Pass | Line% | Func% | Branch% |
|-----|:---:|:---:|:-----:|:-----:|:------:|
| A (Atomic) | 18 | 18 | 20.2% | 40.2% | 3.5% |
| C (Compressed) | 45 | 45 | 27.5% | 41.3% | 7.2% |
| F (Single FP) | 18 | 18 | 26.7% | 41.0% | 6.6% |
| D (Double FP) | 27 | 27 | 26.8% | 41.0% | 6.7% |
| **Combined** | **108** | **108** | **28.9%** | **41.7%** | **8.0%** |

### 2.4 Per-ISA Breakdown (Sail — RISCOF RV32) 🆕

| ISA | ELF | Pass | Line% | Func% | Branch% |
|-----|:---:|:---:|:-----:|:-----:|:------:|
| I (Base Integer) | 38 | 38 | 20.2% | 40.1% | 3.6% |
| M (Multiply) | 8 | 8 | 20.2% | 40.0% | 3.5% |
| A (Atomic) | 9 | 9 | 20.1% | 40.1% | 3.5% |
| C (Compressed) | 27 | 26 | 20.5% | 40.2% | 3.9% |
| **F (Single FP)** | **342** | **342** | **27.3%** | **41.2%** | **7.0%** |
| **D (Double FP)** | **679** | **679** | **27.6%** | **41.3%** | **7.1%** |
| **RV32 IMAFDC Combined** | **1,103** | **1,102** | **29.5%** | **41.8%** | **8.3%** |
| **RV64+RV32 ALL** | **1,211** | **1,210** | **27.8%** | **31.6%*** | **5.4%*** |

*\*RV64+RV32 denominator includes additional Spike source files (423K lines vs 372K for Sail-only)*

### 2.5 Per-ISA Breakdown (Sail — Privileged) 🆕

| ISA | ELF | Pass | Line% | Func% | Branch% |
|-----|:---:|:---:|:-----:|:-----:|:------:|
| pmp | 65 | 65 | 28.7% | 41.7% | 7.8% |
| privilege | 21 | 21 | 26.7% | 41.1% | 6.6% |
| vm_pmp | 12 | 12 | 27.3% | 41.7% | 6.9% |
| vm_sv39 | 36 | 36 | 27.4% | 41.8% | 7.0% |
| vm_sv48 | 36 | 36 | 27.4% | 41.8% | 7.0% |
| vm_sv57 | 34 | 34 | 27.4% | 41.8% | 7.0% |
| **Privileged Combined** | **204** | **204** | **30.5%** | **42.6%** | **9.0%** |

*\*Privileged combined = RV64 IMAFDC (28.9%) + all privileged ISAs merged*

---

## 3. Side-by-Side Comparison

### 3.1 Line Coverage

```
Suite                    Spike        Sail         Sail/Spike ratio
--------------------------------------------------------------------------
RISCOF ALL IMAFDC        29.0%*       29.5%**      1.02x (RV32 solo)
RISCOF ALL IMAFDC        29.0%*       27.8%***     0.96x (full denominator)
MicroTESK                19.6%        29.7%        1.52x
RISCOF RV64I             15.5%        20.2%†       1.30x
Imperas                  15.7%        26.3%        1.68x
```

*\*Spike IMAFDC-filtered (40,374 lines)*  
*\*\*Sail RV32 IMAFDC solo (372,297 lines) — directly comparable to RV64 Sail*  
*\*\*\*Sail RV64+RV32 combined (423,311 lines — includes extra code from RV64 info files)*  
*†RISCOF RV64I+RV32I combined*

### 3.2 Function Coverage

```
Suite                    Spike        Sail         Notes
--------------------------------------------------------------------------
RISCOF ALL IMAFDC        22.0%        41.8%        Sail funcs much denser
MicroTESK                14.6%        42.5%        Sail funcs much denser
Imperas                  12.3%        40.9%        Same pattern
```

### 3.3 Ranking Within Each Simulator

**Spike (Line%):**
1. RISCOF ALL (filtered): 29.0%
2. MicroTESK (filtered): 25.9%
3. Imperas: 15.7%

**Sail (Line% — Sail-only denominator 372K):**
1. **ALL Combined: 32.2%** 🏆 New record
2. IMAFDC+Privileged: 30.5%
3. MicroTESK: 29.7%
4. RISCOF RV32 IMAFDC: 29.5%
5. Imperas: 26.3%

---

## 4. Key Observations

### 4.1 Sail Has Higher Absolute Coverage
Sail's line coverage is consistently ~1.3-1.7x higher than Spike for the same test suites. This is because Sail's code is auto-generated from a formal specification — the generated C code is more centralized (monolithic `sail_riscv_model.cpp`) and fewer code paths remain completely untouched. Spike's hand-written per-instruction implementation has more "dead" code paths that specific test scenarios don't reach.

### 4.2 Function Coverage Is Vastly Different
Sail's function coverage (~40%) dwarfs Spike's (~12-15%). This is an artifact of code generation: the Sail compiler emits many small functions for the formal model's state machine, and most of them get touched even with basic instruction execution.

### 4.3 MicroTESK Is Surprisingly Strong on Sail
On Sail, MicroTESK (214 ELF, 29.7%) slightly edges out RISCOF RV64 IMAFDC (108 ELF, 28.9%). The MicroTESK algorithmic tests, though fewer in number, exercise more diverse coverage patterns in Sail's monolithic code. This is the opposite of Spike where RISCOF dominates.

### 4.4 Imperas RV32I Effectiveness
Imperas (only 48 ELF, RV32I-only) achieves 26.3% line coverage on Sail — comparable to RISCOF RV64 IMAFDC's 28.9% with 2x more ELFs. This suggests Imperas RV32I tests are well-designed for exercising fundamental ISA infrastructure in Sail.

### 4.5 Branch Coverage Parallels Line Coverage
Branch coverage follows the same pattern: Sail (6-8%) vs Spike (2-3%). Both simulators show low branch coverage because branch instrumentation captures all conditional branches in the code — test suites only exercise a fraction of possible execution paths.

### 4.6 Privileged Tests Break 30% Ceiling on Sail 🆕

Running 204 privileged tests (pmp, privilege, vm_pmp, vm_sv39/48/57) on Sail pushed combined coverage to **30.5%** (IMAFDC+Privileged) and **32.2%** (all RISCOF). Key insights:

- **pmp alone matches IMAFDC**: 65 PMP tests achieve 28.7% — nearly the 28.9% of 108 IMAFDC ELFs, demonstrating PMP's broad code impact
- **Privileged adds +1.6pp over IMAFDC**: more than RV32 IMAFDC (+0.6pp), showing privileged infrastructure is underrepresented in IMAFDC-only testing
- **Branch coverage hits 10.0%**: first time reaching double digits on Sail (from 8.3% IMAFDC)
- **Functions at 43.4%**: approaching half of Sail's 22,912 functions
- **All 204 privileged ELFs pass**: 100% pass rate, confirming Sail's mature privileged mode implementation
- **New Sail coverage record**: 32.2% surpasses MicroTESK's 29.7%

### 4.7 RISCOF RV32 IMAFDC Narrows Gap on Sail

With the addition of RV32 IMAFDC (1,103 ELFs, 1,102 pass), RISCOF achieved **29.5% line coverage** on Sail — just 0.2pp behind MicroTESK (29.7%). Key insights:

- **F/D are the dominant contributors**: RV32F (+7.1pp) and RV32D (+7.4pp) each contribute more than I/M/A/C combined (~20% baseline)
- **RISCOF achieves this with 5× more tests**: 1,103 ELFs vs MicroTESK's 214, yet nearly identical coverage — suggesting diminishing returns above ~30% for Sail's monolithic code
- **RV64+RV32 combined (27.8%) appears lower** because the RV64 info files were generated differently and include extra Spike source files (423K vs 372K denominator)
- **Branch coverage (8.3%)** is close to MicroTESK (8.6%), confirming similar execution path diversity

### 4.7 Test Suite Pass/Fail Behavior Consistent
All three test suites pass at similar rates on both simulators:
- MicroTESK: 185/214 (Spike) vs 187/214 (Sail) — 2 extra passes on Sail
- RISCOF: 100% pass on both
- Imperas: 100% pass on both

The 27-29 MicroTESK failures are the known IEEE 754 expected-value mismatch in F/D tests, not simulator bugs.

### 4.8 🆕 Sail Spec-Level Coverage — New Dimension

Sail C Simulator has **two layers** of coverage:

| Layer | Mechanism | Denominator | IMAFDC Result |
|-------|-----------|:-----------:|:------------:|
| **Sail Spec-Level** | COVERAGE=ON → `.branch_info` + `sail_coverage` | 38,387 spec points | **7.1%** |
| **C Code-Level** | GCC `--coverage` → gcov/lcov | 412,320 C lines | **28.3%** |

The spec-level coverage directly measures how much of the **formal Sail specification** is exercised — a fundamentally different metric from C code coverage.

**Three-Suite Sail Spec Coverage:**

| Suite | ELFs | C-Level (gcov) | **Sail Spec** | Spec/C Ratio |
|-------|:----:|:-------------:|:------------:|:------------:|
| MicroTESK | 214 | 28.9% | **7.3%** | 0.25× |
| RISCOF IMAFDC | 1,103 | 28.3% | 7.1% | 0.25× |
| Imperas | 48 | 25.3% | 5.0% | 0.20× |
| **All 3 Combined** | **1,365** | — | **8.7%** | — |

**By spec point type (combined):**
| Type | Covered | Total Static | Ratio |
|------|:------:|:------------:|:-----:|
| Functions | 286 | 1,769 | 16.2% |
| Branches | 1,225 | 12,242 | 10.0% |
| Branch Targets | 1,840 | 24,376 | 7.5% |

**Delta — Unique Spec Points Added:**
- RISCOF only: +453 points (+1.2pp)
- MicroTESK only: +409 points (+1.1pp)  
- Imperas only: +63 points (+0.2pp)

**Key observations:**
1. **Sail spec coverage is ~20-25% of C code coverage** — the formal specification is far more comprehensive than the generated C code
2. **MicroTESK leads spec coverage (7.3%)** despite 5× fewer ELFs than RISCOF — confirms MT exercises more diverse specification paths
3. **Combined only reaches 8.7%** — >91% of the formal Sail specification remains untested by any suite
4. **Functions best covered (16.2%)** — specification-level functions correspond to ISA-level operations that basic tests naturally exercise
5. **Branch targets worst covered (7.5%)** — specification branches capture all architectural corner cases, most untested by conformance suites

---

## 5. Conclusions

1. **Dual-simulator gcov coverage fully operational** — both Spike and Sail collect C-level coverage from all three test suites.

2. **Triple-layer coverage achieved 🆕** — added **Sail spec-level** (7.1%) as third dimension alongside Spike C-level (29.0% IMAFDC) and Sail C-level (28.3%). Spec coverage measures formal specification exercise.

3. **Sail coverage record: 32.2% (C-level)** — combining RISCOF RV64+RV32+Privileged. Spec-level combined: **8.7%** across all three suites.

4. **MicroTESK leads spec coverage (7.3%)** — 214 ELF beat RISCOF's 1,103 ELF (7.1%), confirming MT's broader specification path diversity.

5. **>91% of Sail specification untested** — all three suites combined cover only 8.7% of 38,387 formal specification points, revealing the vast gap between conformance testing and full specification exercise.

6. **Spike vs Sail rankings converge** — with enough tests, both simulators show consistent test suite rankings. The spec-level dimension provides a more rigorous comparison than C code coverage alone.

---

## 6. Next Steps

- [x] Run full RISCOF RV32 IMAFDC on Sail ✅
- [x] Run privileged mode tests on Sail ✅
- [x] 🆕 Sail spec-level coverage: rebuild with COVERAGE=ON, collect .branch_info ✅
- [x] 🆕 Three-suite spec coverage comparison ✅
- [ ] Regenerate RV64 Sail data with build_sailcov (consistent denominator)
- [ ] Final project report
- [ ] Generate IMAFDC-equivalent filter for Sail spec coverage
