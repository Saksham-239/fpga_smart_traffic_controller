# =========================================================================
# ModelSim Simulation Automation Script
# Project:     FPGA Smart Traffic Light Controller
# File:        run_sim.do
# Description: Automates library creation, compilation, loading of UUT signals
#              into the Wave window, and runs the complete test scenario.
# Usage:       In ModelSim command line, type: do run_sim.do
# Author:      Saksham Arora (24BEC0185)
# =========================================================================

# 1. Create work mapping library
if [file exists work] {
    vdel -all
}
vlib work
vmap work work

# 2. Compile synthesizable design files
echo "Compiling Synthesizable RTL..."
vlog ../verilog/debounce.v
vlog ../verilog/traffic_fsm.v
vlog ../verilog/countdown_timer.v
vlog ../verilog/seven_seg_decoder.v
vlog ../verilog/traffic_ctrl.v

# 3. Compile testbench file
echo "Compiling Testbench..."
vlog tb_traffic_ctrl.v

# 4. Load the design for simulation
echo "Loading simulation..."
vsim -novopt work.tb_traffic_ctrl

# 5. Add signals of interest to the wave viewer
echo "Setting up Wave Viewer..."
add wave -divider "Top-Level Ports"
add wave -color "Yellow" sim:/tb_traffic_ctrl/tb_clk
add wave -color "Orange" sim:/tb_traffic_ctrl/tb_key
add wave -color "Cyan"   sim:/tb_traffic_ctrl/tb_sw
add wave -color "White"  sim:/tb_traffic_ctrl/tb_ledr
add wave -color "Pink"   sim:/tb_traffic_ctrl/tb_hex0

add wave -divider "Internal FSM State"
add wave -color "Green"  sim:/tb_traffic_ctrl/uut/u_fsm/state
add wave -color "Blue"   sim:/tb_traffic_ctrl/uut/u_fsm/prev_state
add wave                 sim:/tb_traffic_ctrl/uut/u_fsm/ped_request

add wave -divider "Timer Internal Status"
add wave                 sim:/tb_traffic_ctrl/uut/u_timer/load_val
add wave -color "Red"    sim:/tb_traffic_ctrl/uut/u_timer/time_left
add wave                 sim:/tb_traffic_ctrl/uut/u_timer/done

# 6. Run the simulation
echo "Running testbench scenarios..."
run -all

# 7. Zoom to fit the full waveform display range
wave zoom full
