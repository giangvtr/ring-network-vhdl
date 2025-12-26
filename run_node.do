# Compiler
vlib work
vcom node.vhd
vcom node_tb.vhd

# Simuler
vsim work.node_tb
noforce *

# Ajouter les signaux à la waveform
add wave -hex *

# Run
run 200 ns
wave zoom full