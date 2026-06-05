# Verification Plan — 4-bit ALU
**Version:** 1.0  
**Author:** [Your Name]  
**Date:** 2025  
**Status:** Active  

---

## 1. Design Overview

| Property        | Value                              |
|-----------------|------------------------------------|
| Module name     | `alu`                              |
| File            | `rtl/alu.sv`                       |
| Interface type  | Combinational (no clock)           |
| Inputs          | `A[3:0]`, `B[3:0]`, `op[2:0]`     |
| Outputs         | `result[3:0]`, `carry`, `zero`, `overflow` |
| Operations      | 8 (ADD, SUB, AND, OR, XOR, NOT, SHL, SHR) |

### 1.1 Operation Table

| op[2:0] | Mnemonic | Description                        |
|---------|----------|------------------------------------|
| 000     | ADD      | result = A + B; carry = carry-out  |
| 001     | SUB      | result = A − B; carry = borrow     |
| 010     | AND      | result = A & B                     |
| 011     | OR       | result = A \| B                    |
| 100     | XOR      | result = A ^ B                     |
| 101     | NOT      | result = ~A  (B is ignored)        |
| 110     | SHL      | result = A << 1; carry = A[3]      |
| 111     | SHR      | result = A >> 1; carry = A[0]      |

### 1.2 Flag Definitions

| Flag     | Condition                                              |
|----------|--------------------------------------------------------|
| carry    | Unsigned carry-out (ADD), borrow (SUB), shifted-out bit (SHL/SHR) |
| zero     | Asserted when `result == 4'b0000`, for ALL operations  |
| overflow | Signed two's-complement overflow for ADD and SUB only  |

---

## 2. Verification Goals

### 2.1 Functional Goals (must be 100% complete)
- [ ] Verify correct `result` for all 8 opcodes
- [ ] Verify `carry` flag correct for ADD, SUB, SHL, SHR
- [ ] Verify `carry == 0` for AND, OR, XOR, NOT
- [ ] Verify `zero` flag correct for all operations
- [ ] Verify `overflow` flag correct for ADD and SUB signed overflow cases
- [ ] Verify `overflow == 0` for all non-arithmetic operations
- [ ] Verify no X or Z values on any output for any valid input combination

### 2.2 Structural Goals
- [ ] All 8 opcodes exercised at least once
- [ ] All status flag states (0 and 1) exercised for `carry`, `zero`, `overflow`
- [ ] Boundary operands exercised: A=0, A=0xF, B=0, B=0xF, A==B

---

## 3. Test Plan

### 3.1 Directed Tests

All directed tests are in `tb/alu_tb_selfcheck.sv` Phase 1.  
Label format: `DT-NNN` maps to the row below.

| Test ID | Op     | A    | B    | Expected Result | Expected Flags         | Requirement Covered             |
|---------|--------|------|------|-----------------|------------------------|---------------------------------|
| DT-001  | ADD    | 0x3  | 0x5  | 0x8             | none                   | ADD basic                       |
| DT-002  | ADD    | 0xF  | 0x1  | 0x0             | carry=1, zero=1        | ADD carry-out                   |
| DT-003  | ADD    | 0x7  | 0x1  | 0x8             | overflow=1             | ADD signed overflow (+→−)       |
| DT-004  | ADD    | 0x0  | 0x5  | 0x5             | none                   | ADD with A=0                    |
| DT-005  | ADD    | 0x0  | 0x0  | 0x0             | zero=1                 | ADD both zero                   |
| DT-006  | ADD    | 0xF  | 0xF  | 0xE             | carry=1                | ADD both max (double carry)     |
| DT-007  | SUB    | 0x8  | 0x3  | 0x5             | none                   | SUB basic                       |
| DT-008  | SUB    | 0x0  | 0x1  | 0xF             | carry=1 (borrow)       | SUB with borrow                 |
| DT-009  | SUB    | 0x5  | 0x5  | 0x0             | zero=1                 | SUB equal operands              |
| DT-010  | SUB    | 0x8  | 0x1  | 0x7             | overflow=1             | SUB signed overflow (−→+)       |
| DT-011  | AND    | 0x5  | 0xA  | 0x0             | zero=1                 | AND complementary values        |
| DT-012  | AND    | 0x7  | 0xF  | 0x7             | none                   | AND with all-ones mask          |
| DT-013  | AND    | 0xF  | 0x0  | 0x0             | zero=1                 | AND with B=0                    |
| DT-014  | OR     | 0x5  | 0xA  | 0xF             | none                   | OR complementary → all ones     |
| DT-015  | OR     | 0x7  | 0x0  | 0x7             | none                   | OR with B=0                     |
| DT-016  | XOR    | 0x9  | 0x9  | 0x0             | zero=1                 | XOR same values → zero          |
| DT-017  | XOR    | 0x5  | 0xA  | 0xF             | none                   | XOR complementary → all ones    |
| DT-018  | NOT    | 0x0  | —    | 0xF             | none                   | NOT of zero → all ones          |
| DT-019  | NOT    | 0xF  | —    | 0x0             | zero=1                 | NOT of all ones → zero          |
| DT-020  | NOT    | 0xA  | —    | 0x5             | none                   | NOT of alternating pattern      |
| DT-021  | SHL    | 0x8  | —    | 0x0             | carry=1, zero=1        | SHL MSB=1 → carry, result=0     |
| DT-022  | SHL    | 0x3  | —    | 0x6             | none                   | SHL normal                      |
| DT-023  | SHL    | 0xF  | —    | 0xE             | carry=1                | SHL all ones                    |
| DT-024  | SHR    | 0x1  | —    | 0x0             | carry=1, zero=1        | SHR LSB=1 → carry, result=0     |
| DT-025  | SHR    | 0xA  | —    | 0x5             | none                   | SHR normal                      |
| DT-026  | SHR    | 0xF  | —    | 0x7             | carry=1                | SHR all ones                    |

