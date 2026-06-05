# 4-bit ALU — Design Verification Project

A complete, beginner-to-intermediate Design Verification (DV) environment
for a 4-bit Arithmetic Logic Unit, written in SystemVerilog.

This project demonstrates the full DV workflow used in industry:
**Verification Plan → RTL analysis → Directed tests → Randomized tests →
Self-checking scoreboard → Assertion-based checking → Coverage closure.**

---

## Project Summary

| Property            | Value                                    |
|---------------------|------------------------------------------|
| Design Under Test   | 4-bit ALU (8 operations)                 |
| Language            | SystemVerilog (no UVM)                   |
| Simulator           | ModelSim / Questa (Windows or Linux)     |
| Directed vectors    | 26                                       |
| Random vectors      | 10,000                                   |
| Assertions          | 17 (immediate, combinational)            |
| Functional coverage | 14 coverpoints (manual tracking)         |
| Result              | All tests PASS, 0 assertion failures     |

---

## Repository Structure

```
alu_verification/
├── rtl/
│   └── alu.sv                  # Design Under Test — 4-bit ALU
├── tb/
│   └── alu_tb_selfcheck.sv     # Self-checking testbench (main)
├── assertions/
│   └── alu_sva.sv              # Assertion checker module
├── sim/
│   ├── run_sim.do              # ModelSim: compile + simulate
│   └── waves.do                # ModelSim: waveform window setup
├── docs/
│   └── verification_plan.md   # VPlan: what, how, and done criteria
└── README.md
```

---

## ALU Operation Table

| op\[2:0\] | Mnemonic | Operation                    |
|-----------|----------|------------------------------|
| 000       | ADD      | result = A + B               |
| 001       | SUB      | result = A − B               |
| 010       | AND      | result = A & B               |
| 011       | OR       | result = A \| B              |
| 100       | XOR      | result = A ^ B               |
| 101       | NOT      | result = ~A (B ignored)      |
| 110       | SHL      | result = A << 1, carry=A\[3\]|
| 111       | SHR      | result = A >> 1, carry=A\[0\]|

**Status Flags:**  
- `carry` — unsigned carry-out / borrow / shift-out  
- `zero` — high when result == 0 (all operations)  
- `overflow` — signed overflow (ADD and SUB only)

---

## How to Run

### Prerequisites
- ModelSim PE / DE / Questa installed  
- `vsim` and `vlog` on your PATH  
  (On Windows: add `C:\intelFPGA\XX.X\modelsim_ase\win32aloem` to PATH)

### Option A — ModelSim GUI (recommended for learning)

```tcl
# In the ModelSim transcript window:
cd C:/path/to/alu_verification
do sim/run_sim.do
```

The script will:
1. Create the `work` library  
2. Compile `alu.sv` → `alu_sva.sv` → `alu_tb_selfcheck.sv`  
3. Start the simulator  
4. Open the Wave window with all signals pre-configured  
5. Run until `$finish`

### Option B — Batch mode (no GUI, output to terminal)

```bash
cd C:\path\to\alu_verification
vsim -c -do "cd sim; do run_sim.do" -do "quit -f" | tee sim.log
```

---

## Expected Console Output

```
==============================================
   ALU SELF-CHECKING TESTBENCH - START
==============================================

--- PHASE 1: DIRECTED TESTS ---
[PASS] DT-001   | op=000 A=3 B=5 -> result=8 carry=0 zero=0 overflow=0
[PASS] DT-002   | op=000 A=f B=1 -> result=0 carry=1 zero=1 overflow=0
[PASS] DT-003   | op=000 A=7 B=1 -> result=8 carry=0 zero=0 overflow=1
[PASS] DT-004   | op=000 A=0 B=5 -> result=5 carry=0 zero=0 overflow=0
... (26 directed tests) ...
Phase 1 complete: 26 passed, 0 failed

--- PHASE 2: RANDOMIZED TESTS (10,000 vectors, seed=42) ---
Phase 2 complete: 10026 total passed, 0 total failed

==============================================
         FUNCTIONAL COVERAGE REPORT
==============================================
Opcodes exercised : 8 / 8
  ADD  (op=000)   : HIT
  SUB  (op=001)   : HIT
  AND  (op=010)   : HIT
  OR   (op=011)   : HIT
  XOR  (op=100)   : HIT
  NOT  (op=101)   : HIT
  SHL  (op=110)   : HIT
  SHR  (op=111)   : HIT

Flag coverage:
  carry    == 1   : HIT
  zero     == 1   : HIT
  overflow == 1   : HIT

Operand boundary coverage:
  A == 4h0        : HIT
  A == 4hF        : HIT
  B == 4h0        : HIT
  B == 4hF        : HIT
  A == B          : HIT
==============================================

==============================================
            SIMULATION SUMMARY
==============================================
Total vectors   : 10026
Passed          : 10026
Failed          : 0
----------------------------------------------
>>> ALL TESTS PASSED - DUT IS CORRECT <<<
==============================================
```

