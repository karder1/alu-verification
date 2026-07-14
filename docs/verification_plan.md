# Verification Plan — 4-bit ALU

**Version:** 1.1  
**Author:** Bui Huu Phat  
**Date:** July 2026  
**Status:** Active

---

## 1. Design Overview

| Property | Value |
|---|---|
| Module | `alu` |
| RTL file | `rtl/alu.sv` |
| Interface | Combinational, no clock |
| Inputs | `A[3:0]`, `B[3:0]`, `op[2:0]` |
| Outputs | `result[3:0]`, `carry`, `zero`, `overflow` |
| Operations | ADD, SUB, AND, OR, XOR, NOT, SHL, SHR |

### Flag definitions

| Flag | Definition |
|---|---|
| `carry` | ADD carry-out, SUB borrow (`A < B`), SHL/SHR shifted-out bit |
| `zero` | `1` exactly when `result == 4'b0000` |
| `overflow` | Signed two's-complement overflow for ADD and SUB only |

---

## 2. Verification Goals

The environment shall verify:

- the result of all eight operations;
- ADD carry-out and SUB borrow behavior;
- SHL and SHR shifted-out bits;
- zero-flag equivalence for every operation;
- signed overflow and non-overflow cases for ADD and SUB;
- zero carry/overflow for logical operations;
- deterministic outputs without X/Z for valid input combinations;
- complete exercise of the valid input space.

---

## 3. Test Strategy

### 3.1 Directed tests

The 26 directed tests provide readable corner-case evidence and requirement
traceability.

| ID | Op | A | B | Expected result | Expected flags | Purpose |
|---|---|---:|---:|---:|---|---|
| DT-001 | ADD | 3 | 5 | 8 | none | basic addition |
| DT-002 | ADD | F | 1 | 0 | carry=1, zero=1 | carry-out |
| DT-003 | ADD | 7 | 1 | 8 | overflow=1 | positive signed overflow |
| DT-004 | ADD | 0 | 5 | 5 | none | zero operand |
| DT-005 | ADD | 0 | 0 | 0 | zero=1 | zero result |
| DT-006 | ADD | F | F | E | carry=1 | maximum unsigned operands |
| DT-007 | SUB | 7 | 3 | 4 | none | basic subtraction without overflow |
| DT-008 | SUB | 0 | 1 | F | carry=1 | unsigned borrow |
| DT-009 | SUB | 5 | 5 | 0 | zero=1 | equal operands |
| DT-010 | SUB | 8 | 1 | 7 | overflow=1 | `-8 - 1` signed overflow |
| DT-011 | AND | 5 | A | 0 | zero=1 | complementary inputs |
| DT-012 | AND | 7 | F | 7 | none | all-ones mask |
| DT-013 | AND | F | 0 | 0 | zero=1 | zero mask |
| DT-014 | OR | 5 | A | F | none | complementary inputs |
| DT-015 | OR | 7 | 0 | 7 | none | OR identity |
| DT-016 | XOR | 9 | 9 | 0 | zero=1 | self-cancellation |
| DT-017 | XOR | 5 | A | F | none | complementary inputs |
| DT-018 | NOT | 0 | X | F | none | B ignored |
| DT-019 | NOT | F | X | 0 | zero=1 | B ignored, zero result |
| DT-020 | NOT | A | X | 5 | none | alternating pattern |
| DT-021 | SHL | 8 | X | 0 | carry=1, zero=1 | MSB shifted out |
| DT-022 | SHL | 3 | X | 6 | none | normal shift |
| DT-023 | SHL | F | X | E | carry=1 | all-ones input |
| DT-024 | SHR | 1 | X | 0 | carry=1, zero=1 | LSB shifted out |
| DT-025 | SHR | A | X | 5 | none | normal shift |
| DT-026 | SHR | F | X | 7 | carry=1 | all-ones input |

### 3.2 Exhaustive tests

| Property | Value |
|---|---|
| Valid A values | 16 |
| Valid B values | 16 |
| Opcodes | 8 |
| Total exhaustive vectors | 2,048 |
| Checker | Independent golden-model task |
| Pass criterion | Zero mismatches across all 2,048 vectors |

Exhaustive testing replaces the previous LCG random phase. It guarantees that
every valid `{A, B, op}` combination is checked.

### 3.3 Reference-model independence

The DUT uses Boolean sign-bit equations for ADD/SUB overflow. The reference
model uses a different method:

1. sign-extend A and B;
2. calculate the mathematical signed result;
3. assert overflow when the result is outside `[-8, +7]`.

SUB borrow is calculated as `A < B`, rather than copying the RTL's intermediate
MSB implementation.

---

## 4. Assertion Plan

| Property | Requirement |
|---|---|
| Zero equivalence | `zero == (result == 0)` |
| Known outputs | no X/Z on result or flags |
| Logical flags | carry=0 and overflow=0 for AND/OR/XOR/NOT |
| AND property | result is a subset of both operands |
| OR property | result is a superset of both operands |
| XOR identity | equal operands produce zero |
| SHL property | carry=A[3], result[0]=0 |
| SHR property | carry=A[0], result[3]=0 |

Every failure increments `assertion_fail_count`. The final regression result is
FAIL when this count is nonzero.

---

## 5. Functional Coverage Plan

### Opcode targets — 8

All bits of `op_seen[7:0]` must be set.

### Flag targets — 3

- carry observed high;
- zero observed high;
- overflow observed high.

### Operand-boundary targets — 5

- A=0;
- A=F;
- B=0;
- B=F;
- A=B.

Total manually tracked targets: **16**.

---

## 6. Completion Criteria

Verification is complete only when all conditions are true:

1. all 26 directed tests pass;
2. all 2,048 exhaustive vectors pass;
3. `assertion_fail_count == 0`;
4. all 16 coverage targets are hit;
5. compilation completes without errors;
6. the simulation does not reach the watchdog timeout.

The testbench calls `$fatal` when any verification condition fails so a batch
regression receives a failing simulator status.

---

## 7. Files

| File | Purpose |
|---|---|
| `rtl/alu.sv` | synthesizable DUT |
| `tb/alu_tb_selfcheck.sv` | stimulus, reference model, scoreboard and coverage |
| `assertions/alu_sva.sv` | property checker and assertion-failure counter |
| `sim/run_sim.do` | ModelSim/Questa compile and run script |
| `sim/waves.do` | waveform setup |
| `alu.qsf` | Quartus RTL synthesis project |
