# Applied fixes

## Files changed

### `tb/alu_tb_selfcheck.sv`

- Replaced the LCG-based 10,000-loop phase with an exhaustive sweep of all
  `16 × 16 × 8 = 2,048` valid input combinations.
- Kept the 26 directed tests for readable corner-case evidence.
- Changed DT-007 from `0x8 - 0x3` to `0x7 - 0x3`, so the “basic subtraction”
  test is genuinely a non-overflow case.
- Corrected the DT-006 explanation: `0xF + 0xF = 0xE`, carry=1, zero=0.
- Removed the fragile string `substr()` check by passing an explicit
  `print_on_pass` argument to the checker task.
- Rewrote the ADD/SUB reference overflow calculation using signed range checks,
  making it structurally different from the RTL equations.
- Added assertion count and coverage closure to the final PASS/FAIL condition.
- Added `$fatal` for regression failure and timeout.

### `assertions/alu_sva.sv`

- Consolidated assertions into one monitor process.
- Added `assertion_fail_count` output.
- Every assertion failure increments the counter and is included in the final
  testbench result.

### `sim/waves.do`

- Added `assertion_fail_count`, `cov_B_zero`, and `cov_B_ones`.
- Extended the initial waveform view to 25 us for the exhaustive run.

### `docs/verification_plan.md` and `README.md`

- Updated the methodology from 10,000 LCG iterations to 2,048 exhaustive
  vectors.
- Corrected the total vector count to 2,074.
- Corrected coverage target count to 16.
- Synchronized DT-006 and DT-007 with the testbench.
- Documented that scoreboard, assertions and coverage all gate regression PASS.

### `alu.qsf`

- Kept only the synthesizable RTL source `rtl/alu.sv`.
- Removed simulation-only testbench and assertion sources from Quartus synthesis.
- Removed the invalid `tb/alu_sva.sv` path.

## Files intentionally unchanged

- `rtl/alu.sv`: the DUT behavior was retained.
- `sim/run_sim.do`: its compile order already matches the corrected structure.
