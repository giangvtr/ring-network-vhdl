# =======================================================
# SCRIPT DE SIMULATION POUR LE RESEAU EN ANNEAU (N=3)
# Fichier: run_network_test.do
# =======================================================

# 1. NETTOYAGE ET COMPILATION
# Créer (ou nettoyer) la librairie de travail 'work'
vlib work
vmap work work

# Compiler les fichiers VHDL dans l'ordre de dépendance :
# - data_types.vhd (package)
# - Node.vhd (composant de base, si vous l'avez)
# - network.vhd (architecture réseau)
# - network_tb.vhd (testbench)

vcom Node.vhd
vcom network.vhd
vcom network_tb.vhd

# 2. LANCEMENT DE LA SIMULATION
# Lancer la simulation sur l'entité test (NETWORK_TB)
# Utiliser l'option +acc pour accéder aux signaux internes du DUT (UUT)
vsim -c -novopt +acc work.network_tb

# 3. CONFIGURATION DE LA FENÊTRE D'ONDES (WAVE)

# Ajouter l'horloge et les ports de contrôle/status (Ports externes)
add wave /network_tb/clk_sig

add wave -divider "Ports Externes H-G (N?ud 0)"
add wave /network_tb/test_in1_sig
add wave /network_tb/test_ok1_sig
add wave /network_tb/env_mes1_sig
add wave /network_tb/mess_in1_sig
add wave /network_tb/mess_out1_sig

add wave -divider "Ports Externes B-D (N?ud 7)"
add wave /network_tb/test_in2_sig
add wave /network_tb/test_ok2_sig
add wave /network_tb/env_mes2_sig
add wave /network_tb/mess_in2_sig
add wave /network_tb/mess_out2_sig

#signaux internes
add wave -divider "Liens (Trames) : trout_mat"
add wave /network_tb/uut/trout_mat

# Configuration de l'affichage en Hexadécimal pour la lisibilité
radix hex /network_tb/uut/trout_mat
radix hex /network_tb/mess_out1_sig
radix hex /network_tb/mess_out2_sig

# Déplier le signal trout_mat pour voir les 8 liens (0 à 7) individuellement
# C'est ainsi que vous verrez la trame se déplacer à chaque cycle.
force -freeze sim:/network_tb/uut/trout_mat -expand 

# Positionner la fenêtre d'ondes au début
wave zoom full

# 4. EXÉCUTION DE LA SIMULATION
# Exécuter la simulation pour 600 ns (suffisant pour le testbench)
run 600 ns