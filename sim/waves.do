# ==============================================================
# File    : sim/waves.do
# Project : 4-bit ALU Verification
# Tool    : ModelSim / Questa
#
# Description:
#   Sets up the Wave window with all DUT and testbench signals
#   organized into labeled groups for easy debugging.
#
#   Run after vsim starts (called automatically from run_sim.do).
#   You can also run it manually from the transcript at any time:
#       do sim/waves.do
#
# Display formats:
#   -radix hex  = show value in hexadecimal
#   -radix bin  = show value in binary  (good for opcodes/flags)
#   -radix dec  = show value in decimal
#   -radix uns  = unsigned decimal
# ==============================================================


# Clear any existing waveforms
quietly WaveActivateNextPane {} 0


# ==============================================================
# GROUP 1 : INPUTS TO DUT
# ==============================================================
add wave -divider "========== INPUTS =========="

# Operand A — hex is most readable for 4-bit values
add wave -noupdate -label {A [3:0]} \
    -radix hex \
    sim:/alu_tb_selfcheck/A

# Operand B
add wave -noupdate -label {B [3:0]} \
    -radix hex \
    sim:/alu_tb_selfcheck/B

# Opcode — binary shows all 3 bits individually; easy to read
add wave -noupdate -label {op [2:0]} \
    -radix bin \
    sim:/alu_tb_selfcheck/op


# ==============================================================
# GROUP 2 : DUT OUTPUTS
# ==============================================================
add wave -divider "========== DUT OUTPUTS =========="

add wave -noupdate -label {result [3:0]} \
    -radix hex \
    sim:/alu_tb_selfcheck/result

# Flags shown in binary (they are single bits)
add wave -noupdate -label "carry" \
    -radix bin \
    sim:/alu_tb_selfcheck/carry

add wave -noupdate -label "zero" \
    -radix bin \
    sim:/alu_tb_selfcheck/zero

add wave -noupdate -label "overflow" \
    -radix bin \
    sim:/alu_tb_selfcheck/overflow


# ==============================================================
# GROUP 3 : SCOREBOARD COUNTERS
#   Watching these in real-time lets you see pass/fail counts
#   accumulate as the simulation runs.
# ==============================================================
add wave -divider "========== SCOREBOARD =========="

add wave -noupdate -label "total_tests" \
    -radix unsigned \
    sim:/alu_tb_selfcheck/total_tests

add wave -noupdate -label "total_pass" \
    -radix unsigned \
    sim:/alu_tb_selfcheck/total_pass

add wave -noupdate -label "total_fail" \
    -radix unsigned \
    sim:/alu_tb_selfcheck/total_fail

add wave -noupdate -label "assertion_fail_count" \
    -radix unsigned \
    sim:/alu_tb_selfcheck/assertion_fail_count


# ==============================================================
# GROUP 4 : INTERNAL DUT SIGNAL (for debugging)
#   Viewing the 5-bit full_result lets you see carry generation
#   before it is split into result[3:0] and carry.
# ==============================================================
add wave -divider "========== DUT INTERNAL (DEBUG) =========="

add wave -noupdate -label {full_result [4:0]} \
    -radix hex \
    sim:/alu_tb_selfcheck/dut/full_result


# ==============================================================
# GROUP 5 : FUNCTIONAL COVERAGE FLAGS
#   Watch these toggle from 0→1 as coverage bins are hit.
# ==============================================================
add wave -divider "========== COVERAGE FLAGS =========="

add wave -noupdate -label {op_seen [7:0]} \
    -radix bin \
    sim:/alu_tb_selfcheck/op_seen

add wave -noupdate -label "cov_carry_high" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_carry_high

add wave -noupdate -label "cov_zero_high" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_zero_high

add wave -noupdate -label "cov_overflow_high" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_overflow_high

add wave -noupdate -label "cov_A_zero" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_A_zero

add wave -noupdate -label "cov_A_ones" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_A_ones

add wave -noupdate -label "cov_B_zero" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_B_zero

add wave -noupdate -label "cov_B_ones" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_B_ones

add wave -noupdate -label "cov_A_eq_B" \
    -radix bin \
    sim:/alu_tb_selfcheck/cov_A_eq_B


# ==============================================================
# FINAL FORMATTING
# ==============================================================

# Zoom to fit all simulation time in the window
WaveRestoreZoom {0 ns} {25 us}

# Update the display
update