### 3.2 Randomized Tests

| Property         | Value                                      |
|------------------|--------------------------------------------|
| Vectors          | 10,000                                     |
| Seed             | 42 (deterministic, change to explore more) |
| RNG method       | Linear Congruential Generator (LCG)        |
| Checker          | Golden model task in testbench             |
| Pass criterion   | Zero mismatches across all 10,000 vectors  |

### 3.3 Assertion Checks

| Assertion ID            | Property                                      |
|-------------------------|-----------------------------------------------|
| assert_zero_flag_hi     | `result==0 → zero==1`                        |
| assert_zero_flag_lo     | `result≠0 → zero==0`                        |
| assert_no_x_result      | `result` never X or Z                        |
| assert_no_x_carry       | `carry` never X or Z                         |
| assert_no_x_zero        | `zero` never X or Z                          |
| assert_no_x_overflow    | `overflow` never X or Z                      |
| assert_logic_no_carry   | `carry==0` for AND/OR/XOR/NOT                |
| assert_logic_no_overflow| `overflow==0` for AND/OR/XOR/NOT             |
| assert_and_subset_A     | AND result has no bits not present in A      |
| assert_and_subset_B     | AND result has no bits not present in B      |
| assert_or_superset_A    | OR result has all bits from A                |
| assert_or_superset_B    | OR result has all bits from B                |
| assert_xor_self_cancel  | `XOR(A,A)==0` and `zero==1`                  |
| assert_shl_carry        | `carry == A[3]` before shift                 |
| assert_shl_lsb_zero     | `result[0]==0` after SHL                     |
| assert_shr_carry        | `carry == A[0]` before shift                 |
| assert_shr_msb_zero     | `result[3]==0` after SHR                     |

---

## 4. Functional Coverage Plan

### 4.1 Opcode Coverage
**Goal:** Every opcode must be exercised at least once.  
**Tracked by:** `op_seen[7:0]` register in testbench.  
**Target:** `op_seen == 8'hFF` (all 8 bits set).

### 4.2 Status Flag Coverage
| Coverpoint          | Target |
|---------------------|--------|
| `carry == 1`        | HIT    |
| `zero == 1`         | HIT    |
| `overflow == 1`     | HIT    |

### 4.3 Operand Boundary Coverage
| Coverpoint    | Target |
|---------------|--------|
| `A == 4'h0`   | HIT    |
| `A == 4'hF`   | HIT    |
| `B == 4'h0`   | HIT    |
| `B == 4'hF`   | HIT    |
| `A == B`      | HIT    |

---

## 5. Completion Criteria

The verification is complete when ALL of the following are true:

1. **Directed tests:** All 26 directed tests report `[PASS]`
2. **Randomized tests:** Zero mismatches in 10,000 random vectors
3. **Assertions:** Zero assertion failures during simulation
4. **Functional coverage:**
   - `op_seen == 8'hFF` (all opcodes hit)
   - All flag coverage bins: HIT
   - All operand boundary bins: HIT
5. **Clean compile:** Zero errors, zero critical warnings

---

## 6. Tools & Environment

| Tool          | Version        | Purpose                        |
|---------------|----------------|--------------------------------|
| ModelSim      | 10.7+ / Questa | Simulation and waveform viewer |
| Language      | SystemVerilog  | RTL, testbench, assertions     |
| OS            | Windows 10/11  | Development environment        |

---

## 7. File List

| File                           | Purpose                        |
|--------------------------------|--------------------------------|
| `rtl/alu.sv`                   | Design Under Test              |
| `tb/alu_tb_selfcheck.sv`       | Self-checking testbench        |
| `assertions/alu_sva.sv`        | Assertion checker module       |
| `sim/run_sim.do`               | ModelSim compile+run script    |
| `sim/waves.do`                 | Waveform window setup          |
| `docs/verification_plan.md`    | This document                  |
| `README.md`                    | Project overview               |
