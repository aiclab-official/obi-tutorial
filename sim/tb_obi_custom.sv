// -----------------------------------------------------------------------------
// Project:      OBI Tutorial
// Company:      AICLAB
// 
// Module:       tb_obi_custom
// Description:
//   Testbench for custom OBI master and slave interaction.
//
//
// Test Coverage:
//   - Multiple transactions
// -----------------------------------------------------------------------------

module tb_obi_custom;

// Test parameters
localparam time CyclTime = 10ns;

// Clock and reset
logic clk, rst_n;

// OBI signals between master and slave
logic        obi_req, obi_gnt, obi_we, obi_rvalid, obi_err;
logic [31:0] obi_addr, obi_wdata, obi_rdata;
logic [3:0]  obi_be;

// Master status signals
logic        busy, test_done, test_pass;
logic [7:0]  error_count;

// Clock generation
initial begin
    clk = 0;
    forever #(CyclTime/2) clk = ~clk;
end

// Reset generation
initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
end

// Autonomous OBI Master - performs self-test
obi_master_custom #(
    .NUM_TEST_WORDS ( 8         ),
    .BASE_ADDR      ( 32'h100   ),
    .TEST_PATTERN   ( 32'hA5A5A5A5 )
) i_master (
    .clk_i         ( clk        ),
    .rst_ni        ( rst_n      ),
    .busy_o        ( busy       ),
    .test_done_o   ( test_done  ),
    .test_pass_o   ( test_pass  ),
    .error_count_o ( error_count),
    .obi_req_o     ( obi_req    ),
    .obi_gnt_i     ( obi_gnt    ),
    .obi_addr_o    ( obi_addr   ),
    .obi_we_o      ( obi_we     ),
    .obi_be_o      ( obi_be     ),
    .obi_wdata_o   ( obi_wdata  ),
    .obi_rvalid_i  ( obi_rvalid ),
    .obi_rdata_i   ( obi_rdata  )
);

// Simple OBI Slave
obi_slave_custom #(
    .MEM_SIZE ( 1024 )
) i_slave (
    .clk_i        ( clk       ),
    .rst_ni       ( rst_n     ),
    .obi_req_i    ( obi_req   ),
    .obi_gnt_o    ( obi_gnt   ),
    .obi_addr_i   ( obi_addr  ),
    .obi_we_i     ( obi_we    ),
    .obi_be_i     ( obi_be    ),
    .obi_wdata_i  ( obi_wdata ),
    .obi_rvalid_o ( obi_rvalid),
    .obi_rdata_o  ( obi_rdata ),
    .obi_err_o    ( obi_err   )
);

// Main test sequence - monitor autonomous operation
initial begin
    // Wait for reset
    @(posedge rst_n);
    
    $display("\n=== Custom OBI Master + Slave Test ===");
    $display("Master will autonomously test slave memory...");
    
    // Wait for master to start
    wait(busy);
    $display("✓ Master started autonomous test sequence");
    
    // Wait for test completion
    wait(test_done);
    
    // Report results
    $display("\n=== Test Results ===");
    if (test_pass) begin
        $display("✓ SUCCESS: All memory tests passed!");
        $display("✓ Master-Slave communication working correctly");
    end else begin
        $display("✗ FAILURE: %0d errors detected", error_count);
        $display("✗ Check memory interface or data integrity");
    end
    
    repeat(10) @(posedge clk);
    $display("Test completed at time %0t", $time);
    $finish;
end

// Transaction monitor - simplified output
always_ff @(posedge clk) begin
    if (obi_req && obi_gnt) begin
        if (obi_we) begin
            $display("[%0t] Write: addr=0x%x, data=0x%x, be=0x%x", 
                     $time, obi_addr, obi_wdata, obi_be);
        end else begin
            $display("[%0t] Read:  addr=0x%x", $time, obi_addr);
        end
    end
    
    if (obi_rvalid) begin
        $display("[%0t] Response: data=0x%x, err=%b", $time, obi_rdata, obi_err);
    end
end

// Status monitor

// Status monitor (avoid $past, use local registers)
initial begin
    static logic prev_busy = 0;
    static logic prev_test_done = 0;
    forever begin
        @(posedge clk);
        if (busy && !prev_busy) begin
            $display("[%0t] Master: Starting test sequence", $time);
        end
        if (test_done && !prev_test_done) begin
            $display("[%0t] Master: Test sequence completed", $time);
        end
        prev_busy = busy;
        prev_test_done = test_done;
    end
end

// Safety timeout
initial begin
    #(1000 * CyclTime);
    $error("Test timeout - master may be stuck!");
    $finish;
end

endmodule
    