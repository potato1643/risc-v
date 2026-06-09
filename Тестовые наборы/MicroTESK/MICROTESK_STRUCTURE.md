# MicroTESK 目录结构分析

> `/opt/microtesk-riscv` 在 Docker 容器 `riscv-env` 内

## 一级目录

```
/opt/microtesk-riscv/
├── arch/          ← 架构定义 (nML 模型 + 模板)
├── bin/           ← 工具脚本 (generate, compile, disassemble 等)
├── doc/           ← 文档
├── etc/           ← 配置
├── gen/           ← 生成器
├── lib/           ← 库 (jar, jruby)
├── output/        ← 生成的测试程序 (.elf, .s, .dump 等)
├── output-gcov/   ← gcov 版本输出
├── src/           ← 源码
├── tools/         ← 工具
├── logs/          ← 日志
└── coverage-lcov/ ← lcov 覆盖数据
```

## arch/riscv/model/ — nML 模型 (~9700 行)

定义 RISC-V 指令集架构，按扩展拆分：

| 文件 | 扩展 | 内容 |
|------|------|------|
| riscv.nml | 基础 | 核心定义 |
| riscv_rv32i.nml | RV32I | 整数基本指令 |
| riscv_rv32i_sys.nml | RV32I 系统 | ECALL/EBREAK/CSR |
| riscv_rv64i.nml | RV64I | 64位特定指令 |
| riscv_rv32m.nml | RV32M | 乘除法 (32位) |
| riscv_rv64m.nml | RV64M | 乘除法 (64位) |
| riscv_rv32a.nml | RV32A | 原子操作 (32位) |
| riscv_rv64a.nml | RV64A | 原子操作 (64位) |
| riscv_rv32f.nml | RV32F | 单精度浮点 |
| riscv_rv64f.nml | RV64F | 单精度浮点 (64位) |
| riscv_rv32d.nml | RV32D | 双精度浮点 |
| riscv_rv64d.nml | RV64D | 双精度浮点 (64位) |
| riscv_rvc.nml | RVC | 压缩指令 |
| riscv_rv32v.nml | RV32V | 向量 (32位) |
| riscv_pseudo.nml | — | 伪指令 |
| riscv_csreg.nml | — | CSR 寄存器定义 |

## arch/riscv/templates/ — 测试模板 (.rb)

### compliance/ — ISA 合规测试 ⭐核心

| 目录 | 扩展 | 模板数 | 当前 ELF | 状态 |
|------|------|:------:|:--------:|:----:|
| **rv64ui** | RV64I 用户 | 51 | 50 | fence_i 失败 |
| **rv64mi** | RV64I 机器 | 3 | 1 | access,breakpoint 生成失败 |
| **rv64si** | RV64I 监管 | 1 | 1 | ✅ |
| **rv64um** | RV64M | 13 | 13 | ✅ |
| **rv64ua** | RV64A | 19 | 19 | ✅ |
| **rv64uc** | RV64C | 1 (rvc.rb) | 0 | 未生成 |
| **rv64ud** | RV64D | 12 | 0 | 未生成 |
| **rv64uf** | RV64F | 11 | 0 | 未生成 |
| rv32ui | RV32I 用户 | ~50 | ? | 未跑 |
| rv32um | RV32M | ~13 | ? | 未跑 |
| rv32ua | RV32A | 10 | ? | 未跑 |
| rv32uc/ud/uf/uv | C/D/F/V | — | — | — |

**rv64ui 模板列表** (51 个):
```
add, addi, addiw, addw, and, andi, auipc, beq, bge, bgeu, blt, bltu, bne,
fence_i, jal, jalr, lb, lbu, ld, lh, lhu, lui, lw, lwu, or, ori, sb, sd,
sh, simple, sll, slli, slliw, sllw, slt, slti, sltiu, sltu, sra, srai,
sraiw, sraw, srl, srli, srliw, srlw, sub, subw, sw, xor, xori
```

**rv64um 模板列表** (13 个):
```
div, divu, divuw, divw, mul, mulh, mulhsu, mulhu, mulw, rem, remu, remuw, remw
```

