# OBI Bus Tutorial - Creating a Minimal OBI Master and Slave

> Validated against the PULP OBI test infrastructure

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
    # Run the default testbench (custom master)
    make all
    ```

## Usage

This project supports two different simulation workflows: command-line using Makefiles and GUI-based using Vivado projects.

### Method 1: Command-Line Simulation (Makefile)

The Makefile provides quick command-line simulation using Vivado Xsim:

```bash
# Run all tests
make all

# Test custom master vs PULP memory (requires external deps)
make test_master


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
cd obi-tutorial
vivado -mode tcl -source scripts/create_project.tcl
```

After the script completes, vivado/obi_tutorial.xpr project file will be created, and you'll see a `Vivado%` prompt. You can then:

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

- **`sim_tb_obi_master`**: Custom master vs PULP memory (requires external deps)

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
   # Switch to master validation test  
   current_fileset -simset [get_filesets sim_tb_obi_master]
   ```

#### Simulation Output

```bash
make test_master
```

<details>
<summary>Results</summary>

```
=== Autonomous OBI Master Memory Test ===
Master started autonomous test sequence
Write: addr=0x00001000, data=0xa5a5a5a5
Write: addr=0x00001004, data=0xa5a52184
Write: addr=0x00001008, data=0xa5a4ade7
Write: addr=0x0000100c, data=0xa5a429c6
Write: addr=0x00001010, data=0xa5a7b521
Write: addr=0x00001014, data=0xa5a73100
Write: addr=0x00001018, data=0xa5a6bd63
Write: addr=0x0000101c, data=0xa5a63942
Write: addr=0x00001020, data=0xa5a184ad
Write: addr=0x00001024, data=0xa5a1008c
Write: addr=0x00001028, data=0xa5a08cef
Write: addr=0x0000102c, data=0xa5a008ce
Write: addr=0x00001030, data=0xa5a39429
Write: addr=0x00001034, data=0xa5a31008
Write: addr=0x00001038, data=0xa5a29c6b
Write: addr=0x0000103c, data=0xa5a2184a
Read response: data=0xxxxxxxxx
Read response: data=0xxxxxxxxx
Read: addr=0x00001000
Read: addr=0x00001004
Read: addr=0x00001008
Read response: data=0xa5a5a5a5
Read: addr=0x0000100c
Read response: data=0xa5a52184
Read: addr=0x00001010
Read response: data=0xa5a4ade7
Read: addr=0x00001014
Read response: data=0xa5a429c6
Read: addr=0x00001018
Read response: data=0xa5a7b521
Read: addr=0x0000101c
Read response: data=0xa5a73100
Read: addr=0x00001020
Read response: data=0xa5a6bd63
Read: addr=0x00001024
Read response: data=0xa5a63942
Read: addr=0x00001028
Read response: data=0xa5a184ad
Read: addr=0x0000102c
Read response: data=0xa5a1008c
Read: addr=0x00001030
Read response: data=0xa5a08cef
Read: addr=0x00001034
Read response: data=0xa5a008ce
Read: addr=0x00001038
Read response: data=0xa5a39429
Read: addr=0x0000103c
Read response: data=0xa5a31008
Read response: data=0xa5a29c6b
Read response: data=0xa5a2184a
SUCCESS: All memory tests passed!
=== Test Results ===
✓ Memory test PASSED - All data verified correctly
✓ Master performed autonomous write/read sequence successfully
```
</details>

---

### Dependencies

- **PULP Integration Tests** (`tb_obi_master`): Requires external PULP OBI infrastructure
  ```bash
  ./scripts/setup.sh  # Run this first to clone dependencies
  ```


## Project Structure

```
.
├── rtl/         # Custom OBI master module
├── sim/         # Testbenches
    ├── tb_obi_master.sv  # Testbench for custom OBI master
├── external/    # PULP OBI reference infrastructure (submodule)
├── scripts/     # Clone dependencies
└── docs/        # Diagrams and tutorial assets
```


## Source Files Overview

### RTL Modules (`rtl/`)
- **obi_master_custom.sv**: Autonomous OBI master for memory BIST, supports pipelined requests, used for protocol validation and self-testing.

### Testbenches (`sim/`)
- **tb_obi_master.sv**: Tests the custom master against the official PULP OBI memory model, validating master protocol compliance.

## Example Simulation Output

### Key Design Decisions

- **Simple Port Interface**: Modules use standard input/output ports instead of SystemVerilog interfaces to maximize compatibility and simplify integration.
- **Minimal Protocol**: The implementation adheres strictly to the required OBI signals, avoiding optional features like atomics, user fields, or transaction IDs.
- **PULP Validation**: Compatibility is ensured by testing against the official PULP OBI memory models, random managers, and assertion checkers.

## Validation Strategy

To ensure OBI compliance, this project uses a multi-faceted testing approach, validating the custom modules against both the official PULP OBI infrastructure and each other.

### Testing Combinations

The following testbenches are provided to cover all key validation scenarios:


1.  **Custom Master vs. PULP Slave**

    - **Testbench**: `sim/tb_obi_master.sv`
    - **Description**: This test validates the custom OBI master against the standard PULP `obi_sim_mem` (a slave memory model). It confirms the master can correctly initiate read/write transactions and interact with a standard OBI slave.

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
|              | `rdata`  | Read data                              |


## References

- [OBI Protocol Documentation](https://github.com/openhwgroup/obi/blob/main/OBI-v1.6.0.pdf)
- [PULP Platform OBI Specification](https://github.com/pulp-platform/obi)
- [PULP OBI Peripherals](https://github.com/pulp-platform/obi_peripherals)
- [Common Cells Library](https://github.com/pulp-platform/common_cells)
