# cocotb test suite — run from this directory:
#   make                 -> node-level directed tests (test_node.py)
#   make network         -> network-level randomized tests (test_network.py)
#   make all_tests       -> both

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES = $(PWD)/../node.vhd $(PWD)/../network.vhd $(PWD)/network_cocotb.vhd

GHDL_ARGS = --std=08

export PYTHONPATH := $(shell python3 -c "import pathlib,cocotb_tools; print(pathlib.Path(cocotb_tools.__file__).parents[1])"):$(PYTHONPATH)

COCOTB_TOPLEVEL ?= node
COCOTB_TEST_MODULES ?= test_node

include $(shell cocotb-config --makefiles)/Makefile.sim

network:
	$(MAKE) COCOTB_TOPLEVEL=network_cocotb COCOTB_TEST_MODULES=test_network SIM_BUILD=sim_build_network

all_tests:
	$(MAKE)
	$(MAKE) network