---

## Verification Methodology

```
           Specification
                 │
                 ▼
        ┌─────────────────┐     Written BEFORE any code
        │ Verification    │     Documents: what to test, how to test it,
        │ Plan (VPlan)    │     and what "done" means.
        └────────┬────────┘
                 │
                 ▼
        ┌─────────────────┐     Independent implementation of the spec.
        │  Golden Model   │     Never derived from RTL — otherwise you
        │  (Reference)    │     replicate bugs instead of catching them.
        └────────┬────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌──────────┐          ┌──────────────┐
│ Directed │          │  Randomized  │
│  Tests   │          │    Tests     │
│ (26 vec) │          │ (10K vectors)│
└────┬─────┘          └───────┬──────┘
     │                        │
     └───────────┬────────────┘
                 │
                 ▼
    ┌───────────────────────┐
    │  Self-Checking        │
    │  Scoreboard           │  DUT output vs Golden Model
    │  (auto PASS/FAIL)     │  every single vector
    └────────────┬──────────┘
                 │
                 ▼
    ┌───────────────────────┐
    │  Assertion Checker    │  Always-on property monitors
    │  (alu_sva.sv)         │  Fire immediately on violation
    └────────────┬──────────┘
                 │
                 ▼
    ┌───────────────────────┐
    │  Coverage Closure     │  Have we tested the RIGHT things?
    │  (14 coverpoints)     │  Drives test addition if bins MISS
    └───────────────────────┘
```

---

## Key Concepts Demonstrated

| Concept                  | Where Implemented                        |
|--------------------------|------------------------------------------|
| Verification Plan        | `docs/verification_plan.md`              |
| Golden reference model   | `golden_model` task in testbench         |
| Directed testing         | Phase 1, 26 labeled test vectors         |
| Constrained-random       | Phase 2, LCG-based 10K random vectors    |
| Self-checking scoreboard | `check_outputs` task + counters          |
| Immediate assertions     | `assertions/alu_sva.sv`, 17 properties   |
| Functional coverage      | Manual bitflag tracking, 14 coverpoints  |
| Simulation scripting     | `sim/run_sim.do` (TCL for ModelSim)      |
| Debug messages           | Detailed `[FAIL]` output with all signals|

---

## Common Compile Errors & Fixes

| Error Message                                  | Cause & Fix                                                  |
|------------------------------------------------|--------------------------------------------------------------|
| `** Error: Undefined variable 'i'`             | Declare `int i` at the top of the block, not inside `for`   |
| `** Error: Cannot find port 'result'`          | Module port name mismatch — check instantiation port names   |
| `** Error: near "inside": syntax error`        | `inside` needs `-sv` flag: add `-sv` to `vlog` command      |
| `** Warning: implicit wire declaration`        | Add explicit `logic` or `wire` declaration                   |
| `** Error: Unknown module alu`                 | Compile `alu.sv` before `alu_tb_selfcheck.sv`                |
| `** Error: Unknown module alu_sva`             | Compile `alu_sva.sv` before `alu_tb_selfcheck.sv`            |
| `could not find signal sim:/tb/dut/full_result`| Add `+acc` to `vlog` and `-voptargs=+acc` to `vsim`         |
| `Infinite loop / simulation hangs`             | Timeout fires at 50 ms; check for missing `#10` in tasks    |

---

## What to Check in the Wave Window

| Signal         | What to Look For                                    |
|----------------|-----------------------------------------------------|
| `op[2:0]`      | Cycles through 000–111 during directed tests        |
| `result[3:0]`  | Changes within 10 ns of input change (combinational)|
| `carry`        | Only high for ADD carry, SUB borrow, SHL/SHR shifts |
| `zero`         | Goes high exactly when `result == 4'h0`             |
| `overflow`     | Only high for signed overflow in ADD/SUB            |
| `full_result`  | Bit [4] should match `carry` for ADD/SUB            |
| `total_pass`   | Counts up smoothly; should reach 10026              |
| `total_fail`   | Must stay at 0 throughout; any nonzero = bug        |
| `op_seen[7:0]` | All 8 bits go to 1 during Phase 1 directed tests    |

---

## What I Learned

Through this project, I learned how a Design Verification workflow is structured beyond writing a simple testbench. I practiced writing a verification plan before coding, creating directed tests from expected corner cases, building an independent golden model, comparing DUT outputs automatically with a self checking scoreboard, and using assertions to detect incorrect behavior during simulation.

I also learned that randomized testing alone is not enough. Even with 10,000 random vectors, directed tests are still important for explicitly checking corner cases such as carry out, borrow, signed overflow, zero result, and shift behavior.

This project helped me understand the difference between simply simulating a design and building a reusable verification environment.

## Author

**Bui Huu Phat**  
Electronics and Telecommunications, University of Science, VNU-HCM  
Focus: IC Design Verification  

---
