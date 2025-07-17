# PULP OBI Tutorial - Custom Implementation

This project provides a hands-on guide for creating and validating a minimal, OBI-compliant master and slave using simple SystemVerilog ports. All modules are tested against the official PULP OBI standard infrastructure.

## Quickstart

1.  **Setup**: Clone the required PULP dependencies:
  - common_cells
  - common_verification
  - obi
  
    ```bash
    ./scripts/setup.sh
    ```
2.  **Run Simulation**: Execute the validation testbenches using Vivado Xsim.

    ```bash
    # Run the default testbench (custom master + slave)
    make all
    ```

## Usage

This project supports two different simulation workflows: command-line using Makefiles and GUI-based using Vivado projects.

### Method 1: Command-Line Simulation (Makefile)

The Makefile provides quick command-line simulation using Vivado Xsim:

```bash
# Run all tests
make all

# Test custom master + slave (standalone, no external deps)
make test_custom

# Test custom master vs PULP memory (requires external deps)
make test_master

# Test custom slave vs PULP master (requires external deps) 
make test_slave

# Run specific testbench
make sim TB=tb_obi_custom

# Syntax check only
make check

# Clean generated files
make clean

# Show help
make help
```

### Method 2: Vivado GUI Project

For interactive debugging and waveform analysis, create a Vivado project:

#### Create Project

```bash
cd /home/amir/Projects/AICLAB/Site/obi-tutorial
vivado -mode tcl -source scripts/create_project.tcl
```

After the script completes, you'll see a `Vivado%` prompt. You can then:

**Launch GUI (Recommended):**
```tcl
start_gui
```

**Or run simulation directly from TCL:**
```tcl
launch_simulation -mode behavioral
```

**Or exit and launch GUI separately:**
```tcl
exit
# Then Launch Vivado GUI with the project: 
vivado vivado/obi_tutorial.xpr
```

This creates a Vivado project with three simulation sets:

- **`sim_tb_obi_custom`**: Custom master + slave (standalone, no external deps)
- **`sim_tb_obi_master`**: Custom master vs PULP memory (requires external deps)
- **`sim_tb_obi_slave`**: Custom slave vs PULP master (requires external deps)

#### Run Simulations

1. **Launch Vivado GUI**:
   ```bash
   vivado vivado/obi_tutorial.xpr
   ```

2. **Select Simulation Set**:
   - In Flow Navigator, expand "Simulation"
   - Right-click on desired simulation set (e.g., "sim_tb_obi_custom")
   - Select "Make Active"

3. **Run Simulation**:
   - Click "Run Simulation" → "Run Behavioral Simulation"
   - Or use Tcl command: `launch_simulation -mode behavioral`

4. **Switch Between Tests**:
   ```tcl
   # Switch to custom master+slave test
   current_fileset -simset [get_filesets sim_tb_obi_custom]
   
   # Switch to master validation test  
   current_fileset -simset [get_filesets sim_tb_obi_master]
   
   # Switch to slave validation test
   current_fileset -simset [get_filesets sim_tb_obi_slave]
   ```

### Dependencies

- **Standalone Test** (`tb_obi_custom`): No external dependencies required
- **PULP Integration Tests** (`tb_obi_master`, `tb_obi_slave`): Requires external PULP OBI infrastructure
  ```bash
  ./scripts/setup.sh  # Run this first to clone dependencies
  ```


## Project Structure

```
.
├── rtl/         # Custom OBI master and slave modules
├── sim/         # Testbenches
    ├── tb_obi_master.sv  # Testbench for custom OBI master
    ├── tb_obi_slave.sv   # Testbench for custom OBI slave
    └── tb_obi_custom.sv  # Testbench for custom master + slave integration
├── external/    # PULP OBI reference infrastructure (submodule)
├── scripts/     # Clone dependencies
└── docs/        # Diagrams and tutorial assets
```


## Source Files Overview

### RTL Modules (`rtl/`)
- **obi_master_custom.sv**: Autonomous OBI master for memory BIST, supports pipelined requests, used for protocol validation and self-testing.
- **obi_slave_custom.sv**: Minimal, high-performance OBI slave with embedded memory, byte-enable support, and immediate pipelined responses.

### Testbenches (`sim/`)
- **tb_obi_custom.sv**: Standalone testbench connecting the custom master and slave directly, demonstrating protocol correctness and integration.
- **tb_obi_master.sv**: Tests the custom master against the official PULP OBI memory model, validating master protocol compliance.
- **tb_obi_slave.sv**: Tests the custom slave against the official PULP OBI random manager, validating slave protocol compliance and robustness.

## Example Simulation Output

### Key Design Decisions

- **Simple Port Interface**: Modules use standard input/output ports instead of SystemVerilog interfaces to maximize compatibility and simplify integration.
- **Minimal Protocol**: The implementation adheres strictly to the required OBI signals, avoiding optional features like atomics, user fields, or transaction IDs.
- **PULP Validation**: Compatibility is ensured by testing against the official PULP OBI memory models, random managers, and assertion checkers.

## Validation Strategy

To ensure OBI compliance, this project uses a multi-faceted testing approach, validating the custom modules against both the official PULP OBI infrastructure and each other.

### Testing Combinations

The following testbenches are provided to cover all key validation scenarios:

1.  **Custom Slave vs. PULP Master**

    - **Testbench**: `sim/tb_obi_slave.sv`
    - **Description**: This test validates the custom OBI slave against the official PULP `obi_rand_manager`. It ensures the slave correctly handles a wide range of randomized transactions, verifying full protocol compliance from the perspective of a standard-compliant master.

2.  **Custom Master vs. PULP Slave**

    - **Testbench**: `sim/tb_obi_master.sv`
    - **Description**: This test validates the custom OBI master against the standard PULP `obi_sim_mem` (a slave memory model). It confirms the master can correctly initiate read/write transactions and interact with a standard OBI slave.

3.  **Custom Master vs. Custom Slave**
    - **Testbench**: `sim/tb_obi_custom.sv`
    - **Description**: This test connects the custom master directly to the custom slave. It serves as a baseline integration test to ensure both modules work together correctly in a closed loop.

This strategy ensures that the custom modules are not only self-consistent but also fully compatible with the broader PULP OBI ecosystem.

## OBI Protocol

### Signal Reference

| Phase        | Signal   | Description                            |
| :----------- | :------- | :------------------------------------- |
| **Address**  | `req`    | Master asserts to start a transaction  |
|              | `gnt`    | Slave asserts to accept the request    |
|              | `addr`   | Transaction address                    |
|              | `we`     | Write enable (1 for write, 0 for read) |
|              | `be`     | Byte enables for partial writes        |
|              | `wdata`  | Write data                             |
| **Response** | `rvalid` | Slave asserts when response is valid   |
|              | `rready` | Master asserts when ready for response |
|              | `rdata`  | Read data                              |
|              | `err`    | Slave signals a transaction error      |


## References

- [OBI Protocol Documentation](https://github.com/openhwgroup/obi/blob/main/OBI-v1.6.0.pdf)
- [PULP Platform OBI Specification](https://github.com/pulp-platform/obi)
- [PULP OBI Peripherals](https://github.com/pulp-platform/obi_peripherals)
- [Common Cells Library](https://github.com/pulp-platform/common_cells)
