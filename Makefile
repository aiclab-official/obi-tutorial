# Makefile for Custom OBI Tutorial
# Vivado Xsim simulation only

# Default testbench
TB ?= tb_obi_custom

# Source directories
RTL_DIR = rtl
SIM_DIR = sim
EXT_DIR = external

# Vivado tools
XVLOG = xvlog
XELAB = xelab
XSIM = xsim

# Include paths for Vivado
INCDIRS = -i $(EXT_DIR)/obi/include -i $(EXT_DIR)/common_cells/include

# Vivado flags
XVLOG_FLAGS = --sv $(INCDIRS)
XELAB_FLAGS = -debug all
XSIM_FLAGS = -t xsim.tcl

# Source files
RTL_SOURCES = $(RTL_DIR)/obi_master_custom.sv

# Common cells dependencies (required for OBI)
COMMON_CELLS_SOURCES = $(EXT_DIR)/common_cells/src/cf_math_pkg.sv \
                       $(EXT_DIR)/common_cells/src/addr_decode.sv \
                       $(EXT_DIR)/common_cells/src/delta_counter.sv \
                       $(EXT_DIR)/common_cells/src/lzc.sv \
                       $(EXT_DIR)/common_cells/src/addr_decode_dync.sv \
                       $(EXT_DIR)/common_cells/src/rr_arb_tree.sv \
                       $(EXT_DIR)/common_cells/src/fifo_v3.sv \
                       $(EXT_DIR)/common_verification/src/clk_rst_gen.sv

# OBI dependencies
OBI_SOURCES = $(EXT_DIR)/obi/src/obi_pkg.sv \
              $(EXT_DIR)/obi/src/obi_intf.sv \
              $(EXT_DIR)/obi/src/obi_sram_shim.sv \
              $(EXT_DIR)/obi/src/obi_mux.sv \
              $(EXT_DIR)/obi/src/obi_demux.sv \
              $(EXT_DIR)/obi/src/obi_xbar.sv \
              $(EXT_DIR)/obi/src/test/obi_sim_mem.sv \
              $(EXT_DIR)/obi/src/test/obi_asserter.sv \
              $(EXT_DIR)/obi/src/test/obi_test.sv \
              $(EXT_DIR)/obi/src/test/atop_golden_mem_pkg.sv

# All external dependencies
EXT_SOURCES = $(COMMON_CELLS_SOURCES) $(OBI_SOURCES)

# Default target
all: test_master


# Test custom master vs PULP memory
test_master: 
	@echo "Running custom master vs PULP memory test..."
	$(XVLOG) $(XVLOG_FLAGS) $(RTL_SOURCES) $(EXT_SOURCES) $(SIM_DIR)/tb_obi_master.sv
	$(XELAB) tb_obi_master -s tb_obi_master_sim $(XELAB_FLAGS)
	$(XSIM) tb_obi_master_sim $(XSIM_FLAGS)

# Generic simulation target
# Usage: make sim TB=tb_obi_custom
sim:
	@echo "Running Vivado simulation for $(TB)..."
	$(XVLOG) $(XVLOG_FLAGS) $(RTL_SOURCES) $(EXT_SOURCES) $(SIM_DIR)/$(TB).sv
	$(XELAB) $(TB) -s $(TB)_sim $(XELAB_FLAGS)
	$(XSIM) $(TB)_sim $(XSIM_FLAGS)

# Syntax check
check:
	@echo "Checking syntax..."
	$(XVLOG) $(XVLOG_FLAGS) $(RTL_SOURCES)

# Clean generated files
clean:
	rm -rf .Xil .Xil_*
	rm -rf *.jou *.log *.wdb
	rm -rf *_sim
	rm -rf xsim.dir

# Help
help:
	@echo "PULP OBI Tutorial - Custom Implementation"
	@echo "========================================"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Vivado (tested with v2024.2)"
	@echo "  - Run './scripts/setup.sh' first to clone dependencies"
	@echo ""
	@echo "Available targets:"
	@echo "  all               - Run all tests"
	@echo "  test_master       - Test custom master vs PULP memory (requires ext deps)"
	@echo "  sim               - Generic simulation (use TB=testbench_name)"
	@echo "  check             - Syntax check only"
	@echo "  clean             - Clean generated files"
	@echo "  help              - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  TB                - Testbench name for sim target (default: $(TB))"
	@echo ""
	@echo "Examples:"
	@echo "  make sim TB=tb_obi_master          # Run specific testbench"
	@echo "  make clean; make test_master       # Clean and test"
	@echo ""
	@echo "Notes:"
	@echo "  - All simulations use Vivado Xsim"
	@echo "  - Waveforms are saved as .wdb files"

.PHONY: all test_master  sim check clean help
