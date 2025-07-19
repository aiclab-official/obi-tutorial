# Designing an OBI Slave Controller

Welcome! This tutorial will guide you through the process of designing a minimal, high-performance **OBI (Open Bus Interface) slave controller** in SystemVerilog. By the end, you'll understand the OBI slave protocol and how to implement a slave that supports pipelined, immediate responses for both reads and writes.

---

## 1. What is OBI?

**OBI** is a simple, pipelined bus protocol used in open hardware projects (like PULP). It supports single-cycle requests, pipelined transactions, and separate read/write channels.

**Key OBI signals:**
- `req`/`gnt`: Request/Grant handshake for transaction start
- `addr`: Address bus
- `we`: Write enable (1=write, 0=read)
- `be`: Byte enables (which bytes are valid)
- `wdata`: Write data
- `rvalid`: Read data valid
- `rdata`: Read data
- `err`: Error indicator

| **Signal Name** | **Bit Width** | **Driven By** | **Description**                         |
| --------------- | ------------- | ------------- | --------------------------------------- |
| **clk**         | 1             | Clock         | Clock                                   |
| **rst_n**       | 1             | Reset         | Active low reset                        |
| **req**         | 1             | Master        | Address transfer request                |
| **gnt**         | 1             | Slave         | Grant: Ready to accept address transfer |
| **addr**        | 32            | Master        | Address signal for memory access        |
| **we**          | 1             | Master        | Write enable (1=write, 0=read)          |
| **wdata**       | 32            | Master        | Write data                              |
| **be**          | 4             | Master        | Byte enable                             |
| **rvalid**      | 1             | Slave         | Response transfer request               |
| **rdata**       | 32            | Slave         | Read data                               |
| **err**         | 1             | Slave         | Error response                          |

---

## 2. Design Specification

### Purpose
The OBI slave controller provides a simple, high-throughput memory-mapped interface for OBI masters. It supports immediate, pipelined responses for both reads and writes, and includes error handling for out-of-bounds accesses.

### Features
- **Immediate Single-Cycle Responses:** Both reads and writes are acknowledged in the same cycle as the request.
- **Full Pipelining:** Accepts new requests every cycle, maximizing throughput.
- **Always-Grant Policy:** The slave always asserts `gnt`, never stalls the master.
- **Byte-Enable Support:** Allows partial word writes.
- **Error Handling:** Returns an error if the address is out of bounds.
- **Simple Logic:** No complex state machines, easy to understand and modify.

### OBI Protocol Interface
- **Request Handling:** Accepts every request (`req`), always grants (`gnt`), and generates a response (`rvalid`) immediately.
- **Read:** Returns data from memory if address is valid, otherwise returns zero and sets `err`.
- **Write:** Updates memory with byte enables if address is valid, otherwise sets `err`.

### Operation Sequence
1. **Request:** Master asserts `req` with address, data, and control signals.
2. **Grant:** Slave always asserts `gnt`.
3. **Response:**
   - For reads: Returns data and sets `rvalid`.
   - For writes: Sets `rvalid` (data is zero).
   - If address is invalid, sets `err`.

### Parameters
- `ADDR_WIDTH`: Address bus width (default 32)
- `DATA_WIDTH`: Data bus width (default 32)
- `MEM_SIZE`: Memory size in bytes (default 1024)

### Outputs
- `obi_gnt_o`: Always high (slave always ready)
- `obi_rvalid_o`: High when response is valid
- `obi_rdata_o`: Read data (for reads)
- `obi_err_o`: High if address is invalid

---

## 3. Operation Flow

The OBI slave controller operates as a simple combinational and sequential logic block:

1. **Request Handling**
   - On every cycle, if `obi_req_i` is high, the slave processes the request.
   - Checks if the address is valid (within memory bounds).
2. **Read Operation**
   - If `obi_we_i` is low and address is valid, returns the requested word from memory.
   - If address is invalid, returns zero and sets `err`.
3. **Write Operation**
   - If `obi_we_i` is high and address is valid, updates memory using byte enables.
   - If address is invalid, sets `err`.
4. **Response Generation**
   - Sets `rvalid` high for every request.
   - Sets `err` if address is invalid.

**Summary:**

| **Step**   | **What Happens?**                                      |
| ----------| ------------------------------------------------------ |
| Request   | Master issues request, slave always grants.            |
| Read      | Returns data if valid, else zero and error.            |
| Write     | Updates memory if valid, else sets error.              |
| Response  | `rvalid` high for every request, `err` if invalid.     |

---

## 4. Code Structure

### Module Interface

