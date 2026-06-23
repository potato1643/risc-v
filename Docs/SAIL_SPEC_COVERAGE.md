# Sail Spec-Level Coverage Analysis

## Overview

Sail C Simulator has **two layers** of coverage:

| Layer | Mechanism | What it Measures | Previous Status |
|-------|-----------|-----------------|:---------------:|
| **Sail Spec-Level** | `COVERAGE=ON` → `--c-coverage` → `.branch_info` + `sail_coverage` | Formal Sail specification exercise | ❌ Not collected |
| **C Code-Level** | GCC `--coverage` → gcov/lcov `.info` | Generated C code exercise | ✅ Collected |

This analysis is the **first-ever** collection and comparison of both layers.

## Build: Sail with COVERAGE=ON

- **Binary**: `/opt/sail-riscv/build_sailcov/c_emulator/sail_riscv_sim` (75 MB)
- **Static reference**: `sail_riscv_model.branch_info` — 38,387 coverage points
  - 1,769 Functions (F)
  - 12,242 Branches (B)
  - 24,376 Branch targets (T)
- **Runtime output**: `sail_coverage` file (appended per test run)
- **Z3 required**: Built from source (4.13.4, ARM64)
- **Bug note**: `--sailcov-file` flag causes segfault; workaround uses `cd` + default filename

## Results: RISCOF RV32 IMAFDC (1,103 ELF)

### C Code-Level (gcov/lcov)

| ISA | ELFs | Pass | Lines | Functions | Branches |
|-----|:----:|:----:|:-----:|:---------:|:--------:|
| I   | 38   | 38   | 18.7% | 40.1%     | 3.3%     |
| M   | 8    | 8    | 18.7% | 40.1%     | 3.3%     |
| A   | 9    | 9    | 18.6% | 40.1%     | 3.2%     |
| C   | 27   | 26   | 19.0% | 40.2%     | 3.6%     |
| F   | 342  | 335  | 26.3% | 41.2%     | 7.3%     |
| D   | 679  | 673  | 26.6% | 41.3%     | 7.4%     |
| **Combined** | **1,103** | **1,089** | **28.3%** | **41.8%** | **8.5%** |

Denominator: 412,320 lines (build_sailcov)

### Sail Spec-Level (deduplicated)

| ISA | Unique Points | Functions | Branches | Branch Targets | **Coverage %** |
|-----|:------------:|:---------:|:--------:|:--------------:|:------------:|
| I   | 1,094        | 148       | 391      | 555            | **2.8%** |
| M   | 1,048        | 148       | 386      | 514            | **2.7%** |
| A   | 1,064        | 148       | 391      | 525            | **2.8%** |
| C   | 1,157        | 152       | 416      | 589            | **3.0%** |
| F   | 2,102        | 219       | 835      | 1,048          | **5.5%** |
| D   | 2,239        | 227       | 895      | 1,117          | **5.8%** |
| **Combined** | **2,761** | **233** | **1,056** | **1,472** | **7.1%** |

Static reference: 38,387 total points (F:1,769 B:12,242 T:24,376)

### Per-Type Coverage Ratios (Combined)

| Type | Covered | Total | Ratio |
|------|:-------:|:-----:|:-----:|
| Functions | 233 | 1,769 | **13.1%** |
| Branches | 1,056 | 12,242 | **8.6%** |
| Branch Targets | 1,472 | 24,376 | **6.0%** |
| **All points** | **2,761** | **38,387** | **7.1%** |

## Layer Comparison

| | C Code-Level | Sail Spec-Level |
|---|---|---|
| Technique | gcov/lcov | Sail built-in coverage |
| Denominator | 412,320 C lines | 38,387 spec points |
| IMAFDC Coverage | **28.3%** | **7.1%** |
| What it measures | Generated C code | Formal specification |
| Granularity | Source lines | Spec branches/functions |

### Key Insight

The **Sail spec-level coverage (7.1%)** is much lower than C code coverage (28.3%) for the same tests. This is because:

1. **Sail specification is comprehensive** — formally defines all architectural behavior, including error paths, corner cases, and privileged modes
2. **C code is inflated** — includes softfloat library, configuration validation, and infrastructure code that's always executed
3. **Test focus** — RISCOF IMAFDC tests focus on instruction correctness, not full specification exercise
4. **Infrastructure bias** — Top covered Sail files include `validate_config.sail` (189 hits) and `platform.sail` (74 hits), which are always executed regardless of test ISA

## Top Covered Sail Specification Files

| File | Unique Points | Description |
|------|:------------:|-------------|
| extensions/FD/dext_insts.sail | 289 | D-extension instructions |
| extensions/FD/fext_insts.sail | 269 | F-extension instructions |
| postlude/validate_config.sail | 189 | Configuration validation (infrastructure) |
| extensions/I/base_insts.sail | 186 | Integer base instructions |
| core/sys_regs.sail | 130 | System registers |
| extensions/C/zca_insts.sail | 128 | Compressed instructions |
| extensions/FD/fdext_regs.sail | 114 | F/D register operations |
| core/regs.sail | 112 | General-purpose registers |

## ISA Contribution to Spec Coverage

| ISA | Unique Added | Cumulative | Incremental |
|-----|:------------:|:----------:|:-----------:|
| I   | 1,094        | 1,094      | +2.8%       |
| +M  | 1,048        | 1,144      | +0.1%       |
| +A  | 1,064        | 1,298      | +0.4%       |
| +C  | 1,157        | 1,414      | +0.3%       |
| +F  | 2,102        | 2,426      | +2.6%       |
| +D  | 2,239        | 2,761      | +0.9%       |
| **All IMAFDC** | — | **2,761** | **7.1%** |

- **F/D dominate**: F+D add +3.5pp over I/M/A/C baseline (3.7% → 7.1%)
- **I/M/A/C are similar** (~2.7–3.0% each) — infrastructure dominates
- **D only +0.9pp over F** — most D coverage already covered by F infrastructure

## Delta: Spec vs C Code by ISA

| ISA | C Code (gcov) | Sail Spec | Spec/C Ratio |
|-----|:------------:|:---------:|:------------:|
| I   | 18.7%        | 2.8%      | 0.15×        |
| M   | 18.7%        | 2.7%      | 0.14×        |
| A   | 18.6%        | 2.8%      | 0.15×        |
| C   | 19.0%        | 3.0%      | 0.16×        |
| F   | 26.3%        | 5.5%      | 0.21×        |
| D   | 26.6%        | 5.8%      | 0.22×        |

**Consistent pattern**: Sail spec coverage is ~15–22% of C code coverage across ISAs.

## Three-Suite Comparison (build_sailcov)

| Suite | ELFs | C-Level (gcov) | Sail Spec | Spec/C Ratio |
|-------|:----:|:-------------:|:---------:|:------------:|
| MicroTESK | 214 | 28.9% | **7.3%** | 0.25× |
| RISCOF IMAFDC | 1,103 | 28.3% | 7.1% | 0.25× |
| Imperas | 48 | 25.3% | 5.0% | 0.20× |
| **All 3 Combined** | **1,365** | — | **8.7%** | — |

### Three-Way Delta: Unique Points Added

| Suite | Unique Added | Incremental |
|-------|:------------:|:-----------:|
| RISCOF only (not in MT/Imperas) | +453 | +1.2pp |
| MicroTESK only | +409 | +1.1pp |
| Imperas only | +63 | +0.2pp |

### Combined by Type (all 3 suites)
- Functions: 286 / 1,769 = **16.2%**
- Branches: 1,225 / 12,242 = **10.0%**
- Branch targets: 1,840 / 24,376 = **7.5%**

## Files

| File | Description |
|------|-------------|
| `sail_riscv_model.branch_info` | Static reference (38,387 points) |
| `riscof_sail_rv32_*.sailcov.txt` | RISCOF per-ISA runtime coverage |
| `microtesk_sailcov.txt` | MicroTESK runtime coverage |
| `imperas_sailcov.txt` | Imperas runtime coverage |
| `sail_spec_imafdc_combined_unique.txt` | RISCOF combined deduplicated |
| `*_sailcov_unique.txt` | Per-suite deduplicated files |
