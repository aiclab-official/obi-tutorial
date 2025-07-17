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

```bash
make test_slave
```

<details>
<summary>Results</summary>

```
=== OBI Slave Tutorial Test ===

Test 1: Basic Write/Read Operation
  Writing 0xCAFEBABE to address 0x100
[60000] Write: addr=0x00000100, data=0xcafebabe, be=0xf
[70000] Response: data=0x00000000, err=0
  Reading from address 0x100
[80000] Read:  addr=0x00000100
[90000] Response: data=0xcafebabe, err=0
  ✓ PASS: Read data matches written data (0xcafebabe)

Test 2: Byte Enable Functionality
  Writing 0xDEADBEEF with byte enables 0x3 (lower 2 bytes only)
[100000] Write: addr=0x00000200, data=0xdeadbeef, be=0x3
[110000] Response: data=0x00000000, err=0
[120000] Read:  addr=0x00000200
[130000] Response: data=0x0000beef, err=0
  ✓ PASS: Byte enables working correctly (0x0000beef)

Test 3: Pipelined Operations
  Phase 1: Pipelined Writes
    Write 0: addr=0x00000300, data=0xa0000000
[140000] Write: addr=0x00000300, data=0xa0000000, be=0xf
    Write 1: addr=0x00000304, data=0xa0000001
[150000] Write: addr=0x00000304, data=0xa0000001, be=0xf
[150000] Response: data=0x00000000, err=0
    Write 2: addr=0x00000308, data=0xa0000002
[160000] Write: addr=0x00000308, data=0xa0000002, be=0xf
[160000] Response: data=0x00000000, err=0
    Write 3: addr=0x0000030c, data=0xa0000003
[170000] Write: addr=0x0000030c, data=0xa0000003, be=0xf
[170000] Response: data=0x00000000, err=0
    Write 4: addr=0x00000310, data=0xa0000004
[180000] Write: addr=0x00000310, data=0xa0000004, be=0xf
[180000] Response: data=0x00000000, err=0
    Write 5: addr=0x00000314, data=0xa0000005
[190000] Write: addr=0x00000314, data=0xa0000005, be=0xf
[190000] Response: data=0x00000000, err=0
    Write 6: addr=0x00000318, data=0xa0000006
[200000] Write: addr=0x00000318, data=0xa0000006, be=0xf
[200000] Response: data=0x00000000, err=0
    Write 7: addr=0x0000031c, data=0xa0000007
[210000] Write: addr=0x0000031c, data=0xa0000007, be=0xf
[210000] Response: data=0x00000000, err=0
[220000] Response: data=0x00000000, err=0
  Phase 2: Pipelined Reads with Verification
[260000] Read:  addr=0x00000300
[270000] Read:  addr=0x00000304
[270000] Response: data=0xa0000000, err=0
    ✓ Read 0: data=0xa0000000 matches expected
[280000] Read:  addr=0x00000308
[280000] Response: data=0xa0000001, err=0
    ✓ Read 1: data=0xa0000001 matches expected
[290000] Read:  addr=0x0000030c
[290000] Response: data=0xa0000002, err=0
    ✓ Read 2: data=0xa0000002 matches expected
[300000] Read:  addr=0x00000310
[300000] Response: data=0xa0000003, err=0
    ✓ Read 3: data=0xa0000003 matches expected
[310000] Read:  addr=0x00000314
[310000] Response: data=0xa0000004, err=0
    ✓ Read 4: data=0xa0000004 matches expected
[320000] Read:  addr=0x00000318
[320000] Response: data=0xa0000005, err=0
    ✓ Read 5: data=0xa0000005 matches expected
[330000] Read:  addr=0x0000031c
[330000] Response: data=0xa0000006, err=0
    ✓ Read 6: data=0xa0000006 matches expected
[340000] Response: data=0xa0000007, err=0
    ✓ Read 7: data=0xa0000007 matches expected
  ✓ PASS: All pipelined operations successful

=== Test Completed ===
Simulation completed successfully!
```
</details>

---

```bash
make test_custom
```

<details>
<summary>Results</summary>

```
=== Custom OBI Master + Slave Test ===
Master will autonomously test slave memory...
✓ Master started autonomous test sequence
[55000] Write: addr=0x00000100, data=0xa5a5a5a5, be=0xf
[55000] Master: Starting test sequence
[65000] Write: addr=0x00000104, data=0xa5a5b4b4, be=0xf
[65000] Response: data=0x00000000, err=0
[75000] Write: addr=0x00000108, data=0xa5a58787, be=0xf
[75000] Response: data=0x00000000, err=0
[85000] Write: addr=0x0000010c, data=0xa5a59696, be=0xf
[85000] Response: data=0x00000000, err=0
[95000] Write: addr=0x00000110, data=0xa5a5e1e1, be=0xf
[95000] Response: data=0x00000000, err=0
[105000] Write: addr=0x00000114, data=0xa5a5f0f0, be=0xf
[105000] Response: data=0x00000000, err=0
[115000] Write: addr=0x00000118, data=0xa5a5c3c3, be=0xf
[115000] Response: data=0x00000000, err=0
[125000] Write: addr=0x0000011c, data=0xa5a5d2d2, be=0xf
[125000] Response: data=0x00000000, err=0
[135000] Response: data=0x00000000, err=0
[155000] Read:  addr=0x00000100
[165000] Read:  addr=0x00000104
[165000] Response: data=0xa5a5a5a5, err=0
[175000] Read:  addr=0x00000108
[175000] Response: data=0xa5a5b4b4, err=0
[185000] Read:  addr=0x0000010c
[185000] Response: data=0xa5a58787, err=0
[195000] Read:  addr=0x00000110
[195000] Response: data=0xa5a59696, err=0
[205000] Read:  addr=0x00000114
[205000] Response: data=0xa5a5e1e1, err=0
[215000] Read:  addr=0x00000118
[215000] Response: data=0xa5a5f0f0, err=0
[225000] Read:  addr=0x0000011c
[225000] Response: data=0xa5a5c3c3, err=0
[235000] Response: data=0xa5a5d2d2, err=0

=== Test Results ===
✓ SUCCESS: All memory tests passed!
✓ Master-Slave communication working correctly
[245000] Master: Test sequence completed
```
</details>

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
