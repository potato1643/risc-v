# Sail C Simulator — Build & Coverage Notes

## Source Location (riscv-env container)

- **Repository:** https://github.com/riscv/sail-riscv (cloned at `/opt/sail-riscv/`)
- **Version:** 0.9 (git: 0.9-81-g397a7e8)
- **Sail compiler:** `/opt/sail/bin/sail` (v0.20.1)
- **Original build:** `/opt/sail-riscv/build/` (Release, NO coverage)
- **Gcov build:** `/opt/sail-riscv/build_cov/` (Debug + --coverage)

## Binary Locations

| Binary | Path |
|--------|------|
| Original (no coverage) | `/opt/sail-riscv/build/c_emulator/sail_riscv_sim` |
| GCOV-instrumented | `/opt/sail-riscv/build_cov/c_emulator/sail_riscv_sim` |
| Symlink (PATH) | `/usr/local/bin/sail_riscv_sim` → original build |

## Rebuild with GCOV

```bash
export PATH="/opt/sail/bin:$PATH"
cd /opt/sail-riscv
mkdir -p build_cov && cd build_cov
cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_FLAGS="--coverage -g -O0" \
    -DCMAKE_CXX_FLAGS="--coverage -g -O0" \
    -DCMAKE_EXE_LINKER_FLAGS="--coverage"
cmake --build . -j$(nproc)
```

## Key Files

| File | Path | Description |
|------|------|-------------|
| Binary | `build_cov/c_emulator/sail_riscv_sim` | 59 MB, gcov instrumented |
| RV64 Config | `config/rv64d_v256_e64.json` | Default RV64 config |
| RISCOF RV64 Config | `/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json` | Used by RISCOF |
| RISCOF RV32 Config | `/opt/riscv-arch-test/riscof-plugins/rv32/sail_cSim/env/sail_config.json` | Used by RISCOF |

## Running Tests with GCOV

```bash
# Clear previous counters
find /opt/sail-riscv/build_cov -name "*.gcda" -delete

# Run ELF
/opt/sail-riscv/build_cov/c_emulator/sail_riscv_sim \
    --config=/opt/riscv-arch-test/riscof-plugins/rv64/sail_cSim/env/sail_config.json \
    --test-signature=/dev/null \
    my_test.elf

# Collect coverage
lcov --rc lcov_branch_coverage=1 \
     --capture --directory /opt/sail-riscv/build_cov \
     --output-file sail_coverage.info \
     --ignore-errors gcov,source

# Generate HTML
genhtml --rc genhtml_branch_coverage=1 \
        sail_coverage.info \
        --output-directory sail_html
```

## Sail vs Spike: Key Differences for Coverage

| Aspect | Spike | Sail |
|--------|-------|------|
| Code | Hand-written C++ (~44K lines) | Auto-generated C from Sail spec (~372K lines) |
| ISA config | `--isa=rv64gc` flag | JSON config file |
| Instruction files | Per-instruction .h files | Monolithic `sail_riscv_model.cpp` |
| IMAFDC filter | `lcov --remove /opt/riscv-isa-sim/riscv/insns/v* ...` | N/A (monolithic code) |
| Coverage base | Per-instruction C++ | Generated Sail-to-C translation |
