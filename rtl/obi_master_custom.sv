// -----------------------------------------------------------------------------
// Project:      OBI Tutorial
// Company:      AICLAB
//
// Module:       obi_master_custom
// Description:
//   Autonomous OBI master for memory Built-In Self-Test (BIST).
//   After reset, this master automatically performs a configurable sequence of
//   write and read operations to a specified memory region. It verifies the
//   data and reports the test status.
//
//   Features:
//   - Fully autonomous operation, no external controller needed.
//   - Pipelined OBI requests for high throughput.
//   - Configurable test parameters (address, data pattern, number of words).
//   - Parallel verification of read responses.
//   - Status outputs for easy integration and monitoring.
//
// Operation Sequence:
//   1. IDLE:       Waits for reset to de-assert.
//   2. WRITE_REQ:  Writes a sequence of test patterns to memory.
//   3. WRITE_WAIT: Inserts a delay to ensure write responses are flushed.
//   4. READ_REQ:   Reads back the data from memory.
//   5. READ_WAIT:  Verifies incoming read data against expected values.
//   6. DONE:       Test complete, holds final status.
//
// -----------------------------------------------------------------------------

module obi_master_custom
#(
    parameter int unsigned ADDR_WIDTH     = 32,
    parameter int unsigned DATA_WIDTH     = 32,
    parameter int unsigned NUM_TEST_WORDS = 8,            // Number of words to test
    parameter logic [31:0] BASE_ADDR      = 32'h1000,     // Base address for testing
    parameter logic [31:0] TEST_PATTERN   = 32'hA5F3895A  // Base test pattern
) (
    input  logic clk_i,
    input  logic rst_ni,

    // Status outputs
    output logic                    busy_o,         // Master is performing operations
    output logic                    test_done_o,    // Test sequence completed
    output logic                    test_pass_o,    // All tests passed
    output logic [7:0]              error_count_o,  // Number of errors detected

    // OBI interface
    output logic                    obi_req_o,      // Request
    input  logic                    obi_gnt_i,      // Grant
    output logic [  ADDR_WIDTH-1:0] obi_addr_o,     // Address
    output logic                    obi_we_o,       // Write enable
    output logic [DATA_WIDTH/8-1:0] obi_be_o,       // Byte enables
    output logic [  DATA_WIDTH-1:0] obi_wdata_o,    // Write data

    input  logic                    obi_rvalid_i,   // Read valid
    input  logic [  DATA_WIDTH-1:0] obi_rdata_i     // Read data
);

    // State machine for autonomous operation
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        WRITE_REQ   = 3'b001,
        WRITE_WAIT  = 3'b010,
        READ_REQ    = 3'b011,
        READ_WAIT   = 3'b100,
        DONE        = 3'b110
    } state_e;

    state_e state_q, state_d;

    // Internal control registers
    logic [$clog2(NUM_TEST_WORDS):0] word_count_q, word_count_d;  // For address generation
    logic [$clog2(NUM_TEST_WORDS):0] verify_count_q;              // For response verification
    logic [7:0]                      error_count_q;
    logic [2:0]                      wait_count_q, wait_count_d;  // For WRITE_WAIT delay
    logic [31:0]                     current_addr;
    logic [31:0]                     current_wdata;
    logic [31:0]                     expected_rdata;
    logic                            all_done_q, all_done_d;

    // Generate test data and addresses
    assign current_addr   = BASE_ADDR + (word_count_q << 2);     // Word-aligned addresses
    assign current_wdata  = TEST_PATTERN ^ {word_count_q, word_count_q, word_count_q, word_count_q};
    assign expected_rdata = TEST_PATTERN ^ {verify_count_q, verify_count_q, verify_count_q, verify_count_q};

    // State register
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q       <= IDLE;
            word_count_q  <= '0;
            wait_count_q  <= '0;
            all_done_q    <= 1'b0;
        end else begin
            state_q       <= state_d;
            word_count_q  <= word_count_d;
            wait_count_q  <= wait_count_d;
            all_done_q    <= all_done_d;
        end
    end

    // Next state logic
    always_comb begin
        // Default values - maintain current state
        state_d       = state_q;
        word_count_d  = word_count_q;
        wait_count_d  = wait_count_q;
        all_done_d    = all_done_q;
        case (state_q)
            IDLE: begin
                // Automatically start test sequence after reset
                if (!all_done_q) begin
                    state_d = WRITE_REQ;
                end
            end

            WRITE_REQ: begin
                if (obi_gnt_i) begin
                    // Move to next word or switch to read phase
                    if (word_count_q == NUM_TEST_WORDS - 1) begin
                        word_count_d  = '0;
                        state_d       = WRITE_WAIT;
                    end else begin
                        word_count_d  = word_count_q + 1;
                        // Stay in WRITE_REQ to continue writing
                    end
                end
            end

            WRITE_WAIT: begin
                // Wait for 2 cycles to separate write and read rvalid responses
                if (wait_count_q >= 3'd1) begin  // Wait for 2 cycles (0, 1)
                    wait_count_d = '0;
                    state_d = READ_REQ;
                end else begin
                    wait_count_d = wait_count_q + 1;
                end
            end

            READ_REQ: begin
                if (obi_gnt_i) begin
                    // Move to next word or finish read requests
                    if (word_count_q == NUM_TEST_WORDS - 1) begin
                        word_count_d = '0;  // Reset for next phase
                        state_d      = READ_WAIT;
                    end else begin
                        word_count_d = word_count_q + 1;
                        // Stay in READ_REQ to continue reading
                    end
                end
            end

            READ_WAIT: begin
                // Just wait for all responses to be verified
                if (verify_count_q >= NUM_TEST_WORDS - 1) begin
                    all_done_d = 1'b1;
                    state_d    = DONE;
                end
            end

            DONE: begin
                // Test sequence completed, stay here
                state_d = DONE;
            end

            default: state_d = IDLE;
        endcase
    end

    // Parallel verification process - happens whenever obi_rvalid_i is high
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            verify_count_q <= '0;
            error_count_q <= '0;
        end else begin
            if (obi_rvalid_i && (state_q == READ_REQ || state_q == READ_WAIT)) begin
                // Check if read data matches expected
                if (obi_rdata_i != expected_rdata) begin
                    error_count_q <= error_count_q + 1;
                end
                
                // Increment verification counter
                verify_count_q <= verify_count_q + 1;
            end
        end
    end

    // OBI output assignments
    assign obi_req_o    = (state_q == WRITE_REQ) || (state_q == READ_REQ);
    assign obi_addr_o   = current_addr;
    assign obi_we_o     = (state_q == WRITE_REQ);
    assign obi_be_o     = 4'hF;  // Always full word accesses
    assign obi_wdata_o  = current_wdata;

    // Status outputs
    assign busy_o        = !all_done_q && (state_q != IDLE);
    assign test_done_o   = all_done_q;
    assign test_pass_o   = all_done_q && (error_count_q == 0);
    assign error_count_o = error_count_q;

endmodule