**rv64ua 模板列表** (19 个):
```
amoadd_d, amoand_d, amomax_d, amomaxu_w, amomin_d, amominu_w, amoor_d,
amoswap_d, amoxor_d, lrsc, amoadd_w, amoand_w, amomaxu_d, amomax_w,
amominu_d, amomin_w, amoor_w, amoswap_w, amoxor_w
```
> 注: 每个 AMO 模板覆盖对应的 .W 和 .D 变体，lrsc 覆盖 LR.W/SC.W

**rv64mi 模板** (3 个):
```
access, breakpoint, mcsr
```
> access 和 breakpoint 生成 `.s` 失败，mcsr 正常

**rv64si 模板** (1 个):
```
wfi
```

**rv64uc 模板** (1 个):
```
rvc.rb — 压缩指令集
```

**rv64ud 模板** (12 个):
```
fadd, fclass, fcmp, fcvt, fcvt_w, fdiv, fmadd, fmin, ldst, move, recoding, structural
```

**rv64uf 模板** (11 个):
```
fadd, fclass, fcmp, fcvt, fcvt_w, fdiv, fmadd, fmin, ldst, move, recoding
```

### debug/ — 调试模板 (22 个)

按扩展/功能的独立调试模板：
```
debug_rv64i, debug_rv64m, debug_rv64a, debug_rv64f, debug_rv64d, debug_rvc
debug_jalr, debug_la, debug_li
debug_ld_sd, debug_ld_sd_sv39, debug_ld_sd_sv48
debug_lw_sw, debug_lw_sw_sv32
debug_csrs, debug_rv32a/d/f/f2/i/m/v
```

### algorithms/ — 算法测试

| 目录 | ELF | 内容 |
|------|:---:|------|
| integer | 4 | 整数运算算法 |
| sorting | 3 | 排序算法 (bubblesort_hword/word/byte) |

### examples/ — 示例

| 目录 | ELF | 内容 |
|------|:---:|------|
| branches | 3 | 分支指令示例 |
| labels | 3 | 标签用法 |
| sequences | 7 | 序列生成 |
| registers | 4 | 寄存器操作 |
| testdata | 4 | 测试数据 |
| preparators | 1 | 准备器 |
| selfcheck | 1 | 自检 |

### synthetics/ — 合成测试 (有问题)

- rv32v — 暂时禁用
- rvxxx — 暂时禁用

### errata/ — 勘误

- microchip, stm, temic — 厂商勘误测试

## bin/ — 工具脚本

| 脚本 | 功能 |
|------|------|
| generate.sh | 从 .rb 模板生成 .s 汇编 |
| compile.sh | 编译 .s → .elf |
| disassemble.sh | 反汇编 |
| transform.sh | 模板转换 |
| autogen.sh | 自动生成 |
| symexecute.sh | 符号执行 |

## output/ 和 output-gcov/

```
output/
├── compliance/
│   ├── rv64ui/  (50 ELF)
│   ├── rv64mi/  (1 ELF: mcsr)
│   ├── rv64si/  (1 ELF: wfi)
│   ├── rv64um/  (13 ELF)
│   └── rv64ua/  (19 ELF)
├── algorithms/  (7 ELF)
└── examples/    (23 ELF)

output-gcov/
└── algorithms/  (gcov 版本输出)
```

## 测试流程

```
1. run.sh <template>     → 生成 .s 汇编文件
2. run-toolchain.sh      → 编译 .s → .elf, 生成 .dump
3. spike -l <elf>        → 在 Spike 上运行
4. lcov --capture        → 收集覆盖率
```

## 关键发现

1. **已跑**: rv64ui(50) + rv64mi(1) + rv64si(1) + rv64um(13) + rv64ua(19) = **84 ELF**
2. **可扩展**: rv64uc (C扩展), rv64ud (D浮点), rv64uf (F浮点), debug 模板
3. **现有问题**: fence_i 模板编译失败, access/breakpoint .s 生成失败
4. **分母问题**: 所有 lcov .info 分母固定 ~53k, 因为 Spike 编译了所有扩展
