# MicroTESK F/D 测试 "崩溃" 根因分析

> 日期: 2026-06-09
> 分析对象: RV64F/RV64D 测试在 Spike 上 exit 255/3 的问题

## 结论

**F/D 测试并没有导致 Spike 崩溃。** 实际的崩溃原因是：
1. MicroTESK 生成的测试数据中的**预期结果值不正确**（与 IEEE 754 标准不匹配）
2. Spike 正确执行了 FPU 指令，但结果与测试数据中的预期值不匹配
3. 测试框架检测到不匹配后跳转到 `fail` → ecall → `write_tohost` 死循环
4. Spike 的 HTIF 无法正确处理 tohost=0x2 的退出码，产生 "Access exception" 错误

## 详细分析

### 1. 崩溃现象

| 测试类型 | ELF 数 | Pass | Crash | 退出码 |
|---------|:------:|:----:|:-----:|:------:|
| fadd/fsub/fmul | 11 | 0 | 11 | 255 |
| fdiv/fsqrt | 2 | 0 | 2 | 255 |
| fmadd/fmsub/fnmsub/fnmadd | 4 | 0 | 4 | 255 |
| fcmp (feq/flt/fle) | 3 | 0 | 3 | 255 |
| fcvt/fcvt_w | 4 | 0 | 4 | 255 |
| fmin/fmax | 2 | 0 | 2 | 3 |
| fclass | 1 | 1 | 0 | 0 |
| ldst (fld/fsd/flw/fsw) | 1 | 1 | 0 | 0 |
| move (fmv/fmvsgnj) | 1 | 1 | 0 | 0 |
| recoding | 1 | 0 | 1 | 255 |

### 2. 通过 vs 失败的测试对比

**通过的测试** (fclass, ldst, move)：
- 不做浮点**算术**运算
- fclass: 只用 `fclass.s` 指令（分类操作），预期值是硬编码常数
- ldst: 只做加载/存储
- move: 只做数据搬运 (fmv, fsgnj)

**失败的测试** (fadd, fsub, fmul, fdiv, fmadd, fcmp, fcvt, fmin, fcvt_w, recoding)：
- 全部涉及浮点**算术**运算
- 测试结构：加载输入 → 执行FPU运算 → 比较结果与预期值

### 3. 测试执行流程（以 fadd.s 为例）

```
test_2:
    flw ft0, 0(a0)      # 加载输入1
    flw ft1, 4(a0)      # 加载输入2
    lw  a3, 12(a0)      # 加载预期结果 (整数位模式)
    fadd.s ft3, ft0, ft1  # ← Spike 正确执行了这个指令
    fmv.x.w a0, ft3      # 读取结果到整数寄存器
    fsflags a1, zero     # 读取 fflags
    bne a0, a3, fail     # ← 结果不匹配！跳转 fail
    bne a1, a2, fail     # fflags 不匹配检查
```

### 4. 实际数据对比 (test_2)

| 项目 | 位模式 | 浮点值 |
|------|--------|--------|
| 输入1 (ft0) | 0x4e804000 | 1,075,838,976.0 |
| 输入2 (ft1) | 0x4e7e0000 | 1,065,353,216.0 |
| MicroTESK 预期 | 0x4e80c000 | 1,080,033,280.0 |
| IEEE 754 实际和 | **0x4eff4000** | **2,141,192,192.0** |
| **匹配?** | **❌ 不匹配** | |

关键发现：预期值 (0x4e80c000) 非常接近输入1 (0x4e804000)，仅差 0x8000（mantissa 低位差 1 bit）。
但正确的 IEEE 754 和是 0x4eff4000，mantissa 完全不同。

### 5. 根本原因

**MicroTESK 测试数据生成器的浮点模型与 IEEE 754 不一致。**

流程：
1. 模板文件 (fadd.rb): `TEST_FP_OP2_S(2, 'fadd_s', 0, 3.5, 2.5, 1.0)`
2. MicroTESK 测试生成器将模板中的字面值(2.5, 1.0, 3.5)替换为**生成的大数值**
3. 生成的预期值是使用 MicroTESK 内部的 FPU 模型计算的
4. 在 Spike 上执行时，输入值被正确加载，`fadd.s` 产生 IEEE 754 结果
5. IEEE 754 结果与 MicroTESK 内部模型计算的结果不匹配 → **测试失败**

数据生成的问题：
- 模板中 val1=2.5 → 生成 val1=1,075,838,976.0 (指数差 29，但比例不是精确的 2^29)
- 预期结果似乎是基于 val1 计算，val2 的贡献被严重低估
- 这表明 MicroTESK 内部的舍入模型或精度模型有 bug

### 6. exit 255 的来源

测试失败后的代码路径：
```
fail:
    fence
    sll gp, gp, ra       # gp = 2 << ra (ra=某个值)
    or  gp, gp, ra       # gp 变成一个大数值
    ecall                # 触发 trap
→ trap_vector:
    csrr t5, mcause      # mcause = 8 (environment call from U-mode)
    li  t6, 8
    beq t5, t6, write_tohost  # 跳转到 write_tohost
→ write_tohost:
    sw gp, tohost, t5    # 将 gp 值写入 tohost (gp ≈ 0x2 或更大的值)
    j write_tohost       # 死循环
```

Spike 的 HTIF 看到 tohost=0x2（或类似值），尝试将其作为 HTIF 命令处理，访问内存地址 0x0，产生 "Access exception"。

**exit 255 是 Fake Crash**：不是 Spike FPU 崩溃，是 HTIF 处理非标准退出码的副作用。

fmin 的 exit 3：fmin 写了 `tohost=3`（标准失败码），Spike 正确识别为失败退出。

### 7. 为什么部分覆盖率仍然被收集？

即使测试"崩溃"（exit 255），Spike 在执行 `fadd.s` 等指令时已经：
1. 执行了对应的 C++ 代码（在 `riscv/insns/` 目录下）
2. gcov 计数器被递增
3. lcov 收集到了这些覆盖率数据

所以虽然测试报告"崩溃"，覆盖率数据仍然有效。

## 修复建议

### 方案 A（推荐）：使用官方 riscv-tests 预期值
- 从 [riscv-tests](https://github.com/riscv/riscv-tests) 仓库获取预编译的 F/D 测试
- 官方的预期值是使用正确的 IEEE 754 模型计算的
- 这是最可靠的方案

### 方案 B：修改 MicroTESK 测试数据生成器
- 修复 MicroTESK 内部 FP 模型，使其符合 IEEE 754
- 需要深入 MicroTESK 源码 (Java/Scala)
- 工作量较大

### 方案 C：接受现状
- F/D 模板 100% 覆盖了所有指令
- 覆盖率数据（gcov）仍然有效
- 文档化这个限制
- 在比较报告中注明 F/D 测试的覆盖率是 "partial execution coverage"

## 影响评估

| 方面 | 影响 |
|------|------|
| 覆盖率数据 | ✅ 仍然有效（gcov 计数器被正确递增） |
| 测试有效性 | ⚠️ 无法验证 FPU 计算正确性 |
| 比较报告 | 需要注明 F/D 覆盖率是 "partial" |
| 整体覆盖率 | 19.7% → 不受影响（覆盖率来自代码执行而非测试通过） |