```systemverilog
module obi_slave_custom #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned MEM_SIZE = 1024
) (
    input  logic clk_i,
    input  logic rst_ni,
    // OBI interface
    input  logic                    obi_req_i,
    output logic                    obi_gnt_o,
    input  logic [ADDR_WIDTH-1:0]   obi_addr_i,
    input  logic                    obi_we_i,
    input  logic [DATA_WIDTH/8-1:0] obi_be_i,
    input  logic [DATA_WIDTH-1:0]   obi_wdata_i,
    output logic                    obi_rvalid_o,
    output logic [DATA_WIDTH-1:0]   obi_rdata_o,
    output logic                    obi_err_o
);
```

---

### Memory and Address Checking

```systemverilog
logic [7:0] memory [0:MEM_SIZE-1];
logic addr_valid;
assign addr_valid = (obi_addr_i <= MEM_SIZE - 4);  // Ensure 32-bit word fits
```

---

### Read Logic

```systemverilog
// Always grant requests
assign obi_gnt_o = 1'b1;

// Combinational read logic
logic [DATA_WIDTH-1:0] read_data;
always_comb begin
    if (addr_valid) begin
        read_data = {memory[obi_addr_i + 3], 
                    memory[obi_addr_i + 2], 
                    memory[obi_addr_i + 1], 
                    memory[obi_addr_i + 0]};
    end else begin
        read_data = '0;
    end
end
```

This block creates a 32-bit word (`read_data`) from the memory array for read operations:

- If the requested address is valid (within memory bounds), it assembles the 32-bit word by concatenating four consecutive bytes from the memory array, starting at `obi_addr_i`. The bytes are ordered so that `memory[obi_addr_i + 0]` is the least significant byte and `memory[obi_addr_i + 3]` is the most significant, forming a little-endian word.
- If the address is invalid (out of bounds), it returns zero.

---

### Response Generation

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        rvalid_q <= '0;
        rdata_q  <= '0;
        err_q    <= '0;
        for (int i = 0; i < MEM_SIZE; i++) begin
            memory[i] <= 8'h0;
        end
    end else begin
        if (obi_req_i) begin
            rvalid_q <= 1'b1;
            err_q    <= !addr_valid;
            if (obi_we_i) begin
                rdata_q <= '0;  // Write responses have no data
            end else begin
                rdata_q <= read_data;  // Read responses return data
            end
        end else begin
            rvalid_q <= 1'b0;
        end
    end
end
```

This block handles the OBI slave’s response to every request:
- On reset, it clears the response registers and initializes the memory to zero.
- On each clock cycle:
  - If a request (`obi_req_i`) is present:
    - Sets `rvalid_q` high to indicate a valid response.
    - Checks if the address is valid; if not, sets the error flag (`err_q`).
    - For a write (`obi_we_i` high): returns zero as write responses do not provide data.
    - For a read (`obi_we_i` low): returns the data from memory (`read_data`).
  - If there is no request, `rvalid_q` is cleared (no response).

---

### Write Handling

```systemverilog
always_ff @(posedge clk_i) begin
    if (obi_req_i && obi_we_i && addr_valid) begin
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
            if (obi_be_i[i]) begin
                memory[obi_addr_i + i] <= obi_wdata_i[i*8 +: 8];
            end
        end
    end
end
```

This block updates the memory array for every valid write request. The for loop is responsible for supporting partial (byte-wise) writes:

- On each clock cycle, if a write request is present and the address is valid:
  - The loop iterates over each byte in the data word (i from 0 to 3 for 32-bit data).
  - For each byte, it checks the corresponding byte enable (`obi_be_i[i]`).
  - If the byte enable is set, it writes that byte from the write data (`obi_wdata_i`) into the correct memory location (`memory[obi_addr_i + i]`).


---

### Output Assignments

```systemverilog
assign obi_rvalid_o = rvalid_q;
assign obi_rdata_o  = rdata_q;
assign obi_err_o    = err_q;
```

---

## 5. Complete Example

See the full [`obi_slave_custom.sv`](../rtl/obi_slave_custom.sv) file for a working implementation.

---

## 6. Summary

- **OBI slave** provides immediate, pipelined responses
- **Always-grant** policy for maximum throughput
- **Byte-enable** and error handling support
- **Simple, educational code structure**

---

## 7. Next Steps

- Try changing `MEM_SIZE` to see how the slave handles different memory sizes.
- Integrate this slave with your own OBI master or testbench.
- Add more advanced error handling or features as needed.

---

**Congratulations!** You now understand how to design a minimal OBI slave controller in SystemVerilog.

For more, see the [PULP OBI documentation](https://github.com/pulp-platform/obi) and the rest of this tutorial project.
