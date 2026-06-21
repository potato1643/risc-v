# Spike vs Sail C Simulator — Coverage Comparison Report

**Date:** 2026-06-21  
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

---

## 3. Side-by-Side Comparison

### 3.1 Line Coverage

```
Suite           Spike        Sail         Sail/Spike ratio
--------------------------------------------------------------------
MicroTESK       19.6%        29.7%        1.52x
RISCOF RV64I    15.5%        20.2%*       1.30x
Imperas         15.7%        26.3%        1.68x
```

*\*RISCOF RV64I+RV32I combined*

### 3.2 Function Coverage

```
Suite           Spike        Sail         Notes
--------------------------------------------------------------------
MicroTESK       14.6%        42.5%        Sail funcs much denser
RISCOF RV64I    11.8%        40.1%        Same pattern
Imperas         12.3%        40.9%        Same pattern
```

### 3.3 Ranking Within Each Simulator

**Spike (Line%):**
1. RISCOF ALL (filtered): 29.0%
2. MicroTESK (filtered): 25.9%
3. Imperas: 15.7%

**Sail (Line%):**
1. MicroTESK: 29.7%
2. RISCOF RV64 IMAFDC: 28.9%
3. Imperas: 26.3%

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

### 4.6 Test Suite Pass/Fail Behavior Consistent
All three test suites pass at similar rates on both simulators:
- MicroTESK: 185/214 (Spike) vs 187/214 (Sail) — 2 extra passes on Sail
- RISCOF: 100% pass on both
- Imperas: 100% pass on both

The 27-29 MicroTESK failures are the known IEEE 754 expected-value mismatch in F/D tests, not simulator bugs.

---

## 5. Conclusions

1. **Both simulators successfully collect gcov coverage** with the same test suites, confirming the dual-simulator architecture works.

2. **Sail coverage is structurally different from Spike** — higher percentages across the board due to monolithic code generation. Direct % comparison is misleading; the value is in the patterns.

3. **MicroTESK shows unexpected strength on Sail**, ranking #1 (29.7%) vs RISCOF's #2 (28.9%). On Spike, RISCOF dominates (29.0% vs 25.9%).

4. **RISCOF's full potential on Sail is still untapped** — only 108 RV64 IMAFDC ELFs were run (from 1,268 total). Running the full RV32 IMAFDC (+1,097 ELFs) would likely push Sail coverage significantly higher.

5. **The dual-simulator setup is operational** — all scripts support `SIMULATOR=spike|sail`, coverage data can be compared via `compare_simulators.sh`.

---

## 6. Next Steps

- Run full RISCOF RV32 IMAFDC on Sail (1,097 ELF)
- Apply Delta analysis: unique coverage per simulator
- Generate IMAFDC-equivalent filter for Sail (if possible)
- Update poster with dual-simulator results
