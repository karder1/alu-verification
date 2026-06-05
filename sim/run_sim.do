# ============================================================
# File: sim/run_sim.do
# Purpose: Compile and run ALU verification project in ModelSim
# Run from sim folder:
#   cd C:/Users/Phat/OneDrive/Documents/TechProj/ALU_4bit/alu_verification/sim
#   do run_sim.do
# ============================================================

# Create/refresh work library
if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

echo ""
echo ">>> Compiling RTL: ../rtl/alu.sv"
vlog -sv -work work +acc ../rtl/alu.sv

echo ""
echo ">>> Compiling Assertions: ../assertions/alu_sva.sv"
vlog -sv -work work +acc ../assertions/alu_sva.sv

echo ""
echo ">>> Compiling Testbench: ../tb/alu_tb_selfcheck.sv"
vlog -sv -work work +acc ../tb/alu_tb_selfcheck.sv

echo ""
echo ">>> Starting simulation"
vsim -t 1ns -voptargs="+acc" work.alu_tb_selfcheck

echo ""
echo ">>> Loading waveform setup"
do waves.do

echo ""
echo ">>> Running simulation"
run -all