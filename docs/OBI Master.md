# Designing an OBI Master Controller

Welcome! This tutorial will guide you through the process of designing a minimal, **OBI (Open Bus Interface) master controller** in SystemVerilog. By the end, you'll understand the OBI protocol basics and how to implement a master that can perform memory tests without external control.

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
---


## 2. Design Specification

### Purpose
The OBI master controller autonomously performs a memory Built-In Self-Test (BIST) using the OBI protocol. It writes a sequence of test patterns to memory, reads them back, verifies correctness, and reports the result, all without external control.

### Features
- **Autonomous Operation:** Begins test sequence automatically after reset.
- **Pipelined OBI Requests:** Issues back-to-back write and read requests for high throughput.
- **Configurable Test Parameters:** Number of words, base address, and test pattern are parameterized.
- **Parallel Verification:** Checks read data against expected values as responses arrive.
- **Status Outputs:** Indicates busy, done, pass/fail, and error count for easy integration.

### OBI Protocol Interface
- **Write:** Issues requests with `obi_req_o`, `obi_we_o=1`, address, data, and byte enables. Waits for `obi_gnt_i` before proceeding.
- **Read:** Issues requests with `obi_req_o`, `obi_we_o=0`, and address. Waits for `obi_gnt_i` and then for `obi_rvalid_i` to receive data.
- **Verification:** Compares received data (`obi_rdata_i`) with expected pattern and counts errors.

### Operation Sequence (State Machine)
1. **IDLE:** Waits for reset de-assertion.
2. **WRITE_REQ:** Writes test patterns to memory, one word at a time.
3. **WRITE_WAIT:** Inserts a delay to separate write and read responses.
4. **READ_REQ:** Issues read requests to the same addresses.
5. **READ_WAIT:** Waits for and verifies all read responses.
6. **DONE:** Test complete; status outputs are held.

### Parameters
- `ADDR_WIDTH`: Address bus width (default 32)
- `DATA_WIDTH`: Data bus width (default 32)
- `NUM_TEST_WORDS`: Number of words to test (default 8)
- `BASE_ADDR`: Starting address for test (default 0x1000)
- `TEST_PATTERN`: Base pattern for test data (default 0xA5F3895A)

### Outputs
- `busy_o`: High when test is running
- `test_done_o`: High when test is complete
- `test_pass_o`: High if all data verified correctly
- `error_count_o`: Number of data mismatches detected


---

## 3. Operation Flow

The OBI master controller operates as a state machine, following these steps:

1. **IDLE**
   - Waits for reset to de-assert.
   - When reset is released, the master starts the test sequence.

2. **WRITE_REQ**
   - Issues write requests to memory.
   - For each word:
     - Sets up address and data.
     - Asserts `obi_req_o`, sets `obi_we_o = 1`.
     - Waits for `obi_gnt_i` (grant) from the slave.
     - Increments the address for the next word.
   - After all words are written, moves to the next state.

3. **WRITE_WAIT**
   - Inserts a short delay (e.g., 2 cycles) to ensure all write responses are flushed and the bus is ready for reads.

4. **READ_REQ**
   - Issues read requests to the same addresses.
   - For each word:
     - Sets up address.
     - Asserts `obi_req_o`, sets `obi_we_o = 0`.
     - Waits for `obi_gnt_i` (grant).
     - Increments the address for the next word.
   - After all read requests, moves to verification.

5. **READ_WAIT**
   - Waits for read responses (`obi_rvalid_i`).
   - For each response:
     - Compares received data (`obi_rdata_i`) with the expected pattern.
     - Increments error counter if data mismatches.
     - Increments verification counter.
   - When all responses are checked, moves to DONE.

6. **DONE**
   - Test is complete.
   - Status outputs (`test_done_o`, `test_pass_o`, `error_count_o`) are set.
   - The master remains in this state.

**Summary:**

| **State**  | **What Happens?**                                  |
| ---------- | -------------------------------------------------- |
| IDLE       | Wait for reset release, then start test.           |
| WRITE_REQ  | Write each test word to memory, one by one.        |
| WRITE_WAIT | Short pause to separate write and read phases.     |
| READ_REQ   | Issue read requests for each test word.            |
| READ_WAIT  | Wait for read responses, check data, count errors. |
| DONE       | Test finished, outputs results, waits for reset.   |

---
## 4. Code Structure

### Module Interface

Define the module parameters and ports:

```systemverilog
module obi_master_custom #(
    parameter int unsigned ADDR_WIDTH     = 32,
    parameter int unsigned DATA_WIDTH     = 32,
    parameter int unsigned NUM_TEST_WORDS = 8,
    parameter logic [31:0] BASE_ADDR      = 32'h1000,
    parameter logic [31:0] TEST_PATTERN   = 32'hA5F3895A
) (
    input  logic clk_i,
    input  logic rst_ni,
    // Status outputs
    output logic busy_o,
    output logic test_done_o,
    output logic test_pass_o,
    output logic [7:0] error_count_o,
    // OBI interface
    output logic obi_req_o,
    input  logic obi_gnt_i,
    output logic [ADDR_WIDTH-1:0] obi_addr_o,
    output logic obi_we_o,
    output logic [DATA_WIDTH/8-1:0] obi_be_o,
    output logic [DATA_WIDTH-1:0] obi_wdata_o,
    input  logic obi_rvalid_i,
    input  logic [DATA_WIDTH-1:0] obi_rdata_i
);
```

---

### State Machine

Define the states for the autonomous sequence:

- **IDLE**: Wait for reset release
- **WRITE_REQ**: Issue write requests
- **WRITE_WAIT**: Wait for writes to complete
- **READ_REQ**: Issue read requests
- **READ_WAIT**: Wait for and verify read responses
- **DONE**: Test complete

```systemverilog
typedef enum logic [2:0] {
    IDLE, WRITE_REQ, WRITE_WAIT, READ_REQ, READ_WAIT, DONE
} state_e;
state_e state_q, state_d;
```

---

### Address and Data Generation

Generate addresses and test patterns for each word:

```systemverilog
logic [$clog2(NUM_TEST_WORDS):0] word_count_q, word_count_d;
logic [$clog2(NUM_TEST_WORDS):0] verify_count_q;
logic [31:0] current_addr, current_wdata, expected_rdata;
```

1. **Address Calculation**: Generates the address for each memory access.

```systemverilog
assign current_addr   = BASE_ADDR + (word_count_q << 2); // Word-aligned
```

shifting left by 2 multiplies by 4, so addresses increment by 4 bytes (32 bits), ensuring each access is word-aligned. For each test word, the address is `BASE_ADDR`, `BASE_ADDR+4`, `BASE_ADDR+8`, etc.

2. **Data Generation**: Creates the test data pattern based on the current word count.

```systemverilog
assign current_wdata  = TEST_PATTERN ^ {word_count_q, word_count_q, word_count_q, word_count_q};
assign expected_rdata = TEST_PATTERN ^ {verify_count_q, verify_count_q, verify_count_q, verify_count_q};
```

Generates a unique data pattern for each write. The test pattern is XORed with a vector where each byte is the current word index. This ensures each word written has a different value, making it easy to detect addressing or data errors.

---

### State Machine Logic

The OBI master uses a state machine to control its autonomous memory test. 
Implement the state transitions and counters:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        state_q      <= IDLE;
        word_count_q <= '0;
        // ... other resets ...
    end else begin
        state_q      <= state_d;
        word_count_q <= word_count_d;
        // ... other updates ...
    end
end

always_comb begin
    // Default assignments
    state_d      = state_q;
    word_count_d = word_count_q;
    // ... other defaults ...
    case (state_q)
        IDLE: if (!all_done_q) state_d = WRITE_REQ;
        WRITE_REQ: if (obi_gnt_i) begin
            if (word_count_q == NUM_TEST_WORDS - 1) begin
                word_count_d = '0;
                state_d = WRITE_WAIT;
            end else word_count_d = word_count_q + 1;
        end
        // ... other states ...
    endcase
end
```


- **IDLE:**
  - Waits for reset to finish.
  - If the test hasn’t run yet (`!all_done_q`), moves to `WRITE_REQ` to start the test.
- **WRITE_REQ:**
  - Issues write requests.
  - Waits for the slave to grant (`obi_gnt_i`).
  - If all words have been written (`word_count_q == NUM_TEST_WORDS - 1`), resets the counter and moves to `WRITE_WAIT`.
  - Otherwise, increments the word counter to write the next word.
- **WRITE_WAIT:**
  - Waits for 2 cycles (using `wait_count_q`) to separate write and read responses.
  - After waiting, resets the wait counter and moves to `READ_REQ`.
- **READ_REQ:**
  - Issues read requests.
  - Waits for the slave to grant (`obi_gnt_i`).
  - If all read requests have been issued, resets the counter and moves to `READ_WAIT`.
  - Otherwise, increments the word counter to issue the next read.
- **READ_WAIT:**
  - Waits for all read responses to be verified (tracked by `verify_count_q` elsewhere).
  - When all responses are checked, sets `all_done_d` and moves to `DONE`.
- **DONE:**
  - The test is complete. The state machine stays here until reset.
- **default:**
  - If for some reason the state is invalid, returns to `IDLE`.

---

### Verification Logic

Check read data as it arrives:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        verify_count_q <= '0;
        error_count_q  <= '0;
    end else if (obi_rvalid_i && (state_q == READ_REQ || state_q == READ_WAIT)) begin
        if (obi_rdata_i != expected_rdata)
            error_count_q <= error_count_q + 1;
        verify_count_q <= verify_count_q + 1;
    end
end
```

---

### OBI Output Logic

Drive the OBI bus based on the current state:

```systemverilog
assign obi_req_o    = (state_q == WRITE_REQ) || (state_q == READ_REQ);
assign obi_addr_o   = current_addr;
assign obi_we_o     = (state_q == WRITE_REQ);
assign obi_be_o     = 4'hF; // Full word
assign obi_wdata_o  = current_wdata;
```

---

### Status Outputs

Report the test status:

```systemverilog
assign busy_o        = !all_done_q && (state_q != IDLE);
assign test_done_o   = all_done_q;
assign test_pass_o   = all_done_q && (error_count_q == 0);
assign error_count_o = error_count_q;
```

---

## 5. Complete Example

See the full [`obi_master_custom.sv`](rtl/obi_master_custom.sv) file for a working implementation.

---

## 6. Summary

- **OBI master** issues pipelined write/read requests
- **Autonomous** operation via state machine
- **Verification** logic checks data correctness
- **Status outputs** for integration and monitoring

---

## 7. Next Steps

- Try changing `NUM_TEST_WORDS`, `BASE_ADDR`, or `TEST_PATTERN` to see different test behaviors.
- Integrate this master with your own OBI-compliant memory or slave device.
- Expand the state machine for more advanced test scenarios.

---

**Congratulations!** You now understand how to design a minimal OBI master controller in SystemVerilog.

For more, see the [PULP OBI documentation](https://github.com/pulp-platform/obi) and the rest of this tutorial project.